#!/usr/bin/env python3
"""J-078 inspection recount: every admission, binding,
budget, refusal, and deferred-recipe claim in
docs/janas/J078_ASSISTANT_MODEL_DRAFTS.md as an assertion
over this tree, the filed pair record, and the filed test
record. Run from the repo root. Exit 0 iff all checks pass.
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


module = read("aesir_engine/core/assistant_pairing.mojo")
test = read("aesir_engine/tests/test_assistant_pairing.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
loop = read("aesir_engine/core/speculative_loop.mojo")
placement = read("aesir_engine/core/placement_options.mojo")
aesir = read("aesir_engine/aesir.mojo")
record = read("docs/janas/j078_test_output.txt")
doc = read("docs/janas/J078_ASSISTANT_MODEL_DRAFTS.md")
pair_out = read("docs/janas/j078_pair_record_output.txt")

# The pairing module exists, binds (does not duplicate).
check("pairing defines evaluate_assistant_pair",
      "def evaluate_assistant_pair(" in module)
check("pairing defines admitted_assistant_shape",
      "def admitted_assistant_shape(" in module)
check("pairing defines assistant_pair_refusal_line",
      "def assistant_pair_refusal_line(" in module)
check("census verdicts come from J-076's MtpCensus",
      "from core.mtp_census import" in module and "MtpCensus()" in module)
check("classifier not restated (no substring rules in pairing)",
      '"nextn" in' not in module and '"mtp" in' not in module
      and '"assistant" in' not in module)
check("head-form admission goes through J-077's gate",
      "from core.mtp_head_support import" in module
      and "evaluate_mtp_admission(" in module)
check("tokenizer and sides bound from J-074, not restated",
      "from core.cross_model_pairing import" in module
      and "def compare_tokenizers" not in module
      and "TokenizerComparison" in module and "ModelSide" in module)
check("budget sized through J-026's shared pool only",
      "plan_shared_cache_pool(" in module
      and "plan_expert_cache_budget(" not in module)
check("shape dispatched through J-072's head slot",
      "dispatch_proposer(SLOT_HEAD" in module
      and "from core.speculative_loop import" in module)
check("k cap read from J-071, not restated",
      "plan_proposer(PROPOSER_ASSISTANT_MODEL).max_k" in module)
check("share bound pre-registered at a quarter (250 per mille)",
      "ASSISTANT_MAX_SHARE_PER_MILLE = 250" in module)
check("pairing names every reason code",
      all(c in module for c in (
          "ASSISTANT_ADMITTED", "ASSISTANT_REFUSE_EMPTY_FILE_NAME",
          "ASSISTANT_REFUSE_MISSING_FILE", "ASSISTANT_REFUSE_UNCENSUSED_FILE",
          "ASSISTANT_REFUSE_VOCAB_ONLY", "ASSISTANT_REFUSE_FAMILY_MISMATCH",
          "ASSISTANT_REFUSE_ASSISTANT_FORM",
          "ASSISTANT_REFUSE_TOKENIZER_UNVERIFIED",
          "ASSISTANT_REFUSE_TOKENIZER_MISMATCH",
          "ASSISTANT_REFUSE_ASSISTANT_NOT_SMALLER",
          "ASSISTANT_REFUSE_OVER_BUDGET_SHARE", "ASSISTANT_REFUSE_K_OVER_CAP",
          "ASSISTANT_REFUSE_BUDGET_EXCEEDED")))
check("pairing contains no speed",
      all(w not in module for w in ("tok/s", "benchmark", "time_ns")))

# The test defines its 10 groups and labels its fixtures.
check("pairing test defines its 10 groups", all(
    f"def {fn}(" in test for fn in (
        "test_head_form_admitted",
        "test_standalone_admitted",
        "test_budget_arithmetic_exact",
        "test_missing_empty_uncensused_vocab",
        "test_family_refusals",
        "test_assistant_form_refusal",
        "test_tokenizer_gate",
        "test_size_and_share_refusals",
        "test_k_and_budget_refusals",
        "test_refusal_lines_and_no_shape",
    )))
check("pairing test labels its fixtures SIMULATED", "SIMULATED" in test)

# J-071/J-072 premises the gate binds to.
check("head slot holds the assistant kind (J-071)",
      "PROPOSER_ASSISTANT_MODEL" in verify and "SLOT_HEAD" in verify)
check("loop dispatch refuses wrong slots (J-072)",
      "def dispatch_proposer(" in loop)

# The filed pair record over real ground.
refused = [ln for ln in pair_out.splitlines() if ln.startswith("REFUSED")]
admitted = [ln for ln in pair_out.splitlines() if ln.startswith("ADMITTED")]
check("pair record files 5 refused rows", len(refused) == 5, str(len(refused)))
check("pair record files 2 admitted rows", len(admitted) == 2, str(len(admitted)))
check("pair record summary exact",
      "SUMMARY rows=7 admitted=2 refuse_missing_file=1 "
      "refuse_uncensused=1 refuse_vocab_only=1 refuse_family_mismatch=1 "
      "refuse_not_smaller=1" in pair_out)
check("every admitted row is a SIMULATED fixture",
      all("(SIMULATED)" in ln for ln in admitted))
check("the roadmap's Gemma pair refused as missing",
      any("Gemma 4 assistant file" in ln and "REFUSE_MISSING_FILE" in ln
          for ln in refused))
check("every refusal line bars running the pair",
      all("not run" in ln for ln in refused))
check("record budgets agree with the doc's arithmetic",
      "budget_bytes=3450000000" in pair_out
      and "budget_bytes=3250000000" in pair_out
      and "3,450,000,000" in doc and "3,250,000,000" in doc
      and "16,550,000,000" in doc and "share_per_mille=103" in pair_out)

# Live wiring still absent (Part V state unchanged).
check("require_draft_check_use still fails closed",
      "draft-check passes do not exist in Aesir yet" in placement)
check("engine facade speculative_generate still raises not-implemented",
      "speculative_generate" in aesir and "not-implemented" in aesir)
imported_by = subprocess.run(
    ["grep", "-rl", "from core.assistant_pairing import",
     "--include=*.mojo", "."],
    capture_output=True, text=True, cwd=ROOT).stdout.split()
check("assistant_pairing imported only by its own test",
      imported_by == ["./aesir_engine/tests/test_assistant_pairing.mojo"],
      " ".join(imported_by))

# The filed test record carries the counts.
for line in (
    "ALL PASS: assistant-model draft pairing (10 groups)",
    "ALL PASS: mtp head support (10 groups)",
    "ALL PASS: mtp census classifier (8 groups)",
    "ALL PASS: cross-model draft pairing (10 groups)",
    "ALL PASS: speculative verification account (13 groups)",
    "ALL PASS: speculative draft loop (12 groups)",
    "ALL PASS: speculative token-identity proof (8 groups;",
    "ALL PASS: speculative acceptance measurement (10 groups)",
    "PAIR RECORD DETERMINISM: run1 sha256 == run2 sha256",
):
    check(f"test record -- {line[:52]}", line in record)

# Doc elements.
for name, needle in (
    ("verdict is CLOSED-WITH-DEFERRED-LEG", "CLOSED-WITH-DEFERRED-LEG"),
    ("box unreachable, last seen filed", "02:07:13Z"),
    ("measured gain deferred with reason", "DEFERRED-WITH-REASON"),
    ("recipe names the J-072 loop", "run_loop_round"),
    ("recipe names J-075 acceptance per text type", "per text type"),
    ("re-cite point is the J-086 gate", "J-086"),
    ("rules recorded as answered-locally", "answered-locally"),
    ("fixture evidence labelled SIMULATED", "SIMULATED"),
    ("no defect found in prior work, stated", "No defect was found"),
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
