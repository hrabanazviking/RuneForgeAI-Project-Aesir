#!/usr/bin/env python3
"""J-079 inspection recount: every rule, binding, refusal,
measurement, and deferred-recipe claim in
docs/janas/J079_ADAPTIVE_DEPTH.md as an assertion over
this tree, the filed fixture replay, and the filed test
record. Run from the repo root. Exit 0 iff all pass.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


def read(rel):
    return (ROOT / rel).read_text(errors="replace")


module = read("aesir_engine/core/speculative_adaptive.mojo")
test = read("aesir_engine/tests/test_speculative_adaptive.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
loop = read("aesir_engine/core/speculative_loop.mojo")
acceptance = read("aesir_engine/core/speculative_acceptance.mojo")
placement = read("aesir_engine/core/placement_options.mojo")
aesir = read("aesir_engine/aesir.mojo")
record = read("docs/janas/j079_test_output.txt")
doc = read("docs/janas/J079_ADAPTIVE_DEPTH.md")
meas = read("docs/janas/j079_measurement_output.txt")
meas_py = read("docs/janas/j079_measurement.py")

# The controller exists and binds (does not duplicate).
check("adaptive defines record_adaptive_round",
      "def record_adaptive_round(" in module)
check("adaptive defines decide_from_ledger_row",
      "def decide_from_ledger_row(" in module)
check("adaptive defines plan_adaptive_round",
      "def plan_adaptive_round(" in module)
check("evidence gated on J-071's account_is_consistent",
      "account_is_consistent(account)" in module
      and "from core.speculative_verify import" in module)
check("cap read from J-071's plan_proposer, never restated",
      "plan_proposer(kind)" in module and "shape.max_k" in module)
check("floor and start read from J-072, never restated",
      "LOOP_K_MIN" in module and "LOOP_K_INITIAL" in module
      and "from core.speculative_loop import" in module)
check("capacity planning is J-072's plan_round_k",
      "plan_round_k(" in module)
check("ledger rate is J-075's rate_basis_points, not restated",
      "from core.speculative_acceptance import" in module
      and "rate_basis_points(row)" in module)
check("J-075's rate_basis_points exists in its module",
      "def rate_basis_points(" in acceptance)
check("J-071 premises exist (plan_verify, proposer kinds)",
      "def plan_verify(" in verify and "PROPOSER_CROSS_MODEL" in verify)
check("J-072 premises exist (suggest_next_k superseded shape)",
      "def suggest_next_k(" in loop and "def plan_round_k(" in loop)

# The pre-registered rule, exactly as filed.
check("window pre-registered at 4 rounds",
      "ADAPT_WINDOW_ROUNDS = 4" in module)
check("deepen allowance pre-registered at 2 wasted",
      "ADAPT_DEEPEN_MAX_WASTED = 2" in module)
check("cold threshold pre-registered at 3000 bp",
      "ADAPT_COLD_BP = 3000" in module)
check("step pre-registered at 2",
      "ADAPT_STEP = 2" in module)
check("deepen scales with evidence length (exact integers)",
      "wasted * ADAPT_WINDOW_ROUNDS <= ADAPT_DEEPEN_MAX_WASTED"
      " * evidence_rounds" in module)
check("module contains no speed and executes no forward",
      all(w not in module for w in ("tok/s", "benchmark", "time_ns")))

# The test defines its 11 groups and labels its fixtures.
check("adaptive test defines its 11 groups", all(
    f"def {fn}(" in test for fn in (
        "test_initial_and_bounds",
        "test_minimum_evidence",
        "test_deepen_on_hot",
        "test_shallow_on_cold",
        "test_hysteresis_deadband_holds",
        "test_thresholds_exact",
        "test_bounds_clamp_at_cap_and_floor",
        "test_no_pathological_oscillation",
        "test_ledger_row_binding",
        "test_refusals_leave_state_untouched",
        "test_determinism_trajectory_and_planning",
    )))
check("adaptive test labels its fixtures SIMULATED", "SIMULATED" in test)
check("adaptive test builds accounts through J-071's plan_verify",
      "plan_verify(" in test)

# The fixture replay: exact filed lines.
for line in (
    "regime=hot/adaptive drafted=360 accepted=319 wasted=41 emitted=367"
    " rate_bp=8861",
    "regime=hot/adaptive moves=2 trajectory=4->6->8->8",
    "regime=cold/adaptive drafted=104 accepted=48 wasted=56 emitted=96"
    " rate_bp=4615",
    "regime=cold/adaptive moves=1 trajectory=4->2->2",
    "regime=mixed/adaptive moves=0 trajectory=4->4->4",
    "regime=switch/adaptive drafted=264 accepted=175 wasted=89 emitted=223"
    " rate_bp=6628",
    "trajectory=4->6->8->8->8->8->8->6->4->2->2->2->2",
    "regime=hot/fixed8 drafted=384 accepted=336 wasted=48",
    "regime=cold/fixed4 drafted=192 accepted=48 wasted=144",
):
    check(f"measurement -- {line[:52]}", line in meas)
check("measurement script mirrors the filed rule constants",
      "WINDOW = 4" in meas_py and "DEEPEN_MAX_WASTED = 2" in meas_py
      and "COLD_BP = 3000" in meas_py and "STEP = 2" in meas_py)
check("measurement is labelled SIMULATED throughout",
      meas.count("SIMULATED") >= 10)

# Live wiring still absent (Part V state unchanged).
check("require_draft_check_use still fails closed",
      "draft-check passes do not exist in Aesir yet" in placement)
check("engine facade speculative_generate still raises not-implemented",
      "speculative_generate" in aesir and "not-implemented" in aesir)
imported_by = subprocess.run(
    ["grep", "-rl", "from core.speculative_adaptive import",
     "--include=*.mojo", "."],
    capture_output=True, text=True, cwd=ROOT).stdout.split()
check("speculative_adaptive imported only by its own test",
      imported_by == ["./aesir_engine/tests/test_speculative_adaptive.mojo"],
      " ".join(imported_by))

# The filed test record carries the counts.
for line in (
    "ALL PASS: speculative adaptive depth (11 groups)",
    "ALL PASS: speculative verification account (13 groups)",
    "ALL PASS: speculative draft loop (12 groups)",
    "ALL PASS: speculative acceptance measurement (10 groups)",
    "ALL PASS: speculative token-identity proof (8 groups;",
    "ALL PASS: cross-model draft pairing (10 groups)",
    "ALL PASS: mtp census classifier (8 groups)",
    "ALL PASS: mtp head support (10 groups)",
    "ALL PASS: assistant-model draft pairing (10 groups)",
    "MEASUREMENT DETERMINISM: rerun sha256 == filed sha256",
):
    check(f"test record -- {line[:52]}", line in record)

# Doc elements.
for name, needle in (
    ("verdict is CLOSED-WITH-DEFERRED-LEG", "CLOSED-WITH-DEFERRED-LEG"),
    ("box unreachable, last seen filed", "02:07:13Z"),
    ("live tuning deferred with reason", "DEFERRED-WITH-REASON"),
    ("rejected rate-only variant recorded", "REJECTED"),
    ("recipe names the J-072 loop", "run_loop_round"),
    ("re-cite point is the J-086 gate", "J-086"),
    ("rules recorded as answered-locally", "answered-locally"),
    ("fixture evidence labelled SIMULATED", "SIMULATED"),
):
    check(f"doc element -- {name}", needle in doc)

failed = 0
for name, ok, detail in checks:
    print(("PASS " if ok else "FAIL ") + name
          + (f" -- {detail}" if detail and not ok else ""))
    failed += 0 if ok else 1
print("== done ==")
print(f"({len(checks) - failed}/{len(checks)} checks PASS)")
sys.exit(1 if failed else 0)
