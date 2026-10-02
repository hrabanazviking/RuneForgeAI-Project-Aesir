#!/usr/bin/env python3
"""Fixed complete-model matrix-prefill precision and conditional timing evidence."""
import argparse
from array import array
import csv
import hashlib
import importlib
import io
import json
import math
from pathlib import Path
import re
import statistics

from launch import digest
from profile_native_cuda import read_text
from check_turing_activations import f32
from check_llama3_logits import compare_case, VOCABULARY, MAX_ABSOLUTE_ERROR, MAX_RMS_ERROR


def parse(path):
    text = read_text(path, 64 * 1024 * 1024)
    if len(text.encode("utf-8")) > 64 * 1024 * 1024:
        raise ValueError("Model CSV grew beyond byte admission")
    reader = iter(csv.reader(io.StringIO(text)))
    cuda = next(reader)
    if not cuda or not cuda[0].startswith("[CUDA]") or "api=cuda" not in cuda[0] or "cpu_offload=0" not in cuda[0]:
        raise ValueError("Missing actual native CUDA identity")
    meta = next(reader); precision = 0
    if meta == ["META", "1", str(VOCABULARY), "1536", "32", "f16", "8"]:
        pass
    elif len(meta) == 8 and meta[:6] == ["META", "1", str(VOCABULARY), "1536", "32", "f16"] and meta[6] in ("1", "2", "3", "4") and meta[7] == "8":
        precision = int(meta[6])
    else:
        raise ValueError("Wrong matrix-model metadata")
    cases = []
    for index in range(4):
        row = next(reader)
        if len(row) != 3 or row[:2] != ["CASE", str(index)] or not 2 <= int(row[2]) <= 1536:
            raise ValueError("Matrix-model case identity/context mismatch")
        count = int(row[2]); ids = []
        for ordinal in range(count):
            row = next(reader)
            if len(row) != 4 or row[:3] != ["INPUT", str(index), str(ordinal)] or not 0 <= int(row[3]) < VOCABULARY:
                raise ValueError("Incomplete/duplicate/invalid matrix input")
            ids.append(int(row[3]))
        native = array("f"); matrix = array("f")
        for token in range(VOCABULARY):
            row = next(reader)
            if len(row) != 5 or row[:3] != ["LOGIT", str(index), str(token)]:
                raise ValueError("Incomplete/duplicate/out-of-order complete logits")
            native.append(f32(row[3])); matrix.append(f32(row[4]))
        times = []
        for sample in range(4):
            for step in range(2):
                mode = (sample + step) % 2; row = next(reader)
                if len(row) != 7 or row[:4] != ["TIME", str(index), str(mode), str(sample)] or row[5:] != [str(count), "0"]:
                    raise ValueError("Matrix timing order/position/repeat mismatch")
                elapsed = float(row[4])
                if not math.isfinite(elapsed) or elapsed <= 0:
                    raise ValueError("Invalid actual matrix prefill timing")
                times.append(dict(mode=mode, sample=sample, seconds=elapsed, committed_position=count, repeat_logit_mismatches=0))
        if next(reader) != ["GUARD", str(index), "1088", "0"]:
            raise ValueError("Matrix model guarded buffers incomplete or failed")
        cases.append(dict(input_ids=ids, native=native, logits=matrix, timings=times,
                          native_comparison=compare_case(matrix, native)))
    if next(reader) != ["COMPLETE", "matrix_model", "4", str(4 * VOCABULARY), "32", "8"]:
        raise ValueError("Matrix-model collection totals mismatch")
    if next(reader, None) is not None:
        raise ValueError("Trailing matrix-model evidence")
    return dict(cases=cases, activation_precision=precision, csv_sha256=hashlib.sha256(text.encode("utf-8")).hexdigest())


def independent(data, model, threads):
    import numpy as np
    import llama_cpp
    if np.__version__ != "2.4.4" or llama_cpp.__version__ != "0.3.23":
        raise ValueError("Pinned optional full-model reference versions required")
    binding = importlib.import_module("llama_cpp.llama_cpp")
    library = Path(binding._lib._name)
    result = dict(llama_cpp_python=llama_cpp.__version__, numpy=np.__version__,
                  library_sha256=digest(library), requested_gpu_layers=0, context=4096,
                  kv="f16", batch=128, threads=threads, weight_mode="dequantized_f32", cases=[])
    cpu = llama_cpp.Llama(model_path=str(model), n_ctx=4096, n_batch=128,
                         n_gpu_layers=0, n_threads=threads, n_threads_batch=threads,
                         type_k=llama_cpp.GGML_TYPE_F16, type_v=llama_cpp.GGML_TYPE_F16,
                         logits_all=True, flash_attn=False, verbose=False)
    try:
        if cpu.metadata.get("general.file_type") != "0" or cpu.n_vocab() != VOCABULARY:
            raise ValueError("Independent reference is not the declared F32 model")
        for c in data["cases"]:
            cpu.reset(); cpu.eval(c["input_ids"])
            expected = cpu.scores[len(c["input_ids"]) - 1].astype(np.float64)
            result["cases"].append(dict(native=compare_case(c["native"], expected),
                                        matrix=compare_case(c["logits"], expected)))
    finally:
        cpu.close()
    result["passed"] = all(c["native"]["passed"] and c["matrix"]["passed"] for c in result["cases"])
    return result


