# GAUNTLET verdicts — PASS/FAIL emission with evidence paths (H181).
#
# A Verdict is the framework's output unit: which gate, which verdict,
# the measured value vs the threshold, and where the evidence lives.
# A VerdictSet aggregates many verdicts into one campaign-level judgment
# and emits it as machine-readable JSON.

from gauntlet.gates import Gate, gate_holds
from gauntlet.metrics import Measurement


struct Verdict:
    """One gate's judgment on one measurement."""
    var gate_id: String
    var result: String  # "PASS" or "FAIL"
    var measured: Float64
    var threshold: Float64
    var evidence_path: String

    def __init__(
        out self,
        gate_id: String,
        result: String,
        measured: Float64,
        threshold: Float64,
        evidence_path: String,
    ):
        self.gate_id = gate_id
        self.result = result
        self.threshold = threshold
        self.measured = measured
        self.evidence_path = evidence_path


def judge(g: Gate, m: Measurement) -> Verdict:
    """Evaluate one measurement against one gate; emit its verdict."""
    var ok = gate_holds(g, m)
    var word = String("FAIL")
    if ok:
        word = String("PASS")
    return Verdict(g.gate_id, word, m.value, g.threshold, m.evidence_path)


struct VerdictSet:
    """The campaign-level judgment: many verdicts, one overall word."""
    var title: String
    var verdicts: List[Verdict]

    def __init__(out self, title: String):
        self.title = title
        self.verdicts = List[Verdict]()

    def add(mut self, v: Verdict):
        self.verdicts.append(v.copy())

    def n_pass(self) -> Int:
        var n = 0
        for i in range(len(self.verdicts)):
            if self.verdicts[i].result == "PASS":
                n += 1
        return n

    def overall(self) -> String:
        """One FAIL anywhere fails the set — the gate has teeth."""
        for i in range(len(self.verdicts)):
            if self.verdicts[i].result == "FAIL":
                return String("FAIL")
        return String("PASS")


def _f2s(v: Float64) -> String:
    # Float64 -> String with enough digits for evidence (Mojo String(Float64)
    # gives shortest round-trip; keep it).
    return String(v)


def verdictset_to_json(vs: VerdictSet) -> String:
    """Machine-readable verdict record."""
    var out = String("{\"title\": \"")
    out += vs.title
    out += "\", \"overall\": \""
    out += vs.overall()
    out += "\", \"n_gates\": "
    out += String(len(vs.verdicts))
    out += ", \"n_pass\": "
    out += String(vs.n_pass())
    out += ", \"verdicts\": ["
    for i in range(len(vs.verdicts)):
        var v = vs.verdicts[i]
        if i > 0:
            out += ", "
        out += "{\"gate_id\": \"" + v.gate_id + "\", \"result\": \""
        out += v.result + "\", \"measured\": " + _f2s(v.measured)
        out += ", \"threshold\": " + _f2s(v.threshold)
        out += ", \"evidence\": \"" + v.evidence_path + "\"}"
    out += "]}"
    return out
