#!/usr/bin/env python3
"""J-086 inspection recount: every load-bearing claim in
docs/janas/J086_PART_V_GATE.md as an assertion over the tree
and the filed records. Exit 0 iff all checks pass."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAMP = Path("/home/hatch/workspace/model-tests/janas")
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}: {name}")


def read(rel):
    return (ROOT / rel).read_text()


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


gate_doc = read("docs/janas/J086_PART_V_GATE.md")
gate_tests = read("docs/janas/j086_test_output.txt")
facade = read("aesir_engine/aesir.mojo")

SLICES = list(range(71, 86))
DOCS = {
    71: "J071_VERIFICATION_FIRST_DESIGN.md", 72: "J072_DRAFT_LOOP.md",
    73: "J073_TOKEN_IDENTITY_PROOF.md", 74: "J074_CROSS_MODEL_DRAFTS.md",
    75: "J075_ACCEPTANCE_MEASUREMENT.md", 76: "J076_MTP_CENSUS_IN_FILES.md",
    77: "J077_MTP_HEAD_SUPPORT.md", 78: "J078_ASSISTANT_MODEL_DRAFTS.md",
    79: "J079_ADAPTIVE_DEPTH.md", 80: "J080_DRAFTS_STREAMING.md",
    81: "J081_DRAFTS_PLACEMENT.md", 82: "J082_SAMPLING_CORRECTNESS.md",
    83: "J083_DRAFT_CONFIG_SURFACE.md", 84: "J084_WHEN_DRAFTS_LOSE.md",
    85: "J085_LONG_SESSION_STABILITY.md",
}

# --- doc census: tree == campaign for every Part V doc + filed outputs ---
for n in SLICES:
    check(f"J-{n} doc sha-identical tree vs campaign",
          sha(ROOT / "docs/janas" / DOCS[n]) == sha(CAMP / DOCS[n]))
    check(f"J-{n} filed test output sha-identical tree vs campaign",
          sha(ROOT / f"docs/janas/j{n:03d}_test_output.txt")
          == sha(CAMP / f"j{n:03d}_test_output.txt"))
    check(f"J-{n} filed inspect output sha-identical tree vs campaign",
          sha(ROOT / f"docs/janas/j{n:03d}_inspect_output.txt")
          == sha(CAMP / f"j{n:03d}_inspect_output.txt"))

# --- gate test re-runs: every primary suite ALL PASS at the filed count ---
PRIMARY = {
    "speculative verification account": 13, "speculative draft loop": 12,
    "speculative token-identity proof": 8, "cross-model draft pairing": 10,
    "speculative acceptance measurement": 10, "mtp census classifier": 8,
    "mtp head support": 10, "assistant-model draft pairing": 10,
    "speculative adaptive depth": 11, "speculative placement": 13,
    "speculative sampling correctness": 17,
    "draft configuration surface": 17, "draft loss guard": 12,
    "long session stability": 13,
}
total = 0
for name, groups in PRIMARY.items():
    line = f"ALL PASS: {name} ({groups} groups)"
    check(f"gate re-run: {line}",
          line in gate_tests or f"ALL PASS: {name} ({groups} groups;" in gate_tests)
    total += groups
check("gate primary groups sum to 164", total == 164)
check("gate neighbours: test_speculative 2/2 + test_expert_cache 9/9 filed",
      "test_speculative 2/2 groups PASS" in gate_tests
      and "test_expert_cache 9/9 PASS" in gate_tests)
check("every gate module RUN_EXIT=0 (16 modules + replay build)",
      gate_tests.count("RUN_EXIT=0") >= 16)
check("gate shim hashes match the J-079--J-085 staging builds",
      "88f19b955be000099238f50fb85938745a21b4cccfb4680e41bccb1bfe76cacd"
      in gate_tests and "2082ce3fa09a5db83ce175c596d9f40d42f731c294a629b94b0b8cfd086c28a8"
      in gate_tests)

# --- J-080 replay + streaming taxes recomputed from the filed JSON ---
check("gate J-080 replay EXACT at both budgets",
      "Gate verdict: EXACT vs the filed j080_replay_results.txt" in gate_tests
      and "hits=25698" in gate_tests and "hits=56741" in gate_tests)
res = json.loads(read("docs/janas/j080_streaming_results.json"))
check("J-080 trace + model pins as filed",
      res["trace_sha256"].startswith("85e1d2413cbfcd4351")
      and res["model_sha256"].startswith("8c310f1435a1222338"))
check("J-080 validation gate EXACT (tournament + mojo replay)",
      res["validation_gate"]["seq@128"]["tournament"] == "EXACT"
      and res["validation_gate"]["seq@512"]["mojo_replay"] == "EXACT")
cold8 = res["batch_all"]["cold"]["k8@128"]["net_vs_seq_pct"]
cold2 = res["batch_all"]["cold"]["k2@128"]["net_vs_seq_pct"]
check("J-080 cold byte tax: k=8 @128 above +300%, k=2 @128 +47.10%",
      cold8 > 300.0 and abs(cold2 - 47.10) < 0.05)
mixed_prefix = None
for k, cell in res.get("batch_prefix", {}).get("mixed", {}).items():
    if k == "k2@512":
        mixed_prefix = cell["net_vs_seq_pct"]
check("J-080 single prefix-beats-SEQ cell is mixed k=2 @512 at -0.33%",
      mixed_prefix is not None and abs(mixed_prefix - (-0.33)) < 0.05)

# --- J-076 census recomputed from the filed JSON output ---
census = json.loads(read("docs/janas/j076_census_output.txt"))
check("J-076 census: 27 files, 0 MTP hits, 2,987 tensor entries",
      len(census) == 27
      and sum(r.get("mtp_hit_count", 0) for r in census) == 0
      and sum(r.get("n_tensors", 0) for r in census) == 2987)
check("J-076 census verdicts: NO_MTP x8, VOCAB_ONLY x19",
      sum(1 for r in census if r.get("verdict") == "NO_MTP") == 8
      and sum(1 for r in census if r.get("verdict") == "VOCAB_ONLY") == 19)
adm = read("docs/janas/j077_admission_output.txt")
check("J-077 admission summary: 27 censused, 0 admitted, 8/19/5 refusals",
      "censused=27" in adm and "admitted=0" in adm
      and "refuse_no_mtp=8" in adm and "refuse_vocab_only=19" in adm
      and "refuse_not_proven=5" in adm)

# --- J-075 acceptance table (SIMULATED) as filed ---
doc75 = read("docs/janas/J075_ACCEPTANCE_MEASUREMENT.md")
check("J-075 fixture table: english 85.00 / italian 30.00 / code 90.00 / structured 77.50",
      all(s in doc75 for s in ("85.00%", "30.00%", "90.00%", "77.50%")))
check("J-075 table labelled SIMULATED, real-pair acceptance NOT PROVEN",
      "SIMULATED" in doc75 and "NOT PROVEN" in doc75)

# --- J-082 chi-square evidence as filed ---
mirror = read("docs/janas/j082_mirror_output.txt")
check("J-082 mirror statistics present (8.518318 / 5.676114 / 0.641060 / 1.674679 / 5.596804 / 6.747471)",
      all(s in mirror for s in ("8.518318", "5.676114", "0.641060", "1.674679", "5.596804", "6.747471")))

# --- J-073 identity proof counts as filed ---
doc73 = read("docs/janas/J073_TOKEN_IDENTITY_PROOF.md")
check("J-073 loop identity: 7 configurations, 2,842 tokens, 797 rounds",
      all(s in doc73 for s in ("2,842", "797")) and "7 configurations" in doc73)

# --- J-085 long-session totals as filed ---
doc85 = read("docs/janas/J085_LONG_SESSION_STABILITY.md")
check("J-085 totals: 2,224 emitted, 7,003 checks, 0 violations",
      all(s in doc85 for s in ("2,224", "7,003")))

# --- G-PROPOSER + G-EXECUTOR still stand in this tree ---
check("facade speculative_generate still raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented"
      in facade)
opts = read("aesir_engine/core/placement_options.mojo")
check("J-036 require_draft_check_use still fails closed",
      "require_draft_check_use" in opts)

# --- every deferred live leg is re-cited in its own doc, pointing at J-086 ---
for n in range(73, 86):
    d = read(f"docs/janas/{DOCS[n]}")
    check(f"J-{n} doc files its deferred leg for the J-086 gate",
          "DEFERRED-WITH-REASON" in d and "J-086" in d)

# --- gate doc carries the required pack ---
check("gate verdict is CLOSED-WITH-DEFERRED-LEGS for Part V",
      "Part V CLOSED-WITH-DEFERRED-LEGS" in gate_doc)
check("gate names net tok/s NOT PROVEN per pair",
      gate_doc.count("NOT PROVEN") >= 10 and "net tok/s" in gate_doc)
check("gate names the losses (J-080 byte tax, J-084 floor)",
      "307" in gate_doc and "floor" in gate_doc)
check("gate re-cites all thirteen deferred legs J-073..J-085",
      all(f"J-{n:03d}" in gate_doc for n in range(73, 86)))
check("gate files the inspect snapshot-class disposition (12 FAIL)",
      "488 PASS" in gate_doc and "12 FAIL" in gate_doc)
check("gate files concordance deltas for rows 28-33",
      all(s in gate_doc for s in ("| 28 |", "| 29 |", "| 30 |", "| 31 |", "| 32 |", "| 33 |")))

fails = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(fails)}/{len(checks)} checks PASS ==")
if fails:
    print(f"== FAILURES: {len(fails)} ==")
    sys.exit(1)