def provenance(path, original_sha, reference_sha):
    text = read_text(path, 5 * 1024 * 1024); value = json.loads(text)
    expansion = value["reference_expansion"]
    if value["model_sha256"] != original_sha or expansion["derived_sha256"] != reference_sha or expansion["exit_code"] != 0 or expansion["derived_bytes"] <= 0 or not re.fullmatch(r"[0-9a-f]{64}", expansion["converter_sha256"]):
        raise ValueError("Original-to-F32 derivation identity mismatch")
    return dict(snapshot_sha256=hashlib.sha256(text.encode("utf-8")).hexdigest(),
                original_sha256=original_sha, derived_sha256=reference_sha,
                converter_sha256=expansion["converter_sha256"], derived_bytes=expansion["derived_bytes"])


def summarize(data):
    return dict(schema=1, passed=False, collection_complete=True, speed_scored=False,
                activation_precision=data["activation_precision"],
                csv_sha256=data["csv_sha256"], full_model_values_per_mode=4 * VOCABULARY,
                invalid_tiles=8, guards=4352,
                numerical_budget=dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True),
                cases=[dict(input_ids=c["input_ids"], native_comparison=c["native_comparison"], timings=c["timings"], prefill_speed_ratio=None) for c in data["cases"]],
                limits="Isolated native test orchestration only, context1536/F16 KV. Four public final-prompt vectors through1070 inputs. Batch32 Q/output/FFN uses staged Turing MMA, K/V and four/scalar tails use F32 references. One unscored warm/export pair then three alternating fresh pairs. No runtime admission, generation/restore/cancellation/concurrency, decode/provider lead or second-session promotion.")


def score(report):
    for c in report["cases"]:
        c["prefill_speed_ratio"] = None
        c.pop("native_prefill_median_seconds", None)
        c.pop("matrix_prefill_median_seconds", None)
    report["passed"] = all(c["native_comparison"]["passed"] for c in report["cases"]) and report["independent_reference"]["passed"]
    if report["activation_precision"] != 0:
        report["native_refinement_rms_budget"] = .0005
        report["native_refinement_passed"] = all(c["native_comparison"]["rms_error"] <= .0005 for c in report["cases"])
        report["passed"] = report["passed"] and report["native_refinement_passed"]
    report["speed_scored"] = report["passed"]
    if not report["passed"]:
        report["error"] = "Fixed complete-model quality gate failed; timing ratios withheld"
        return
    report.pop("error", None)
    for c in report["cases"]:
        native = [s["seconds"] for s in c["timings"] if s["mode"] == 0 and s["sample"] != 0]
        matrix = [s["seconds"] for s in c["timings"] if s["mode"] == 1 and s["sample"] != 0]
        c.update(native_prefill_median_seconds=statistics.median(native), matrix_prefill_median_seconds=statistics.median(matrix),
                 prefill_speed_ratio=statistics.median(native) / statistics.median(matrix))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path); parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--model-sha256", required=True); parser.add_argument("--reference-model", type=Path, required=True)
    parser.add_argument("--reference-sha256", required=True); parser.add_argument("--reference-provenance", type=Path, required=True)
    parser.add_argument("--threads", type=int, default=4); parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.threads <= 16 or any(not re.fullmatch(r"[0-9a-f]{64}", value) for value in (args.model_sha256, args.reference_sha256)):
        parser.error("Lowercase SHA-256 identities and1..16 reference threads required")
    with args.output.open("x", encoding="utf-8") as stream:
        report = dict(schema=1, passed=False, collection_complete=False, speed_scored=False)
        try:
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256:
                raise ValueError("Original/derived reference checksum mismatch")
            derived = provenance(args.reference_provenance, args.model_sha256, args.reference_sha256)
            if args.reference_model.stat().st_size != derived["derived_bytes"]:
                raise ValueError("Derived reference size mismatch")
            data = parse(args.csv); report = summarize(data)
            report.update(model_sha256=args.model_sha256, reference_derivation=derived,
                          independent_reference=independent(data, args.reference_model, args.threads))
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256:
                raise ValueError("Original/derived model changed during oracle")
            score(report)
        except Exception as error:
            report.update(passed=False, speed_scored=False, error=f"{type(error).__name__}: {error}")
        json.dump(report, stream, indent=2, allow_nan=False); stream.write("\n")
    print("PASS: complete-model matrix prefill gate" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
