#!/usr/bin/env python3
"""J-075 inspection recount: every inspection, instrument,
measurement-record, and deferred-recipe claim in
docs/janas/J075_ACCEPTANCE_MEASUREMENT.md as an assertion
over this tree and the filed test record.
Run from the repo root. Exit 0 iff all checks pass.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


def read(rel):
    return (ROOT / rel).read_text(errors="replace")


acc = read("aesir_engine/core/speculative_acceptance.mojo")
test = read("aesir_engine/tests/test_speculative_acceptance.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
loop = read("aesir_engine/core/speculative_loop.mojo")
pairing = read("aesir_engine/core/cross_model_pairing.mojo")
aesir = read("aesir_engine/aesir.mojo")
placement = read("aesir_engine/core/placement_options.mojo")
moe_session = read("aesir_engine/core/moe_session.mojo")
record = read("docs/janas/j075_test_output.txt")
doc = read("docs/janas/J075_ACCEPTANCE_MEASUREMENT.md")

# The instrument exists and binds to J-071/J-072 (no parallel accounting).
check("acceptance module defines classify_text", "def classify_text(" in acc)
check("acceptance module defines record_round", "def record_round(" in acc)
check("acceptance module defines record_round_classified",
      "def record_round_classified(" in acc)
check("acceptance module defines rate_basis_points",
      "def rate_basis_points(" in acc)
check("acceptance module defines ledger_totals", "def ledger_totals(" in acc)
check("acceptance module defines row_totals_reproduce",
      "def row_totals_reproduce(" in acc)
check("records gated on J-071 account consistency",
      "account_is_consistent(account)" in acc)
check("kind read from the J-071 account, never restated",
      "account.proposer_kind" in acc and "VerifyAccount" in acc)
check("pair id 1 names the J-074 first pair",
      "PAIR_ID_QWEN3_06B_TO_4B = 1" in acc)
check("acceptance module contains no speed",
      all(w not in acc for w in ("tok/s", "benchmark", "time_ns")))
check("J-071 host contract assigns J-075 the filing",
      "J-075's acceptance" in verify and "instrumentation read accounts" in verify)
check("J-072 loop contains no acceptance statistic (owned here)",
      "contains no speed and no acceptance statistic" in loop)
check("J-074 pairing contains no acceptance statistic (owned here)",
      "contains no acceptance statistic" in pairing)

# The classifier's stated rules are the module's rules.
for token in (
    "TEXT_PROSE", "TEXT_CODE", "TEXT_STRUCTURED",
    "LANG_ENGLISH", "LANG_ITALIAN", "LANG_OTHER", "LANG_NOT_APPLICABLE",
):
    check(f"acceptance module names {token}", token in acc)
check("structured rule stated in the module header",
      "STRUCTURED: starts_structured" in acc)
check("code rule stated in the module header", "CODE: code_fences >= 1" in acc)
check("language threshold stated in the module header",
      "italian_hits >= 2" in acc)

# The test defines its 10 groups and its measurement fixtures.
check("acceptance test defines its 10 groups", all(
    f"def {fn}(" in test for fn in (
        "test_classifier_structured_and_code",
        "test_classifier_prose_and_language",
        "test_record_binds_verify_account",
        "test_record_refusals",
        "test_row_key_separation",
        "test_measurement_italian_collapse",
        "test_measurement_text_types",
        "test_distribution_reproduces_totals",
        "test_classified_recording_path",
        "test_rate_edges_and_names",
    )))
check("acceptance test builds fixtures through plan_verify",
      "plan_verify(" in test)
check("acceptance test contains no speed or timing",
      all(w not in test for w in ("tok/s", "perf_counter", "time_ns")))

# Live wiring still absent (doc section 2).
check("require_draft_check_use still fails closed",
      "draft-check passes do not exist in Aesir yet" in placement
      and "def require_draft_check_use() raises:" in placement)
check("engine facade speculative_generate still raises not-implemented",
      "speculative_generate" in aesir and "not-implemented" in aesir)
import subprocess
imported_by = subprocess.run(
    ["grep", "-rl", "from core.speculative_acceptance import",
     "--include=*.mojo", "."],
    capture_output=True, text=True, cwd=ROOT).stdout.split()
check("acceptance imported only by its own test",
      imported_by == ["./aesir_engine/tests/test_speculative_acceptance.mojo"],
      " ".join(imported_by))
check("MoE session carries no loop or acceptance state",
      "speculative_acceptance" not in moe_session
      and "AcceptanceLedger" not in moe_session)

# The filed test record carries the measurement at its class.
for line in (
    "MEASURE SIMULATED pair=cross_model/1 prose/english accepted=34 drafted=40 rate_bp=8500",
    "MEASURE SIMULATED pair=cross_model/1 prose/italian accepted=12 drafted=40 rate_bp=3000",
    "MEASURE SIMULATED pair=cross_model/1 prose/AGGREGATE accepted=46 drafted=80 rate_bp=5750",
    "MEASURE SIMULATED pair=cross_model/1 code accepted=36 drafted=40 rate_bp=9000",
    "MEASURE SIMULATED pair=cross_model/1 structured accepted=31 drafted=40 rate_bp=7750",
    "MEASURE SIMULATED pair=cross_model/1 ALL accepted=113 drafted=160 rate_bp=7062",
    "ALL PASS: speculative acceptance measurement (10 groups)",
    "ALL PASS: speculative verification account (13 groups)",
    "ALL PASS: speculative draft loop (12 groups)",
    "ALL PASS: speculative token-identity proof (8 groups;",
    "ALL PASS: cross-model draft pairing (10 groups)",
):
    check(f"test record -- {line[:52]}", line in record)

# Doc elements.
for name, needle in (
    ("verdict is CLOSED-WITH-DEFERRED-LEG", "CLOSED-WITH-DEFERRED-LEG"),
    ("measurement class is SIMULATED", "SIMULATED"),
    ("italian row filed at 30.00%", "30.00%"),
    ("english row filed at 85.00%", "85.00%"),
    ("prose aggregate filed at 57.50%", "57.50%"),
    ("real-pair acceptance NOT PROVEN", "Acceptance rates for any real pair — NOT PROVEN"),
    ("re-cite point is the J-086 gate", "J-086"),
    ("guarded idle-gap rule names the 204 heartbeat", "ROADMAP_204_STATE.md"),
    ("ids-first criterion re-cited", "ids-first criterion"),
    ("acceptance filed per pair x text type x language",
     "per pair × text type × language"),
    ("classifier recorded as answered-locally", "answered-locally"),
    ("first pair target pin re-cited", "9190094f"),
):
    check(f"doc element -- {name}", needle in doc)

failed = 0
for name, ok, detail in checks:
    print(("PASS " if ok else "FAIL ") + name + (f" -- {detail}" if detail and not ok else ""))
    failed += 0 if ok else 1
print("== done ==")
print(f"({len(checks) - failed}/{len(checks)} checks PASS)")
sys.exit(1 if failed else 0)
