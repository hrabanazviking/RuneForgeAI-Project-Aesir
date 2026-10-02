#!/usr/bin/env python3
"""Bounded streaming complete post-prefill decode quality; never a speed score."""
import argparse
from array import array
import csv
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import stat
import struct

from launch import digest
from check_turing_activations import f32
from check_llama3_logits import compare_case, VOCABULARY, MAX_ABSOLUTE_ERROR, MAX_RMS_ERROR
from check_turing_model_prefill import provenance

MAX_BYTES = 2 * 1024**3
MAX_LINE = 1024
MAX_FRAMES = 96
INPUT_COUNTS = (37, 37, 1070, 1070)
INPUT_HASHES = (
    "e61b3c3d28d99afdf68208dc9abe07282160e483ba366ed32245835ff1401c38",
    "45a55697a8cd61453b2ad626ef6847bba7079591035de35bc327a541b0885766")
EOS = (128001, 128009)


class Records:
    """One bounded line at a time on the same no-follow regular descriptor."""
    def __init__(self, path, maximum=None):
        self.maximum = MAX_BYTES if maximum is None else maximum
        if type(self.maximum) is not int or not 1 <= self.maximum <= MAX_BYTES:
            raise ValueError("Invalid bounded stream allowance")
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        self.source = os.fdopen(fd, "rb")
        try:
            self.before = os.fstat(fd)
            if not stat.S_ISREG(self.before.st_mode) or not 0 < self.before.st_size <= self.maximum:
                raise ValueError("Decode stream must be a bounded regular file")
        except BaseException:
            self.source.close()
            raise
        self.hash = hashlib.sha256()
        self.bytes = 0

    def close(self):
        self.source.close()

    def next(self, optional=False):
        line = self.source.readline(MAX_LINE + 1)
        if not line:
            if optional: return None
            raise ValueError("Incomplete decode evidence")
        self.bytes += len(line)
        if len(line) > MAX_LINE or self.bytes > self.maximum or not line.endswith(b"\n"):
            raise ValueError("Decode line/stream exceeded bounds or lacks newline")
        self.hash.update(line)
        row = next(csv.reader([line.decode("utf-8", errors="strict")], strict=True))
        if not row or len(row) > 16 or any(len(field) > 256 for field in row):
            raise ValueError("Invalid bounded decode fields")
        return row

    def expect(self, expected):
        if self.next() != expected: raise ValueError("Wrong ordered decode record: " + expected[0])

    def finish(self):
        if self.next(optional=True) is not None: raise ValueError("Trailing decode evidence")
        after = os.fstat(self.source.fileno())
        if (after.st_size, after.st_mtime_ns) != (self.before.st_size, self.before.st_mtime_ns) or self.bytes != after.st_size:
            raise ValueError("Decode stream changed during admission")
        return self.hash.hexdigest()


def integer(value, low, high):
    if not re.fullmatch(r"0|[1-9][0-9]*", value): raise ValueError("Noncanonical decode integer")
    number = int(value)
    if not low <= number <= high: raise ValueError("Decode integer outside declared bounds")
    return number


def policy_rows(records):
    for index, floats, seed in ((0, (0, .95, 0, 1), 42), (1, (.7, .9, .05, 1.1), 1234)):
        row = records.next()
        if len(row) != 9 or row[:2] != ["POLICY", str(index)] or row[3] != "40" or row[7:] != ["64", str(seed)]:
            raise ValueError("Unknown or altered sampling policy")
        actual = [f32(row[i]) for i in (2, 4, 5, 6)]
        expected = [struct.unpack("<f", struct.pack("<f", v))[0] for v in floats]
        if any(struct.pack("<f", a) != struct.pack("<f", b) for a, b in zip(actual, expected)):
            raise ValueError("Sampling F32 policy mismatch")


def state(row, label, index, step, count, choice):
    if len(row) != 13 or row[:3] != [label, str(index), str(step)]:
        raise ValueError("Wrong decode frame identity/order")
    values = [integer(v, 0, max(VOCABULARY, 1536)) for v in row[3:]]
    native, matrix, np, mp, nh, mh, nd, md, nb, mb = values
    draws = step + 1 if choice else 0
    if (np, mp, nh, mh, nd, md) != (count + step, count + step, count + step, count + step, draws, draws):
        raise ValueError("Decode causal position/history/draw mismatch")
    if native >= VOCABULARY or matrix >= VOCABULARY or nb > VOCABULARY or mb > VOCABULARY:
        raise ValueError("Decode chosen ID or bit mismatch count outside vocabulary")
    if choice and any(v >= 128000 and v not in EOS for v in (native, matrix)):
        raise ValueError("Seeded sampler selected a forbidden reserved token")
    if label == "STEP" and (nb or mb): raise ValueError("First-round replay differences are invalid")
    return dict(native_choice=native, matrix_choice=matrix, position=np, history=nh, draws=nd,
                native_replay_bit_mismatches=nb, matrix_replay_bit_mismatches=mb)


