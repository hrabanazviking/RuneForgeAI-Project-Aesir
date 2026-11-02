#!/usr/bin/env python3
"""J-077 inspection recount: every admission, binding,
refusal, and deferred-recipe claim in
docs/janas/J077_MTP_HEAD_SUPPORT.md as an assertion over
this tree, J-076's filed census, and the filed admission
record. Run from the repo root. Exit 0 iff all checks pass.
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


def read(rel):
    return (ROOT / rel).read_text(errors="replace")


support = read("aesir_engine/core/mtp_head_support.mojo")
test = read("aesir_engine/tests/test_mtp_head_support.mojo")
census_mod = read("aesir_engine/core/mtp_census.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
loop = read("aesir_engine/core/speculative_loop.mojo")
placement = read("aesir_engine/core/placement_options.mojo")
aesir = read("aesir_engine/aesir.mojo")
record = read("docs/janas/j077_test_output.txt")
doc = read("docs/janas/J077_MTP_HEAD_SUPPORT.md")
admission_out = read("docs/janas/j077_admission_output.txt")
census = json.loads(read("docs/janas/j076_census_output.txt"))

# The admission module exists, binds (does not duplicate).
check("support defines evaluate_mtp_admission",
      "def evaluate_mtp_admission(" in support)
check("support defines admitted_proposer_shape",
      "def admitted_proposer_shape(" in support)
check("support defines mtp_refusal_line",
      "def mtp_refusal_line(" in support)
check("verdict comes from J-076's MtpCensus",
      "from core.mtp_census import" in support and "MtpCensus()" in support)
check("classifier not restated (no substring rules in support)",
      '"nextn" in' not in support and '"mtp" in' not in support
      and '"assistant" in' not in support)
check("shape dispatched through J-072",
      "dispatch_proposer(SLOT_HEAD" in support
      and "from core.speculative_loop import" in support)
check("k cap read from J-071, not restated",
      "plan_proposer(kind).max_k" in support)
check("support names every reason code",
      all(c in support for c in (
          "MTP_ADMITTED", "MTP_REFUSE_NO_MTP", "MTP_REFUSE_VOCAB_ONLY",
          "MTP_REFUSE_NOT_PROVEN", "MTP_REFUSE_EMPTY_FILE_NAME")))
check("assistant-only files the assistant proposer",
      "PROPOSER_ASSISTANT_MODEL" in support)
check("support contains no speed",
      all(w not in support for w in ("tok/s", "benchmark", "time_ns")))

# The test defines its 10 groups.
check("support test defines its 10 groups", all(
    f"def {fn}(" in test for fn in (
        "test_nextn_admitted",
        "test_mixed_heads_admitted",
        "test_assistant_only_admitted",
        "test_no_mtp_refused_by_name",
        "test_vocab_only_refused_by_name",
        "test_not_proven_refused",
        "test_empty_name_refused",
        "test_refusal_lines",
        "test_refused_has_no_shape",
        "test_k_cap_from_j071",
    )))
check("support test labels WITH_MTP fixtures SIMULATED",
      "SIMULATED" in test)
check("support test labels real rows PROVEN inputs",
      "PROVEN" in test)

# J-071/J-072 premises the admission binds to.
check("head slot holds mtp-head and assistant kinds (J-071)",
      "PROPOSER_MTP_HEAD" in verify and "PROPOSER_ASSISTANT_MODEL" in verify
      and "SLOT_HEAD" in verify)
check("loop dispatch refuses wrong slots (J-072)",
      "def dispatch_proposer(" in loop)

# The filed admission over J-076's real census rows.
adm_lines = [ln for ln in admission_out.splitlines() if ln.strip()]
refused = [ln for ln in adm_lines if ln.startswith("REFUSED")]
check("admission files 32 refusal lines (27 censused + 5 named)",
      len(refused) == 32, str(len(refused)))
check("admission summary exact",
      "SUMMARY censused=27 admitted=0 refuse_no_mtp=8 "
      "refuse_vocab_only=19 refuse_not_proven=5" in admission_out)
check("every censused file refused under its J-076 verdict",
      all(
          any(
              pathlib.Path(r["path"]).name in ln
              and r["verdict"] in ln
              for ln in refused
          )
          for r in census
      ))
check("no censused file admitted (zero WITH_MTP in J-076)",
      all(r["verdict"] != "WITH_MTP" for r in census)
      and "ADMITTED file=" not in admission_out)
check("named cases refused as NOT_PROVEN",
      admission_out.count("verdict=NOT_PROVEN") == 5)
check("every refusal line bars plain fallback",
      all("not run plain" in ln for ln in refused))

# Live wiring still absent (Part V state unchanged).
check("require_draft_check_use still fails closed",
      "draft-check passes do not exist in Aesir yet" in placement)
check("engine facade speculative_generate still raises not-implemented",
      "speculative_generate" in aesir and "not-implemented" in aesir)
imported_by = subprocess.run(
    ["grep", "-rl", "from core.mtp_head_support import",
     "--include=*.mojo", "."],
    capture_output=True, text=True, cwd=ROOT).stdout.split()
check("mtp_head_support imported only by its own test",
      imported_by == ["./aesir_engine/tests/test_mtp_head_support.mojo"],
      " ".join(imported_by))

# The filed test record carries the counts.
for line in (
    "ALL PASS: mtp head support (10 groups)",
    "ALL PASS: mtp census classifier (8 groups)",
    "ALL PASS: speculative acceptance measurement (10 groups)",
    "ALL PASS: speculative verification account (13 groups)",
    "ALL PASS: speculative draft loop (12 groups)",
    "ALL PASS: speculative token-identity proof (8 groups;",
    "ALL PASS: cross-model draft pairing (10 groups)",
    "ADMISSION DETERMINISM: run1 sha256 == run2 sha256",
):
    check(f"test record -- {line[:52]}", line in record)

# Doc elements.
for name, needle in (
    ("verdict is CLOSED-WITH-DEFERRED-LEG", "CLOSED-WITH-DEFERRED-LEG"),
    ("first act attempted, box unreachable", "02:07:13Z"),
    ("live leg deferred with reason", "DEFERRED-WITH-REASON"),
    ("recipe names J-071 identity proof", "J-071"),
    ("re-cite point is the J-086 gate", "J-086"),
    ("refused by name, never silently plain", "never silently plain"),
    ("rules recorded as answered-locally", "answered-locally"),
    ("synthetic evidence labelled SIMULATED", "SIMULATED"),
    ("own-build defect recorded", "byte_length"),
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
