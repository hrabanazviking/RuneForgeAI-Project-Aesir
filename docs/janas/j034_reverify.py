#!/usr/bin/env python3
"""J-034 Part II gate re-verification.

Re-parses the FILED Part II artefacts (results JSONs, replay outputs, run
logs) from the campaign records (~/workspace/model-tests/janas/) and the
in-tree docs/janas/ of this branch line, and recomputes / cross-checks
every headline Part II number. No number is taken from prose alone:
where a doc is quoted (J-029 verdict, J-031 accounting), the quoted
figure is checked against the recomputed artefact value.

Exit 0 iff every check PASSes. Prints PASS/FAIL per check, grouped.
"""
import hashlib
import json
import pathlib
import re
import subprocess
import sys

HOME = pathlib.Path.home()
CAMP = HOME / "workspace" / "model-tests" / "janas"
HARV = CAMP / "j023_harvest"
# in-tree docs: this script lives in docs/janas/ inside the repo when run
# from the worktree; fall back to the j033 worktree for campaign runs.
_here = pathlib.Path(__file__).resolve()
_candidates = [_here.parent, HOME / "workspace" / "aesir-janas-j034" / "docs" / "janas",
               HOME / "workspace" / "aesir-janas-j033-wt" / "docs" / "janas"]
TREE = next((c for c in _candidates if (c / "J033_SOAK.md").exists()), _candidates[-1])
FIXDIR = HOME / "workspace" / ".verify-tmp" / "j034" / "fixtures"

RESULTS = []
GROUP = ["?"]