def vectors(records, index, step):
    native, matrix = array("f"), array("f")
    for token in range(VOCABULARY):
        row = records.next()
        if len(row) != 6 or row[:4] != ["LOGIT", str(index), str(step), str(token)]:
            raise ValueError("Incomplete/duplicate/out-of-order complete decode vector")
        native.append(f32(row[4])); matrix.append(f32(row[5]))
    return native, matrix


def case(records, report, index, oracle):
    count, choice = INPUT_COUNTS[index], index % 2
    cap = 16 if choice else 32
    records.expect(["CASE", str(index), str(count), str(choice), str(cap)])
    ids = []
    for ordinal in range(count):
        row = records.next()
        if len(row) != 4 or row[:3] != ["INPUT", str(index), str(ordinal)]: raise ValueError("Wrong ordered decode input")
        ids.append(integer(row[3], 0, VOCABULARY - 1))
    identity = hashlib.sha256(b"".join(struct.pack("<I", token) for token in ids)).hexdigest()
    if identity != INPUT_HASHES[index // 2]: raise ValueError("Public decode input identity changed")
    result = dict(index=index, input_ids=ids, input_sha256=identity, policy=choice, cap=cap, frames=[], replay=[])
    report["cases"].append(result)
    if oracle is not None: oracle.begin(ids)
    row = records.next()
    for step in range(cap):
        observed = state(row, "STEP", index, step, count, choice)
        records.expect(["CAUSAL", str(index), str(step), str(count + step), "0"])
        native, matrix = vectors(records, index, step)
        comparison = compare_case(matrix, native)
        observed.update(native_comparison=comparison, sample_equal=observed["native_choice"] == observed["matrix_choice"])
        observed["greedy_argmax_passed"] = bool(choice) or (observed["native_choice"] == comparison["reference_argmax"] and observed["matrix_choice"] == comparison["native_argmax"])
        if oracle is not None:
            expected = oracle.expected(count + step)
            observed["independent"] = dict(native=compare_case(native, expected), matrix=compare_case(matrix, expected))
        result["frames"].append(observed)
        del native, matrix
        row = records.next()
        if row[0] == "END": break
        if observed["native_choice"] in EOS or step + 1 >= cap: raise ValueError("Decode continued beyond EOS or cap")
        if oracle is not None: oracle.advance(observed["native_choice"])
    frames = len(result["frames"])
    finish = "eos" if result["frames"][-1]["native_choice"] in EOS else "length"
    if row != ["END", str(index), str(frames), finish] or finish == "length" and frames != cap:
        raise ValueError("Decode actual completion/finish mismatch")
    result.update(evaluated_frames=frames, finish_reason=finish)
    for step, first in enumerate(result["frames"]):
        again = state(records.next(), "REPLAY", index, step, count, choice)
        records.expect(["CAUSAL", str(index), str(step), str(count + step), "0"])
        again["passed"] = (again["native_choice"], again["matrix_choice"]) == (first["native_choice"], first["matrix_choice"]) and again["native_replay_bit_mismatches"] == again["matrix_replay_bit_mismatches"] == 0
        result["replay"].append(again)
    records.expect(["REPLAY_END", str(index), str(frames), finish])
    records.expect(["GUARD", str(index), "1088", "0"])


def initial_report():
    return dict(schema=1, passed=False, collection_complete=False, speed_scored=False, activation_precision=0,
                numerical_budget=dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True),
                cases=[], limits="Test-only strict3B/context1536/F16KV on native-forced causal IDs. Public37/1070 prefixes; greedy32 and seeded16 caps; exact own replay. Sample equality covers these cases only. No speed/provider score, free-running matrix trajectory, persisted restoration, production32 admission or concurrency claim.")


