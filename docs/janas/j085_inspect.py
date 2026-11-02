#!/usr/bin/env python3
"""J-085 inspection recount: every load-bearing claim in
docs/janas/J085_LONG_SESSION_STABILITY.md as an assertion
over the tree and the filed records. Exit 0 iff all checks
pass."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}: {name}")


def read(rel):
    return (ROOT / rel).read_text()


module = read("aesir_engine/core/long_session_stability.mojo")
suite = read("aesir_engine/tests/test_long_session_stability.mojo")
doc = read("docs/janas/J085_LONG_SESSION_STABILITY.md")
evidence = read("docs/janas/j085_test_output.txt")
options = read("aesir_engine/core/placement_options.mojo")
facade = read("aesir_engine/aesir.mojo")

check("new module exists and names J-085", "J-085" in module)
check("the verdict rule is in the module header before the code",
      module.index("THE VERDICT RULE") < module.index("def regime_name"))
check("the three legs are named in the header before the code",
      all(module.index(s) < module.index("def regime_name") for s in (
          "NO DRIFT", "NO STATE LEAKAGE", "MEMORY HELD")))
check("soak constants are the J-033 shape (8 windows, 2,000 floor, 512 ctx)",
      "comptime LONG_SEGMENT_COUNT = 8" in module
      and "comptime LONG_MIN_EMITTED = 2000" in module
      and "comptime LONG_KV_CAPACITY = 512" in module
      and "comptime LONG_PROMPT_MAX = 200" in module)
check("rounds bind J-072's loop over a real LoopState",
      "from core.speculative_loop import" in module
      and "run_loop_round" in module and "LoopState" in module)
check("every round files through J-075's ledger",
      "from core.speculative_acceptance import" in module
      and "record_round(ledger, 1," in module)
check("k is planned by J-079's controller through J-072's plan",
      "plan_adaptive_round" in module
      and "record_adaptive_round" in module
      and "plan_round_k" in module)
check("one J-084 guard per segment, step-form price stated once",
      "loss_guard_start" in module and "record_loss_round" in module
      and "comptime LONG_PLAIN_COST = 100" in module
      and "comptime LONG_DRAFT_STEP_COST = 50" in module)
check("a guard disable stops speculating and falls back plain",
      "decision == GUARD_DISABLED" in module
      and "speculating = False" in module)
check("J-082 binds by band (sampled cap == J-071 band top less one)",
      "from core.speculative_sampling import SAMPLED_K_MAX" in module
      and "SAMPLED_K_MAX == DRAFT_CHECK_MAX_WIDTH - 1" in module)
check("ledger bound + units bound to J-075 (5 rows; 3 + hist bins)",
      "comptime LONG_LEDGER_ROW_BOUND = 5" in module
      and "comptime LEDGER_ROW_UNITS = 3 + ACCEPT_HIST_BINS" in module)
check("drift is J-071's checker over the concatenated streams",
      "identity_first_divergence" in module
      and "report.divergence" in module)
check("leakage is counted, and the verdict refuses any violation",
      "leakage_violations" in module
      and "if report.leakage_violations != 0:" in module)
check("the verdict requires the closing plateau at the row bound",
      "segment_end_rows[n - 1] != report.segment_end_rows[n - 2]" in module
      and "report.ledger_rows_final != LONG_LEDGER_ROW_BOUND" in module)
check("rollback identity and ledger completeness are verdict terms",
      "report.rollback_rows != report.drafted - report.accepted" in module
      and "report.ledger_rounds_total != report.rounds" in module)
check("module contains no speed or timing function",
      "def speed" not in module and "external_call" not in module)
check("suite has 13 groups", suite.count("def test_") == 13)
check("suite pins the soak totals and the round-8 hostile disable",
      "expect_eq(report.emitted, 2224" in suite
      and "divergence exactly -1" in suite
      and "disabled at exactly round 8" in suite
      and "48" in suite)
check("use gate still fails closed (J-036, unedited by this slice)",
      "raise Error(" in options and "draft-check passes do not exist" in options)
check("facade speculative_generate still raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented"
      in facade)
status = subprocess.run(
    ["git", "-C", str(ROOT), "status", "--porcelain"],
    capture_output=True, text=True,
).stdout
changed = {
    line[3:] for line in status.splitlines() if line.strip()
}
allowed = {
    "aesir_engine/core/long_session_stability.mojo",
    "aesir_engine/tests/test_long_session_stability.mojo",
    "docs/janas/J085_LONG_SESSION_STABILITY.md",
    "docs/janas/j085_inspect.py",
    "docs/janas/j085_inspect_output.txt",
    "docs/janas/j085_test_output.txt",
}
check("no other tree file changed (J-071--J-084 modules unedited)",
      changed <= allowed)
check("doc numbers match the filed test output numbers",
      all(s in evidence for s in (
          "ALL PASS: long session stability (13 groups)",
          "ALL PASS: speculative verification account (13 groups)",
          "ALL PASS: speculative draft loop (12 groups)",
          "ALL PASS: draft configuration surface (17 groups)",
          "ALL PASS: speculative sampling correctness (17 groups)",
          "ALL PASS: draft loss guard (12 groups)"))
      and all(s in doc for s in ("13/13", "12/12", "17/17")))
check("doc files the filed totals and the bound table",
      all(s in doc for s in (
          "2,224", "633", "2,517", "1,587", "7,003", "355", "930",
          "154 windows")))
check("doc files the deferred leg, its recipe, and NOT PROVEN",
      all(s in doc for s in (
          "NOT PROVEN", "DEFERRED-WITH-REASON", "J-086",
          "G-PROPOSER", "G-EXECUTOR")))

failed = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(failed)}/{len(checks)} checks PASS ==")
sys.exit(1 if failed else 0)
