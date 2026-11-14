"""A-115: Token-exactness policy, encoded -- per quant
family: where token-exactness is owed, where only
coherence is owed, and the gates encode it (Wave 13,
Oracle infrastructure).

The roadmap text: "Per quant family: where
token-exactness is owed (most GEMV paths), where only
coherence is owed (IQ family), the gates encode it.
Acceptance: policy table + gate tests."

Before this slice the policy lived as prose repeated in
every oracle module's header: A-109's harness ("IQ rows
are graded on rank/gap/coherence, never token-
exactness"), A-111's gate ("IQ-family rows are graded on
coherence, never token-exactness (A-115's policy); this
gate ... mints no token-exactness demand"), A-114's
runner (R3: "the per-family policy encoding is A-115's
slice"). Every grader carried the sentence and none
carried the table: a new quant label, or a grader that
forgot the sentence, would have silently defaulted --
most dangerously by token-exactness-grading an IQ row,
the one verdict the standing law forbids. This module
is the ONE encoding: the policy table over the banked
quant axis, the obligation lookup that REFUSES an
unknown label instead of defaulting it, and the policy
gate every oracle grader files by.

THE POLICY TABLE, PRE-REGISTERED (stated here before
any test in tests/test_exactness_policy_a115.mojo was
run). The quant axis is A-114's matrix_quants(), CALLED
-- the ten A-045 measured labels in filed order followed
by the nine IQ labels A-045 filed fixture-limited -- so
the table cannot drift from the matrix it governs. Per
row, exactly one obligation:

  (P1) TOKEN_EXACTNESS_OWED -- the ten measured quants
       (F16, BF16, Q8_0, Q4_0, Q5_0, Q2_K, Q3_K_M,
       Q4_K_M, Q5_K_M, Q6_K). These are the GEMV-path
       families: teacher-forcing rank + logit gap on RAW
       prompts is the owed evidence, graded by A-111's
       near-tie gate value-for-value (exact = FAITHFUL,
       inside the band = FAITHFUL_NEAR_TIE, divergent =
       DIVERGENT). A coherence claim NEVER rescues a
       divergent exactness-owed row: coherence is not
       the currency these families are graded in.
  (P2) COHERENCE_ONLY -- the nine IQ quants (IQ1_S,
       IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S,
       IQ4_NL, IQ4_XS), recognised by A-114's is_iq_quant,
       called. Token-exactness is NEVER owed and NEVER
       demanded: a divergent rank/gap record for an IQ
       row is not a failure and cannot mint one. The
       only grading currency is stated coherence
       evidence: stated + passing = COHERENCE_PASS,
       stated + failing = COHERENCE_FAIL, unstated =
       NOT_GRADED (no coherence evidence filed -- the
       honest verdict A-114 files as FIXTURE_LIMITED on
       its matrix cells today). No coherence evidence
       exists in the banked records yet, so every IQ row
       grades NOT_GRADED until such evidence is filed;
       the policy mints no pass from token records.

THE POLICY GATE, PRE-REGISTERED. For one row (quant,
per-step rank/gap records, comparator_valid, coherence
stated/pass flags), in this order:
  (T1) The quant must be in the table: an unknown or
       empty label is REFUSED (raised), never defaulted
       to either obligation -- a silent default to
       exactness would forge a demand, and to coherence
       would forgive one.
  (T2) The records are validated by A-111's gate
       (gate_steps): inconsistent records (rank 0 with
       a nonzero gap, positive rank with a zero gap,
       length mismatch) are refused, not graded, for
       BOTH obligations.
  (T3) COMPARATOR_ARTIFACT precedes grading, exactly
       as the gate's G2: comparator_valid == False files
       COMPARATOR_ARTIFACT whatever the records or the
       coherence flags show -- check the comparator
       before suspecting the engine (the standing
       comparator-artifact verdict class; the automated
       checklist is A-112's).
  (T4) Exactness-owed: the verdict IS A-111's gate
       verdict, codes 0..4 value-for-value (FAITHFUL /
       FAITHFUL_NEAR_TIE / DIVERGENT /
       COMPARATOR_ARTIFACT / NOT_GRADED on no records).
       The coherence flags are ignored entirely.
  (T5) Coherence-only: the token records are computed
       for the filing (the summary keeps the gate's
       counts as witness) and then DISREGARDED as a
       verdict source: coherence stated + pass =
       COHERENCE_PASS, stated + fail = COHERENCE_FAIL,
       unstated = NOT_GRADED. A divergent token record
       can never turn an IQ row into a failure.
  A row PASSES iff its verdict is FAITHFUL,
  FAITHFUL_NEAR_TIE, or COHERENCE_PASS -- no other
  verdict passes, and NOT_GRADED never passes.

FAMILIES: each row also names its family -- FLOAT (F16,
BF16), GGML_QUANT (the eight measured K / plain quants),
IQ (the nine coherence-only rows). The family is a
filing label derived from the label itself; the
OBLIGATION is the policy, and the two are kept distinct
so a family rename can never smuggle an obligation
change.

RAW-ORACLE DISCIPLINE (standing): every graded row
rests on teacher-forcing rank + logit gap on RAW
prompts, CPU engine vs CPU comparator only, rows pinned
per A-110, band per A-111, artifacts per A-112, corpus
per A-113, matrix per A-114. The policy itself executes
no model, opens no device, and claims no speed and no
accelerator execution: pure arithmetic on stated
records, in the J-031/J-053 account style.
"""

