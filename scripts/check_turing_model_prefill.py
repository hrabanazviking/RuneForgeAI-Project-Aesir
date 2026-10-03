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


def attention_variant(row,allow_down=False):
    if not row or row[0] != "ATTENTION": return None
    if allow_down and row == ["ATTENTION","rope_cache_elementwise_down128","1","32"]: return 3
    if row == ["ATTENTION", "rope_cache_elementwise_grid", "1", "32"]: return 2
    if row not in (["ATTENTION", "rope_cache_grid", "0", "32"], ["ATTENTION", "rope_cache_grid", "1", "32"]):
        raise ValueError("Unknown batched rotary/cache identity")
    return int(row[2])


def rope_cache_calls(count, variant):
    if variant == 0: return count * 3 * 28
    remaining = count - 1; tiles = 1
    while remaining:
        size = 32 if remaining >= 32 else 4 if remaining >= 4 else 1
        remaining -= size; tiles += 1
    return tiles * 3 * 28


def elementwise_calls(count, variant):
    tiles = count if variant < 2 else rope_cache_calls(count, variant)//84
    return tiles*5*28+1


def reference_fields(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError("Duplicate fixture-reference JSON field")
        result[key] = value
    return result


def parse(path):
    text = read_text(path, 64 * 1024 * 1024)
    if len(text.encode("utf-8")) > 64 * 1024 * 1024:
        raise ValueError("Model CSV grew beyond byte admission")
    reader = iter(csv.reader(io.StringIO(text)))
    cuda = next(reader)
    if not cuda or not cuda[0].startswith("[CUDA]") or "api=cuda" not in cuda[0] or "cpu_offload=0" not in cuda[0]:
        raise ValueError("Missing actual native CUDA identity")
    meta = next(reader); precision = 0; variant = attention_variant(meta,allow_down=True)
    if variant is not None: meta = next(reader)
    if meta == ["META", "1", str(VOCABULARY), "1536", "32", "f16", "8"]:
        pass
    elif len(meta) == 8 and meta[:6] == ["META", "1", str(VOCABULARY), "1536", "32", "f16"] and meta[6] in ("1", "2", "3", "4") and meta[7] == "8":
        precision = int(meta[6])
    else:
        raise ValueError("Wrong matrix-model metadata")
    if variant is not None and precision != 0: raise ValueError("Batched rotary/cache mixed with rejected precision refinement")
    if variant == 3 and (not text.endswith("\n") or next(reader) != ["ADMISSION","3","2","0"]):
        raise ValueError("Incomplete down128 pre-step refusal evidence")
    control_capable = False
    first_case = next(reader)
    if variant == 3 and first_case == ["CONTROL_CAPABLE","3","1"]:
        control_capable = True; first_case = next(reader)
    cases = []
    for index in range(4):
        row = first_case if index == 0 else next(reader)
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
        case = dict(input_ids=ids, native=native, logits=matrix, timings=times,
                    native_comparison=compare_case(matrix, native))
        if variant is not None:
            calls = rope_cache_calls(count, variant)
            if next(reader) != ["ENQUEUE", str(index), str(calls)]: raise ValueError("Actual rotary/cache host enqueue count mismatch")
            if variant in (2,3):
                cells = elementwise_calls(count,variant)
                if next(reader) != ["ELEMENTWISE",str(index),str(cells)]: raise ValueError("Actual elementwise host enqueue count mismatch")
                case["elementwise_host_enqueues"] = cells
            if variant == 3:
                down = ((count-1)//32)*28
                if next(reader) != ["DOWN_ROWS128",str(index),str(down)]:raise ValueError("Actual down128 selected enqueue count mismatch")
                case["down128_host_enqueues"] = down
            cache = next(reader)
            if len(cache) != 4 or cache[:3] != ["CACHE", str(index), "176160832"] or not re.fullmatch(r"[0-9a-f]{64}", cache[3]): raise ValueError("Incomplete guarded cache identity")
            case.update(rope_cache_host_enqueues=calls, guarded_cache_sha256=cache[3])
        cases.append(case)
    if next(reader) != ["COMPLETE", "matrix_model", "4", str(4 * VOCABULARY), "32", "8"]:
        raise ValueError("Matrix-model collection totals mismatch")
    if next(reader, None) is not None:
        raise ValueError("Trailing matrix-model evidence")
    return dict(cases=cases, activation_precision=precision, attention_variant=variant, control_capable=control_capable, csv_sha256=hashlib.sha256(text.encode("utf-8")).hexdigest())


def fixture_reference(data, csv_path, report_path, model_sha):
    reference = parse(csv_path); text = read_text(report_path, 5 * 1024**2)
    report_sha = hashlib.sha256(text.encode("utf-8")).hexdigest()
    if digest(csv_path) != reference["csv_sha256"] or digest(report_path) != report_sha:
        raise ValueError("Fixture reference changed during admission")
    report = json.loads(text, object_pairs_hook=reference_fields, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Nonfinite fixture reference")))
    budget = dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True)
    if report.get("passed") is not True or report.get("collection_complete") is not True or report.get("model_sha256") != model_sha or report.get("csv_sha256") != reference["csv_sha256"] or report.get("activation_precision") != 0 or report.get("numerical_budget") != budget or report.get("independent_reference", {}).get("passed") is not True:
        raise ValueError("Fixture reference lacks matching fixed independent acceptance")
    if report.get("attention_variant") != reference["attention_variant"] or report.get("full_model_values_per_mode") != 4*VOCABULARY or report.get("invalid_tiles") != 8 or report.get("guards") != 4352:
        raise ValueError("Fixture reference scope differs from complete CSV")
    cases = report["independent_reference"].get("cases", [])
    if len(cases) != 4 or any(c.get(mode, {}).get("passed") is not True for c in cases for mode in ("native", "matrix")):
        raise ValueError("Fixture reference lacks every independent owner/case")
    if data["attention_variant"] == 1 and reference["attention_variant"] != 0:
        raise ValueError("Batched variant requires explicit independently accepted scalar-cache baseline")
    if data["attention_variant"] == 2 and reference["attention_variant"] != 1:
        raise ValueError("Elementwise variant requires explicit independently accepted rotary/cache baseline")
    if data["attention_variant"] == 3:
        if reference["attention_variant"] != 2:raise ValueError("Down128 requires explicitly accepted elementwise strategy2")
        def fixed(value):
            if not isinstance(value,dict) or value.get("passed") is not True or value.get("values") != VOCABULARY:return False
            for key,limit in (("maximum_absolute_error",MAX_ABSOLUTE_ERROR),("rms_error",MAX_RMS_ERROR)):
                n=value.get(key)
                if isinstance(n,bool) or not isinstance(n,(int,float)) or not math.isfinite(n) or not 0<=n<=limit:return False
            a=value.get("native_argmax");b=value.get("reference_argmax")
            return type(a) is int and type(b) is int and a==b and 0<=a<VOCABULARY
        cpu=report["independent_reference"]
        if (type(cpu.get("requested_gpu_layers")) is not int or cpu["requested_gpu_layers"]!=0 or cpu.get("context")!=4096
            or cpu.get("kv")!="f16" or cpu.get("batch")!=128 or cpu.get("weight_mode")!="dequantized_f32"
            or cpu.get("numpy")!="2.4.4" or cpu.get("llama_cpp_python")!="0.3.23"
            or not re.fullmatch(r"[0-9a-f]{64}",cpu.get("library_sha256","")) or len(report.get("cases",[]))!=4):
            raise ValueError("Down128 source lacks declared zero-GPU F32 independent scope")
        for before,declared,independent_case in zip(reference["cases"],report["cases"],cases,strict=True):
            if (declared.get("native_comparison")!=before["native_comparison"] or not fixed(before["native_comparison"])
                or any(not fixed(independent_case.get(mode)) for mode in ("native","matrix"))
                or declared.get("input_ids")!=before["input_ids"]
                or any(declared.get(key)!=before[key] for key in ("rope_cache_host_enqueues","elementwise_host_enqueues","guarded_cache_sha256"))):
                raise ValueError("Down128 source numerical/counter/cache/ID coverage mismatch")
    results = []
    for current, before in zip(data["cases"], reference["cases"]):
        ids = current["input_ids"] == before["input_ids"]
        native = current["native"].tobytes() == before["native"].tobytes()
        matrix = current["logits"].tobytes() == before["logits"].tobytes()
        cache = (current.get("guarded_cache_sha256") == before.get("guarded_cache_sha256")) if reference["attention_variant"] is not None else data["attention_variant"] == 0
        results.append(dict(input_ids_equal=ids, native_f32_bytes_equal=native, matrix_f32_bytes_equal=matrix,
                            guarded_cache_identity_passed=cache, passed=ids and native and matrix and cache))
    return dict(csv_sha256=reference["csv_sha256"], report_sha256=report_sha, attention_variant=reference["attention_variant"], cases=results, passed=all(c["passed"] for c in results))


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
                attention_variant=data["attention_variant"], control_capable=data["control_capable"],
                csv_sha256=data["csv_sha256"], full_model_values_per_mode=4 * VOCABULARY,
                invalid_tiles=8, guards=4352,
                numerical_budget=dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True),
                cases=[dict(input_ids=c["input_ids"], native_comparison=c["native_comparison"], timings=c["timings"], prefill_speed_ratio=None,
                            **({k: c[k] for k in ("rope_cache_host_enqueues", "guarded_cache_sha256")} if data["attention_variant"] is not None else {}),
                            **({"elementwise_host_enqueues":c["elementwise_host_enqueues"]} if data["attention_variant"] in (2,3) else {}),
                            **({"down128_host_enqueues":c["down128_host_enqueues"]} if data["attention_variant"] == 3 else {})) for c in data["cases"]],
                limits="Isolated native test orchestration only, context1536/F16 KV. Four public final-prompt vectors through1070 inputs. Batch32 Q/output/FFN uses staged Turing MMA, K/V and four/scalar tails use F32 references. One unscored warm/export pair then three alternating fresh pairs. No runtime admission, generation/restore/cancellation/concurrency, decode/provider lead or second-session promotion.")


