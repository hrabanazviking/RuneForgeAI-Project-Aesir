#!/usr/bin/env python3
"""Strict native matrix CSV admission and optional independent real-weight dots."""
import argparse
from array import array
import csv
import importlib.metadata
import json
import math
from pathlib import Path
import statistics
import hashlib

from launch import digest
from profile_native_cuda import read_text

NAMES = ("blk.0.attn_q.weight", "blk.0.attn_k.weight", "blk.0.attn_v.weight",
         "blk.0.attn_output.weight", "blk.0.ffn_gate.weight", "blk.0.ffn_up.weight",
         "blk.0.ffn_down.weight")
BATCHES = (4, 8, 16, 32)
MAX_ERROR = 0.002
MAX_RMS = 0.0002


def number(value):
    result = float(value)
    if not math.isfinite(result):
        raise ValueError("Nonfinite matrix evidence")
    return result


def parse(path):
    # CSV size bound before reading prevents FIFO/symlink and unbounded admission.
    text = read_text(path, 256 * 1024 * 1024)
    import io
    cases = []
    synthetic = False
    cuda = False
    complete = False
    tile = (32, 32)
    tile_seen = False
    candidate = "simt_shared"
    mode_seen = False
    staged_input_columns = None
    snapshot_sha256 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    for row in csv.reader(io.StringIO(text)):
        if row and row[0].startswith("[CUDA]") and not synthetic:
            if cuda or "api=cuda" not in row[0] or "cpu_offload=0" not in row[0]:
                raise ValueError("Wrong native backend")
            cuda = True
            continue
        if complete or not row:
            raise ValueError("Unexpected trailing/empty matrix record")
        tag = row[0]
        if row == ["MODE", "turing_mma_split_weight_f16_f32"] and not synthetic and not mode_seen and not tile_seen:
            candidate = row[1]; mode_seen = True; tile = (16, 8)
        elif tag == "MODE" and len(row) == 3 and row[1] == "turing_mma_staged_f16_f32" and not synthetic and not mode_seen and not tile_seen:
            staged_rows = int(row[2])
            if staged_rows not in (16, 32, 64):
                raise ValueError("Unsupported staged Turing rows")
            candidate = row[1]; mode_seen = True; tile = (staged_rows, 8); staged_input_columns = 32
        elif tag == "MODE" and len(row) == 4 and row[1] == "turing_mma_staged_wide_f16_f32" and not synthetic and not mode_seen and not tile_seen:
            staged_rows, staged_columns = map(int, row[2:])
            if staged_rows not in (32,64) or staged_columns not in (64,128) or (2*staged_rows+32)*(staged_columns+1)*2 > 49152:
                raise ValueError("Unsupported wide Turing geometry")
            candidate = row[1]; mode_seen = True; tile = (staged_rows,8); staged_input_columns = staged_columns
        elif tag == "TILE" and len(row) == 3 and not synthetic and not tile_seen and not mode_seen:
            tile = tuple(map(int, row[1:]))
            if tile[0] not in (8, 16, 32) or tile[1] not in (32, 64, 128) or (tile[0] + 32) * (tile[1] + 1) * 4 > 49152:
                raise ValueError("Unsupported matrix tile")
            tile_seen = True
        elif tag == "SYNTHETIC" and row == ["SYNTHETIC", "144", "0"] and not synthetic:
            synthetic = True
        elif tag == "CASE" and len(row) == 8 and synthetic:
            index = int(row[1]); kind, columns, rows, batch, offset = map(int, row[3:])
            if index != len(cases) or index >= 28 or row[2] != NAMES[index % 7] or batch != BATCHES[index // 7]:
                raise ValueError("Matrix case identity/order mismatch")
            if kind not in (12, 14) or not 256 <= columns <= 14336 or columns % 256 or not 1 <= rows <= 128256 or offset < 0:
                raise ValueError("Invalid matrix shape")
            if cases:
                validate(cases[-1])
            cases.append({"index": index, "name": row[2], "kind": kind, "columns": columns,
                          "rows": rows, "batch": batch, "offset": offset, "tile": tile,
                          "candidate": candidate, "csv_sha256": snapshot_sha256,
                          "staged_input_columns": staged_input_columns,
                          "reference": array("d"), "actual": array("d"), "timings": {}, "guards": None})
        elif tag == "VALUE" and len(row) == 6 and cases:
            c = cases[-1]; index, token, r = map(int, row[1:4])
            position = len(c["actual"])
            if index != c["index"] or token != position // c["rows"] or r != position % c["rows"] or position >= c["rows"] * c["batch"] or c["guards"] is not None:
                raise ValueError("Duplicate/out-of-order/late matrix value")
            c["reference"].append(number(row[4])); c["actual"].append(number(row[5]))
        elif tag == "GUARD" and len(row) == 4 and cases:
            c = cases[-1]
            if int(row[1]) != c["index"] or int(row[2]) < 1 or row[3] != "0" or c["guards"] is not None or len(c["actual"]) != c["rows"] * c["batch"]:
                raise ValueError("Incomplete/failed guard evidence")
            c["guards"] = int(row[2])
        elif tag == "TIME" and len(row) == 6 and cases:
            c = cases[-1]; index, mode, sample, iterations = map(int, row[1:5]); value = number(row[5])
            if c["guards"] is None or index != c["index"] or mode not in (0, 1) or not 0 <= sample < 10 or iterations != 3 or value <= 0 or (mode, sample) in c["timings"]:
                raise ValueError("Invalid or duplicate matrix timing")
            c["timings"][mode, sample] = value / iterations
        elif tag == "PASS" and len(row) == 5 and len(cases) == 28:
            if row[1] != "matrix" or list(map(int, row[2:])) != [28, sum(len(c["actual"]) for c in cases), 560]:
                raise ValueError("Matrix completion totals mismatch")
            validate(cases[-1]); complete = True
        else:
            raise ValueError("Unexpected matrix CSV record")
    if not complete or not cuda:
        raise ValueError("Missing complete matrix marker")
    return cases


def errors(actual, expected):
    if not len(actual) or len(actual) != len(expected):
        raise ValueError("Invalid matrix comparison shape")
    maximum = 0; total = 0
    for a, b in zip(actual, expected):
        if not math.isfinite(a) or not math.isfinite(b):
            raise ValueError("Nonfinite matrix comparison")
        error = abs(a - b) / (1 + abs(b))
        maximum = max(maximum, error); total += error * error
    rms = math.sqrt(total / len(actual))
    return {"maximum_scaled_error": maximum, "normalized_rms": rms,
            "passed": maximum <= MAX_ERROR and rms <= MAX_RMS}


def validate(c):
    if c["guards"] is None or len(c["actual"]) != c["rows"] * c["batch"] or len(c["timings"]) != 20:
        raise ValueError("Incomplete matrix case")
    if not errors(c["actual"], c["reference"])["passed"]:
        raise ValueError("Native matrix reference budget failed")


def independent(cases, model):
    # Test-only imports; never supply native runtime inference.
    if importlib.metadata.version("gguf") != "0.19.0" or importlib.metadata.version("numpy") != "2.4.4":
        raise ValueError("Independent oracle requires gguf0.19.0 / NumPy2.4.4")
    import numpy as np
    from gguf import GGUFReader
    from gguf.quants import dequantize
    from gguf.constants import GGMLQuantizationType, GGML_QUANT_SIZES
    reader = GGUFReader(str(model))
    tensors = {t.name: t for t in reader.tensors}
    result = []
    for c in cases:
        t = tensors[c["name"]]
        if tuple(map(int, t.shape)) != (c["columns"], c["rows"]) or int(t.tensor_type) != c["kind"] or t.data_offset != c["offset"]:
            raise ValueError("Independent GGUF descriptor mismatch")
        kind = GGMLQuantizationType(c["kind"])
        block, size = GGML_QUANT_SIZES[kind]
        selected = sorted({0, 1, 17, c["rows"] // 2, c["rows"] - 1})
        expected = []; actual = []; native = []
        activations = (((np.arange(c["columns"], dtype=np.int64)[None, :] * 7 +
                        np.arange(c["batch"], dtype=np.int64)[:, None] * 13) % 29 - 14) / 16).astype(np.float64)
        # Index/dequantization is supplied by independent upstream gguf code.
        for row in selected:
            encoded = t.data.reshape(c["rows"], c["columns"] // block * size)[row:row + 1]
            weights = dequantize(encoded, kind).reshape(-1).astype(np.float64)
            dots = activations @ weights
            for token in range(c["batch"]):
                expected.append(float(dots[token])); actual.append(c["actual"][token * c["rows"] + row]); native.append(c["reference"][token * c["rows"] + row])
        result.append({"case": c["index"], "rows": selected, "outputs": len(actual),
                       "candidate": errors(actual, expected), "reference": errors(native, expected)})
    # Memmaps are read-only; do not modify source model or publisher artifacts.
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("csv", type=Path); p.add_argument("--model", type=Path, required=True)
    p.add_argument("--model-sha256", required=True); p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    with a.output.open("x", encoding="utf-8") as stream:
        report = {"schema": 1, "passed": False, "full_model_speed_claim": False}
        try:
            if digest(a.model) != a.model_sha256:
                raise ValueError("Matrix oracle source checksum mismatch")
            cases = parse(a.csv); oracle = independent(cases, a.model)
            if not all(r["candidate"]["passed"] and r["reference"]["passed"] for r in oracle):
                raise ValueError("Independent real-weight primitive budget failed")
            report.update(tile_rows=cases[0]["tile"][0], tile_columns=cases[0]["tile"][1],
                          candidate=cases[0]["candidate"],
                          tile_rows_meaning="CTA weight rows" if cases[0]["candidate"] != "turing_mma_split_weight_f16_f32" else "warp weight rows",
                          tile_columns_meaning="output token columns" if cases[0]["candidate"] != "simt_shared" else "staged input columns",
                          staged_input_columns=cases[0]["staged_input_columns"],
                          model_sha256=a.model_sha256, csv_sha256=cases[0]["csv_sha256"], oracle=oracle,
                          native_outputs=sum(len(c["actual"]) for c in cases), independent_outputs=sum(r["outputs"] for r in oracle),
                          limits="Primitive evidence only. Five selected real rows per tensor/batch; full native-reference output coverage. Host-monotonic launch/synchronize timing, warmed weights, one physical session. No model-level quality/speed or default dispatch change.")
            summary = []
            for c in cases:
                baseline = [c["timings"][0, i] for i in range(10)]
                candidate = [c["timings"][1, i] for i in range(10)]
                summary.append({"name": c["name"], "batch": c["batch"], "rows": c["rows"], "columns": c["columns"],
                                "reference_seconds": baseline, "candidate_seconds": candidate,
                                "speed_ratio": statistics.median(baseline) / statistics.median(candidate),
                                "native_error": errors(c["actual"], c["reference"]), "guards": c["guards"]})
            report.update(passed=True, cases=summary)
        except Exception as error:
            report["error"] = f"{type(error).__name__}: {error}"
        json.dump(report, stream, indent=2); stream.write("\n")
    print("PASS: matrix primitive evidence" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