def parse(path, oracle=None, report=None):
    report = initial_report() if report is None else report
    records = Records(path)
    try:
        cuda = records.next()
        if len(cuda) != 1 or not cuda[0].startswith("[CUDA] native Mojo ") or "api=cuda" not in cuda[0] or "cpu_offload=0" not in cuda[0]:
            raise ValueError("Missing actual native CUDA identity")
        report["native_banner"] = cuda[0]
        records.expect(["META", "1", "turing_decode", "1536", str(VOCABULARY), "4", "2"])
        policy_rows(records)
        for index in range(4): case(records, report, index, oracle)
        total = sum(c["evaluated_frames"] for c in report["cases"])
        if not 4 <= total <= MAX_FRAMES: raise ValueError("Decode frame bound exceeded")
        records.expect(["COMPLETE", "turing_decode", "4", str(total), str(total * VOCABULARY), "4352", "2"])
        report.update(csv_sha256=records.finish(), csv_bytes=records.bytes, collection_complete=True,
                      evaluated_frames=total, full_model_values_per_mode=total * VOCABULARY, guards=4352)
        score(report)
        return report
    finally:
        records.close()


def score(report):
    frames = [frame for c in report["cases"] for frame in c["frames"]]
    report["native_quality_passed"] = bool(frames) and all(f["native_comparison"]["passed"] and f["sample_equal"] and f["greedy_argmax_passed"] for f in frames)
    report["replay_passed"] = bool(frames) and all(r["passed"] for c in report["cases"] for r in c["replay"])
    report["independent_reference_passed"] = bool(frames) and all("independent" in f and all(v["passed"] for v in f["independent"].values()) for f in frames)
    report["passed"] = report["collection_complete"] and report["native_quality_passed"] and report["replay_passed"] and report["independent_reference_passed"]
    if not report["passed"]: report["error"] = "Complete fixed decode quality/replay/independent gate failed"
    else: report.pop("error", None)


class CPUReference:
    def __init__(self, model):
        import numpy as np
        import llama_cpp
        if np.__version__ != "2.4.4" or llama_cpp.__version__ != "0.3.23": raise ValueError("Pinned optional reference versions required")
        library = Path(importlib.import_module("llama_cpp.llama_cpp")._lib._name)
        self.identity = dict(llama_cpp_python=llama_cpp.__version__, numpy=np.__version__, library_sha256=digest(library), requested_gpu_layers=0,
                             context=4096, kv="f16", batch=128, threads=4, weight_mode="dequantized_f32")
        self.cpu = llama_cpp.Llama(model_path=str(model), n_ctx=4096, n_batch=128, n_gpu_layers=0, n_threads=4, n_threads_batch=4,
                                  type_k=llama_cpp.GGML_TYPE_F16, type_v=llama_cpp.GGML_TYPE_F16, logits_all=True, flash_attn=False, verbose=False)
        try:
            if self.cpu.metadata.get("general.file_type") != "0" or self.cpu.n_vocab() != VOCABULARY:
                raise ValueError("Independent reference is not the declared F32 model")
        except BaseException:
            self.cpu.close()
            raise

    def begin(self, ids):
        self.cpu.reset(); self.cpu.eval(ids)

    def expected(self, position):
        return self.cpu.scores[position - 1].astype("float64")

    def advance(self, token):
        self.cpu.eval([token])

    def close(self):
        self.cpu.close()


def main():
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("csv", type=Path)
    for name in ("model", "reference-model", "reference-provenance", "output"): options.add_argument("--" + name, type=Path, required=True)
    for name in ("model-sha256", "reference-sha256"): options.add_argument("--" + name, required=True)
    args = options.parse_args()
    if any(not re.fullmatch(r"[0-9a-f]{64}", v) for v in (args.model_sha256, args.reference_sha256)): options.error("Explicit lowercase SHA-256 identities required")
    with args.output.open("x", encoding="utf-8") as output:
        report = initial_report(); oracle = None
        try:
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256: raise ValueError("Original/derived model checksum mismatch")
            derived = provenance(args.reference_provenance, args.model_sha256, args.reference_sha256)
            if args.reference_model.stat().st_size != derived["derived_bytes"]: raise ValueError("Derived reference size mismatch")
            report.update(model_sha256=args.model_sha256, reference_derivation=derived)
            oracle = CPUReference(args.reference_model)
            report["independent_reference"] = oracle.identity
            parse(args.csv, oracle, report)
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256: raise ValueError("Original/derived model changed during oracle")
        except (Exception, KeyboardInterrupt) as error:
            report.update(passed=False, error=f"{type(error).__name__}: {error}")
        finally:
            if oracle is not None:
                try: oracle.close()
                except Exception as error: report.update(passed=False, error=f"Reference cleanup failed: {type(error).__name__}: {error}")
        json.dump(report, output, indent=2, allow_nan=False); output.write("\n")
    print("PASS: complete decode quality and replay" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
