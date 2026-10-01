"""Fail-closed comparison of supervised native HTTP benchmark evidence.

Require the same model digest, controls, prefix policy and complete request/reply
sequence. Recompute medians from positive finite warm samples; never trust a
report's summary as proof. A failed parity gate writes a failure artifact and
exits nonzero, without publishing speed ratios.
"""
import argparse
import json
import math
from pathlib import Path
import re
import statistics


def validate(report):
    if report.get("errors") != [] or report.get("failed_samples") != 0:
        raise ValueError("Benchmark contains failures")
    if not re.fullmatch(r"[0-9a-f]{64}", report["binary_sha256"]):
        raise ValueError("Missing binary identity")
    count = report["samples_per_case"]
    if type(count) is not int or not 1 <= count <= 10:
        raise ValueError("Invalid sample count")
    health = report["health"]
    if (health["status"] != "ready" or health["backend"] != "cuda"
            or health["cpu_offload"] != 0 or health["model"] != report["model"]
            or health["context"] != report["context"]
            or not re.fullmatch(r"sha256:[0-9a-f]{64}", health["model_digest"])
            or type(report["prefix_cache"]) is not bool
            or health["capabilities"]["exact_prefix_reuse"] != report["prefix_cache"]
            or report["prefix_cache_requested"] != report["prefix_cache"]):
        raise ValueError("Invalid native model or policy identity")
    groups = {}
    for sample in report["samples"]:
        seconds = sample["seconds"]
        if (type(seconds) not in (int, float) or not math.isfinite(seconds)
                or seconds <= 0 or "failure_category" in sample
                or sample["status"] != 200):
            raise ValueError("Failed or invalid timing sample")
        reply = sample["reply"]
        if (reply["backend"] != "cuda" or reply["cpu_offload"] != 0
                or reply["model"] != health["model"]
                or reply["model_digest"] != health["model_digest"]
                or reply["finish_reason"] not in ("eos", "length")
                or not reply["text"].strip()):
            raise ValueError("Invalid completion identity")
        for field in ("prompt_tokens", "generated_tokens", "context_used"):
            if type(reply[field]) is not int or reply[field] < 1:
                raise ValueError("Invalid completion counts")
        if (reply["generated_tokens"] > report["max_tokens"]
                or reply["context_used"] > report["context"]):
            raise ValueError("Completion exceeded admitted bounds")
        groups.setdefault(sample["case"], []).append(sample)
    if not groups:
        raise ValueError("Empty evidence")
    for samples in groups.values():
        if ([s["phase"] for s in samples] != ["warmup"] + ["warm"] * count
                or len({s["prompt"] for s in samples}) != 1):
            raise ValueError("Incomplete warmup/sample sequence")
    return groups


def compare(before, after):
    old, new = validate(before), validate(after)
    if before.get("suite", "standard") != after.get("suite", "standard"):
        raise ValueError("Comparison benchmark suite mismatch")
    for field in ("model", "context", "samples_per_case", "system", "max_tokens",
                  "sampling", "prefix_cache", "health"):
        if before[field] != after[field]:
            raise ValueError("Comparison policy mismatch: " + field)
    if list(old) != list(new) or len(before["samples"]) != len(after["samples"]):
        raise ValueError("Comparison request sequence mismatch")
    for a, b in zip(before["samples"], after["samples"]):
        for field in ("case", "prompt", "phase", "status", "reply"):
            if a[field] != b[field]:
                raise ValueError("Comparison request/reply mismatch: " + field)
    cases = {}
    for name in old:
        a = statistics.median(s["seconds"] for s in old[name] if s["phase"] == "warm")
        b = statistics.median(s["seconds"] for s in new[name] if s["phase"] == "warm")
        cases[name] = {"before_median_seconds": a, "after_median_seconds": b,
                       "speed_ratio": a / b}
    return {"status": "passed", "before_binary_sha256": before["binary_sha256"],
            "after_binary_sha256": after["binary_sha256"],
            "model_digest": before["health"]["model_digest"],
            "prefix_cache": before["prefix_cache"],
            "matched_replies": len(before["samples"]), "cases": cases,
            "limits": "Same-policy native HTTP wall time; excludes one warmup per case. Small samples and device/thermal variance apply. No independent full-model logits or broad model/device speed claim."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--after", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    with args.output.open("x", encoding="utf-8") as target:
        try:
            result = compare(json.loads(args.before.read_text()), json.loads(args.after.read_text()))
        except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
            result = {"status": "failed", "reason": str(error)}
        json.dump(result, target, indent=2)
        target.write("\n")
    print(json.dumps(result))
    return int(result["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