def score(report):
    for c in report["cases"]:
        c["prefill_speed_ratio"] = None
        c.pop("native_prefill_median_seconds", None)
        c.pop("matrix_prefill_median_seconds", None)
    report["passed"] = all(c["native_comparison"]["passed"] for c in report["cases"]) and report["independent_reference"]["passed"]
    if report.get("attention_variant") is not None:
        report["passed"] = report["passed"] and report.get("fixture_reference", {}).get("passed") is True
    if report["activation_precision"] != 0:
        report["native_refinement_rms_budget"] = .0005
        report["native_refinement_passed"] = all(c["native_comparison"]["rms_error"] <= .0005 for c in report["cases"])
        report["passed"] = report["passed"] and report["native_refinement_passed"]
    report["speed_scored"] = report["passed"]
    if not report["passed"]:
        report["error"] = "Fixed complete-model quality gate failed; timing ratios withheld"
        return
    report.pop("error", None)
    medians=[]
    for c in report["cases"]:
        native = statistics.median(s["seconds"] for s in c["timings"] if s["mode"] == 0 and s["sample"] != 0)
        matrix = statistics.median(s["seconds"] for s in c["timings"] if s["mode"] == 1 and s["sample"] != 0)
        ratio=native/matrix
        if not all(math.isfinite(v) and v>0 for v in (native,matrix,ratio)):
            report.update(passed=False,speed_scored=False,error="Unbounded prefill timing ratio; all scores withheld")
            return
        medians.append((native,matrix,ratio))
    for c,(native,matrix,ratio) in zip(report["cases"],medians,strict=True):
        c.update(native_prefill_median_seconds=native,matrix_prefill_median_seconds=matrix,prefill_speed_ratio=ratio)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path); parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--model-sha256", required=True); parser.add_argument("--reference-model", type=Path, required=True)
    parser.add_argument("--reference-sha256", required=True); parser.add_argument("--reference-provenance", type=Path, required=True)
    parser.add_argument("--threads", type=int, default=4); parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference-csv", type=Path); parser.add_argument("--reference-report", type=Path)
    args = parser.parse_args()
    if (args.reference_csv is None) != (args.reference_report is None): parser.error("Fixture reference requires both CSV/report")
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
            if data["attention_variant"] is not None:
                if args.reference_csv is None: raise ValueError("Explicit rotary/cache evidence requires accepted fixture reference")
                report["fixture_reference"] = fixture_reference(data, args.reference_csv, args.reference_report, args.model_sha256)
            report.update(model_sha256=args.model_sha256, reference_derivation=derived,
                          independent_reference=independent(data, args.reference_model, args.threads))
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256:
                raise ValueError("Original/derived model changed during oracle")
            if digest(args.csv) != data["csv_sha256"]:
                raise ValueError("Complete model CSV changed during oracle")
            if digest(args.reference_provenance) != derived["snapshot_sha256"]:
                raise ValueError("Original-to-F32 provenance changed during oracle")
            if data["attention_variant"] is not None and (digest(args.reference_csv) != report["fixture_reference"]["csv_sha256"] or digest(args.reference_report) != report["fixture_reference"]["report_sha256"]):
                raise ValueError("Accepted fixture reference changed during oracle")
            score(report)
        except (Exception, KeyboardInterrupt) as error:
            report.update(passed=False, speed_scored=False, error=f"{type(error).__name__}: {error}")
            for c in report.get("cases",[]):
                c["prefill_speed_ratio"]=None
                c.pop("native_prefill_median_seconds",None);c.pop("matrix_prefill_median_seconds",None)
        json.dump(report, stream, indent=2, allow_nan=False); stream.write("\n")
    print("PASS: complete-model matrix prefill gate" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
