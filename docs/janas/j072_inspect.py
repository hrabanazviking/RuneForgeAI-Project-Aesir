#!/usr/bin/env python3
"""J-072 inspection recount: every design/wiring claim in
docs/janas/J072_DRAFT_LOOP.md section 2 as an assertion over
this tree. Run from the repo root. Exit 0 iff all checks pass.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))


def read(rel):
    return (ROOT / rel).read_text(errors="replace")


loop = read("aesir_engine/core/speculative_loop.mojo")
spec = read("aesir_engine/core/speculative.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
aesir = read("aesir_engine/aesir.mojo")
placement = read("aesir_engine/core/placement_options.mojo")
moe_session = read("aesir_engine/core/moe_session.mojo")

for fn in (
    "dispatch_proposer",
    "plan_round_k",
    "suggest_next_k",
    "run_loop_round",
    "run_loop",
):
    check(f"loop module defines {fn}", f"def {fn}(" in loop)
check(
    "loop derives rounds through J-071's plan_verify",
    "from core.speculative_verify import" in loop and "plan_verify(" in loop,
)
check(
    "loop k bounds stated (initial 4, caps 15 / 8)",
    "LOOP_K_INITIAL = 4" in loop
    and "LOOP_K_MAX_MODEL = 15" in loop
    and "LOOP_K_MAX_CONVERSATION = 8" in loop,
)
check(
    "capacity shortening is a recorded plan fact",
    "shortened_for_capacity" in loop and "fit_k" in loop,
)
check(
    "rollback asserted against the snapshot (KV, context, proposer KV, RNG)",
    "KV rollback disagrees with the account" in loop
    and "context rollback disagrees with the account" in loop
    and "proposer KV rollback disagrees with the account" in loop
    and "RNG state word changed inside a greedy round" in loop,
)
check(
    "driver asserts identity under J-071's checker",
    "sequences_identical(state.emitted, plain_target)" in loop,
)
check(
    "legacy hard bound reconciled: 15 in code, no 64 bound left",
    "between 1 and 15" in spec and "> 64" not in spec and "must be between 1 and 64" not in spec,
)
check(
    "legacy default 4 retained",
    "num_draft_tokens: Int = 4" in spec,
)
check(
    "J-071 account untouched (band still 2..16)",
    "DRAFT_CHECK_MAX_WIDTH = 16" in verify and "DRAFT_CHECK_MIN_WIDTH = 2" in verify,
)
check(
    "require_draft_check_use still fails closed",
    "draft-check passes do not exist in Aesir yet" in placement
    and "def require_draft_check_use() raises:" in placement,
)
check(
    "engine facade speculative_generate still raises not-implemented",
    "speculative model generation and KV reconciliation are not implemented" in aesir,
)
check(
    "host contract comment for J-072 recorded in aesir.mojo",
    "The draft loop (Janas road J-072)" in aesir
    and "NO session consumes the loop" in aesir,
)
importers = []
for p in (ROOT / "aesir_engine").rglob("*.mojo"):
    if "from core.speculative_loop import" in p.read_text(errors="replace"):
        importers.append(str(p.relative_to(ROOT)))
check(
    "loop imported only by its own test (no session wiring faked)",
    importers == ["aesir_engine/tests/test_speculative_loop.mojo"],
    ", ".join(importers),
)
check(
    "MoE session carries no loop state",
    "speculative_loop" not in moe_session and "LoopState" not in moe_session,
)
check(
    "loop module contains no speed or timing",
    all(w not in loop for w in ("tok/s", "perf_counter", "time_ns", "benchmark")),
)

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
