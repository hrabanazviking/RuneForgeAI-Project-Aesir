# tests/test_divergence_localiser_a116.mojo
# A-116: First-divergence localisation -- the roadmap
# acceptance is a demonstration on a seeded divergence,
# and these cases cover: the seeded trace localising
# exactly at its seed (layer 7, mlp.down_proj, probe
# index 31) with the near-tie probes before it respected,
# identical and near-tie-only traces filing no location,
# a layer-0 separation, a mid-stack first divergence
# reported at its origin and not downstream, the band's
# two conjuncts each binding at a probe, A-112's
# checklist refusing localisation for the template,
# backend-mismatch, and step-0 classes (no location
# filed), a divergent row whose probes never separate
# filing NO_DIVERGENCE honestly, a deterministic digest,
# and broken traces refused, not localised.

from core.comparator_checklist import (
    ARTIFACT_BACKEND_MISMATCH,
    ARTIFACT_NONE,
    ARTIFACT_STEP0_BOUNDARY,
    ARTIFACT_TEMPLATE,
)
from core.divergence_localiser import (
    DEMO_LAYERS,
    LOC_COMPARATOR_ARTIFACT,
    LOC_LOCALISED,
    LOC_NO_DIVERGENCE,
    LOC_NOT_GRADED,
    SEEDED_GAP_MILLI,
    SEEDED_INDEX,
    SEEDED_LAYER,
    SEEDED_OP,
    Localisation,
    Probe,
    first_divergent_probe,
    localise_divergence,
    localise_seeded,
    localisation_line,
    localisation_render,
    localisation_verdict_name,
    localiser_ops,
    loc_fnv1a64,
    seeded_probes,
)


def _row_ranks() -> List[Int]:
    return List[Int]([0, 0, 3, 4])


def _row_gaps() -> List[Int]:
    return List[Int]([0, 0, 1450, 1700])


def _clean(
    probes: List[Probe],
) raises -> Localisation:
    """Localise under the clean row account (RAW
    prompt, BOS both sides, CPU vs CPU, divergent
    past step 0)."""
    return localise_divergence(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        _row_ranks(),
        _row_gaps(),
        probes,
    )


def _raises_localise(probes: List[Probe]) -> Bool:
    try:
        _ = _clean(probes)
    except:
        return True
    return False


def test_localise_constants_and_names() raises:
    if DEMO_LAYERS != 12:
        raise Error("demo trace must carry 12 layers")
    if SEEDED_LAYER != 7 or SEEDED_OP != String("mlp.down_proj"):
        raise Error("seed coordinates drifted")
    if SEEDED_INDEX != 31:
        raise Error("seed probe index drifted: 7 * 4 + 3 = 31")
    var ops = localiser_ops()
    if len(ops) != 4 or ops[3] != String("mlp.down_proj"):
        raise Error("per-layer op order drifted")
    if localisation_verdict_name(LOC_LOCALISED) != String("LOCALISED"):
        raise Error("verdict name drifted: LOCALISED")
    if localisation_verdict_name(LOC_NO_DIVERGENCE) != String(
        "NO_DIVERGENCE"
    ):
        raise Error("verdict name drifted: NO_DIVERGENCE")
    if localisation_verdict_name(LOC_COMPARATOR_ARTIFACT) != String(
        "COMPARATOR_ARTIFACT"
    ):
        raise Error("verdict name drifted: COMPARATOR_ARTIFACT")
    if localisation_verdict_name(LOC_NOT_GRADED) != String("NOT_GRADED"):
        raise Error("verdict name drifted: NOT_GRADED")
    if String("A-116") not in localisation_line():
        raise Error("localiser line must name its slice")


def test_localise_identical_no_divergence() raises:
    var probes = List[Probe]()
    probes.append(Probe(0, String("attn.q_proj"), 0, 0))
    probes.append(Probe(0, String("mlp.down_proj"), 0, 0))
    probes.append(Probe(1, String("attn.q_proj"), 0, 0))
    var loc = _clean(probes)
    if loc.verdict != LOC_NO_DIVERGENCE:
        raise Error("identical probes must file NO_DIVERGENCE")
    if loc.first_index != -1 or loc.first_layer != -1:
        raise Error("no location may be filed for identical probes")
    if loc.exact_count != 3 or loc.divergent_count != 0:
        raise Error("identical probes must count 3 exact, 0 divergent")
    # A faithful row (no divergent record) also files
    # NO_DIVERGENCE even under divergent probes (L4):
    # there is no failing row to localise against.
    var faithful = localise_divergence(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 1]),
        List[Int]([0, 240]),
        seeded_probes(),
    )
    if faithful.verdict != LOC_NO_DIVERGENCE:
        raise Error("a faithful row must file NO_DIVERGENCE")
    if faithful.row_divergent != 0:
        raise Error("faithful row witness must show 0 divergent records")


