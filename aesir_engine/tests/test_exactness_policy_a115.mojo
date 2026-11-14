# tests/test_exactness_policy_a115.mojo
# A-115: Token-exactness policy, encoded -- the policy
# table + gate tests. These cases cover: the table over
# the banked A-114 quant axis (19 rows, in axis order,
# derived not re-typed), every measured quant owing
# token-exactness, every IQ quant owing coherence only
# and never token-exactness, unknown labels refused
# (never defaulted), exact and near-tie passes for
# exactness-owed rows with the A-111 band edges binding,
# divergence failing an exactness-owed row, divergence
# NEVER failing an IQ row, coherence pass / fail /
# unstated for IQ rows, comparator-artifact precedence
# for both obligations, coherence never rescuing an
# exactness-owed divergence, inconsistent records
# refused, and a deterministic table digest.

from core.exactness_policy import (
    POLICY_COHERENCE_ONLY,
    POLICY_TOKEN_EXACTNESS_OWED,
    POL_COHERENCE_FAIL,
    POL_COHERENCE_PASS,
    POL_COMPARATOR_ARTIFACT,
    POL_DIVERGENT,
    POL_FAITHFUL,
    POL_FAITHFUL_NEAR_TIE,
    POL_NOT_GRADED,
    PolicyRow,
    obligation_name,
    policy_counts,
    policy_digest,
    policy_family,
    policy_for_quant,
    policy_gate,
    policy_gate_codes_match_a111,
    policy_line,
    policy_passes,
    policy_render,
    policy_row_line,
    policy_table,
    policy_verdict_name,
)
from core.matrix_runner import is_iq_quant, matrix_quants


def _gate(
    quant: String,
    ranks: List[Int],
    gaps: List[Int],
    comparator_valid: Bool,
    coherence_stated: Bool,
    coherence_pass: Bool,
) raises -> Int:
    var s = policy_gate(
        quant, ranks, gaps, comparator_valid, coherence_stated,
        coherence_pass,
    )
    return s.verdict


def _raises_lookup(quant: String) -> Bool:
    try:
        _ = policy_for_quant(quant)
    except:
        return True
    return False


def _raises_gate(
    quant: String,
    ranks: List[Int],
    gaps: List[Int],
) -> Bool:
    try:
        _ = policy_gate(quant, ranks, gaps, True, False, False)
    except:
        return True
    return False


def test_policy_table_complete() raises:
    var rows = policy_table()
    var quants = matrix_quants()
    if len(rows) != 19 or len(quants) != 19:
        raise Error("policy table is not the 19-row matrix axis")
    for i in range(len(rows)):
        if rows[i].quant != quants[i]:
            raise Error("policy row drifted from matrix axis order")
    var counts = policy_counts()
    if counts[0] != 19 or counts[1] != 10 or counts[2] != 9:
        raise Error("policy counts are not 19 / 10 owed / 9 coherence")
    if not policy_gate_codes_match_a111():
        raise Error("policy verdict codes drifted from the A-111 gate")
    if policy_family("F16") != String("FLOAT"):
        raise Error("F16 family is not FLOAT")
    if policy_family("Q4_K_M") != String("GGML_QUANT"):
        raise Error("Q4_K_M family is not GGML_QUANT")
    if policy_family("IQ3_S") != String("IQ"):
        raise Error("IQ3_S family is not IQ")


def test_policy_measured_exactness_owed() raises:
    var rows = policy_table()
    var owed = 0
    for i in range(len(rows)):
        if not is_iq_quant(rows[i].quant):
            owed += 1
            if rows[i].obligation != POLICY_TOKEN_EXACTNESS_OWED:
                raise Error(
                    "measured quant not exactness-owed: " + rows[i].quant
                )
            if rows[i].gate != String("near_tie_gate"):
                raise Error("exactness row lost its gate name")
            var one = policy_for_quant(rows[i].quant)
            if one.obligation != POLICY_TOKEN_EXACTNESS_OWED:
                raise Error("lookup disagrees with table: " + rows[i].quant)
    if owed != 10:
        raise Error("exactness-owed row count is not 10")


