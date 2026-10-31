#!/usr/bin/env python3
"""J-023 analyser: parse the idle and loaded streamed-run logs and
emit the comparison table + the thrash verdict.

Thrash collapse was defined BEFORE measuring (J-023 doc section 2):
any of (a) loaded hit rate < 0.5 x idle hit rate, (b) loaded streamed
bytes/token > 2 x idle, (c) generated ids differ from the idle run,
(d) loaded run fails or its wall/token exceeds 3 x idle wall/token.
Gentle degradation = none of (a)-(d); the wall/token ratio is the
degradation measure. Usage: j023_analyze.py run_idle.log run_loaded.log
"""
import re
import sys


def parse(path):
    text = open(path).read()
    out = {}
    m = re.search(r"Generated IDs: \[([0-9, ]*)\]", text)
    out["gen_ids"] = [int(x) for x in m.group(1).split(",")] if m else None
    c = re.search(r"\[CACHE\] (.*)", text)
    kv = dict(re.findall(r"(\w+)=([0-9.]+)", c.group(1))) if c else {}
    out["cache"] = {k: float(v) for k, v in kv.items()}
    s = re.search(r"\[STREAM\] .*reads=(\d+), bytes_read=(\d+)", text)
    out["stream_reads"] = int(s.group(1)) if s else None
    out["stream_bytes"] = int(s.group(2)) if s else None
    t = re.search(
        r"TIMING prompt_tokens=\s*(\d+)\s*prefill_s=\s*([0-9.]+)\s*"
        r"generated=\s*(\d+)\s*decode_s=\s*([0-9.]+)", text)
    if t:
        out["prompt_tokens"] = int(t.group(1))
        out["prefill_s"] = float(t.group(2))
        out["generated"] = int(t.group(3))
        out["decode_s"] = float(t.group(4))
    return out


def main():
    idle, loaded = parse(sys.argv[1]), parse(sys.argv[2])
    for name, r in (("idle", idle), ("loaded", loaded)):
        tot_tokens = r["prompt_tokens"] + r["generated"]
        r["total_tokens"] = tot_tokens
        r["bytes_per_token"] = r["cache"]["bytes_streamed"] / tot_tokens
        r["wall_per_token"] = (r["prefill_s"] + r["decode_s"]) / tot_tokens
        r["hit_rate"] = r["cache"]["hit_rate_per_mille"] / 1000.0
        print(f"{name}: hit={r['hit_rate']:.3f} "
              f"bytes_streamed={int(r['cache']['bytes_streamed'])} "
              f"bytes/token={r['bytes_per_token']:.1f} "
              f"wall/token={r['wall_per_token']:.4f}s "
              f"prefill={r['prefill_s']:.2f}s decode={r['decode_s']:.2f}s "
              f"evictions={int(r['cache']['evictions'])} "
              f"bypasses={int(r['cache']['bypasses'])} "
              f"admissions={int(r['cache']['admissions'])}")
    same_ids = idle["gen_ids"] == loaded["gen_ids"]
    print(f"token_identity_loaded_vs_idle: {same_ids}")
    hr_ratio = loaded["hit_rate"] / idle["hit_rate"]
    bpt_ratio = loaded["bytes_per_token"] / idle["bytes_per_token"]
    wpt_ratio = loaded["wall_per_token"] / idle["wall_per_token"]
    print(f"ratios: hit={hr_ratio:.3f} bytes/token={bpt_ratio:.3f} "
          f"wall/token={wpt_ratio:.3f}")
    thrash = (hr_ratio < 0.5 or bpt_ratio > 2.0 or not same_ids
              or wpt_ratio > 3.0)
    print("VERDICT: " + ("THRASH COLLAPSE" if thrash
                         else "NO THRASH -- gentle degradation"))


if __name__ == "__main__":
    main()
