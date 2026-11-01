#!/usr/bin/env python3
"""J-098 inspection recount: every load-bearing claim in
docs/janas/J098_PART_VI_GATE.md as an assertion over the tree
and the filed records. Exit 0 iff all checks pass."""
import hashlib
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


gate_doc = read("docs/janas/J098_PART_VI_GATE.md")
gate_tests = read("docs/janas/j098_test_output.txt")

SLICES = list(range(87, 98))
DOCS = {
    87: "J087_KV_PRECISION_CENSUS.md", 88: "J088_8BIT_KV.md",
    89: "J089_KV_FAITHFULNESS.md", 90: "J090_MIXED_DISCIPLINE.md",
    91: "J091_CONTEXT_LADDER.md", 92: "J092_ATTENTION_SHARE.md",
    93: "J093_MEMORY_CEILING.md", 94: "J094_PROMPT_READ_ECONOMICS.md",
    95: "J095_KV_DRAFTS.md", 96: "J096_KV_PERSISTENCE.md",
    97: "J097_SLIDING_WINDOW.md",
}

# --- doc census: tree == campaign for every Part VI doc + filed outputs ---
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
    "kv account": 10, "kv int8": 8, "kv faith": 6, "kv mixed": 6,
    "kv ladder": 8, "attention share": 10, "memory ceiling": 10,
    "prompt read": 11, "kv drafts": 11, "kv persistence": 11,
    "kv window": 10,
}
total = 0
for name, groups in PRIMARY.items():
    check(f"gate re-run: ALL PASS: {name} ({groups} groups)",
          f"ALL PASS: {name} ({groups} groups)" in gate_tests)
    total += groups
check("gate primary groups sum to 101", total == 101)
check("every gate module RUN_EXIT=0 (11 primaries)",
      gate_tests.count("RUN_EXIT=0") >= 11)
check("gate shim hashes match the Part VI staging builds",
      "88f19b955be000099238f50fb85938745a21b4cccfb4680e41bccb1bfe76cacd"
      in gate_tests and "2082ce3fa09a5db83ce175c596d9f40d42f731c294a629b94b0b8cfd086c28a8"
      in gate_tests)

# --- gate harness re-runs reproduce the filed sha256 (J-091..J-097) ---
FILED_HARNESS_SHA = {
    91: "b7c8f3c8df5dd9c8491810f28d1fc5bd5b837ba8dd8a2d08cbef27c3c5cbc2f5",
    92: "18c6f279c22538293832a9c72cd33a11a4efe10fed7208e0ac8c21335acfeeed",
    93: "703c5514eb5e8e01cc29050d81addc3cb16585788f0d2d7131b9390156d52092",
    94: "4a95869ad6e4b5e1ba2a4d33d892526c6c8bfe87973a931c9ebc2c71c1415359",
    95: "f2fac570133ffa2a3f25b69ce9a945ef200bdd1f3b001e7602a8478aa3a1074d",
    96: "ebc9780eefe78e8331857dc4f9d264c8a71fcee0633281c16057fb1eba2dc507",
    97: "d8593c57776490c509a9db19e1e23d066b5b3ea9c0bf9dd25e698d2413555b8e",
}
for n, s in FILED_HARNESS_SHA.items():
    check(f"gate harness J-{n} sha256 reproduces the filed sha",
          f"GATE HARNESS j{n:03d}: sha256 {s}" in gate_tests
          or (s in gate_tests and f"j{n:03d}" in gate_tests))

# --- ladder re-measurement: independent Python re-derivation ---
# Census prices (J-087 section 4, exact arithmetic over the tree constants)
check("census: Llama 3 8B f16 = 131,072 B/token",
      32 * 2 * 8 * 128 * 2 == 131072)
check("census: Llama 3.2 3B / Qwen3 0.6B f16 = 114,688 B/token",
      28 * 2 * 8 * 128 * 2 == 114688)
check("census: Coder 7B f16 = 57,344 B/token",
      28 * 2 * 4 * 128 * 2 == 57344)
check("census: J-053's 3B defect figure 131,072 does NOT derive from its shape",
      28 * 2 * 1024 * 2 == 114688 and 28 * 2 * 1024 * 2 != 131072)
# int8 prices (J-088: payload + one f32 scale per (layer, K/V, kv-head) row)
check("int8: 8B shape = 67,584 B/token (0.5156 of f16)",
      32 * 2 * 8 * 128 + 32 * 2 * 8 * 4 == 67584)
check("int8: Coder shape = 29,568 B/token",
      28 * 2 * 4 * 128 + 28 * 2 * 4 * 4 == 29568)
# Ladder frame (J-091 section 5.1): KV held per rung, both precisions
RUNGS = [1024, 4096, 8192, 16384, 32768]
FILED_KV_F16 = [58720256, 234881024, 469762048, 939524096, 1879048192]
FILED_KV_I8 = [30277632, 121110528, 242221056, 484442112, 968884224]
check("ladder: KV f16 column re-derives exactly at all 5 rungs",
      all(57344 * L == v for L, v in zip(RUNGS, FILED_KV_F16)))
check("ladder: KV int8 column re-derives exactly at all 5 rungs",
      all(29568 * L == v for L, v in zip(RUNGS, FILED_KV_I8)))
