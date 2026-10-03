"""Accepted strategy3/explicit4 complete model source for explicit test-only consumers."""
import hashlib
import json
import math
import re

from launch import digest
from profile_native_cuda import read_text
from check_turing_model_prefill import parse, reference_fields
from check_llama3_logits import VOCABULARY, MAX_ABSOLUTE_ERROR, MAX_RMS_ERROR


def fixed_comparison(value):
    if not isinstance(value, dict) or value.get("passed") is not True or type(value.get("values")) is not int or value["values"] != VOCABULARY:
        return False
    for key, limit in (("maximum_absolute_error", MAX_ABSOLUTE_ERROR), ("rms_error", MAX_RMS_ERROR)):
        number = value.get(key)
        if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or not 0 <= number <= limit:
            return False
    a, b = value.get("native_argmax"), value.get("reference_argmax")
    return type(a) is int and type(b) is int and a == b and 0 <= a < VOCABULARY


def accepted_model(csv_path, report_path, model_sha, *, fused=False, binary=None, fused_controls=False):
    """Retain complete vectors, but never trust an acceptance Boolean alone."""
    if fused_controls and not fused: raise ValueError("Fused control source requires explicit fused strategy")
    variant = 4 if fused else 3
    binary_sha = digest(binary) if fused and binary is not None else None
    if fused and binary_sha is None: raise ValueError("Fused source requires actual model binary")
    data = parse(csv_path, allow_fused=fused, allow_fused_controls=fused_controls)
    text = read_text(report_path, 5 * 1024**2)
    report = json.loads(text, object_pairs_hook=reference_fields,
        parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Nonfinite down source")))
    budget = dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True)
    if (type(report.get("schema")) is not int or report["schema"] != 1 or
        any(report.get(key) is not True for key in ("passed", "collection_complete", "speed_scored")) or
        type(report.get("activation_precision")) is not int or report["activation_precision"] != 0 or
        type(report.get("attention_variant")) is not int or report["attention_variant"] != variant or
        data["activation_precision"] != 0 or data["attention_variant"] != variant or
        report.get("model_sha256") != model_sha or report.get("csv_sha256") != data["csv_sha256"] or
        report.get("numerical_budget") != budget or report.get("full_model_values_per_mode") != 4 * VOCABULARY or
        report.get("invalid_tiles") != 8 or report.get("guards") != 4352):
        raise ValueError("Down source lacks exact complete accepted strategy3 scope")
    if (type(report.get("control_capable", False)) is not bool or
        report.get("control_capable", False) != data["control_capable"]):
        raise ValueError("Down source control capability differs from actual capture")
    if fused and (report.get("binary_sha256") != binary_sha or data["control_capable"] != fused_controls):
        raise ValueError("Fused source binary identity or closed capability mismatch")
    cpu = report.get("independent_reference", {})
    if (cpu.get("passed") is not True or type(cpu.get("requested_gpu_layers")) is not int or cpu["requested_gpu_layers"] != 0 or
        cpu.get("context") != 4096 or cpu.get("kv") != "f16" or cpu.get("batch") != 128 or cpu.get("threads") != 4 or
        cpu.get("weight_mode") != "dequantized_f32" or cpu.get("numpy") != "2.4.4" or cpu.get("llama_cpp_python") != "0.3.23" or
        not re.fullmatch(r"[0-9a-f]{64}", cpu.get("library_sha256", ""))):
        raise ValueError("Down source lacks pinned zero-GPU F32 independent identity")
    predecessor = report.get("fixture_reference", {})
    if (predecessor.get("passed") is not True or type(predecessor.get("attention_variant")) is not int or predecessor["attention_variant"] != (4 if fused_controls else variant - 1) or
        any(not re.fullmatch(r"[0-9a-f]{64}", predecessor.get(key, "")) for key in ("csv_sha256", "report_sha256")) or
        len(predecessor.get("cases", [])) != 4 or any(any(c.get(key) is not True for key in
            ("input_ids_equal", "native_f32_bytes_equal", "matrix_f32_bytes_equal", "guarded_cache_identity_passed", "passed")) for c in predecessor["cases"])):
        raise ValueError("Down source lacks exact accepted strategy2 predecessor")
    if fused_controls and (predecessor.get("control_capable") is not False or not re.fullmatch(r"[0-9a-f]{64}", predecessor.get("binary_sha256", ""))):
        raise ValueError("Fused capable source lacks exact closed default4 predecessor binary")
    declared, independent = report.get("cases", []), cpu.get("cases", [])
    if len(declared) != 4 or len(independent) != 4: raise ValueError("Down source case coverage incomplete")
    for source, case, oracle in zip(data["cases"], declared, independent, strict=True):
        keys = ("input_ids", "rope_cache_host_enqueues", "elementwise_host_enqueues", "down128_host_enqueues", "guarded_cache_sha256")
        if fused: keys += ("fused_attention_host_enqueues", "original_attention_queries")
        if (any(case.get(key) != source[key] for key in keys) or case.get("native_comparison") != source["native_comparison"] or
            not fixed_comparison(source["native_comparison"]) or any(not fixed_comparison(oracle.get(owner)) for owner in ("native", "matrix"))):
            raise ValueError("Down source complete numerical/counter/cache/ID coverage mismatch")
    proof = dict(passed=True, attention_variant=variant, control_capable=data["control_capable"], csv_sha256=data["csv_sha256"],
        report_sha256=hashlib.sha256(text.encode("utf-8")).hexdigest(), model_sha256=model_sha)
    if fused:
        proof["binary_sha256"] = binary_sha
        if digest(binary) != binary_sha: raise ValueError("Fused model binary changed during admission")
    if digest(csv_path) != proof["csv_sha256"] or digest(report_path) != proof["report_sha256"]:
        raise ValueError("Down model source changed during admission")
    return data, proof