from core.matrix_runner import is_iq_quant, matrix_quants, mx_fnv1a64
from core.near_tie_gate import (
    BAND_COMPARATOR_ARTIFACT,
    BAND_DIVERGENT,
    BAND_FAITHFUL,
    BAND_FAITHFUL_NEAR_TIE,
    BAND_NOT_GRADED,
    GateSummary,
    gate_steps,
)

# Obligations: the policy itself. Exactly one per row.
comptime POLICY_TOKEN_EXACTNESS_OWED = 0
comptime POLICY_COHERENCE_ONLY = 1

# Policy verdicts. 0..4 are value-for-value the A-111
# gate's verdict codes for exactness-owed rows (see the
# header); 5 and 6 are the coherence verdicts only a
# coherence-only row can file.
comptime POL_FAITHFUL = 0
comptime POL_FAITHFUL_NEAR_TIE = 1
comptime POL_DIVERGENT = 2
comptime POL_COMPARATOR_ARTIFACT = 3
comptime POL_NOT_GRADED = 4
comptime POL_COHERENCE_PASS = 5
comptime POL_COHERENCE_FAIL = 6


struct PolicyRow(Copyable, ImplicitlyCopyable):
    """One row of the policy table: a quant label from
    the banked matrix axis, its family filing label, and
    the one obligation the policy assigns it. gate names
    the grading currency in filed words."""

    var quant: String
    var family: String
    var obligation: Int
    var gate: String

    def __init__(
        out self,
        quant: String,
        family: String,
        obligation: Int,
        gate: String,
    ):
        self.quant = quant
        self.family = family
        self.obligation = obligation
        self.gate = gate


struct PolicySummary(Copyable, ImplicitlyCopyable):
    """One row graded by the policy gate: the quant, its
    obligation, the verdict the pre-registered rule
    states, and the A-111 gate summary over the token
    records as witness (computed for both obligations;
    a verdict source only for exactness-owed rows)."""

    var quant: String
    var obligation: Int
    var verdict: Int
    var gate_summary: GateSummary

    def __init__(
        out self,
        quant: String,
        obligation: Int,
        verdict: Int,
        gate_summary: GateSummary,
    ):
        self.quant = quant
        self.obligation = obligation
        self.verdict = verdict
        self.gate_summary = gate_summary


def policy_family(quant: String) -> String:
    """The filing family of a quant label: IQ for the
    IQ family (A-114's predicate, called), FLOAT for
    F16 / BF16, GGML_QUANT for the rest of the axis."""
    if is_iq_quant(quant):
        return String("IQ")
    if quant == String("F16") or quant == String("BF16"):
        return String("FLOAT")
    return String("GGML_QUANT")


def policy_table() -> List[PolicyRow]:
    """The policy table: one row per label on A-114's
    matrix_quants() axis, in axis order, derived -- the
    measured labels are never re-typed here. IQ rows
    (A-114's predicate) are COHERENCE_ONLY; every other
    axis row is TOKEN_EXACTNESS_OWED."""
    var rows = List[PolicyRow]()
    var quants = matrix_quants()
    for i in range(len(quants)):
        var q = quants[i]
        if is_iq_quant(q):
            rows.append(
                PolicyRow(
                    q,
                    policy_family(q),
                    POLICY_COHERENCE_ONLY,
                    String("coherence"),
                )
            )
        else:
            rows.append(
                PolicyRow(
                    q,
                    policy_family(q),
                    POLICY_TOKEN_EXACTNESS_OWED,
                    String("near_tie_gate"),
                )
            )
    return rows^


def policy_for_quant(quant: String) raises -> PolicyRow:
    """The policy row for one label. An unknown or empty
    label is REFUSED, never defaulted (T1): a default to
    exactness would forge a token-exactness demand (the
    forbidden IQ verdict, for a mistyped IQ label), and
    a default to coherence would forgive an owed one."""
    if quant.byte_length() == 0:
        raise Error("ExactnessPolicy: empty quant label refused")
    var rows = policy_table()
    for i in range(len(rows)):
        if rows[i].quant == quant:
            return rows[i]
    raise Error("ExactnessPolicy: unknown quant label refused: " + quant)


def policy_counts() -> List[Int]:
    """[total, exactness_owed, coherence_only] over the
    table, counted from the rows themselves."""
    var rows = policy_table()
    var owed = 0
    var coherence = 0
    for i in range(len(rows)):
        if rows[i].obligation == POLICY_TOKEN_EXACTNESS_OWED:
            owed += 1
        else:
            coherence += 1
    var counts_out = List[Int]()
    counts_out.append(len(rows))
    counts_out.append(owed)
    counts_out.append(coherence)
    return counts_out^


