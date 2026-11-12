# tests/bench_phase_timing_a036.mojo
# A-036: phase timing hooks — the MEASURED standard run (not in run_all).
#
# Standard run = the pinned stories260K fixture through the AesirEngine
# facade: construct (load phase), generate_tokens("One day, Timmy went
# to", 32) greedy — the same facade configuration A-030 baselined.
# The engine emits AESIR_TIMING_JSON from _run_generation; this driver
# ALSO measures an independent external wall (CLOCK_MONOTONIC around
# construction + generation, the span the JSON wall claims to cover)
# and prints A036_MEASURED lines with both coverages:
#   coverage_engine_pct   = JSON accounted / JSON wall
#   coverage_external_pct = JSON accounted / external wall
# Acceptance (roadmap A-036): the standard run's JSON accounts for
# >= 95% of wall time across phases. Both figures are filed in the
# A-036 ledger exactly as printed here — measured, never asserted.
# Correctness: the greedy token IDs must equal the A-030/A-004 oracle
# (first token 265, 32 IDs) — timing hooks must not change outputs.

from std.sys import argv

from core.phase_timing import phase_now_ns
from aesir import AesirEngine


def _expected_generated() -> List[Int]:
    var e = List[Int]()
    e.append(265); e.append(282); e.append(295); e.append(433)
    e.append(335); e.append(345); e.append(357); e.append(426)
    e.append(342); e.append(394); e.append(261); e.append(370)
    e.append(268); e.append(414); e.append(444); e.append(335)
    e.append(261); e.append(370); e.append(268); e.append(414)
    e.append(444); e.append(426); e.append(291); e.append(268)
    e.append(414); e.append(444); e.append(286); e.append(399)
    e.append(262); e.append(423); e.append(388); e.append(269)
    return e^


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: bench_phase_timing_a036 <model.gguf>")
    var path = String(args[1])
    var reps = 3
    var expected = _expected_generated()
    for r in range(reps):
        var wall_t0 = phase_now_ns()
        var engine = AesirEngine(path)
        var result = engine.generate_tokens("One day, Timmy went to", 32)
        var wall_ext_ns = phase_now_ns() - wall_t0
        if result.prompt_token_count != 8:
            raise Error("A036: prompt token count != oracle 8")
        if result.generated_token_count() != 32:
            raise Error("A036: generated token count != 32")
        for i in range(32):
            if result.token_ids[i] != expected[i]:
                raise Error("A036: generated token differs from oracle at " + String(i))
        var t = result.timings.copy()
        var ext_bp = Int64(0)
        if wall_ext_ns > 0:
            ext_bp = t.accounted_ns() * 10000 // wall_ext_ns
        print(
            "A036_MEASURED rep=", r,
            " load_ns=", t.load_ns,
            " prefill_ns=", t.prefill_ns,
            " decode_ns=", t.decode_ns,
            " sample_ns=", t.sample_ns,
            " accounted_ns=", t.accounted_ns(),
            " wall_engine_ns=", t.wall_ns,
            " wall_external_ns=", wall_ext_ns,
            " coverage_engine_bp=", t.coverage_basis_points(),
            " coverage_external_bp=", ext_bp,
            " gate=", t.meets_coverage_gate(),
        )
        print("A036_JSON: " + t.to_json())
    print("A036_BENCH: PASS")
