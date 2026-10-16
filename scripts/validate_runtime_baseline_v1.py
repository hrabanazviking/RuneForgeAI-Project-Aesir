#!/usr/bin/env python3
"""Independently recompute and validate an S25 machine-readable baseline."""
import argparse
import json
import math
from pathlib import Path
import re

EXPECTED_PROMPT_SHA256 = {
    "arithmetic": "1c1d6377c7be15ac511d3f4daafe4712ce3f0cfa52e4bc04829c84b750d4b192",
    "long_prompt": "cab78f5b9b6c4dd512fce63c556db27ffdc06c923d2a35ab1b9aa5b7efca6fb5",
}


def quantile(values, fraction):
    ordered = sorted(values)
    if not ordered or not all(type(x) in (int, float) and math.isfinite(x) and x > 0 for x in ordered):
        raise ValueError("invalid timing values")
    at = (len(ordered) - 1) * fraction
    low = math.floor(at)
    high = math.ceil(at)
    return ordered[low] + (ordered[high] - ordered[low]) * (at - low)


def _positive_number(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def validate(report):
    if (report.get("schema_version") != 1 or report.get("status") != "passed"
            or report.get("errors") != []
            or not re.fullmatch(r"[0-9a-f]{64}", report.get("binary_sha256", ""))
            or not re.fullmatch(r"sha256:[0-9a-f]{64}", report.get("model_digest", ""))):
        raise ValueError("missing successful runtime/model identity")
    if (not report.get("model") or type(report.get("context")) is not int
            or type(report.get("max_tokens")) is not int
            or type(report.get("samples_per_case")) is not int
            or not 512 <= report["context"] <= 8192
            or not 1 <= report["max_tokens"] <= 256
            or not 2 <= report["samples_per_case"] <= 20):
        raise ValueError("invalid benchmark controls")
    gpu = report.get("gpu")
    if (type(gpu) is not dict or not gpu.get("name") or not gpu.get("driver_version")
            or type(gpu.get("total_mib")) is not int or gpu["total_mib"] < 1):
        raise ValueError("missing physical GPU identity")
    loads = report.get("load_processes")
    if type(loads) is not list or [entry.get("kind") for entry in loads] != ["first_process", "repeat_process"]:
        raise ValueError("missing paired process-load observations")
    for load in loads:
        memory = load.get("process_memory_kib", {})
        baseline = load.get("prelaunch_device_vram_mib")
        peak = load.get("sampled_device_vram_peak_mib")
        if (not _positive_number(load.get("ready_seconds"))
                or type(memory.get("VmHWM")) is not int or memory["VmHWM"] < 1
                or type(baseline) is not int or baseline < 0
                or type(peak) is not int or peak < baseline):
            raise ValueError("invalid load/RAM/device-VRAM evidence")
        process_peak = load.get("sampled_process_vram_peak_mib")
        if process_peak is not None and (type(process_peak) is not int or process_peak < 1):
            raise ValueError("invalid process VRAM observation")
    samples = report.get("samples")
    if type(samples) is not list:
        raise ValueError("raw samples missing")
    cases = tuple(EXPECTED_PROMPT_SHA256)
    expected = [(case, phase) for case in cases
                for phase in ["warmup"] + ["sample"] * report["samples_per_case"]]
    if [(sample.get("case"), sample.get("phase")) for sample in samples] != expected:
        raise ValueError("sample sequence incomplete or reordered")
    hashes = {}
    for item in samples:
        if (not re.fullmatch(r"[0-9a-f]{64}", item.get("prompt_sha256", ""))
                or type(item.get("text")) is not str or not item["text"].strip()
                or item.get("finish_reason") not in ("eos", "length")
                or type(item.get("prompt_tokens")) is not int or item["prompt_tokens"] < 1
                or type(item.get("generated_tokens")) is not int
                or not 1 <= item["generated_tokens"] <= report["max_tokens"]
                or type(item.get("record_count")) is not int or item["record_count"] < 2
                or not _positive_number(item.get("wall_seconds"))
                or not _positive_number(item.get("ttft_seconds"))
                or item["ttft_seconds"] > item["wall_seconds"]
                or type(item.get("prefill_ms")) is not int or item["prefill_ms"] < 1
                or type(item.get("decode_ms")) is not int or item["decode_ms"] < 1):
            raise ValueError("invalid raw sample")
        hashes.setdefault(item["case"], set()).add(item["prompt_sha256"])
    if any(hashes.get(case) != {expected} for case, expected in EXPECTED_PROMPT_SHA256.items()):
        raise ValueError("prompt does not match fixed benchmark case")
    summary = report.get("summary")
    if type(summary) is not dict or set(summary) != set(cases):
        raise ValueError("summary cases do not match raw samples")
    for case in cases:
        group = [item for item in samples if item["case"] == case and item["phase"] == "sample"]
        expected_values = {
            "latency_p50_seconds": quantile([item["wall_seconds"] for item in group], .5),
            "latency_p95_seconds": quantile([item["wall_seconds"] for item in group], .95),
            "ttft_p50_seconds": quantile([item["ttft_seconds"] for item in group], .5),
            "prefill_tokens_per_second_p50": quantile([item["prompt_tokens"] * 1000 / item["prefill_ms"] for item in group], .5),
            "decode_tokens_per_second_p50": quantile([item["generated_tokens"] * 1000 / item["decode_ms"] for item in group], .5),
        }
        if set(summary[case]) != set(expected_values):
            raise ValueError("summary metric set changed")
        for name, expected_value in expected_values.items():
            actual = summary[case][name]
            if not _positive_number(actual) or not math.isclose(actual, expected_value, rel_tol=1e-12):
                raise ValueError("summary does not match raw samples")
    return {"model_digest": report["model_digest"], "sample_count": len(samples),
            "cases": list(cases), "process_vram_available": all(
                item["sampled_process_vram_peak_mib"] is not None for item in loads)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    data = json.loads(args.report.read_text(encoding="utf-8"))
    print(json.dumps(validate(data), sort_keys=True))


if __name__ == "__main__":
    main()
