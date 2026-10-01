"""Optional independent CPU oracle and conditional roofline for native probe CSV.

Test-only: llama-cpp-python 0.3.23 / NumPy 2.4.4. Never imported by inference.
Numerical budgets are declared in docs/SPEED_MEASUREMENT.md before comparison.
"""
from __future__ import annotations

import argparse
from array import array
import csv
import hashlib
import importlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import tempfile
from typing import Any

VOCABULARY = 128256
MAX_ABSOLUTE_ERROR = 0.05
MAX_RMS_ERROR = 0.005
COPY_BYTES = (8388611 * 4, 33554437 * 4)


def positive(value: str) -> float:
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise ValueError("Invalid positive measurement")
    return number


def parse_probe(path: Path) -> dict:
    if not path.is_file() or path.stat().st_size > 64 * 1024 * 1024:
        raise ValueError("Invalid probe file size/type")
    cases = {i: {"input_ids": [], "logits": array("f", [0]) * VOCABULARY,
                 "seen": bytearray(VOCABULARY), "timings": []} for i in range(4)}
    result = {"cases": cases, "bandwidth": [], "copy_checks": []}
    done = False
    with path.open(encoding="utf-8") as source:
        for row in csv.reader(source):
            if done:
                raise ValueError("Trailing probe data")
            if row and row[0].startswith("[CUDA] native Mojo "):
                if "api=cuda" not in row[0] or "cpu_offload=0" not in row[0] or "native_banner" in result:
                    raise ValueError("Invalid native execution banner")
                result["native_banner"] = row[0]
            elif row == ["META", "1", str(VOCABULARY), "4096", "4", "f16"]:
                if "metadata" in result:
                    raise ValueError("Duplicate probe metadata")
                result["metadata"] = row[1:]
            elif len(row) == 7 and row[0] == "TRAFFIC":
                parse_traffic(row, result)
            elif len(row) == 6 and row[0] == "BANDWIDTH":
                parse_bandwidth(row, result)
            elif len(row) == 3 and row[0] == "BANDWIDTH_CHECK":
                value = (int(row[1]), int(row[2]))
                if value in result["copy_checks"] or value not in [(n // 4, 0) for n in COPY_BYTES]:
                    raise ValueError("Invalid copy verification")
                result["copy_checks"].append(value)
            elif row and row[0] in ("INPUT", "LOGIT", "CASE"):
                parse_case(row, cases)
            elif row == ["PASS", "measurement", "4", "16", "513024"]:
                done = True
            else:
                raise ValueError("Malformed probe record")
    validate_probe(result, done)
    return result


def parse_traffic(row: list[str], result: dict) -> None:
    values = [int(x) for x in row[1:]]
    if "traffic" in result or any(x <= 0 or x >= 2**63 for x in values):
        raise ValueError("Invalid traffic accounting")
    if values[1] > values[0]:
        raise ValueError("Projection spans exceed model bytes")
    result["traffic"] = dict(zip(["file_bytes", "projection_bytes", "norm_bytes",
                                 "embedding_row_bytes", "rope_minimum_bytes",
                                 "kv_bytes_per_history_position"], values))


def parse_bandwidth(row: list[str], result: dict) -> None:
    size, index, iterations = map(int, row[1:4])
    elapsed, observed = map(positive, row[4:])
    if size not in COPY_BYTES or not 0 <= index < 10 or iterations != 10:
        raise ValueError("Unexpected bandwidth shape")
    if any(s["bytes"] == size and s["index"] == index for s in result["bandwidth"]):
        raise ValueError("Duplicate bandwidth sample")
    recomputed = size * 2 * iterations / elapsed / 1e9
    if not math.isclose(observed, recomputed, rel_tol=1e-6):
        raise ValueError("Bandwidth arithmetic mismatch")
    result["bandwidth"].append({"bytes": size, "index": index,
                                "iterations": iterations, "seconds": elapsed,
                                "read_plus_write_gb_s": recomputed})


def parse_case(row: list[str], cases: dict) -> None:
    case = int(row[1])
    if case not in cases:
        raise ValueError("Unknown model case")
    data = cases[case]
    if row[0] == "INPUT" and len(row) == 3:
        token = int(row[2])
        if not 0 <= token < VOCABULARY or len(data["input_ids"]) >= 4096 or any(data["seen"]):
            raise ValueError("Invalid or late input ID")
        data["input_ids"].append(token)
    elif row[0] == "LOGIT" and len(row) == 4:
        token, value = int(row[2]), float(row[3])
        if not 0 <= token < VOCABULARY or data["seen"][token] or not math.isfinite(value):
            raise ValueError("Invalid or duplicate model logit")
        data["logits"][token] = value
        if not math.isfinite(data["logits"][token]):
            raise ValueError("Unrepresentable F32 model logit")
        data["seen"][token] = 1
    elif row[0] == "CASE" and len(row) == 10:
        exported, prompt, generated = map(int, row[2:5])
        prefill, decode = map(positive, row[5:7])
        visible, steps = float(row[7]), int(row[8])
        if (exported not in (0, 1) or not math.isfinite(visible) or visible < 0 or visible > decode
                or prompt != len(data["input_ids"]) or not 1 <= generated <= 128
                or steps < generated or len(data["timings"]) >= 4
                or exported != int(not data["timings"]) or row[9] not in ("length", "eos")
                or row[9] == "length" and generated != 128):
            raise ValueError("Invalid actual-call timing/completion")
        data["timings"].append({"exported": bool(exported), "prompt_tokens": prompt,
                                "generated_tokens": generated, "prefill_seconds": prefill,
                                "decode_loop_seconds": decode, "first_visible_after_prefill_seconds": visible,
                                "steps": steps, "finish_reason": row[9]})
    else:
        raise ValueError("Malformed model case record")


def validate_probe(result: dict, done: bool) -> None:
    if not done or not all(k in result for k in ("metadata", "native_banner", "traffic")):
        raise ValueError("Incomplete physical probe")
    if len(result["bandwidth"]) != 20 or len(result["copy_checks"]) != 2:
        raise ValueError("Incomplete bandwidth verification")
    for data in result["cases"].values():
        if not data["input_ids"] or not all(data["seen"]) or len(data["timings"]) != 4:
            raise ValueError("Incomplete full-model data")


def summarize_physical(probe: dict) -> dict:
    largest = [s["read_plus_write_gb_s"] for s in probe["bandwidth"] if s["bytes"] == max(COPY_BYTES)]
    bandwidth = statistics.median(largest)
    traffic = probe["traffic"]
    fixed = sum(traffic[k] for k in ("projection_bytes", "norm_bytes", "embedding_row_bytes", "rope_minimum_bytes"))
    summary = {"traffic": traffic, "bandwidth_samples": probe["bandwidth"],
               "copy_checks": probe["copy_checks"], "large_copy_median_read_plus_write_gb_s": bandwidth,
               "conditional_fixed_weight_floor_seconds": fixed / (bandwidth * 1e9),
               "cases": {}, "limits": "Logical unique spans and observed D2D read-plus-write bandwidth form a conditional reference, not measured decode DRAM traffic or a guaranteed physical ceiling. Stage times are synchronized native host calls; detailed kernel/CPU-enqueue/socket attribution remains open."}
    for case, data in probe["cases"].items():
        scored = [s for s in data["timings"] if not s["exported"]]
        summary["cases"][str(case)] = {
            "input_ids": data["input_ids"], "timings": data["timings"],
            "prefill_median_seconds": statistics.median(s["prefill_seconds"] for s in scored),
            "decode_loop_median_seconds": statistics.median(s["decode_loop_seconds"] for s in scored),
            "first_visible_median_seconds": statistics.median(s["prefill_seconds"] + s["first_visible_after_prefill_seconds"] for s in scored),
            "conditional_initial_history_floor_seconds": (fixed + traffic["kv_bytes_per_history_position"] * len(data["input_ids"])) / (bandwidth * 1e9),
        }
    return summary


def compare_case(actual: Any, expected: Any) -> dict:
    if len(actual) != VOCABULARY or len(expected) != VOCABULARY:
        raise ValueError("Invalid independent full logits")
    if not all(math.isfinite(v) for row in (actual, expected) for v in row):
        raise ValueError("Nonfinite independent logits")
    delta = [float(a) - float(b) for a, b in zip(actual, expected)]
    maximum = max(abs(d) for d in delta)
    rms = math.sqrt(math.fsum(d * d for d in delta) / VOCABULARY)
    native_top = max(range(VOCABULARY), key=lambda i: actual[i])
    reference_top = max(range(VOCABULARY), key=lambda i: expected[i])
    ma, mb = float(actual[native_top]), float(expected[reference_top])
    la = ma + math.log(math.fsum(math.exp(float(v) - ma) for v in actual))
    lb = mb + math.log(math.fsum(math.exp(float(v) - mb) for v in expected))
    divergence = math.fsum(math.exp(float(b) - lb) * (float(b) - lb - float(a) + la)
                           for a, b in zip(actual, expected))
    return {"values": len(actual), "maximum_absolute_error": maximum, "rms_error": rms,
            "native_argmax": native_top, "reference_argmax": reference_top,
            "reference_to_native_kl_at_temperature_1": max(0, divergence),
            "passed": maximum <= MAX_ABSOLUTE_ERROR and rms <= MAX_RMS_ERROR and native_top == reference_top}


def independent_reference(probe: dict, model: Path, threads: int, weight_mode: str = "packed") -> dict:
    import numpy as np
    import llama_cpp
    if np.__version__ != "2.4.4" or llama_cpp.__version__ != "0.3.23":
        raise ValueError("Pinned optional reference versions required")
    binding = importlib.import_module("llama_cpp.llama_cpp")
    library = Path(binding._lib._name)
    with library.open("rb") as source:
        library_hash = hashlib.file_digest(source, "sha256").hexdigest()
    result = {"llama_cpp_python": llama_cpp.__version__, "numpy": np.__version__,
              "library_sha256": library_hash, "requested_gpu_layers": 0,
              "context": 4096, "kv": "f16", "batch": 128, "threads": threads, "weight_mode": weight_mode, "cases": {}}
    reference = llama_cpp.Llama(model_path=str(model), n_ctx=4096, n_batch=128,
                         n_gpu_layers=0, n_threads=threads, n_threads_batch=threads,
                         type_k=llama_cpp.GGML_TYPE_F16, type_v=llama_cpp.GGML_TYPE_F16,
                         logits_all=True, flash_attn=False, verbose=False)
    try:
        if weight_mode == "dequantized_f32" and reference.metadata.get("general.file_type") != "0":
            raise ValueError("Independent converted model is not declared F32")
        if reference.n_vocab() != VOCABULARY:
            raise ValueError("Reference vocabulary differs")
        for case, data in probe["cases"].items():
            reference.reset()
            reference.eval(data["input_ids"])
            expected = reference.scores[len(data["input_ids"]) - 1].astype(np.float64)
            observed = np.asarray(data["logits"], dtype=np.float64)
            result["cases"][str(case)] = compare_case(observed, expected)
    finally:
        reference.close()
    result["passed"] = all(c["passed"] for c in result["cases"].values())
    return result


def expand_reference(model: Path, target: Path, quantizer: Path, threads: int) -> dict:
    if target.exists() or target.is_symlink() or model.resolve() == target.resolve():
        raise ValueError("Reference destination must be a new separate artifact")
    with quantizer.open("rb") as source:
        identity = hashlib.file_digest(source, "sha256").hexdigest()
    # A private staging directory plus exclusive hard-link publication prevents
    # a raced/dangling destination from being truncated by the external converter.
    with tempfile.TemporaryDirectory(prefix=".aesir-reference-", dir=target.parent) as directory:
        staged = Path(directory) / "reference.gguf"
        process = subprocess.run([str(quantizer.resolve()), "--allow-requantize", str(model.resolve()),
                                  str(staged.resolve()), "F32", str(threads)],
                                 capture_output=True, text=True, timeout=600)
        log = (process.stdout + process.stderr).replace(str(model.resolve()), "[source GGUF]").replace(str(staged.resolve()), "[derived F32 GGUF]")
        record = {"converter_sha256": identity, "exit_code": process.returncode,
                  "operation": "allow-requantize source derived F32 threads", "log": log}
        if process.returncode != 0 or not staged.is_file() or staged.is_symlink():
            raise ValueError("Independent F32 expansion failed")
        with staged.open("rb") as source:
            record["derived_sha256"] = hashlib.file_digest(source, "sha256").hexdigest()
        record["derived_bytes"] = staged.stat().st_size
        os.link(staged, target)
    return record


def main() -> int:
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("--csv", required=True, type=Path)
    options.add_argument("--model", required=True, type=Path)
    options.add_argument("--expected-sha256", required=True)
    options.add_argument("--reference-quantizer", type=Path)
    options.add_argument("--reference-model", type=Path)
    options.add_argument("--reference-sha256")
    options.add_argument("--threads", type=int, default=4)
    options.add_argument("--output", required=True, type=Path)
    args = options.parse_args()
    if not 1 <= args.threads <= 16 or len(args.expected_sha256) != 64 or any(c not in "0123456789abcdef" for c in args.expected_sha256):
        options.error("Explicit lowercase SHA-256 and 1..16 CPU threads required")
    if args.reference_quantizer is not None and (args.reference_model is None or args.reference_sha256 is not None):
        options.error("Expansion requires a new --reference-model and no reuse hash")
    if args.reference_quantizer is None and (args.reference_model is None) != (args.reference_sha256 is None):
        options.error("Reference reuse requires both --reference-model and --reference-sha256")
    if args.reference_sha256 is not None and (len(args.reference_sha256) != 64 or any(c not in "0123456789abcdef" for c in args.reference_sha256)):
        options.error("Reference reuse requires a lowercase SHA-256")
    with args.output.open("x", encoding="utf-8") as output:
        report = {"schema_version": 1, "errors": [], "numerical_budget": {
            "max_absolute_error": MAX_ABSOLUTE_ERROR, "max_rms_error": MAX_RMS_ERROR,
            "same_full_vocabulary_argmax": True}, "independent_reference_passed": False}
        try:
            with args.model.open("rb") as model:
                digest = hashlib.file_digest(model, "sha256").hexdigest()
            if digest != args.expected_sha256:
                raise ValueError("Independent model bytes mismatch")
            report["model_sha256"] = digest
            with args.csv.open("rb") as source:
                report["physical_csv_sha256"] = hashlib.file_digest(source, "sha256").hexdigest()
            probe = parse_probe(args.csv)
            report["physical"] = summarize_physical(probe)
            reference_model = args.model
            weight_mode = "packed"
            if args.reference_quantizer is not None:
                report["reference_expansion"] = expand_reference(args.model, args.reference_model, args.reference_quantizer, args.threads)
                reference_model = args.reference_model
                weight_mode = "dequantized_f32"
            elif args.reference_model is not None:
                with args.reference_model.open("rb") as source:
                    reference_digest = hashlib.file_digest(source, "sha256").hexdigest()
                if reference_digest != args.reference_sha256:
                    raise ValueError("Reused independent reference bytes mismatch")
                report["reference_reuse"] = {"verified_sha256": reference_digest, "derivation_provenance_required": True}
                reference_model = args.reference_model
                weight_mode = "dequantized_f32"
            report["independent_reference"] = independent_reference(probe, reference_model, args.threads, weight_mode)
            report["independent_reference_passed"] = report["independent_reference"]["passed"]
        except (OSError, ValueError, TypeError, KeyError, ImportError, AttributeError, RuntimeError, subprocess.SubprocessError) as error:
            report["errors"].append(type(error).__name__)
        json.dump(report, output, indent=2, allow_nan=False)
        output.write("\n")
    print(json.dumps({"errors": report["errors"], "independent_reference_passed": report["independent_reference_passed"],
                      "cases": report.get("independent_reference", {}).get("cases", {})}, indent=2))
    return int(bool(report["errors"]) or not report["independent_reference_passed"])


if __name__ == "__main__":
    raise SystemExit(main())