def test_localise_near_tie_probes_faithful() raises:
    # Every probe inside the band on both conjuncts:
    # the row diverges, the checkpoints never separate,
    # so the honest filing is NO_DIVERGENCE (L6).
    var probes = List[Probe]()
    probes.append(Probe(0, String("attn.q_proj"), 1, 240))
    probes.append(Probe(0, String("mlp.down_proj"), 2, 999))
    probes.append(Probe(1, String("attn.q_proj"), 2, 10))
    var loc = _clean(probes)
    if loc.verdict != LOC_NO_DIVERGENCE:
        raise Error("near-tie probes must never localise")
    if loc.near_tie_count != 3 or loc.divergent_count != 0:
        raise Error("near-tie probes must count 3 near-tie, 0 divergent")
    if first_divergent_probe(probes) != -1:
        raise Error("the pure scan must find no divergent probe")


def test_localise_first_at_layer0() raises:
    var probes = List[Probe]()
    probes.append(Probe(0, String("attn.q_proj"), 3, 1200))
    probes.append(Probe(0, String("mlp.down_proj"), 4, 1700))
    probes.append(Probe(1, String("attn.q_proj"), 4, 1700))
    var loc = _clean(probes)
    if loc.verdict != LOC_LOCALISED:
        raise Error("a layer-0 separation must localise")
    if loc.first_index != 0 or loc.first_layer != 0:
        raise Error("the location must be probe 0, layer 0")
    if loc.first_op != String("attn.q_proj"):
        raise Error("the location must name the first op")
    if loc.first_rank != 3 or loc.first_gap_milli != 1200:
        raise Error("the location must carry its rank/gap witness")


def test_localise_mid_stack_first_exact() raises:
    # Separation seeds at layer 2 mlp.up_proj and
    # propagates: the filing names layer 2, not the
    # louder downstream probes.
    var probes = List[Probe]()
    probes.append(Probe(0, String("attn.q_proj"), 0, 0))
    probes.append(Probe(1, String("attn.q_proj"), 1, 240))
    probes.append(Probe(2, String("attn.q_proj"), 0, 0))
    probes.append(Probe(2, String("mlp.up_proj"), 3, 1300))
    probes.append(Probe(2, String("mlp.down_proj"), 6, 2600))
    probes.append(Probe(3, String("attn.q_proj"), 6, 2600))
    var loc = _clean(probes)
    if loc.verdict != LOC_LOCALISED:
        raise Error("a mid-stack separation must localise")
    if loc.first_layer != 2 or loc.first_op != String("mlp.up_proj"):
        raise Error("the first divergence is layer 2 mlp.up_proj")
    if loc.first_index != 3:
        raise Error("the first divergent probe is index 3")
    if loc.divergent_count != 3:
        raise Error("downstream propagation counts, never re-locates")


def test_localise_seeded_exact() raises:
    var probes = seeded_probes()
    if len(probes) != 49:
        raise Error("seeded trace must carry 49 probes")
    var loc = localise_seeded()
    if loc.verdict != LOC_LOCALISED:
        raise Error("the seeded divergence must localise")
    if loc.first_layer != SEEDED_LAYER:
        raise Error("seeded location must be layer 7")
    if loc.first_op != SEEDED_OP:
        raise Error("seeded location must be mlp.down_proj")
    if loc.first_index != SEEDED_INDEX:
        raise Error("seeded location must be probe index 31")
    if loc.first_rank != 3 or loc.first_gap_milli != SEEDED_GAP_MILLI:
        raise Error("seeded witness must be rank 3, gap 1450")
    if loc.exact_count != 25 or loc.near_tie_count != 6:
        raise Error("pre-seed probes: 25 exact, 6 near-tie")
    if loc.divergent_count != 18:
        raise Error("seed + propagation: 18 divergent probes")
    if loc.kind != ARTIFACT_NONE or loc.row_divergent != 2:
        raise Error("the seeded account is clean, its row divergent twice")


def test_localise_band_edges() raises:
    # Rank 2 with a full-logit gap is OUT (gap conjunct
    # binds); rank 3 with a sub-logit gap is OUT (rank
    # conjunct binds) -- A-111's filed witnesses, at
    # probe level.
    var by_gap = List[Probe]()
    by_gap.append(Probe(0, String("attn.q_proj"), 0, 0))
    by_gap.append(Probe(1, String("attn.q_proj"), 2, 1000))
    var loc_gap = _clean(by_gap)
    if loc_gap.verdict != LOC_LOCALISED or loc_gap.first_index != 1:
        raise Error("rank 2 / gap 1000 must localise (full logit is out)")
    var by_rank = List[Probe]()
    by_rank.append(Probe(0, String("attn.q_proj"), 0, 0))
    by_rank.append(Probe(1, String("attn.q_proj"), 3, 10))
    var loc_rank = _clean(by_rank)
    if loc_rank.verdict != LOC_LOCALISED or loc_rank.first_index != 1:
        raise Error("rank 3 / gap 10 must localise (rank 3 is out)")


