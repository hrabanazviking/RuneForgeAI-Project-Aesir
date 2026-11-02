#!/usr/bin/env python3
"""J-030 re-verification: parse the filed J-022 post-fix and J-023 idle/loaded
run logs, assert token identity and counter identity, and recompute every
derived wall / tok-s figure from the filed raw numbers.

Usage: j030_reverify.py <run_idle.log> <run_loaded.log> <j022_b1_run_fix.txt>

No number in the J-030 doc comes from anywhere else: this script reads only
the three filed artefacts named on its command line and prints what it finds.
Exit code is non-zero if any identity assertion fails.
"""
import re
import sys


def parse(path):
    text = open(path).read()
    out = {}
    m = re.search(r"Prompt IDs: \[([0-9, ]+)\]", text)
    out["prompt_ids"] = [int(x) for x in m.group(1).split(",")]
    m = re.search(r"Generated IDs: \[([0-9, ]+)\]", text)
    out["generated_ids"] = [int(x) for x in m.group(1).split(",")]
    m = re.search(r"\[CACHE\] (.+)", text)
    cache = {}
    for kv in m.group(1).split():
        k, v = kv.split("=")
        cache[k] = int(v)
    out["cache"] = cache
    m = re.search(r"\[STREAM\] .*reads=(\d+), bytes_read=(\d+), advice_calls=(\d+)", text)
    out["stream"] = {
        "reads": int(m.group(1)),
        "bytes_read": int(m.group(2)),
        "advice_calls": int(m.group(3)),
    }
    m = re.search(
        r"TIMING prompt_tokens=\s*(\d+)\s+prefill_s=\s*([0-9.]+)\s+generated=\s*(\d+)\s+decode_s=\s*([0-9.]+)",
        text,
    )
    out["prompt_tokens"] = int(m.group(1))
    out["prefill_s"] = float(m.group(2))
    out["generated"] = int(m.group(3))
    out["decode_s"] = float(m.group(4))
    m = re.search(r"cache_budget_bytes=(\d+)", text)
    out["cache_budget_bytes"] = int(m.group(1))
    m = re.search(r"context=(\d+)", text)
    out["context"] = int(m.group(1))
    return out


def derive(r):
    stepped = r["prompt_tokens"] + r["generated"]
    total = r["prefill_s"] + r["decode_s"]
    c = r["cache"]
    return {
        "stepped_tokens": stepped,
        "engine_wall_s": total,
        "wall_per_token_s": total / stepped,
        "prefill_tok_s": r["prompt_tokens"] / r["prefill_s"],
        "decode_tok_s": r["generated"] / r["decode_s"],
        "overall_tok_s": stepped / total,
        "bytes_per_token": c["bytes_streamed"] / stepped,
        "hit_rate": c["hits"] / c["accesses"],
    }


def show(name, r, d):
    c = r["cache"]
    print(f"[{name}] prompt={r['prompt_tokens']} generated={r['generated']} "
          f"context={r['context']} cache_budget_bytes={r['cache_budget_bytes']}")
    print(f"[{name}] prefill_s={r['prefill_s']:.6f} decode_s={r['decode_s']:.6f} "
          f"engine_wall_s={d['engine_wall_s']:.6f}")
    print(f"[{name}] wall/token={d['wall_per_token_s']:.6f} s  "
          f"prefill_tok/s={d['prefill_tok_s']:.4f}  decode_tok/s={d['decode_tok_s']:.4f}  "
          f"overall_tok/s={d['overall_tok_s']:.4f}")
    print(f"[{name}] accesses={c['accesses']} hits={c['hits']} misses={c['misses']} "
          f"cold={c['cold_misses']} hit_rate={d['hit_rate']:.6f} "
          f"admissions={c['admissions']} promotions={c['promotions']} "
          f"evictions={c['evictions']} bypasses={c['bypasses']} "
          f"evicted_before_reuse={c['evicted_before_reuse']}")
    print(f"[{name}] bytes_streamed={c['bytes_streamed']} "
          f"bytes/token={d['bytes_per_token']:.1f} "
          f"stream_reads={r['stream']['reads']} stream_bytes={r['stream']['bytes_read']} "
          f"advice_calls={r['stream']['advice_calls']}")
    print(f"[{name}] generated_ids={r['generated_ids']}")


def main():
    idle = parse(sys.argv[1])
    loaded = parse(sys.argv[2])
    j022 = parse(sys.argv[3])
    for name, r in (("idle", idle), ("loaded", loaded), ("j022_postfix", j022)):
        show(name, r, derive(r))
    ok = True
    def check(label, cond):
        nonlocal ok
        print(f"CHECK {label}: {'PASS' if cond else 'FAIL'}")
        ok = ok and cond
    check("idle ids == J-022 post-fix ids", idle["generated_ids"] == j022["generated_ids"])
    check("loaded ids == J-022 post-fix ids", loaded["generated_ids"] == j022["generated_ids"])
    check("idle prompt ids == J-022 prompt ids", idle["prompt_ids"] == j022["prompt_ids"])
    check("idle cache == J-022 cache (all counters)",
          idle["cache"] == j022["cache"])
    check("loaded cache == idle cache (all counters)", loaded["cache"] == idle["cache"])
    check("loaded stream == idle stream", loaded["stream"] == idle["stream"])
    check("stream bytes == cache bytes_streamed (idle)",
          idle["stream"]["bytes_read"] == idle["cache"]["bytes_streamed"])
    di, dl = derive(idle), derive(loaded)
    print(f"RATIO loaded/idle wall/token = {dl['wall_per_token_s']/di['wall_per_token_s']:.4f}")
    print(f"RATIO loaded/idle prefill = {loaded['prefill_s']/idle['prefill_s']:.4f}")
    print(f"RATIO loaded/idle decode = {loaded['decode_s']/idle['decode_s']:.4f}")
    dj = derive(j022)
    print(f"J022_POSTFIX (S-093-contended) wall/token = {dj['wall_per_token_s']:.6f} s  "
          f"decode_tok/s={dj['decode_tok_s']:.4f}  (MEASURED-INDICATIVE only, per J-022 S7.3)")
    print("VERDICT:", "ALL CHECKS PASS" if ok else "FAILURES PRESENT")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