def policy_gate(
    quant: String,
    ranks: List[Int],
    gaps_milli: List[Int],
    comparator_valid: Bool,
    coherence_stated: Bool,
    coherence_pass: Bool,
) raises -> PolicySummary:
    """The pre-registered policy gate (T1-T5) for one
    row. The A-111 gate validates and grades the token
    records first; the obligation then decides whether
    that grade IS the verdict (exactness-owed) or only
    a witness (coherence-only)."""
    var row = policy_for_quant(quant)
    var gs = gate_steps(ranks, gaps_milli, comparator_valid)
    if not comparator_valid:
        return PolicySummary(
            row.quant, row.obligation, POL_COMPARATOR_ARTIFACT, gs
        )
    if row.obligation == POLICY_TOKEN_EXACTNESS_OWED:
        return PolicySummary(row.quant, row.obligation, gs.verdict, gs)
    if not coherence_stated:
        return PolicySummary(
            row.quant, row.obligation, POL_NOT_GRADED, gs
        )
    if coherence_pass:
        return PolicySummary(
            row.quant, row.obligation, POL_COHERENCE_PASS, gs
        )
    return PolicySummary(row.quant, row.obligation, POL_COHERENCE_FAIL, gs)


def policy_passes(summary: PolicySummary) -> Bool:
    """True iff the policy files the row passing:
    FAITHFUL or FAITHFUL_NEAR_TIE (exactness-owed) or
    COHERENCE_PASS (coherence-only). NOT_GRADED never
    passes and a comparator artifact is never a pass."""
    return (
        summary.verdict == POL_FAITHFUL
        or summary.verdict == POL_FAITHFUL_NEAR_TIE
        or summary.verdict == POL_COHERENCE_PASS
    )


def obligation_name(obligation: Int) -> String:
    """The filed name of an obligation code."""
    if obligation == POLICY_TOKEN_EXACTNESS_OWED:
        return String("TOKEN_EXACTNESS_OWED")
    if obligation == POLICY_COHERENCE_ONLY:
        return String("COHERENCE_ONLY")
    return String("UNKNOWN")


def policy_verdict_name(verdict: Int) -> String:
    """The filed name of a policy verdict code -- the
    only strings a policy filing may use for a row."""
    if verdict == POL_FAITHFUL:
        return String("FAITHFUL")
    if verdict == POL_FAITHFUL_NEAR_TIE:
        return String("FAITHFUL_NEAR_TIE")
    if verdict == POL_DIVERGENT:
        return String("DIVERGENT")
    if verdict == POL_COMPARATOR_ARTIFACT:
        return String("COMPARATOR_ARTIFACT")
    if verdict == POL_COHERENCE_PASS:
        return String("COHERENCE_PASS")
    if verdict == POL_COHERENCE_FAIL:
        return String("COHERENCE_FAIL")
    return String("NOT_GRADED")


def policy_row_line(row: PolicyRow) -> String:
    """One policy row as one filed line."""
    var s = String("POL_ROW quant=") + row.quant
    s += String(" family=") + row.family
    s += String(" obligation=") + obligation_name(row.obligation)
    s += String(" gate=") + row.gate
    return s


def policy_render() -> String:
    """The full policy table as filed text: header, one
    line per row in axis order, summary. This is the
    text the digest covers."""
    var rows = policy_table()
    var counts = policy_counts()
    var s = String("A115_POLICY rows=") + String(len(rows)) + String("\n")
    for i in range(len(rows)):
        s += policy_row_line(rows[i]) + String("\n")
    s += String("A115_POLICY_SUMMARY total=") + String(counts[0])
    s += String(" exactness_owed=") + String(counts[1])
    s += String(" coherence_only=") + String(counts[2])
    return s


def policy_digest() -> UInt64:
    """FNV-1a 64 digest of the rendered policy table
    (A-114's mx_fnv1a64, called -- the tree's digest
    convention). A re-render reproduces it exactly."""
    return mx_fnv1a64(policy_render())


def policy_line() -> String:
    """The policy's one-line statement, for doctor /
    filing surfaces that quote the rule."""
    return String(
        "A-115 token-exactness policy: the ten measured"
        " GEMV quant families owe token-exactness under"
        " the A-111 near-tie gate; the nine IQ families"
        " owe coherence only and are never graded on"
        " token-exactness; unknown labels are refused"
    )


def policy_gate_codes_match_a111() -> Bool:
    """True iff the policy's exactness verdict codes are
    value-for-value the A-111 gate's, so filings from
    both accounts read alike."""
    return (
        POL_FAITHFUL == BAND_FAITHFUL
        and POL_FAITHFUL_NEAR_TIE == BAND_FAITHFUL_NEAR_TIE
        and POL_DIVERGENT == BAND_DIVERGENT
        and POL_COMPARATOR_ARTIFACT == BAND_COMPARATOR_ARTIFACT
        and POL_NOT_GRADED == BAND_NOT_GRADED
    )