def test_localise_artifact_template_blocks() raises:
    var loc = localise_divergence(
        String("[INST] The sea is wide. [/INST]"),
        True,
        True,
        String("cpu"),
        String("cpu"),
        _row_ranks(),
        _row_gaps(),
        seeded_probes(),
    )
    if loc.verdict != LOC_COMPARATOR_ARTIFACT:
        raise Error("a template-rendered row must file no localisation")
    if loc.kind != ARTIFACT_TEMPLATE:
        raise Error("the blocking kind must be TEMPLATE")
    if loc.first_index != -1 or loc.first_layer != -1:
        raise Error("an artifact files no location, ever")
    if loc.divergent_count != 18:
        raise Error("probe counts are still filed under an artifact")


def test_localise_artifact_backend_blocks() raises:
    var loc = localise_divergence(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("vulkan"),
        _row_ranks(),
        _row_gaps(),
        seeded_probes(),
    )
    if loc.verdict != LOC_COMPARATOR_ARTIFACT:
        raise Error("a cross-backend row must file no localisation")
    if loc.kind != ARTIFACT_BACKEND_MISMATCH:
        raise Error("the blocking kind must be BACKEND_MISMATCH")
    if loc.first_index != -1:
        raise Error("an artifact files no location, ever")


def test_localise_artifact_step0_blocks() raises:
    # The row diverges only at step 0: A-112's K4
    # classes it a prompt-boundary artifact, and a
    # step-0-only row has no layer separation to find
    # -- localisation is refused even though the
    # probes separate downstream.
    var loc = localise_divergence(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([3, 0, 0]),
        List[Int]([1200, 0, 0]),
        seeded_probes(),
    )
    if loc.verdict != LOC_COMPARATOR_ARTIFACT:
        raise Error("a step-0-only row must file no localisation")
    if loc.kind != ARTIFACT_STEP0_BOUNDARY:
        raise Error("the blocking kind must be STEP0_BOUNDARY")
    if loc.first_index != -1:
        raise Error("an artifact files no location, ever")


def test_localise_digest_deterministic() raises:
    var probes = seeded_probes()
    var loc = localise_seeded()
    var render1 = localisation_render(loc, probes)
    var render2 = localisation_render(loc, probes)
    if render1 != render2:
        raise Error("the localisation rendering must be deterministic")
    if loc_fnv1a64(render1) != loc_fnv1a64(render2):
        raise Error("the localisation digest must reproduce")
    if String("first_layer=7") not in render1:
        raise Error("the rendering must file the seeded layer")
    if String("first_op=mlp.down_proj") not in render1:
        raise Error("the rendering must file the seeded op")
    if String("LOCALISED") not in render1:
        raise Error("the rendering must file the verdict")


def test_localise_invalid_refused() raises:
    if not _raises_localise(List[Probe]()):
        raise Error("an empty probe list must be refused")
    var inconsistent = List[Probe]()
    inconsistent.append(Probe(0, String("attn.q_proj"), 0, 5))
    if not _raises_localise(inconsistent):
        raise Error("rank 0 with a nonzero gap must be refused")
    var duplicate = List[Probe]()
    duplicate.append(Probe(1, String("attn.q_proj"), 0, 0))
    duplicate.append(Probe(1, String("attn.q_proj"), 3, 1200))
    if not _raises_localise(duplicate):
        raise Error("a duplicate (layer, op) probe must be refused")
    var decreasing = List[Probe]()
    decreasing.append(Probe(2, String("attn.q_proj"), 0, 0))
    decreasing.append(Probe(1, String("attn.q_proj"), 3, 1200))
    if not _raises_localise(decreasing):
        raise Error("decreasing probe layers must be refused")
    var negative = List[Probe]()
    negative.append(Probe(-1, String("attn.q_proj"), 0, 0))
    if not _raises_localise(negative):
        raise Error("a negative probe layer must be refused")
    # A row account whose record lengths differ is
    # refused by the checklist, not localised.
    var refused = False
    try:
        _ = localise_divergence(
            String("The sea is wide."),
            True,
            True,
            String("cpu"),
            String("cpu"),
            List[Int]([0, 3]),
            List[Int]([0]),
            seeded_probes(),
        )
    except:
        refused = True
    if not refused:
        raise Error("mismatched row records must be refused")
    # An empty row account files NOT_GRADED (L3).
    var ungraded = localise_divergence(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int](),
        List[Int](),
        seeded_probes(),
    )
    if ungraded.verdict != LOC_NOT_GRADED:
        raise Error("an empty row account must file NOT_GRADED")
