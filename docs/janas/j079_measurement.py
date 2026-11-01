#!/usr/bin/env python3
"""J-079 fixture-replay measurement (SIMULATED).

Replays deterministic acceptance fixtures through the
pre-registered adaptive-depth rule (the exact mirror of
aesir_engine/core/speculative_adaptive.mojo: window 4,
deepen +2 only on near-saturation (<= 2 wasted drafts
in the window), cold <= 3000 bp shallow -2,
deadband holds, bounds [1, 15] for the model proposer
used here, start k=4) and through fixed-k baselines
(k = 2, 4, 8), under the cost model stated in
docs/janas/J079_ADAPTIVE_DEPTH.md section 4.

Fixture form: each regime is a repeating cycle of
would-be prefix lengths L -- the number of draft tokens
the proposer would have matched at unbounded depth in
that round. For a round run at depth k:
accepted = min(k, L), drafted = k, wasted = k - accepted,
emitted = accepted + 1 (J-071: the accepted prefix plus
exactly one target token). The same L stream feeds every
strategy, so the comparison is a property of the stated
fixtures, NOT of any model pair. The L cycles are shaped
from J-075's filed fixture shapes (its English-prose row
at k=4 accepts 34/40, its Italian-prose row 12/40, its
code row 36/40, its structured row 31/40), extended past
k=4 by the stated L values so deeper strategies have
something to accept; the extension is part of the
fixture statement, not a measurement of a model.

Run from the repo root or anywhere. Exit 0 always (the
script reports; the Mojo suite asserts the rule).
"""
import pathlib
import sys

WINDOW = 4
DEEPEN_MAX_WASTED = 2
COLD_BP = 3000
STEP = 2
K_MIN = 1
K_MAX = 15  # model-proposer cap, J-071 plan_proposer
K_START = 4
ROUNDS = 48

REGIMES = {
    # Hot, English/code-like: every would-be prefix >= 5.
    "hot": [8, 6, 9, 7, 8, 6, 9, 5],
    # Cold, Italian-like: would-be prefixes in {0, 1, 2},
    # J-075's Italian histogram shape (bins 0/1/2).
    "cold": [1, 0, 2, 1, 1, 0, 1, 2],
    # Mixed, structured-like: wide spread around k=4.
    "mixed": [3, 1, 4, 0, 2, 5, 1, 3],
}


def run_fixed(cycle, k, rounds=ROUNDS):
    drafted = accepted = 0
    for r in range(rounds):
        ell = cycle[r % len(cycle)]
        a = min(k, ell)
        drafted += k
        accepted += a
    return drafted, accepted


def run_adaptive(cycle, rounds=ROUNDS):
    k = K_START
    drafted = accepted = 0
    win_rounds = win_drafted = win_accepted = 0
    moves = 0
    trajectory = [k]
    for r in range(rounds):
        ell = cycle[r % len(cycle)]
        a = min(k, ell)
        drafted += k
        accepted += a
        win_rounds += 1
        win_drafted += k
        win_accepted += a
        if win_rounds == WINDOW:
            rate_bp = win_accepted * 10000 // win_drafted
            wasted_win = win_drafted - win_accepted
            if wasted_win <= DEEPEN_MAX_WASTED and k < K_MAX:
                k = min(K_MAX, k + STEP)
                moves += 1
            elif rate_bp <= COLD_BP and k > K_MIN:
                k = max(K_MIN, k - STEP)
                moves += 1
            trajectory.append(k)
            win_rounds = win_drafted = win_accepted = 0
    return drafted, accepted, moves, trajectory


def run_switch(rounds=ROUNDS):
    """One run over a regime switch: 24 hot rounds, then
    24 cold rounds, adaptive vs fixed k=4."""
    cycle = REGIMES["hot"] * 3 + REGIMES["cold"] * 3
    drafted_f = accepted_f = 0
    for r in range(rounds):
        a = min(4, cycle[r])
        drafted_f += 4
        accepted_f += a
    drafted_a, accepted_a, moves, trajectory = 0, 0, 0, [K_START]
    k = K_START
    win_rounds = win_drafted = win_accepted = 0
    for r in range(rounds):
        a = min(k, cycle[r])
        drafted_a += k
        accepted_a += a
        win_rounds += 1
        win_drafted += k
        win_accepted += a
        if win_rounds == WINDOW:
            rate_bp = win_accepted * 10000 // win_drafted
            wasted_win = win_drafted - win_accepted
            if wasted_win <= DEEPEN_MAX_WASTED and k < K_MAX:
                k = min(K_MAX, k + STEP)
                moves += 1
            elif rate_bp <= COLD_BP and k > K_MIN:
                k = max(K_MIN, k - STEP)
                moves += 1
            trajectory.append(k)
            win_rounds = win_drafted = win_accepted = 0
    return (drafted_f, accepted_f), (drafted_a, accepted_a, moves, trajectory)


def line(name, drafted, accepted, rounds=ROUNDS):
    wasted = drafted - accepted
    emitted = accepted + rounds
    rate_bp = accepted * 10000 // drafted if drafted else 0
    print(
        f"MEASURE SIMULATED regime={name} drafted={drafted} "
        f"accepted={accepted} wasted={wasted} emitted={emitted} "
        f"rate_bp={rate_bp} accepted_per_round_milli="
        f"{accepted * 1000 // rounds} wasted_per_emitted_milli="
        f"{wasted * 1000 // emitted}"
    )


def main():
    print("J-079 fixture replay (SIMULATED) -- adaptive vs fixed k")
    print(
        f"rule window={WINDOW} deepen_max_wasted={DEEPEN_MAX_WASTED} cold_bp={COLD_BP} "
        f"step={STEP} bounds=[{K_MIN},{K_MAX}] start_k={K_START} "
        f"rounds={ROUNDS}"
    )
    print(
        "cost model: drafted=k, accepted=min(k,L), wasted=k-accepted,"
        " emitted=accepted+1 per round"
    )
    for name, cycle in REGIMES.items():
        print(f"-- regime {name}: L cycle {cycle}")
        for k in (2, 4, 8):
            d, a = run_fixed(cycle, k)
            line(f"{name}/fixed{k}", d, a)
        d, a, moves, trajectory = run_adaptive(cycle)
        line(f"{name}/adaptive", d, a)
        print(
            f"MEASURE SIMULATED regime={name}/adaptive moves={moves} "
            f"trajectory={'->'.join(str(x) for x in trajectory)}"
        )
    (df, af), (da, aa, moves, trajectory) = run_switch()
    print("-- regime switch: 24 hot rounds then 24 cold rounds")
    line("switch/fixed4", df, af)
    line("switch/adaptive", da, aa)
    print(
        f"MEASURE SIMULATED regime=switch/adaptive moves={moves} "
        f"trajectory={'->'.join(str(x) for x in trajectory)}"
    )
    print("== done ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