def test_policy_iq_coherence_only() raises:
    var rows = policy_table()
    var iq = 0
    for i in range(len(rows)):
        if is_iq_quant(rows[i].quant):
            iq += 1
            if rows[i].obligation != POLICY_COHERENCE_ONLY:
                raise Error("IQ quant not coherence-only: " + rows[i].quant)
            if rows[i].gate != String("coherence"):
                raise Error("IQ row lost its gate name")
    if iq != 9:
        raise Error("IQ row count is not 9")
    var labels = List[String]()
    labels.append(String("IQ1_S"))
    labels.append(String("IQ1_M"))
    labels.append(String("IQ2_XXS"))
    labels.append(String("IQ2_XS"))
    labels.append(String("IQ2_S"))
    labels.append(String("IQ3_XXS"))
    labels.append(String("IQ3_S"))
    labels.append(String("IQ4_NL"))
    labels.append(String("IQ4_XS"))
    for k in range(len(labels)):
        var row = policy_for_quant(labels[k])
        if row.obligation != POLICY_COHERENCE_ONLY:
            raise Error("filed IQ label not coherence-only: " + labels[k])


def test_policy_unknown_refused() raises:
    if not _raises_lookup("Q9_X"):
        raise Error("unknown quant label was defaulted, not refused")
    if not _raises_lookup(""):
        raise Error("empty quant label was defaulted, not refused")
    if not _raises_lookup("iq2_xs"):
        raise Error("case-drifted IQ label was silently accepted")
    if not _raises_lookup("Q4_K"):
        raise Error("truncated quant label was silently accepted")
    var ranks = List[Int]()
    ranks.append(0)
    var gaps = List[Int]()
    gaps.append(0)
    if not _raises_gate("Q9_X", ranks, gaps):
        raise Error("gate graded an unknown quant instead of refusing")


def test_policy_exact_pass() raises:
    var ranks = List[Int]()
    ranks.append(0)
    ranks.append(0)
    ranks.append(0)
    var gaps = List[Int]()
    gaps.append(0)
    gaps.append(0)
    gaps.append(0)
    var s = policy_gate("F16", ranks, gaps, True, False, False)
    if s.verdict != POL_FAITHFUL:
        raise Error("all-exact F16 row is not FAITHFUL")
    if not policy_passes(s):
        raise Error("FAITHFUL row does not pass the policy gate")
    if s.obligation != POLICY_TOKEN_EXACTNESS_OWED:
        raise Error("F16 summary lost its obligation")
    if s.gate_summary.exact_count != 3:
        raise Error("summary lost the gate witness counts")


def test_policy_near_tie_band_edges() raises:
    var ranks = List[Int]()
    ranks.append(0)
    ranks.append(2)
    var gaps = List[Int]()
    gaps.append(0)
    gaps.append(500)
    if _gate("Q4_K_M", ranks, gaps, True, False, False) != POL_FAITHFUL_NEAR_TIE:
        raise Error("rank 2 / gap 500 row is not FAITHFUL_NEAR_TIE")
    var edge_ranks = List[Int]()
    edge_ranks.append(2)
    var edge_gaps = List[Int]()
    edge_gaps.append(1000)
    var s = policy_gate("Q4_K_M", edge_ranks, edge_gaps, True, False, False)
    if s.verdict != POL_DIVERGENT:
        raise Error("gap 1000 (a full logit) escaped the band as a pass")
    if policy_passes(s):
        raise Error("band-edge divergent row passes the policy gate")


def test_policy_divergent_fails_exactness() raises:
    var ranks = List[Int]()
    ranks.append(0)
    ranks.append(3)
    var gaps = List[Int]()
    gaps.append(0)
    gaps.append(10)
    var s = policy_gate("Q4_0", ranks, gaps, True, False, False)
    if s.verdict != POL_DIVERGENT:
        raise Error("rank 3 / gap 10 row is not DIVERGENT for Q4_0")
    if policy_passes(s):
        raise Error("divergent exactness-owed row passes")
    if s.gate_summary.divergent_count != 1:
        raise Error("divergent witness count lost")


def test_policy_iq_divergent_never_fails() raises:
    var ranks = List[Int]()
    ranks.append(5)
    ranks.append(3)
    var gaps = List[Int]()
    gaps.append(2000)
    gaps.append(1500)
    var s = policy_gate("IQ2_XS", ranks, gaps, True, True, True)
    if s.verdict != POL_COHERENCE_PASS:
        raise Error("IQ row with passing coherence not COHERENCE_PASS")
    if not policy_passes(s):
        raise Error("coherence-passing IQ row does not pass")
    if s.gate_summary.divergent_count != 2:
        raise Error("IQ witness counts were not kept for the filing")
    var bare = policy_gate("IQ2_XS", ranks, gaps, True, False, False)
    if bare.verdict == POL_DIVERGENT or bare.verdict == POL_COHERENCE_FAIL:
        raise Error("token divergence alone minted an IQ failure")
    if bare.verdict != POL_NOT_GRADED:
        raise Error("IQ row without coherence evidence not NOT_GRADED")


