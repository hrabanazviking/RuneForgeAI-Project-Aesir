#!/usr/bin/env python3
"""J-080 inspection recount: every load-bearing claim in
docs/janas/J080_DRAFTS_STREAMING.md as an assertion over the
filed results, the replay record, and the tree. Exit 0 iff all
checks pass."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RES = json.loads((HERE / "j080_streaming_results.json").read_text())
REPLAY = (HERE / "j080_replay_results.txt").read_text()
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}: {name}")


check("trace sha256 is the J-016 pin",
      RES["trace_sha256"].startswith("85e1d2413cbfcd43516a03d8463c72"))
check("model sha256 is the J-015/J-022 OLMoE pin",
      RES["model_sha256"].startswith("8c310f1435a1222338fd2d3d974975"))
check("trace shape 577 tokens / 73,856 sequential accesses",
      RES["n_tokens"] == 577 and RES["n_accesses_seq"] == 73856)
g = RES["validation_gate"]
check("validation gate EXACT vs tournament at 128/256/512",
      all(g[f"seq@{b}"]["tournament"] == "EXACT" for b in (128, 256, 512)))
check("validation gate EXACT vs real-module replay at 128/512",
      all(g[f"seq@{b}"]["mojo_replay"] == "EXACT" for b in (128, 512)))
for b in ("128", "512"):
    s = RES["seq"][b]
    check(f"SEQ@{b} counters are the J-024 fsketch row",
          (s["hits"], s["evictions"]) == ((25953, 1050) if b == "128"
                                          else (56781, 1668)))
v = RES["verdict"]
check("no buildable BATCH-ALL cell is cache-neutral at either budget",
      v["neutral_or_better_cells"] == [])
check("verdict is MIXED per the pre-registered rule",
      v["verdict"].startswith("MIXED"))
check("the only prefix-beats-SEQ cell is mixed/k2@512",
      v["prefix_beats_seq_cells"] == ["mixed/k2@512"])
for b in ("128", "512"):
    for k in (2, 4):
        check(f"hot == perfect at k{k}@{b} (filed fixtures accept all)",
              RES["batch_all"]["hot"][f"k{k}@{b}"]["net_vs_seq_pct"]
              == RES["batch_all"]["perfect"][f"k{k}@{b}"]["net_vs_seq_pct"]
              and RES["batch_all"]["hot"][f"k{k}@{b}"]["waste_accesses"] == 0)
    nets = [RES["batch_all"]["cold"][f"k{k}@{b}"]["net_vs_seq_pct"]
            for k in (2, 4, 8)]
    check(f"cold waste tax strictly grows with k @{b}",
          nets[0] < nets[1] < nets[2])
    check(f"cold k8 tax exceeds +190% @{b}", nets[2] > 190.0)
    check(f"even PERFECT batching costs bytes at k8 @{b}",
          RES["batch_all"]["perfect"][f"k8@{b}"]["net_vs_seq_pct"] > 0.0)
    prefs = {RES["batch_prefix"]["cold"][f"k{k}@{b}"]["net_vs_seq_pct"]
             for k in (2, 4, 8)}
    check(f"cold PREFIX identical across k @{b} (A set by L alone)",
          len(prefs) == 1)
# Headline real-module replay: parse the Mojo record, compare EXACT.
for line in REPLAY.strip().splitlines():
    parts = line.replace("batch_all k4 hot budget ", "").split()
    budget = int(parts[0])
    kv = dict(p.split("=", 1) for p in parts[1:] if "=" in p)
    b = "128" if budget == 128 * 3720 else "512"
    s = RES["batch_all"]["hot"][f"k4@{b}"]
    # bytes_streamed in the Mojo record is in scaled bytes (the
    # replay's scaled construction), compared against the
    # simulator's streamed_scaled directly:
    check(f"real-module replay streamed/hits/evictions EXACT @{b}",
          int(kv["bytes_streamed"]) == s["streamed_scaled"]
          and int(kv["hits"]) == s["hits"]
          and int(kv["evictions"]) == s["evictions"]
          and int(kv["bypasses"]) == s["bypasses"])
failed = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(failed)}/{len(checks)} checks PASS ==")
sys.exit(1 if failed else 0)
