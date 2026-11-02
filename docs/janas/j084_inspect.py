#!/usr/bin/env python3
"""J-084 inspection recount: every load-bearing claim in
docs/janas/J084_WHEN_DRAFTS_LOSE.md as an assertion over
the tree and the filed records. Exit 0 iff all checks pass."""
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


module = read("aesir_engine/core/draft_loss_guard.mojo")
suite = read("aesir_engine/tests/test_draft_loss_guard.mojo")
doc = read("docs/janas/J084_WHEN_DRAFTS_LOSE.md")
evidence = read("docs/janas/j084_test_output.txt")
options = read("aesir_engine/core/placement_options.mojo")
facade = read("aesir_engine/aesir.mojo")

check("new module exists and names J-084", "J-084" in module)
check("the disable rule is in the module header before the code",
      module.index("THE DISABLE RULE") < module.index("def guard_decision_name"))
check("the measured-floor arithmetic is in the header before the code",
      module.index("THE MEASURED FLOOR") < module.index("def guard_decision_name")
      and "net < 0" in module and "a* = k * r" in module)
check("window is J-079's, imported and aliased, never restated",
      "from core.speculative_adaptive import ADAPT_WINDOW_ROUNDS" in module
      and "comptime LOSS_WINDOW_ROUNDS = ADAPT_WINDOW_ROUNDS" in module
      and "comptime ADAPT_WINDOW_ROUNDS" not in module)
check("disable needs exactly two consecutive losing windows",
      "comptime LOSS_DISABLE_WINDOWS = 2" in module
      and "consecutive_losing_windows >= LOSS_DISABLE_WINDOWS" in module)
check("a window is losing iff its net is strictly negative",
      "if window_net < 0:" in module)
check("break-even (net == 0) is stated NOT a loss in the header",
      "break-even, net == 0, is NOT a loss" in module)
check("posture is disabled-for-the-session, no re-probe, in header and code",
      "disabled FOR THE SESSION" in module
      and "no automatic" in module and "re-probe" in module
      and "disabled for the session" in module)
check("disable record carries every pinned field in order",
      all(s in module for s in (
          "event=drafts_disabled", "reason=", "proposer_kind=",
          "pair_id=", "text_type=", "language=", "disabled_at_round=",
          "posture=disabled for the session", "plain_cost_per_token=",
          "window_rounds=", "losing_windows_consecutive=",
          "last_window_rate_bp=", "last_window_net=", "total_rounds=",
          "total_drafted=", "total_accepted=", "total_emitted=",
          "total_cost=", "total_value=", "total_net="))
      and module.index("event=drafts_disabled")
      < module.index("disabled_at_round=")
      < module.index("total_net="))
check("the record is refused before any disable",
      "no disable record exists until" in module)
check("a disabled guard refuses further rounds by name",
      "this row is DISABLED for the" in module)
check("row keys validated by J-075's rules (pair id + prose language)",
      "pair id 0 for every" in module
      and "language applies to prose" in module
      and "TEXT_PROSE" in module)
check("evidence is J-071 accounts only, consistency + kind gated",
      "account_is_consistent(account)" in module
      and "account.proposer_kind != guard.proposer_kind" in module)
check("module contains no speed or timing function",
      "def speed" not in module and "external_call" not in module)
check("suite has 12 groups", suite.count("def test_") == 12)
check("suite fixtures are the filed shapes (italian/english/byte/boundary)",
      "12 accepted of 40" in suite and "34 of 40" in suite
      and "14710" in suite and "5000 bp" in suite
      and "300" in suite and "160" in suite)
check("suite pins the disable at exactly round 8 and the record byte-for-byte",
      "disabled at exactly round 8" in suite
      and "byte for byte" in suite)
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
    "aesir_engine/core/draft_loss_guard.mojo",
    "aesir_engine/tests/test_draft_loss_guard.mojo",
    "docs/janas/J084_WHEN_DRAFTS_LOSE.md",
    "docs/janas/j084_inspect.py",
    "docs/janas/j084_inspect_output.txt",
    "docs/janas/j084_test_output.txt",
}
check("no other tree file changed (J-083 module unedited in particular)",
      changed <= allowed
      and "aesir_engine/core/draft_config.mojo" not in changed)
check("doc numbers match the filed test output numbers",
      all(s in evidence for s in (
          "ALL PASS: draft loss guard (12 groups)",
          "ALL PASS: speculative verification account (13 groups)",
          "ALL PASS: speculative draft loop (12 groups)",
          "ALL PASS: draft configuration surface (17 groups)",
          "ALL PASS: learned file (13 groups)"))
      and all(s in doc for s in ("12/12", "13/13", "17/17")))
check("doc files the floor derivation and the NOT PROVEN cells",
      all(s in doc for s in (
          "1500 bp", "5000 bp", "3000 bp", "+47.10", "NOT PROVEN")))

failed = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(failed)}/{len(checks)} checks PASS ==")
sys.exit(1 if failed else 0)
