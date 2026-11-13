# core/equivalence_gate.mojo
# A-080: Equivalence gate -- the GPU<->CPU output equivalence
# verdict layer scripted into the fast battery (A-035).
#
# This module is the single grading entry point for the fast-tier
# equivalence gate. It deliberately adds NO new grading law: every
# per-position verdict delegates to the A-078 fuzz classifier
# (core/gpu_fuzz.fuzz_classify), which itself builds on the A-045
# parity band (core/parity_battery). The gate layer adds only the
# battery aggregation and the banking decision:
#
#   gate passes  <=>  real divergences == 0 AND invalid == 0
#
# Faithful, near-tie, noise and comparator-artifact verdicts are
# all lawful outcomes with filed classes (standing grading law:
# teacher-forcing rank + logit gap on RAW token sequences, CPU
# engine vs CPU comparator for the oracle side, near-tie band
# rank <= 2 with sub-logit gap = faithful, IQ graded on coherence
# never token-exactness, comparator artifacts checked BEFORE any
# real-defect verdict). A single real or invalid verdict blocks
# banking -- that blocking is what scripts/gate_equivalence.sh
# enforces in the fast tier and the keeper enforces at the seat.

from core.gpu_fuzz import (
    FUZZ_COMPARATOR,
    FUZZ_FAITHFUL,
    FUZZ_INVALID,
    FUZZ_NEAR_TIE,
    FUZZ_NOISE,
    FUZZ_REAL,
    fuzz_classify,
    fuzz_verdict_name,
)

comptime EQUIV_FAITHFUL = FUZZ_FAITHFUL
comptime EQUIV_NEAR_TIE = FUZZ_NEAR_TIE
comptime EQUIV_NOISE = FUZZ_NOISE
comptime EQUIV_COMPARATOR = FUZZ_COMPARATOR
comptime EQUIV_REAL = FUZZ_REAL
comptime EQUIV_INVALID = FUZZ_INVALID


def equiv_classify(
    rank: Int,
    gap: Float32,
    cpu_gap: Float32,
    top_agree: Bool,
    prompt_boundary: Bool,
    iq_format: Bool,
    cpu_margin: Float32,
) -> Int:
    """Verdict for one GPU-vs-CPU teacher-forced position.
    Delegates to the A-078 classifier unchanged, so the fast gate
    can never drift from the fuzz battery's grading law."""
    return fuzz_classify(
        rank, gap, cpu_gap, top_agree, prompt_boundary, iq_format,
        cpu_margin,
    )


def equiv_verdict_name(code: Int) -> String:
    return fuzz_verdict_name(code)


struct EquivBattery:
    """Running tally of equivalence verdicts for one battery.
    Counts are indexed by verdict code offset by +1 so the
    invalid code (-1) lands in slot 0."""

    var counts: List[Int]
    var total: Int

    def __init__(out self):
        self.counts = List[Int]()
        for _ in range(6):
            self.counts.append(0)
        self.total = 0

    def record(mut self, code: Int):
        if code < -1 or code > 4:
            self.counts[0] += 1
        else:
            self.counts[code + 1] += 1
        self.total += 1

    def count(self, code: Int) -> Int:
        if code < -1 or code > 4:
            return 0
        return self.counts[code + 1]

    def gate_passes(self) -> Bool:
        """The banking decision: green only when every position
        was verdicted into a lawful class -- zero real
        divergences and zero invalid rows. An empty battery
        never passes (no evidence is not equivalence)."""
        if self.total <= 0:
            return False
        return self.count(EQUIV_REAL) == 0 and self.count(EQUIV_INVALID) == 0
