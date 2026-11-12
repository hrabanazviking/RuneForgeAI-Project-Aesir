# tests/test_phase_timing.mojo
# A-036: phase timing hooks — the accounting arithmetic, the disjoint
# sample subtraction, the JSON emission schema, and the KVCache sampler
# sink. The >=95% coverage of a REAL run is measured by the standalone
# driver (tests/bench_phase_timing_a036.mojo) and filed in the A-036
# ledger; these cases prove the machinery that measurement relies on,
# with synthetic numbers labelled as synthetic.

from core.phase_timing import PhaseTimings, disjoint_pure_ns
from core.mimir_well import MimirWell, KVCache


def test_phase_timing_coverage_arithmetic() raises:
    # Synthetic: 200+300+400+60 = 960 of 1000 -> 96.00%, gate passes.
    var t = PhaseTimings(
        load_ns=200, prefill_ns=300, decode_ns=400, sample_ns=60, wall_ns=1000
    )
    if t.accounted_ns() != 960:
        raise Error("A036: accounted sum wrong")
    if t.residual_ns() != 40:
        raise Error("A036: residual wrong")
    if t.coverage_basis_points() != 9600:
        raise Error("A036: coverage basis points wrong")
    if t.coverage_percent_str() != String("96.00"):
        raise Error("A036: coverage string wrong: " + t.coverage_percent_str())
    if not t.meets_coverage_gate():
        raise Error("A036: 96% must meet the gate")
    # Boundary: exactly 95.00% passes; 94.99% fails.
    var edge = PhaseTimings(
        load_ns=950, prefill_ns=0, decode_ns=0, sample_ns=0, wall_ns=1000
    )
    if not edge.meets_coverage_gate():
        raise Error("A036: exactly 95% must meet the gate")
    var below = PhaseTimings(
        load_ns=9499, prefill_ns=0, decode_ns=0, sample_ns=0, wall_ns=10000
    )
    if below.meets_coverage_gate():
        raise Error("A036: 94.99% must fail the gate")
    # Zero wall is never a pass and never divides by zero.
    var zero = PhaseTimings()
    if zero.meets_coverage_gate() or zero.coverage_basis_points() != 0:
        raise Error("A036: zero wall must fail closed")


def test_phase_timing_disjoint_pure() raises:
    # A span containing fused sampling: pure = span - nested sample.
    if disjoint_pure_ns(1000, 120) != 880:
        raise Error("A036: disjoint subtraction wrong")
    if disjoint_pure_ns(500, 0) != 500:
        raise Error("A036: zero nested must keep the span")
    # Clock-granularity artefact: nested > span clamps to zero, never
    # a negative phase.
    if disjoint_pure_ns(100, 130) != 0:
        raise Error("A036: disjoint subtraction must clamp at zero")


def test_phase_timing_json_schema() raises:
    var t = PhaseTimings(
        load_ns=1_500_000,
        prefill_ns=2_250_000,
        decode_ns=9_000_000,
        sample_ns=250_000,
        wall_ns=13_100_000,
        prompt_tokens=8,
        generated_tokens=32,
    )
    var j = t.to_json()
    if String("\"timing_version\":1") not in j:
        raise Error("A036: JSON missing timing_version: " + j)
    if String("\"load_ms\":1.500") not in j:
        raise Error("A036: JSON load_ms wrong: " + j)
    if String("\"prefill_ms\":2.250") not in j:
        raise Error("A036: JSON prefill_ms wrong: " + j)
    if String("\"decode_ms\":9.000") not in j:
        raise Error("A036: JSON decode_ms wrong: " + j)
    if String("\"sample_ms\":0.250") not in j:
        raise Error("A036: JSON sample_ms wrong: " + j)
    if String("\"accounted_ms\":13.000") not in j:
        raise Error("A036: JSON accounted_ms wrong: " + j)
    if String("\"wall_ms\":13.100") not in j:
        raise Error("A036: JSON wall_ms wrong: " + j)
    if String("\"residual_ms\":0.100") not in j:
        raise Error("A036: JSON residual_ms wrong: " + j)
    if String("\"coverage_pct\":99.23") not in j:
        raise Error("A036: JSON coverage_pct wrong: " + j)
    if String("\"prompt_tokens\":8") not in j:
        raise Error("A036: JSON prompt_tokens wrong: " + j)
    if String("\"generated_tokens\":32") not in j:
        raise Error("A036: JSON generated_tokens wrong: " + j)
    # Degenerate run: every field still present, phases may be zero.
    var empty = PhaseTimings(wall_ns=1000).to_json()
    if String("\"sample_ms\":0.000") not in empty:
        raise Error("A036: degenerate JSON must still emit sample_ms: " + empty)
    if String("\"coverage_pct\":0.00") not in empty:
        raise Error("A036: degenerate JSON coverage wrong: " + empty)


def test_phase_timing_kvcache_sink() raises:
    # The sampler sink starts at zero on a fresh cache and accumulates.
    var well = MimirWell(4 * 1024 * 1024)
    var cache = KVCache(16, 64, well, 2)
    if cache.sample_ns_total != 0:
        raise Error("A036: fresh KVCache sink must be zero")
    cache.sample_ns_total += 1500
    cache.sample_ns_total += 2500
    if cache.sample_ns_total != 4000:
        raise Error("A036: KVCache sink accumulation wrong")
    var copied = cache.copy()
    if copied.sample_ns_total != 4000:
        raise Error("A036: KVCache copy must carry the sink")
