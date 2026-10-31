#!/usr/bin/env python3
"""J-033 soak analyser: parse the per-window streamed-run logs of the
J-033 soak (j033_run.sh output) and emit the per-window table plus the
degradation / ceiling verdicts.

Every verdict rule was defined BEFORE any soak run, in
docs/janas/J033_SOAK.md section 4 (pre-registered 2026-10-31):

- Memory ceiling: a window BREACHES if its [CACHE] bytes_resident_now
  exceeds its budget_bytes, or its peak RSS (from the window .meta,
  /usr/bin/time -v) exceeds RSS_CEILING_KIB = 2,132,266 KiB
  (J-023 idle peak 1,938,424 KiB x 1.10, rounded up).
- Wall trend: DEGRADATION if the least-squares slope of decode
  seconds-per-generated-token over windows is > 0 AND the last
  window's value exceeds 1.25 x the first window's.
- Hit trend: DEGRADATION if the last window's hit rate is below
  0.8 x the first window's. (Prompt types differ per window; the
  confound is named in the doc and the cumulative row is printed too.)
- Streamed-bytes trend: DEGRADATION if the last window's streamed
  bytes per generated token exceeds 1.25 x the first window's.
- Completeness: total generated tokens < 2,000 makes the soak
  PARTIAL; all trend verdicts are then labelled provisional.
- Overall: DEGRADATION TREND if any trend rule fires or any ceiling
  breaches; otherwise NO DEGRADATION TREND.

Usage: j033_analyze.py <window_log> [<window_log> ...]
Each log's peak RSS is read from the sibling .meta file when present
(run_wNN.log -> run_wNN.meta), else reported as not recorded.
Window order = argument order.
"""
import re
import sys

RSS_CEILING_KIB = 2132266
SOAK_TOKEN_TARGET = 2000


def parse_log(path):
    text = open(path).read()
    out = {"path": path}
    m = re.search(r"Generated IDs: \[([0-9, ]*)\]", text)
    out["gen_ids"] = ([int(x) for x in m.group(1).split(",") if x.strip()]
                      if m else None)
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


def parse_rss_kib(log_path):
    meta_path = re.sub(r"\.log$", ".meta", log_path)
    try:
        text = open(meta_path).read()
    except OSError:
        return None
    m = re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", text)
    return int(m.group(1)) if m else None


def slope(xs, ys):
    n = len(xs)
    if n < 2:
        return 0.0
    mx = sum(xs) / n
    my = sum(ys) / n
    den = sum((x - mx) ** 2 for x in xs)
    if den == 0:
        return 0.0
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / den


def main():
    if len(sys.argv) < 2:
        print("usage: j033_analyze.py <window_log> [...]")
        return 2
    windows = []
    for path in sys.argv[1:]:
        r = parse_log(path)
        missing = [k for k in ("gen_ids", "generated", "prompt_tokens")
                   if r.get(k) is None] + (
                       [] if r["cache"] else ["cache"])
        if missing:
            print(f"PARSE_FAIL {path}: missing {missing}")
            return 1
        r["rss_kib"] = parse_rss_kib(path)
        r["total_tokens"] = r["prompt_tokens"] + r["generated"]
        r["wall_s"] = r["prefill_s"] + r["decode_s"]
        r["wall_per_total_token"] = r["wall_s"] / r["total_tokens"]
        r["decode_s_per_gen"] = r["decode_s"] / r["generated"]
        r["hit_rate"] = r["cache"]["hit_rate_per_mille"] / 1000.0
        r["bytes_per_gen"] = r["cache"]["bytes_streamed"] / r["generated"]
        r["bytes_per_total"] = (r["cache"]["bytes_streamed"]
                                / r["total_tokens"])
        windows.append(r)

    print(f"windows={len(windows)}")
    for i, r in enumerate(windows, 1):
        rss = r["rss_kib"] if r["rss_kib"] is not None else -1
        print(f"w{i}: prompt={r['prompt_tokens']} gen={r['generated']} "
              f"prefill_s={r['prefill_s']:.2f} decode_s={r['decode_s']:.2f} "
              f"decode_s/gen={r['decode_s_per_gen']:.4f} "
              f"wall/total_tok={r['wall_per_total_token']:.4f} "
              f"hit={r['hit_rate']:.3f} "
              f"bytes/gen={r['bytes_per_gen']:.1f} "
              f"bytes/total_tok={r['bytes_per_total']:.1f} "
              f"resident={int(r['cache']['bytes_resident_now'])} "
              f"budget={int(r['cache']['budget_bytes'])} "
              f"rss_kib={rss} "
              f"evictions={int(r['cache']['evictions'])} "
              f"bypasses={int(r['cache']['bypasses'])}")

    total_gen = sum(r["generated"] for r in windows)
    total_access = sum(r["cache"]["accesses"] for r in windows)
    total_hits = sum(r["cache"]["hits"] for r in windows)
    print(f"total_generated={total_gen} target={SOAK_TOKEN_TARGET} "
          f"cumulative_hit={total_hits / total_access:.3f}")

    breaches = []
    for i, r in enumerate(windows, 1):
        if r["cache"]["bytes_resident_now"] > r["cache"]["budget_bytes"]:
            breaches.append(f"w{i}: resident over budget")
        if r["rss_kib"] is not None and r["rss_kib"] > RSS_CEILING_KIB:
            breaches.append(f"w{i}: rss {r['rss_kib']} KiB over ceiling "
                            f"{RSS_CEILING_KIB} KiB")
    for b in breaches:
        print("CEILING_BREACH " + b)
    print("ceiling: " + ("BREACH" if breaches else "HELD"))

    xs = list(range(1, len(windows) + 1))
    first, last = windows[0], windows[-1]
    wall_slope = slope(xs, [r["decode_s_per_gen"] for r in windows])
    wall_ratio = (last["decode_s_per_gen"] / first["decode_s_per_gen"]
                  if first["decode_s_per_gen"] else float("inf"))
    wall_deg = wall_slope > 0 and wall_ratio > 1.25
    print(f"wall_trend: slope={wall_slope:+.5f} s/gen/window "
          f"last/first={wall_ratio:.3f} "
          f"{'DEGRADATION' if wall_deg else 'no degradation'}")

    hit_ratio = (last["hit_rate"] / first["hit_rate"]
                 if first["hit_rate"] else float("inf"))
    hit_deg = hit_ratio < 0.8
    print(f"hit_trend: last/first={hit_ratio:.3f} "
          f"{'DEGRADATION' if hit_deg else 'no degradation'}")

    bytes_slope = slope(xs, [r["bytes_per_gen"] for r in windows])
    bytes_ratio = (last["bytes_per_gen"] / first["bytes_per_gen"]
                   if first["bytes_per_gen"] else float("inf"))
    bytes_deg = bytes_ratio > 1.25
    print(f"bytes_trend: slope={bytes_slope:+.1f} B/gen/window "
          f"last/first={bytes_ratio:.3f} "
          f"{'DEGRADATION' if bytes_deg else 'no degradation'}")

    partial = total_gen < SOAK_TOKEN_TARGET
    if partial:
        print(f"completeness: PARTIAL SOAK ({total_gen} < "
              f"{SOAK_TOKEN_TARGET} generated tokens); verdicts "
              f"provisional")
    degraded = wall_deg or hit_deg or bytes_deg or bool(breaches)
    print("VERDICT: " + ("DEGRADATION TREND" if degraded
                         else "NO DEGRADATION TREND")
          + (" (PARTIAL SOAK)" if partial else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