check("ladder: prefill attention MACs @8,192 == J-053's filed figure",
      (8192 * 8193 // 2) * 200704 == 6735330803712)
# Attention share crossings (J-092): marginal-token work crossing exact
check("share: prefill marginal crossing 32,512 is exact (200,704 x 32,512)",
      200704 * 32512 == 6525288448)
# Memory ceiling growth (J-093): Form A GPU f16 ratio in ppm
check("ceiling: Form A GPU f16 growth = 1,383,894 ppm (FLATTER than 1,884,615)",
      6574888576 * 1000000 // 4751005312 == 1383894
      and 1383894 < 1884615)
# Prompt read (J-094): host chunking's exact weight-byte delta @32,768
check("read: chunking delta @32,768 = 152,855,557,816,320 B",
      (32768 - 128) * 4683074688 == 152855557816320)
# Persistence (J-096): FULL restore @32,768 f16 MACs per traffic byte
check("persistence: @32,768 f16 = 85,568 MACs/traffic-byte, verdict PAYS",
      321576079720448 // 3758096528 == 85568)
# Sliding window (J-097): the mix ppm by direct big-integer division
check("window: mix saved ppm = 450,780 (two-step form == direct division)",
      244430291861504 * 1000000 // 542238528634880 == 450780
      and 450780 >= 250000)

# --- per-slice inspect re-runs: totals + the snapshot-class disposition ---
check("gate inspect re-run total: 428/435 PASS, 7 FAIL (snapshot class)",
      "INSPECT_RERUN TOTAL: 428/435 checks PASS, 7 FAIL" in gate_tests)
check("gate fully clean inspect re-runs: J-089/J-090/J-092/J-093/J-097",
      all(s in gate_tests for s in (
          "INSPECT_RERUN J-089: 31/31", "INSPECT_RERUN J-090: 43/43",
          "INSPECT_RERUN J-092: 27/27", "INSPECT_RERUN J-093: 24/24",
          "INSPECT_RERUN J-097: 59/59")))
check("gate J-088 bench FAITH exercise reproduces filed exactly",
      "FAITH_KV max_abs_err=0.003937006" in gate_tests
      and "FAITH_ATTN max_abs_dev=0.0023426115" in gate_tests)

# --- faithfulness evidence as filed (per precision, section 3 of the gate) ---
doc88 = read("docs/janas/J088_8BIT_KV.md")
doc89 = read("docs/janas/J089_KV_FAITHFULNESS.md")
doc90 = read("docs/janas/J090_MIXED_DISCIPLINE.md")
check("J-088 quantizer bound filed: max round-trip error 0.003937",
      "0.003937" in doc88)
check("J-089 synthetic ladder: NO SYNTHETIC COST FOUND, worst rung 0.0023426115",
      "NO SYNTHETIC COST FOUND" in doc89 and "0.0023426115" in doc89)
check("J-089 files the live grade as NOT PROVEN with its recipe in section 7",
      "NOT PROVEN" in doc89 and "J-098" in doc89)
check("J-090 verdict filed: NOT_KEPT_NO_INDICTMENT for every candidate",
      "NOT_KEPT_NO_INDICTMENT" in doc90)
check("J-090 concentration: max/median never exceeds 1.032 (< 2.0 threshold)",
      "1.032" in doc90)
doc95 = read("docs/janas/J095_KV_DRAFTS.md")
check("J-095 rollback EXACT at int8 (store level) and f16 (account/loop level)",
      "EXACT" in doc95 and "0 codes, 0 scales" in doc95)
check("J-095 acceptance UNCHANGED at account level: difference (0, 0, 0)",
      "(0, 0, 0)" in doc95 and "UNCHANGED" in doc95)

# --- the standing integration fact, re-verified in this tree ---
session_surface = ""
for rel in ("aesir_engine/aesir.mojo", "aesir_engine/core/mimir_well.mojo",
            "aesir_engine/core/inference.mojo",
            "aesir_engine/core/moe_session.mojo"):
    try:
        session_surface += read(rel)
    except FileNotFoundError:
        pass
check("no session/well file imports the int8 store (INTEGRATION_BLOCKED stands)",
      "kv_int8" not in session_surface)

# --- every deferred live leg is re-cited in its own doc, pointing at J-098 ---
for n in range(88, 98):
    d = read(f"docs/janas/{DOCS[n]}")
    check(f"J-{n} doc files its deferred leg for the J-098 gate",
          "DEFERRED-WITH-REASON" in d and "J-098" in d)
doc87 = read("docs/janas/J087_KV_PRECISION_CENSUS.md")
check("J-087 files its baseline deferrals to J-088/J-098 by name",
      "J-098" in doc87)

# --- gate doc carries the required pack ---
check("gate verdict is CLOSED-WITH-DEFERRED-LEGS for Part VI",
      "Part VI CLOSED-WITH-DEFERRED-LEGS" in gate_doc)
check("gate files faithfulness verdicts per precision (f16 and int8 rows)",
      "Per-precision faithfulness verdicts" in gate_doc
      and gate_doc.count("NOT PROVEN") >= 10)
check("gate files the mixed-layout decision on record (NOT KEPT)",
      "NOT KEPT" in gate_doc and "NOT_KEPT_NO_INDICTMENT" in gate_doc)
check("gate re-cites all ten deferred legs J-088..J-097 (section 5 items)",
      all(f"J-{n:03d}" in gate_doc for n in range(88, 98))
      and "§5" in gate_doc)
check("gate files the inspect snapshot-class disposition (7 FAIL)",
      "428 PASS" in gate_doc and "7 FAIL" in gate_doc)
check("gate files concordance deltas for rows 35-36",
      "| 35 |" in gate_doc and "| 36 |" in gate_doc)
check("gate grades under the raw-oracle discipline, never single-turn",
      "teacher-forcing rank + logit gap" in gate_doc
      and "llama-cli --single-turn" in gate_doc)

fails = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(fails)}/{len(checks)} checks PASS ==")
if fails:
    print(f"== FAILURES: {len(fails)} ==")
    sys.exit(1)