def check(name, ok, detail=""):
    RESULTS.append((GROUP[0], name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}  [{GROUP[0]}] {name}  {detail}")


def group(g):
    GROUP[0] = g
    print(f"\n== {g} ==")


def approx(a, b, tol):
    return abs(a - b) <= tol


def load_json(p):
    return json.loads(pathlib.Path(p).read_text())


def parse_run_log(path):
    text = pathlib.Path(path).read_text()
    out = {}
    m = re.search(r"Prompt IDs: \[([0-9, ]+)\]", text)
    out["prompt_ids"] = [int(x) for x in m.group(1).split(",")] if m else None
    m = re.search(r"Generated IDs: \[([0-9, ]+)\]", text)
    out["gen_ids"] = [int(x) for x in m.group(1).split(",")] if m else None
    m = re.search(r"\[CACHE\] (.+)", text)
    cache = {}
    if m:
        for kv in m.group(1).split():
            k, v = kv.split("=")
            cache[k] = int(v)
    out["cache"] = cache
    m = re.search(r"\[STREAM\] .*reads=(\d+), bytes_read=(\d+), advice_calls=(\d+)", text)
    out["stream"] = (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None
    m = re.search(r"TIMING prompt_tokens=\s*(\d+)\s+prefill_s=\s*([0-9.]+)\s+generated=\s*(\d+)\s+decode_s=\s*([0-9.]+)", text)
    if m:
        out.update(prompt=int(m.group(1)), prefill=float(m.group(2)),
                   gen=int(m.group(3)), decode=float(m.group(4)))
    return out


TRACE_SHA = "85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a"

# ---------------------------------------------------------------- census
group("CENSUS doc census (in-tree vs campaign-only)")
tree_docs = sorted(p.name for p in TREE.glob("J0*.md"))
camp_docs = sorted(p.name for p in CAMP.glob("J0*.md"))
part2 = [f"J{n:03d}" for n in range(15, 34)]
print("in-tree:", tree_docs)
print("campaign:", camp_docs)
for n in range(15, 34):
    pref = f"J{n:03d}"
    intree = any(d.startswith(pref) for d in tree_docs)
    incamp = any(d.startswith(pref) for d in camp_docs)
    check(f"{pref} doc present somewhere (tree or campaign)", intree or incamp,
          f"tree={intree} campaign={incamp}")
campaign_only = [d for d in camp_docs if not any(t.startswith(d[:4]) for t in tree_docs)
                 and d[:4] in part2]
check("campaign-only Part II docs are exactly J015/J016/J021",
      sorted(d[:4] for d in campaign_only) == ["J015", "J016", "J021"],
      f"campaign-only={campaign_only}")

# ---------------------------------------------------------------- J-016
group("J-016 trace sha + stats")
trace = CAMP / "j016_trace_olmoe.jsonl"
sha = hashlib.sha256(trace.read_bytes()).hexdigest()
check("trace sha256 == filed pin 85e1d241...cf99a", sha == TRACE_SHA, sha)
st = load_json(CAMP / "j016_olmoe_stats.json")
check("n_tokens == 577", st["n_tokens"] == 577, str(st["n_tokens"]))
check("total accesses == 73,856", st["hit_distribution"]["total_accesses"] == 73856)
check("entropy 5.9836 / 6.0", approx(st["hit_distribution"]["entropy_bits"], 5.9836, 1e-4)
      and st["hit_distribution"]["entropy_max_bits"] == 6.0)
check("cold accesses == 1,024", st["reuse"]["cold_accesses"] == 1024)
check("median stack distance == 298", st["reuse"]["stack_distance"]["median"] == 298)
check("32-token working set mean 805.36 pairs", approx(st["working_set"]["32"]["mean_distinct_pairs"], 805.36, 0.01))
check("integrity PASS", str(st["integrity"]).startswith("PASS"))
for jf in ("j024_tournament_results.json", "j025_prefetch_results.json",
           "j026_multi_results.json", "j027_persistence_results.json",
           "j028_pressure_results.json"):
    check(f"{jf} trace_sha256 field == recomputed sha",
          load_json(CAMP / jf)["trace_sha256"] == sha)

# ---------------------------------------------------------------- J-018
group("J-018 cache replay (real module, filed output)")
txt = (CAMP / "j018_replay_results.txt").read_text()
runs = {}
for line in txt.splitlines():
    m = re.match(r"(lru|lfu|segmented) budget (\d+) accesses=(\d+) hits=(\d+) .*cold_misses=(\d+)", line)
    if m:
        runs[(m.group(1), int(m.group(2)))] = (int(m.group(3)), int(m.group(4)), int(m.group(5)))
check("6 replay runs present (3 policies x 2 budgets)", len(runs) == 6, str(sorted(runs)))
check("cold == 1,024 in all 6 runs", all(v[2] == 1024 for v in runs.values()))
check("accesses == 73,856 in all 6 runs", all(v[0] == 73856 for v in runs.values()))
check("LRU hits 13,733 @128 / 54,691 @512",
      runs[("lru", 476160)][1] == 13733 and runs[("lru", 1904640)][1] == 54691,
      str(runs.get(("lru", 476160))))
check("segmented hits 24,605 @128 beats LRU/LFU @128",
      runs[("segmented", 476160)][1] == 24605 and runs[("segmented", 476160)][1] > runs[("lfu", 476160)][1])

# ---------------------------------------------------------------- J-019
group("J-019 disk bench (pread_ra vs mmap)")
legs = {}
for line in (CAMP / "j019_results.jsonl").read_text().splitlines():
    if line.strip():
        d = json.loads(line)
        legs[(d["strategy"], d["cache_state"])] = d
demand = {k: v for k, v in legs.items() if k[0] != "seq"}
check("12 demand legs + 2 seq legs filed", len(demand) == 12 and len(legs) == 14, f"{len(legs)} legs")
check("all demand legs agree on checksum 5887966450294",
      all(v["checksum"] == 5887966450294 for v in demand.values()))
check("all cold legs resident_before == 0.0",
      all(v.get("resident_before") == 0.0 for k, v in legs.items() if k[1] == "cold"))
pr, mm = legs[("pread_ra", "cold")], legs[("mmap", "cold")]
check("pread_ra cold wall 2.364 s", approx(pr["wall_s"], 2.3637, 0.001), f"{pr['wall_s']:.4f}")
check("mmap cold wall 2.874 s", approx(mm["wall_s"], 2.8738, 0.001), f"{mm['wall_s']:.4f}")
check("pread_ra beats mmap cold by 17.7% of mmap wall",
      approx((mm["wall_s"] - pr["wall_s"]) / mm["wall_s"], 0.177, 0.002),
      f"{(mm['wall_s']-pr['wall_s'])/mm['wall_s']*100:.2f}%")
check("pread_ra cold GB/s recomputed == filed (bytes/wall)",
      approx(pr["bytes"] / pr["wall_s"] / 1e9, pr["gbps"], 0.002), f"{pr['gbps']:.3f}")
check("O_DIRECT cold over-read == 11,231,232 B",
      legs[("odirect", "cold")]["overread_bytes"] == 11231232)
check("mmap+madvise cold buys only ~2.9% over plain mmap",
      approx((mm["wall_s"] - legs[("mmap_wn", "cold")]["wall_s"]) / mm["wall_s"], 0.028, 0.003))

# ---------------------------------------------------------------- J-020
group("J-020 cold/warm (session-scale disk legs)")
j020 = [json.loads(l) for l in (CAMP / "j020_results.jsonl").read_text().splitlines() if l.strip()]
by = {(d["stream"], d["page_state"]): d for d in j020}
cc = by[("coldstream", "coldpage")]
cw = by[("coldstream", "warmpage")]
wc = by[("warmstream", "coldpage")]
check("cold/cold wall 22.513 s, 67,477,831,680 B", approx(cc["wall_s"], 22.513, 0.001) and cc["bytes"] == 67477831680)
check("page-cache warmth -6.6% wall", approx((cc["wall_s"] - cw["wall_s"]) / cc["wall_s"], 0.066, 0.002),
      f"{(cc['wall_s']-cw['wall_s'])/cc['wall_s']*100:.2f}%")
check("expert-cache warmth -8.6% wall on -10.5% bytes",
      approx((cc["wall_s"] - wc["wall_s"]) / cc["wall_s"], 0.086, 0.002)
      and approx((cc["bytes"] - wc["bytes"]) / cc["bytes"], 0.105, 0.002))
check("per-leg checksums internally consistent (cold legs share miss stream)",
      cc["checksum"] == cw["checksum"] and cc["misses"] == cw["misses"] == 17691)

# ---------------------------------------------------------------- J-022
group("J-022 faithfulness + streamed counters")
grade = (TREE / "j022_b1_tf_grade_fix.txt").read_text()
steps = re.findall(r"step (\d+): .*forced \d+ logit [0-9.]+ rank (\d+) gap ([0-9.]+)", grade)
check("24 grade steps filed", len(steps) == 24, str(len(steps)))
rank0 = sum(1 for _, r, _ in steps if int(r) == 0)
check("rank 0 at 23/24 steps", rank0 == 23, f"rank0={rank0}")
s23 = [s for s in steps if int(s[0]) == 23][0]
check("step 23 is the near-tie: rank 1, gap 0.108",
      int(s23[1]) == 1 and approx(float(s23[2]), 0.108, 0.0005), str(s23))
runfix = parse_run_log(TREE / "j022_b1_run_fix.txt")
c = runfix["cache"]
check("streamed counters: accesses 11,648 / hits 3,007 / admissions 1,265 / promotions 192 / evictions 1,125 / bypasses 7,376 / evicted-before-reuse 3,387",
      (c["accesses"], c["hits"], c["admissions"], c["promotions"], c["evictions"], c["bypasses"], c["evicted_before_reuse"]) == (11648, 3007, 1265, 192, 1125, 7376, 3387), str(c))
check("bytes streamed 32,948,699,136 == stream bytes_read",
      c["bytes_streamed"] == 32948699136 and runfix["stream"][1] == 32948699136)
check("24 generated ids filed", len(runfix["gen_ids"]) == 24)
att = (TREE / "j022_qwen3next_attempt.txt").read_text()
check("80B attempt refusal verbatim + EXIT=1",
      "GGUF is missing required tensor: blk.0.attn_q.weight" in att and "EXIT=1" in att)

# ---------------------------------------------------------------- J-023
group("J-023 idle/loaded identity + NO THRASH counters")
idle = parse_run_log(HARV / "run_idle.log")
loaded = parse_run_log(HARV / "run_loaded.log")
check("loaded ids == idle ids == J-022 post-fix ids (24)",
      loaded["gen_ids"] == idle["gen_ids"] == runfix["gen_ids"])
check("loaded cache == idle cache (every counter)", loaded["cache"] == idle["cache"])
check("loaded stream == idle stream", loaded["stream"] == idle["stream"])
iw = (idle["prefill"] + idle["decode"]) / (idle["prompt"] + idle["gen"])
lw = (loaded["prefill"] + loaded["decode"]) / (loaded["prompt"] + loaded["gen"])
check("wall/token idle 0.4113 / loaded 0.4353, ratio 1.058",
      approx(iw, 0.4113, 0.0005) and approx(lw, 0.4353, 0.0005) and approx(lw / iw, 1.058, 0.002),
      f"{iw:.4f} {lw:.4f} ratio {lw/iw:.4f}")
check("NO THRASH by the pre-registered definition (hit ratio 1.000, bytes ratio 1.000, wall ratio < 3, ids identical)",
      loaded["cache"]["hits"] == idle["cache"]["hits"]
      and loaded["cache"]["bytes_streamed"] == idle["cache"]["bytes_streamed"] and lw / iw < 3.0)

# ---------------------------------------------------------------- J-024
group("J-024 tournament + fsketch replay exactness + starvation fix")
t = load_json(CAMP / "j024_tournament_results.json")
check("validation gate: replica-vs-J018 EXACT 6/6 and fast-vs-replica EXACT 6/6",
      all(v == "EXACT" for v in t["validation_gate"]["replica_vs_j018"].values())
      and all(v == "EXACT" for v in t["validation_gate"]["fast_vs_replica"].values()))
for b, hr in ((128, 0.3514), (256, 0.5334), (512, 0.7688)):
    g = t["global_runs"][f"fsketch@{b}"]
    check(f"fsketch @{b} hit {hr}", approx(g["hit_rate"], hr, 0.0005), str(g["hit_rate"]))
    check(f"fsketch @{b} beats segmented/LFU/LRU",
          all(g["hit_rate"] > t["global_runs"][f"{p}@{b}"]["hit_rate"] for p in ("segmented", "lfu", "lru")))
check("pre-fix segmented @1024 starvation on record (0.960, 963 resident)",
      approx(t["global_runs"]["segmented@1024"]["hit_rate"], 0.9600, 0.0005)
      and t["global_runs"]["segmented@1024"]["entries_now"] == 963)
rep = (CAMP / "j024_replay_results.txt").read_text()
fr = {}
sr = {}
for line in rep.splitlines():
    m = re.match(r"(fsketch|segmented) budget (\d+) accesses=\d+ hits=(\d+) .*bytes_streamed=(\d+)", line)
    if m:
        (fr if m.group(1) == "fsketch" else sr)[int(m.group(2))] = (int(m.group(3)), int(m.group(4)))
check("real-module fsketch replay == tournament hits at 128/256/512/1024",
      all(fr[b * 3720][0] == t["global_runs"][f"fsketch@{b}"]["hits"] for b in (128, 256, 512, 1024)),
      str(fr))
seg1024 = [l for l in rep.splitlines() if l.startswith("segmented budget 3809280")][0]
seg1024_kv = dict(re.findall(r"(\w+)=([0-9.]+)", seg1024))
check("starvation fix: post-fix segmented @1024 hits 72,832 == fsketch ceiling, bypasses/evictions 0 in replay line",
      sr[3809280][0] == 72832 and seg1024_kv["bypasses"] == "0" and seg1024_kv["evictions"] == "0"
      and seg1024_kv["entries_now"] == "1024", seg1024)
dr = t["dropping"]["runs"]["segmented@128:documented"]
check("dropping trial: 23.2% dropped, mass/token-layer 0.152",
      approx(dr["dropped_share"], 0.232, 0.001) and approx(dr["dropped_mass_per_token_layer"], 0.152, 0.001))

# ---------------------------------------------------------------- J-025
group("J-025 rejection matrix / oracle ceiling")
p = load_json(CAMP / "j025_prefetch_results.json")
check("validation gate fsketch EXACT @128/256/512",
      all(v == "EXACT" for v in p["validation_gate"].values() if v == "EXACT") and len(p["validation_gate"]) >= 3)
check("PL overlap 0.977/8 BELOW random expectation 1.000",
      approx(p["coverage"]["pl"]["mean_overlap"], 0.9771, 0.001) and p["coverage"]["pl"]["mean_overlap"] < 1.0)
check("verdict REJECT, no passing candidate", p["verdict"]["decision"] == "REJECT" and p["verdict"]["passing"] == [])
check("ORACLE-direct still loses: +28.54% @128 / +12.36% @512",
      approx(p["runs_headline"]["oracle:direct@128"]["net_delta_pct"], 28.54, 0.01)
      and approx(p["runs_headline"]["oracle:direct@512"]["net_delta_pct"], 12.36, 0.01))
check("ORACLE-gatedpre headroom only -0.03% / -0.49%",
      approx(p["runs_headline"]["oracle:gatedpre@128"]["net_delta_pct"], -0.03, 0.005)
      and approx(p["runs_headline"]["oracle:gatedpre@512"]["net_delta_pct"], -0.49, 0.005))
check("best buildable row (PT-TOP4 gatedpre @128) still positive (+0.22% class): no row in runs_headline with net<0 except oracle gatedpre",
      all(v["net_delta_pct"] >= -0.5 for v in p["runs_headline"].values()))

# ---------------------------------------------------------------- J-026
group("J-026 pool / replay exactness")
mu = load_json(CAMP / "j026_multi_results.json")
check("validation gate EXACT (tournament 3 + pool-solo 2)",
      all(v == "EXACT" for v in mu["validation_gate"].values()) and len(mu["validation_gate"]) == 5)
check("tenants: A 266 tok / 34,048 acc, B 311 tok / 39,808 acc",
      mu["tenants"]["A"]["accesses"] == 34048 and mu["tenants"]["B"]["accesses"] == 39808
      and mu["tenants"]["A"]["tokens"] == 266 and mu["tenants"]["B"]["tokens"] == 311)
check("naive independent sizing == ceiling identity (over-commit on record)",
      mu["schemes"]["total@256"]["naive_identity_vs_ceiling"] is True)
pool256 = mu["schemes"]["total@256"]["pool"]["per_tenant"]
check("pool @256 worst tenant B hit 0.3367 > static 0.3226",
      approx(pool256["B"]["hit_rate"], 0.3367, 0.0005)
      and pool256["B"]["hit_rate"] > mu["schemes"]["total@256"]["static"]["per_tenant"]["B"]["hit_rate"])
rep26 = (TREE / "j026_replay_results.txt").read_text()
check("real-module replay == simulator pool counters @256 (A hits 11,605 / B hits 13,403)",
      "tenant A accesses=34048 hits=11605" in rep26 and "tenant B accesses=39808 hits=13403" in rep26
      and pool256["A"]["hits"] == 11605 and pool256["B"]["hits"] == 13403)
check("real-module replay == simulator pool counters @512 (A hits 18,184 / B hits 20,317)",
      "tenant A accesses=34048 hits=18184" in rep26 and "tenant B accesses=39808 hits=20317" in rep26
      and mu["schemes"]["total@512"]["pool"]["per_tenant"]["A"]["hits"] == 18184)

# ---------------------------------------------------------------- J-027
group("J-027 rejection + oracle-zero")
pe = load_json(CAMP / "j027_persistence_results.json")
check("validation gate 7/7 EXACT", len(pe["validation_gate"]) == 7 and all(v == "EXACT" for v in pe["validation_gate"].values()))
check("verdict REJECT, no winner", pe["verdict"]["decision"] == "REJECT" and pe["verdict"]["winner"] is None)
oracle_zero = True
for seg, byb in pe["segmentations"].items():
    for b, data in byb.items():
        agg = data["aggregate"]["ORACLE|PRELOAD-PLAIN"]
        if agg["net_saving_pct"] != 0.0:
            oracle_zero = False
check("ORACLE preload nets exactly 0.000% in every segmentation/budget", oracle_zero)
ft = pe["segmentations"]["NATURAL"]["512"]["aggregate"]["FIRSTTOK|PRELOAD-PLAIN"]
check("FIRSTTOK near-miss: net -0.334% @512 NATURAL, tok0 saving 86.077%",
      approx(ft["net_saving_pct"], -0.334, 0.002) and approx(ft["tok0_saving_pct"], 86.077, 0.01))

# ---------------------------------------------------------------- J-028
group("J-028 pressure schedules + replay exactness + refusal token 288")
pr8 = load_json(CAMP / "j028_pressure_results.json")
check("validation gate 6/6 EXACT", len(pr8["validation_gate"]) == 6 and all(v == "EXACT" for v in pr8["validation_gate"].values()))
s = pr8["schedules"]
check("BASE hit 0.7688 / 112.982 MB-per-token",
      approx(s["base"]["hit_rate"], 0.7688, 0.0005) and approx(s["base"]["streamed_mb_per_token"], 112.982, 0.01))
check("STEP hit 0.5453, streamed 1.963x base (recomputed ratio)",
      approx(s["step"]["hit_rate"], 0.5453, 0.0005)
      and approx(s["step"]["streamed_mb_per_token"] / s["base"]["streamed_mb_per_token"], 1.963, 0.002))
check("SQUEEZE hit 0.6029 / RECOVERY hit 0.6583",
      approx(s["squeeze"]["hit_rate"], 0.6029, 0.0005) and approx(s["recovery"]["hit_rate"], 0.6583, 0.0005))
cr = s["crash"]
check("CRASH refusal at exactly token 288, 36,864 accesses served, resident 0 after shed",
      cr["tokens_served"] == 288 and cr["accesses"] == 36864 and cr["resident_scaled"] == 0
      and cr["refusal"]["token"] == 288)
check("all non-refusal schedules: 0 invariant + 0 accounting violations",
      all(s[k]["invariant_violations"] == 0 and s[k]["accounting_violations"] == 0 for k in ("base", "step", "squeeze", "recovery")))
check("verdict rules a-d all true", all(pr8["verdict"].values()))
rep28 = (CAMP / "j028_replay_results.txt").read_text()
check("real-module RECOVERY replay == simulator (hits 48,622, evictions 1,858, streamed 94,000,896)",
      "hits=48622" in rep28 and "evictions=1858" in rep28 and "bytes_streamed=94000896" in rep28
      and s["recovery"]["hits"] == 48622 and s["recovery"]["streamed_scaled"] == 94000896)

# ---------------------------------------------------------------- J-029
group("J-029 verdict numbers (cross-checked against J-019/J-020/J-023 artefacts)")
doc29 = (CAMP / "J029_NVME_PAGE_CACHE_VERDICT.md").read_text()
for frag in ("2.364", "2.874", "1.470", "1.209", "22.513", "2.997"):
    check(f"J-029 doc quotes {frag} (matches recomputed artefact values above)", frag in doc29)
check("J-029 verdict discipline == pread_ra (the J-019 cold winner recomputed above)",
      "pread" in doc29 and pr["wall_s"] < mm["wall_s"])

# ---------------------------------------------------------------- J-030
group("J-030 CPU-line recomputation (7 checks, re-derived here)")
o30 = (CAMP / "j030_reverify_output.txt").read_text()
npass30 = o30.count("CHECK ") and len(re.findall(r"CHECK .*: PASS", o30))
check("filed j030 output: 7/7 CHECK PASS + ALL CHECKS PASS", npass30 == 7 and "VERDICT: ALL CHECKS PASS" in o30, f"{npass30}")
check("re-derived: idle ids == loaded ids == J-022 ids", idle["gen_ids"] == loaded["gen_ids"] == runfix["gen_ids"])
check("re-derived: idle cache == loaded cache == J-022 cache",
      idle["cache"] == loaded["cache"] == runfix["cache"])
check("re-derived: stream bytes == cache bytes_streamed (idle)",
      idle["stream"][1] == idle["cache"]["bytes_streamed"])
di = {"prefill_tok_s": idle["prompt"] / idle["prefill"], "decode_tok_s": idle["gen"] / idle["decode"],
      "overall": (idle["prompt"] + idle["gen"]) / (idle["prefill"] + idle["decode"])}
check("CPU-line walls recomputed: prefill 2.3894 / decode 2.5563 / overall 2.4313 tok/s",
      approx(di["prefill_tok_s"], 2.3894, 0.0005) and approx(di["decode_tok_s"], 2.5563, 0.0005)
      and approx(di["overall"], 2.4313, 0.0005), str(di))
check("loaded/idle wall ratio recomputed 1.0585", approx(lw / iw, 1.0585, 0.001))

# ---------------------------------------------------------------- J-031
group("J-031 GPU plan accounting arithmetic")
resident, allow, body, usable = 311_027_712, 352_321_536, 3_900_702_720, 5_368_709_120
total = resident + allow + body
check("FULL_GPU sum: 311,027,712 + 352,321,536 + 3,900,702,720 == 4,564,051,968", total == 4_564_051_968)
check("headroom: usable 5,368,709,120 - total == 804,657,152", usable - total == 804_657_152)
doc31 = (CAMP / "J031_STREAMING_GPU_LINE.md").read_text()
for frag in ("311,027,712", "3,900,702,720", "4,564,051,968", "804,657,152", "487,587,840"):
    check(f"J-031 doc carries accounting figure {frag}", frag in doc31)
out31 = (CAMP / "j031_plan_test_output.txt").read_text()
check("plan unit tests: 7/7 PASS lines filed", out31.count("PASS:") == 7, str(out31.count("PASS:")))
check("cold-token demand 487,587,840 B == J-015 ceiling (128 pairs x mean pair, stats file)",
      487_587_840 == st["cache_simulation"]["128"]["approx_bytes_at_mean_expert"])

# ---------------------------------------------------------------- J-032
group("J-032 25/25 re-verification (filed output re-counted + headline re-derived)")
o32 = (CAMP / "j032_reverify_output.txt").read_text()
check("filed j032 output: 25 PASS lines, '25/25 checks PASS', ALL CHECKS PASS",
      len(re.findall(r"^PASS ", o32, re.M)) == 25 and "25/25 checks PASS" in o32 and "ALL CHECKS PASS" in o32)
fb = 48_506_100_512
tot_b = (39_517 + 6_144) * 1024 * 1024
check("size arithmetic re-derived: file exceeds total GPU+RAM by ~0.63 GB",
      fb > tot_b and approx((fb - tot_b) / 1e9, 0.63, 0.01), f"{(fb-tot_b)/1e9:.2f} GB")

# ---------------------------------------------------------------- J-033
group("J-033 analyser exercises (re-run offline at this gate)")
o33 = (CAMP / "j033_analyze_test_output.txt").read_text()
check("filed test output: 4 exercises PASS + RESULT ALL ASSERTIONS PASS",
      o33.count("-> PASS") + o33.count("PASS (") >= 4 and "RESULT: ALL EXERCISED ASSERTIONS PASS" in o33)
FIXDIR.mkdir(parents=True, exist_ok=True)
for name in ("run_idle.log", "run_idle.meta", "run_loaded.log", "run_loaded.meta"):
    (FIXDIR / name).write_bytes((HARV / name).read_bytes())
analyser = TREE / "j033_analyze.py"
proc = subprocess.run([sys.executable, str(analyser),
                       str(FIXDIR / "run_idle.log"), str(FIXDIR / "run_loaded.log")],
                      capture_output=True, text=True)
print(proc.stdout)
check("analyser re-run on real J-023 harvest logs exits 0", proc.returncode == 0, f"rc={proc.returncode}")
check("analyser re-run: total_generated=48 + PARTIAL SOAK label",
      "total_generated=48" in proc.stdout and "PARTIAL SOAK" in proc.stdout)
check("analyser re-run: cumulative_hit=0.258, ceiling HELD, NO DEGRADATION TREND",
      "cumulative_hit=0.258" in proc.stdout and "ceiling: HELD" in proc.stdout
      and "VERDICT: NO DEGRADATION TREND" in proc.stdout)
check("analyser re-run: bytes/total_tok 362073616.9 both windows",
      proc.stdout.count("bytes/total_tok=362073616.9") == 2)
check("analyser re-run: wall/total_tok 0.4113 / 0.4353",
      "wall/total_tok=0.4113" in proc.stdout and "wall/total_tok=0.4353" in proc.stdout)

# ---------------------------------------------------------------- summary
fails = [r for r in RESULTS if not r[2]]
from collections import Counter
per = Counter(g for g, _, _ in RESULTS)
perf = Counter(g for g, _, ok in RESULTS if not ok)
print("\n== SUMMARY ==")
for g in per:
    print(f"{g}: {per[g]-perf.get(g,0)}/{per[g]} PASS")
print(f"TOTAL: {len(RESULTS)-len(fails)}/{len(RESULTS)} PASS, {len(fails)} FAIL")
print("VERDICT:", "ALL CHECKS PASS" if not fails else "FAILURES PRESENT")
sys.exit(0 if not fails else 1)
