# core/phase_timing.mojo
# A-036 — Phase timing hooks for the Aesir engine.
#
# One standard run's phases — load, prefill, decode, sample — are timed
# with CLOCK_MONOTONIC nanoseconds and emitted by the engine as a single
# JSON object (PhaseTimings.to_json). The four phases are DISJOINT by
# construction: sampling is fused inside the forward passes, so the
# sampler's own time is accumulated separately at every
# sample_token_from_logits call site in core/inference.mojo (into the
# per-request KVCache.sample_ns_total sink) and SUBTRACTED from the
# prefill/decode spans that contain it (see disjoint_pure_ns). The
# accounted time is therefore exactly load+prefill+decode+sample with
# no double counting, and coverage = accounted / wall is an honest
# measurement, never an assertion: residual_ns names whatever the
# phases do not cover (engine construction gaps, result assembly,
# detokenize-and-print bookkeeping outside the timed spans).
#
# Timing discipline: two clock reads per phase span at most in the
# generation loop (plus two per sampler call, whose cost is itself
# inside the measured sample time); no allocation, formatting, or I/O
# inside any timed span; JSON is rendered once, after the run.
# Clock source is CLOCK_MONOTONIC (clockid 0 via clock_gettime, the
# same source as armvegr.util.now_ns used by the A-030/A-031 benches):
# monotonic, immune to wall-clock adjustments. All times are host wall
# times on the CPU path; no accelerator execution is claimed by any
# number in this module.

from std.ffi import external_call
from std.memory.alloc import unsafe_alloc


def phase_now_ns() -> Int64:
    """CLOCK_MONOTONIC nanoseconds (same source as armvegr.util.now_ns)."""
    var ts = unsafe_alloc[Int64](2)
    _ = external_call["clock_gettime", Int32, Int32, type_of(ts)](0, ts)
    var sec: Int64 = ts[unsafe_offset=0]
    var nsec: Int64 = ts[unsafe_offset=1]
    return sec * 1_000_000_000 + nsec


def disjoint_pure_ns(span_ns: Int64, nested_ns: Int64) -> Int64:
    """Span time with a nested, separately-accounted part removed.

    Used to keep phases disjoint: the prefill/decode spans contain the
    fused sampler calls, whose accumulated time arrives via nested_ns;
    the pure phase time is what remains. Clamped at zero so a clock
    granularity artefact can never produce a negative phase.
    """
    var pure = span_ns - nested_ns
    if pure < 0:
        return 0
    return pure


def _ms_str(ns: Int64) -> String:
    """Nanoseconds rendered as milliseconds with 3 decimals, e.g. 12.345."""
    var sign = String("")
    var v = ns
    if v < 0:
        sign = String("-")
        v = -v
    var whole = v // 1_000_000
    var frac = (v % 1_000_000) // 1000
    var frac_str = String(frac)
    if frac < 10:
        frac_str = String("00") + frac_str
    elif frac < 100:
        frac_str = String("0") + frac_str
    return sign + String(whole) + String(".") + frac_str


struct PhaseTimings(Copyable):
    """Disjoint per-phase timings for one engine run, plus its wall.

    wall_ns spans engine construction start to generation end, so the
    load phase is inside the wall by construction. accounted_ns() is
    the sum of the four disjoint phases; coverage_basis_points() is
    accounted/wall in hundredths of a percent (9860 == 98.60%).
    """

    var load_ns: Int64
    var prefill_ns: Int64
    var decode_ns: Int64
    var sample_ns: Int64
    var wall_ns: Int64
    var prompt_tokens: Int
    var generated_tokens: Int

    def __init__(
        out self,
        load_ns: Int64 = 0,
        prefill_ns: Int64 = 0,
        decode_ns: Int64 = 0,
        sample_ns: Int64 = 0,
        wall_ns: Int64 = 0,
        prompt_tokens: Int = 0,
        generated_tokens: Int = 0,
    ):
        self.load_ns = load_ns
        self.prefill_ns = prefill_ns
        self.decode_ns = decode_ns
        self.sample_ns = sample_ns
        self.wall_ns = wall_ns
        self.prompt_tokens = prompt_tokens
        self.generated_tokens = generated_tokens

    def __copyinit__(out self, existing: Self):
        self.load_ns = existing.load_ns
        self.prefill_ns = existing.prefill_ns
        self.decode_ns = existing.decode_ns
        self.sample_ns = existing.sample_ns
        self.wall_ns = existing.wall_ns
        self.prompt_tokens = existing.prompt_tokens
        self.generated_tokens = existing.generated_tokens

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.load_ns,
            self.prefill_ns,
            self.decode_ns,
            self.sample_ns,
            self.wall_ns,
            self.prompt_tokens,
            self.generated_tokens,
        )

    def accounted_ns(self) -> Int64:
        return self.load_ns + self.prefill_ns + self.decode_ns + self.sample_ns

    def residual_ns(self) -> Int64:
        return self.wall_ns - self.accounted_ns()

    def coverage_basis_points(self) -> Int64:
        """accounted/wall as hundredths of a percent; 0 when wall <= 0."""
        if self.wall_ns <= 0:
            return 0
        return self.accounted_ns() * 10000 // self.wall_ns

    def coverage_percent_str(self) -> String:
        var bp = self.coverage_basis_points()
        var whole = bp // 100
        var frac = bp % 100
        var frac_str = String(frac)
        if frac < 10:
            frac_str = String("0") + frac_str
        return String(whole) + String(".") + frac_str

    def meets_coverage_gate(self) -> Bool:
        """The A-036 acceptance gate: phases account for >= 95% of wall."""
        return self.wall_ns > 0 and self.coverage_basis_points() >= 9500

    def to_json(self) -> String:
        """The engine's timing emission: one JSON object, all fields
        always present (0 when a phase did not run). Times in ms."""
        var j = String("{\"timing_version\":1")
        j += String(",\"load_ms\":") + _ms_str(self.load_ns)
        j += String(",\"prefill_ms\":") + _ms_str(self.prefill_ns)
        j += String(",\"decode_ms\":") + _ms_str(self.decode_ns)
        j += String(",\"sample_ms\":") + _ms_str(self.sample_ns)
        j += String(",\"accounted_ms\":") + _ms_str(self.accounted_ns())
        j += String(",\"wall_ms\":") + _ms_str(self.wall_ns)
        j += String(",\"residual_ms\":") + _ms_str(self.residual_ns())
        j += String(",\"coverage_pct\":") + self.coverage_percent_str()
        j += String(",\"prompt_tokens\":") + String(self.prompt_tokens)
        j += String(",\"generated_tokens\":") + String(self.generated_tokens)
        j += String(",\"clock\":\"CLOCK_MONOTONIC\"")
        j += String(",\"sample_scope\":\"sample_token_from_logits calls in the forward paths\"}")
        return j