def test_policy_iq_coherence_fail_and_unstated() raises:
    var ranks = List[Int]()
    ranks.append(0)
    var gaps = List[Int]()
    gaps.append(0)
    var fail = policy_gate("IQ4_NL", ranks, gaps, True, True, False)
    if fail.verdict != POL_COHERENCE_FAIL:
        raise Error("stated failing coherence is not COHERENCE_FAIL")
    if policy_passes(fail):
        raise Error("COHERENCE_FAIL row passes")
    var unstated = policy_gate("IQ4_NL", ranks, gaps, True, False, True)
    if unstated.verdict != POL_NOT_GRADED:
        raise Error("unstated coherence (pass flag set) not NOT_GRADED")
    if policy_passes(unstated):
        raise Error("NOT_GRADED IQ row passes on an unstated claim")


def test_policy_comparator_precedence() raises:
    var ranks = List[Int]()
    ranks.append(0)
    ranks.append(0)
    var gaps = List[Int]()
    gaps.append(0)
    gaps.append(0)
    var exact = policy_gate("Q8_0", ranks, gaps, False, False, False)
    if exact.verdict != POL_COMPARATOR_ARTIFACT:
        raise Error("invalid comparator did not precede an exact row")
    if policy_passes(exact):
        raise Error("comparator artifact passes")
    var iq = policy_gate("IQ1_S", ranks, gaps, False, True, True)
    if iq.verdict != POL_COMPARATOR_ARTIFACT:
        raise Error("invalid comparator did not precede an IQ row")
    if iq.verdict == POL_COHERENCE_PASS:
        raise Error("coherence claim overrode a comparator artifact")


def test_policy_coherence_cannot_rescue_exactness() raises:
    var ranks = List[Int]()
    ranks.append(4)
    var gaps = List[Int]()
    gaps.append(1200)
    var s = policy_gate("Q8_0", ranks, gaps, True, True, True)
    if s.verdict != POL_DIVERGENT:
        raise Error("coherence claim rescued a divergent Q8_0 row")
    if policy_passes(s):
        raise Error("rescued divergent row passes")
    var empty_ranks = List[Int]()
    var empty_gaps = List[Int]()
    var none = policy_gate("Q8_0", empty_ranks, empty_gaps, True, True, True)
    if none.verdict != POL_NOT_GRADED:
        raise Error("recordless exactness row not NOT_GRADED")
    if policy_passes(none):
        raise Error("recordless exactness row passes")


def test_policy_invalid_records_refused() raises:
    var bad_ranks = List[Int]()
    bad_ranks.append(0)
    var bad_gaps = List[Int]()
    bad_gaps.append(5)
    if not _raises_gate("F16", bad_ranks, bad_gaps):
        raise Error("rank 0 with nonzero gap graded for F16")
    if not _raises_gate("IQ2_S", bad_ranks, bad_gaps):
        raise Error("rank 0 with nonzero gap graded for IQ2_S")
    var one_rank = List[Int]()
    one_rank.append(0)
    var two_gaps = List[Int]()
    two_gaps.append(0)
    two_gaps.append(0)
    if not _raises_gate("F16", one_rank, two_gaps):
        raise Error("length-mismatched records graded")


def test_policy_render_digest_deterministic() raises:
    var a = policy_render()
    var b = policy_render()
    if a != b:
        raise Error("two renders of the policy table disagree")
    if policy_digest() == UInt64(0):
        raise Error("policy digest is zero")
    if policy_digest() != policy_digest():
        raise Error("policy digest is not deterministic")
    if policy_verdict_name(POL_COHERENCE_PASS) != String("COHERENCE_PASS"):
        raise Error("verdict name drifted: COHERENCE_PASS")
    if policy_verdict_name(POL_DIVERGENT) != String("DIVERGENT"):
        raise Error("verdict name drifted: DIVERGENT")
    if obligation_name(POLICY_COHERENCE_ONLY) != String("COHERENCE_ONLY"):
        raise Error("obligation name drifted: COHERENCE_ONLY")
    if obligation_name(POLICY_TOKEN_EXACTNESS_OWED) != String(
        "TOKEN_EXACTNESS_OWED"
    ):
        raise Error("obligation name drifted: TOKEN_EXACTNESS_OWED")
    var row = policy_for_quant("IQ4_XS")
    var line = policy_row_line(row)
    if line.byte_length() == 0:
        raise Error("policy row line renders empty")
    if policy_line().byte_length() == 0:
        raise Error("policy line renders empty")
