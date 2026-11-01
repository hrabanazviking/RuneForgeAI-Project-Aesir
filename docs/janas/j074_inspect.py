#!/usr/bin/env python3
"""J-074 inspection recount: every inspection, probe-record,
and deferred-recipe claim in docs/janas/J074_CROSS_MODEL_DRAFTS.md
as an assertion over this tree and the filed probe record.
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


pairing = read("aesir_engine/core/cross_model_pairing.mojo")
test = read("aesir_engine/tests/test_cross_model_pairing.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
loop = read("aesir_engine/core/speculative_loop.mojo")
aesir = read("aesir_engine/aesir.mojo")
placement = read("aesir_engine/core/placement_options.mojo")
moe_session = read("aesir_engine/core/moe_session.mojo")
probe = read("docs/janas/j074_probe_output.txt")
doc = read("docs/janas/J074_CROSS_MODEL_DRAFTS.md")

# The pairing module exists and states the six rules.
check("pairing module defines compare_tokenizers",
      "def compare_tokenizers(" in pairing)
check("pairing module defines evaluate_pair", "def evaluate_pair(" in pairing)
for code in (
    "PAIR_REFUSE_MISSING_FILE", "PAIR_REFUSE_UNKNOWN_FAMILY_PAIRING",
    "PAIR_REFUSE_DRAFTER_NOT_SMALLER", "PAIR_REFUSE_TOKENIZER_UNVERIFIED",
    "PAIR_REFUSE_TOKENIZER_MISMATCH", "PAIR_REFUSE_K_OVER_CAP",
    "PAIR_REFUSE_BUDGET_EXCEEDED",
):
    check(f"pairing module names {code}", code in pairing)
check("k cap read from J-071, not restated",
      "plan_proposer(PROPOSER_CROSS_MODEL).max_k" in pairing)
check("pair memory bound to J-026 shared pool",
      "plan_shared_cache_pool" in pairing
      and "from core.expert_cache import" in pairing)
check("pairing module contains no speed or acceptance statistic",
      all(w not in pairing for w in ("tok/s", "acceptance rate", "benchmark")))

# The test drives the real account and the real J-026 sizing.
check("pairing test defines its 10 groups", all(
    f"def {fn}(" in test for fn in (
        "test_tokenizer_identity_exact",
        "test_tokenizer_single_token_mismatch",
        "test_tokenizer_length_and_merges",
        "test_tokenizer_model_and_special_ids",
        "test_admissible_pair_and_shared_sizing",
        "test_missing_file_refusals",
        "test_family_refusals",
        "test_size_refusals",
        "test_tokenizer_gate_refusals",
        "test_k_and_budget_refusals",
    )))
check("pairing test sizes through plan_shared_cache_pool directly",
      "plan_shared_cache_pool(" in test)
check("pairing test contains no speed or timing",
      all(w not in test for w in ("tok/s", "perf_counter", "time_ns")))

# J-071/J-072 premises the pairing binds to (doc section 2).
check("cross-model shape in J-071 requires tokenizer match",
      "PROPOSER_CROSS_MODEL" in verify and "requires_tokenizer_match" in verify)
check("loop dispatches the cross-model slot",
      "SLOT_CROSS_MODEL" in loop and "dispatch_proposer" in loop)

# Live wiring still absent (doc section 2).
check("require_draft_check_use still fails closed",
      "draft-check passes do not exist in Aesir yet" in placement
      and "def require_draft_check_use() raises:" in placement)
check("engine facade speculative_generate still raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented"
      in aesir)
importers = []
for p in (ROOT / "aesir_engine").rglob("*.mojo"):
    if "from core.cross_model_pairing import" in p.read_text(errors="replace"):
        importers.append(str(p.relative_to(ROOT)))
check("pairing imported only by its own test",
      sorted(importers) == ["aesir_engine/tests/test_cross_model_pairing.mojo"],
      ", ".join(sorted(importers)))
check("MoE session carries no loop or pairing state",
      "speculative_loop" not in moe_session
      and "cross_model_pairing" not in moe_session)

# The filed probe record carries the real-file evidence (doc S3).
for phrase, name in (
    ("9190094f771de3d8ceb8051224e2742813b34bd35080713a9373011e303f1547",
     "target file pin"),
    ("8b05ff93285f1447b5746c39179a2b9b337a1b70446249755761dac2d5660be4",
     "cross-quant file pin"),
    ("2e7e49d0c49e3cce1e5ecb05e2d99c77900a3364ad19ca4d20bbe7c2ebcdf80f",
     "target tokenizer fingerprint"),
    ('"vocab_len": 151936', "target vocab length 151936"),
    ('"merges_len": 151387', "target merges length 151387"),
    ('"first_token_divergence": 151646',
     "same-size relative refused at index 151646"),
    ('"identical": true', "identity passes recorded"),
    ('"identical": false', "mismatch refusals recorded"),
):
    check(f"probe record -- {name}", phrase in probe)

# The doc's first-pair verdict classes + deferred recipe (S4/S6).
for phrase, name in (
    ("Qwen3-0.6B", "first pair drafter named"),
    ("Qwen3-4B", "first pair target named"),
    ("Rules-admissible on paper", "paper-admissibility class stated"),
    ("Pair tokenizer identity — NOT PROVEN", "pair identity NOT PROVEN"),
    ("DEFERRED-WITH-REASON", "live leg deferred with reason"),
    ("J-086", "re-cite point is the J-086 gate"),
    ("J-075", "acceptance owned by J-075"),
    ("ROADMAP_204_STATE.md", "guarded idle-gap rule names the 204 heartbeat"),
    ("token-for-token identity over the full stated generation length",
     "ids-first criterion re-cited"),
    ("REFUSE_TOKENIZER_UNVERIFIED", "unverified refusal named in the doc"),
    ("151,646", "same-size divergence index in the doc"),
    ("answered-locally", "clean-room answers recorded"),
):
    check(f"doc element -- {name}", phrase in doc)

failed = 0
for name, ok, detail in checks:
    if ok:
        print(f"PASS {name}" + (f" -- {detail}" if detail else ""))
    else:
        failed += 1
        print(f"FAIL {name}" + (f" -- {detail}" if detail else ""))
print("== done ==")
print(f"({len(checks) - failed}/{len(checks)} checks PASS)")
sys.exit(1 if failed else 0)
