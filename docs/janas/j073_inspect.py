#!/usr/bin/env python3
"""J-073 inspection recount: every inspection, coverage, and
deferred-recipe claim in docs/janas/J073_TOKEN_IDENTITY_PROOF.md
as an assertion over this tree. Run from the repo root.
Exit 0 iff all checks pass.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


def read(rel):
    return (ROOT / rel).read_text(errors="replace")


ident = read("aesir_engine/tests/test_speculative_identity.mojo")
loop = read("aesir_engine/core/speculative_loop.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
aesir = read("aesir_engine/aesir.mojo")
placement = read("aesir_engine/core/placement_options.mojo")
moe_session = read("aesir_engine/core/moe_session.mojo")
doc = read("docs/janas/J073_TOKEN_IDENTITY_PROOF.md")

# The proof test exists and drives the real J-072 loop.
check("identity test defines its 8 groups", all(
    f"def {fn}(" in ident for fn in (
        "test_checker_negative_control",
        "test_head_mtp_always_right_long",
        "test_head_assistant_band_top_long",
        "test_cross_always_wrong_zero_stretch",
        "test_conversation_alternating_cap",
        "test_cross_coincidence_traps",
        "test_capacity_shortened_tail",
        "test_slot_switching_long",
    )))
check("identity test drives run_loop and run_loop_round",
      "run_loop(" in ident and "run_loop_round(" in ident)
check("identity test grades through J-071's checker",
      "sequences_identical" in ident and "identity_first_divergence" in ident)
check("identity test contains no speed or timing",
      all(w not in ident for w in ("tok/s", "perf_counter", "time_ns", "benchmark")))

# Coverage markers: lengths, k values, adversarial shapes.
for marker, name in (
    ("500, 21", "config A: 500 tokens"),
    ("512, 22", "config B: 512 tokens at the band top"),
    ("range(295)", "config C: 295 zero-accepted rounds"),
    ("range(39)", "config D: 39 alternating pairs at the conversation cap"),
    ("range(148)", "config E: 148 coincidence-trap rounds"),
    ("shortened", "config F: capacity-shortened rounds recorded"),
    ("range(25)", "config G: 25 slot-switching cycles"),
    ("2842 tokens, 797 rounds", "filed totals stated in the suite"),
    ("257", "negative control: tamper index 257"),
):
    check(f"coverage marker -- {name}", marker in ident)
check("identity test states its honesty grade (SIMULATED, not live)",
      "SIMULATED" in ident and "NOT a live model proof" in ident)
check("capacity shortening goes through plan_round_k",
      "plan_round_k(" in ident and "shortened_for_capacity" in ident)

# Live wiring still absent (J-073 section 2).
check("require_draft_check_use still fails closed",
      "draft-check passes do not exist in Aesir yet" in placement
      and "def require_draft_check_use() raises:" in placement)
check("engine facade speculative_generate still raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented" in aesir)
importers = []
for p in (ROOT / "aesir_engine").rglob("*.mojo"):
    if "from core.speculative_loop import" in p.read_text(errors="replace"):
        importers.append(str(p.relative_to(ROOT)))
check("loop imported only by its own test and the J-073 proof test",
      sorted(importers) == [
          "aesir_engine/tests/test_speculative_identity.mojo",
          "aesir_engine/tests/test_speculative_loop.mojo",
      ],
      ", ".join(sorted(importers)))
check("MoE session carries no loop state",
      "speculative_loop" not in moe_session and "LoopState" not in moe_session)
check("loop and account modules carry the J-071/J-072 premises",
      "run_loop" in loop and "DRAFT_CHECK_MAX_WIDTH = 16" in verify)

# The doc's deferred live leg: recipe elements present.
for phrase, name in (
    ("DEFERRED-WITH-REASON", "live leg deferred with reason"),
    ("J-086", "re-cite point is the J-086 gate"),
    ("J-074", "dependency slice J-074 named"),
    ("J-077", "dependency slice J-077 named"),
    ("J-078", "dependency slice J-078 named"),
    ("no slice of their own yet in Part V", "unroaded wiring named honestly"),
    ("Llama 3 8B", "arch row Llama 3 8B"),
    ("Llama 3.2 3B", "arch row Llama 3.2 3B"),
    ("Gemma 4 E2B", "arch row Gemma 4 E2B"),
    ("Gemma 4 E4B", "arch row Gemma 4 E4B"),
    ("Qwen3 0.6B", "arch row Qwen3 0.6B"),
    ("Qwen2.5 Coder 7B", "arch row Qwen2.5 Coder 7B"),
    ("Qwen3.5", "arch row Qwen3.5"),
    ("OLMoE", "arch row OLMoE"),
    ("teacher-forcing rank + logit gap", "raw-oracle grading in the recipe"),
    ("never `llama-cli --single-turn`", "template-rendering comparator refused"),
    ("ROADMAP_204_STATE.md", "guarded idle-gap rule names the 204 heartbeat"),
    ("token-for-token identity over the full stated generation length",
     "live pass criterion stated exactly"),
    ("NOT a live model proof", "loop proof graded in the doc's own words"),
    ("CLOSED-WITH-DEFERRED-LEG", "verdict shape stated"),
):
    check(f"doc recipe element -- {name}", phrase in doc)

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
