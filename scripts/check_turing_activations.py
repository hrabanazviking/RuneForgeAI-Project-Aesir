#!/usr/bin/env python3
"""Complete ordinary native F32 operand admission and independent projection gate."""
import argparse
from array import array
import csv
import hashlib
import importlib.metadata
import io
import json
import math
from pathlib import Path
import struct

from launch import digest
from profile_native_cuda import read_text
from check_packed_matrix import errors, NAMES

TENSORS = tuple(name.replace("blk.0.", "blk.27.") for name in NAMES)
SOURCE_IDS = (0, 0, 0, 1, 0, 0, 2)


def f32(text):
    value = float(text)
    if not math.isfinite(value) or struct.unpack("f", struct.pack("f", value))[0] != value:
        raise ValueError("Activation evidence is not an exact finite F32 value")
    return value


def source(reader, state, identity):
    row = next(reader)
    if len(row) != 5 or row[:3] != ["SOURCE", str(state), str(identity)] or row[4] != "4":
        raise ValueError("Activation source identity/order mismatch")
    width = int(row[3])
    if not 256 <= width <= 14336 or width % 256:
        raise ValueError("Activation source width exceeds bounds")
    values = array("d")
    for position in range(4 * width):
        row = next(reader)
        if len(row) != 6 or row[:5] != ["ACT", str(state), str(identity), str(position // width), str(position % width)]:
            raise ValueError("Incomplete/duplicate/out-of-order activation source")
        values.append(f32(row[5]))
    return values


def case(reader, state, index, sources):
    row = next(reader)
    if len(row) != 10 or row[:4] != ["CASE", str(index), str(state), TENSORS[index % 7]]:
        raise ValueError("Activation case identity/order mismatch")
    kind, columns, rows, batch, offset, identity = map(int, row[4:])
    if (kind not in (12, 14) or batch != (4 if index % 14 < 7 else 32) or
        identity != SOURCE_IDS[index % 7] or not 1 <= rows <= 128256 or offset < 0 or
        columns * 4 != len(sources[state, identity])):
        raise ValueError("Activation case descriptor/source mismatch")
    result = dict(index=index, state=state, name=row[3], kind=kind, columns=columns,
                  rows=rows, batch=batch, offset=offset, source=identity,
                  actual=array("d"), reference=array("d"))
    for position in range(rows * batch):
        row = next(reader)
        if len(row) != 6 or row[:4] != ["VALUE", str(index), str(position // rows), str(position % rows)]:
            raise ValueError("Incomplete/duplicate/out-of-order activation output")
        result["reference"].append(f32(row[4])); result["actual"].append(f32(row[5]))
    span = (rows + 31) // 32 * 32
    guards = batch * (columns + 2 * span + 43 - 2 * rows)
    if next(reader) != ["GUARD", str(index), str(guards), "0"]:
        raise ValueError("Activation whole-span guards incomplete or failed")
    row = next(reader)
    numeric = errors(result["actual"], result["reference"])
    if len(row) != 4 or row[:2] != ["METRIC", str(index)]:
        raise ValueError("Missing native activation budget metrics")
    for value, key in zip(row[2:], ("maximum_scaled_error", "normalized_rms")):
        if not math.isfinite(float(value)) or not math.isclose(float(value), numeric[key], rel_tol=1e-12, abs_tol=1e-15):
            raise ValueError("Declared activation metric disagrees with complete values")
    result.update(guards=guards, native_error=numeric)
    return result


def parse(path):
    text = read_text(path, 256 * 1024 * 1024)
    if len(text.encode("utf-8")) > 256 * 1024 * 1024:
        raise ValueError("Activation CSV grew beyond byte admission")
    reader = iter(csv.reader(io.StringIO(text)))
    cuda = next(reader)
    if not cuda or not cuda[0].startswith("[CUDA]") or "api=cuda" not in cuda[0] or "cpu_offload=0" not in cuda[0]:
        raise ValueError("Missing actual native CUDA identity")
    meta = next(reader); precision = 0
    if meta == ["META", "1", "turing_native_f32", "64", "32", "12"]:
        pass
    elif len(meta) == 7 and meta[:5] == ["META", "1", "turing_native_f32_split", "64", "32"] and meta[5] in ("1", "2") and meta[6] == "12":
        precision = int(meta[5])
    else:
        raise ValueError("Wrong activation mode or invalid-span count")
    sources = {}; states = []; cases = []
    for state in range(2):
        row = next(reader)
        if len(row) < 7 or row[:2] != ["STATE", str(state)]:
            raise ValueError("Activation replay state identity/order mismatch")
        position = int(row[2]); tokens = list(map(int, row[3:]))
        if len(tokens) != position or not 4 <= position <= 512 or position % 4 or any(not 0 <= t < 128256 for t in tokens):
            raise ValueError("Activation replay position/token bounds mismatch")
        states.append(dict(position=position, replayed_tokens=tokens))
        for identity in range(3):
            sources[state, identity] = source(reader, state, identity)
        if len(sources[state, 0]) != len(sources[state, 1]):
            raise ValueError("Normalized and attention source widths differ")
        for _ in range(14):
            cases.append(case(reader, state, len(cases), sources))
    outputs = sum(len(c["actual"]) for c in cases)
    inputs = sum(len(s) for s in sources.values())
    if next(reader) != ["COMPLETE", "activation", "28", str(outputs), str(inputs), "12"]:
        raise ValueError("Activation collection totals mismatch")
    if next(reader, None) is not None:
        raise ValueError("Trailing activation evidence")
    return dict(cases=cases, sources=sources, states=states, activation_precision=precision, native_outputs=outputs,
                source_values=inputs, csv_sha256=hashlib.sha256(text.encode("utf-8")).hexdigest())


def independent(data, model):
    if importlib.metadata.version("gguf") != "0.19.0" or importlib.metadata.version("numpy") != "2.4.4":
        raise ValueError("Activation oracle requires gguf0.19.0 / NumPy2.4.4")
    import numpy as np
    from gguf import GGUFReader
    from gguf.quants import dequantize
    from gguf.constants import GGMLQuantizationType, GGML_QUANT_SIZES
    reader = GGUFReader(str(model)); tensors = {t.name: t for t in reader.tensors}
    results = []
    for c in data["cases"]:
        t = tensors[c["name"]]
        if tuple(map(int, t.shape)) != (c["columns"], c["rows"]) or int(t.tensor_type) != c["kind"] or t.data_offset != c["offset"]:
            raise ValueError("Independent activation GGUF descriptor mismatch")
        kind = GGMLQuantizationType(c["kind"]); block, size = GGML_QUANT_SIZES[kind]
        selected = sorted({0, 1, 17, c["rows"] // 2, c["rows"] - 1})
        original = np.array(data["sources"][c["state"], c["source"]], dtype=np.float64).reshape(4, c["columns"])
        activations = np.tile(original, (c["batch"] // 4, 1))
        actual = []; native = []; expected = []
        for row in selected:
            encoded = t.data.reshape(c["rows"], c["columns"] // block * size)[row:row + 1]
            weights = dequantize(encoded, kind).reshape(-1).astype(np.float64)
            dots = activations @ weights
            for token in range(c["batch"]):
                expected.append(float(dots[token])); actual.append(c["actual"][token * c["rows"] + row]); native.append(c["reference"][token * c["rows"] + row])
        results.append(dict(case=c["index"], rows=selected, outputs=len(actual),
                            candidate=errors(actual, expected), reference=errors(native, expected)))
    return results


def summary(data):
    rounded = 0; overflow = 0; maximum = 0
    for values in data["sources"].values():
        for value in values:
            maximum = max(maximum, abs(value))
            try:
                rounded += struct.unpack("e", struct.pack("e", value))[0] != value
            except OverflowError:
                overflow += 1
    return dict(schema=1, passed=False, collection_complete=True, full_model_quality_claim=False,
                activation_precision=data["activation_precision"],
                speed_claim=False, csv_sha256=data["csv_sha256"], states=data["states"],
                native_outputs=data["native_outputs"], source_values=data["source_values"],
                non_f16_representable_inputs=rounded, f16_overflow_inputs=overflow,
                max_absolute_input=maximum, invalid_spans=12,
                cases=[{k: v for k, v in c.items() if k not in ("actual", "reference")} for c in data["cases"]],
                limits="Two final-layer native replay captures only. Q/K/V use representative FFN-normalized vectors; output/gate/up/down use their actual final-layer operands. Batch32 repeats four sources. Full native output coverage; independent checks select five real rows per tensor/case. No complete-model quality, timing, control/state or provider promotion.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path); parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--model-sha256", required=True); parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    with args.output.open("x", encoding="utf-8") as stream:
        report = dict(schema=1, passed=False, collection_complete=False)
        try:
            if digest(args.model) != args.model_sha256:
                raise ValueError("Activation oracle original model checksum mismatch")
            data = parse(args.csv); report = summary(data)
            report.update(model_sha256=args.model_sha256, oracle=independent(data, args.model))
            if digest(args.model) != args.model_sha256:
                raise ValueError("Activation oracle model changed during read")
            report["independent_outputs"] = sum(r["outputs"] for r in report["oracle"])
            report["passed"] = all(c["native_error"]["passed"] for c in data["cases"]) and all(r["candidate"]["passed"] and r["reference"]["passed"] for r in report["oracle"])
            if not report["passed"]:
                report["error"] = "Fixed ordinary-F32 activation precision gate failed"
        except Exception as error:
            report.update(passed=False, error=f"{type(error).__name__}: {error}")
        json.dump(report, stream, indent=2); stream.write("\n")
    print("PASS: ordinary-F32 activation gate" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
