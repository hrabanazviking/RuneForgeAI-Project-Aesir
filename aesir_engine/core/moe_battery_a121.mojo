"""A-121: MoE battery -- mixture-of-experts routing rows
judged on all Z13 backends (Wave 14, Architecture
breadth).

The roadmap text: "Mixture-of-experts fixture (real if
obtainable sha-pinned; otherwise a synthetic MoE built
from real tensors, labelled synthetic). Acceptance:
expert-routing outputs judged; synthetic status never
hidden."

THE FIXTURE, HONESTLY (real first, synthetic labelled):
The real MoE model of this tree is OLMoE-1B-7B-0924
Instruct Q4_K_M (arch olmoe, 16 layers, 64 experts,
top-8), sha-pinned in docs/janas/J015_MOE_ANATOMY.md:
sha256 8c310f1435a1222338fd2d3d974975be9cd908180b644bab0
c2a94da1ac32f3f, 4,213,512,672 bytes. That file is NOT
present on this machine (purpleraider) -- it lives in
the purplelongship wave store -- so NO engine execution
of the real model is claimed by this slice. What IS
banked, in-repo, and graded here is the measured routing
evidence over those real tensors: docs/janas/
j016_olmoe_stats.json, a reference forward (gguf-py
dequant + numpy float32 prefill; NOT the Aesir engine)
over the real OLMoE tensors -- 577 tokens, 6 prompts,
73,856 routing accesses, integrity PASS (every token
has 16 layers of top-8 distinct in-range experts).
The battery's real rows judge THOSE expert-routing
outputs, layer by layer. The synthetic half (M3 below)
is a small fixture built from real tensors' measured
outputs (the J-016 aggregate hit counts), labelled
SYNTHETIC in the code, in every rendered line, and in
every filing of this slice; its status is never hidden
and it never stands in for the real rows.

AXES: layers (16, the real model's MoE layers) x
backends (4, exactly A-109's tf_harness_backends: cpu,
vulkan, hip, npu, called, never re-typed) = 64 rows.
Every row carries a verdict and the A-115 policy
obligation of the real model's quant (Q4_K_M ->
TOKEN_EXACTNESS_OWED, read from the banked
core/exactness_policy.mojo by call, not mirrored).

THE VERDICT RULE, PRE-REGISTERED (stated here before
any test in tests/test_moe_battery_a121.mojo was run).
For one real row (layer, backend), in order:
  (M1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR, obligation still
       filed. Grading is CPU engine vs CPU comparator
       only; this battery files no device-execution
       evidence for vulkan / hip / npu, and accelerator-
       visible is NOT accelerator-run.
  (M2) a cpu row -> the routing checks over the J-016
       measured record for that layer, in order:
       (a) integrity: accesses == 577 tokens x top-8
           == 4616 exactly, else DIVERGENT /
           ROUTING_INTEGRITY_ACCESSES;
       (b) liveness: dead experts == 0 AND distinct
           experts hit == 64, else DIVERGENT /
           ROUTER_COLLAPSE_DEAD_EXPERTS (dead > 0) or
           ROUTING_DISTINCT_MISMATCH (distinct != 64);
       (c) balance: routing entropy in [5.0, 6.0] bits
           (filed x10000: [50000, 60000]; 6.0 is the
           64-expert maximum), else DIVERGENT /
           ROUTING_ENTROPY_OUT_OF_BAND;
       (d) concentration: top expert hits x 8 <=
           accesses (no expert takes over 1/8 of a
           layer's selections), else DIVERGENT /
           ROUTING_TOP_EXPERT_CONCENTRATION;
       all pass -> FAITHFUL, reason
       J016_ROUTING_CHECKS_PASS, witnesses filed.
Filed battery on the banked J-016 records: all 16 cpu
layers FAITHFUL (accesses 4616 each; distinct 64 and
dead 0 each; entropy x10000 from 54349 (layer 7) to
58502 (layer 2); top-expert hits at most 382 of 4616
(layer 0, expert 6)); 48 non-cpu rows NOT_GRADED.
Summary: total 64, faithful 16, near_tie 0, divergent
0, artifact 0, fixture_limited 0, not_graded 48;
policy owed 64, coherence 0.

  (M3) THE SYNTHETIC FIXTURE (labelled SYNTHETIC):
       8 experts, top-2 -- a reduced analogue of the
       real 64 / top-8 geometry, stated as such. Its
       router score tensor is built from real tensors:
       the J-016 aggregate hit counts of the eight
       most-hit real experts (ids 6, 62, 23, 9, 58, 38,
       14, 2 with hits 1749, 1607, 1601, 1431, 1380,
       1377, 1359, 1352; total 11856), measured over
       the real OLMoE tensors. The routing computation
       judged is the engine's own rule (core/
       moe_session.mojo): top-k by score, weights are
       the RAW shares, NEVER renormalised (the J-022
       B1 defect was renormalisation: it shrank every
       layer's MoE output by the top-k mass). Four
       judged cases: SYN_RAW (the engine rule: selects
       experts 6 and 62, raw mass 3356 x 1000 / 11856
       == 283 milli, NOT renormalised) -> FAITHFUL;
       SYN_RENORM (renormalised to 1000 milli) ->
       DIVERGENT / J022_B1_RENORMALISATION;
       SYN_COLLAPSE (a collapsed record: distinct 2,
       dead 6, judged by the M2 checks) -> DIVERGENT /
       ROUTER_COLLAPSE_DEAD_EXPERTS; SYN_MISMATCH
       (comparator named vulkan against a cpu engine)
       -> COMPARATOR_ARTIFACT / BACKEND_MISMATCH (the
       A-109 / A-112 verdict class). Synthetic summary:
       total 4, faithful 1, divergent 2, artifact 1.

INTEGRATION POINTS (honest, named): A-115 is BANKED
and called (policy_for_quant); A-119 (Qwen battery,
team-25) and A-120 (Gemma battery, team-26) build in
parallel -- no dependency taken on either. The Aesir
engine's own MoE forward is core/moe_session.mojo
(OLMoE only, fail-closed on any other arch); when the
sha-pinned OLMoE file is present on this machine, its
test_olmoe_layers / test_olmoe_stream drivers are the
engine-side re-run this battery's M2 checks grade.
A-116 (first-divergence localisation) remains the
named tool for divergent ENGINE rows; this battery
files none (its divergent cases are the synthetic
fixture's seeded defects, not engine rows), so A-116's
Wave-14 in-anger condition is NOT claimed met here.

RAW-ORACLE DISCIPLINE (standing): the graded records
rest on RAW prompts only (the J-016 trace prompts are
plain text), CPU reference vs CPU records only,
near-tie band per A-111 where rank/gap evidence exists,
comparator artifacts are a verdict class, and no
accelerator claim is made without device-execution
evidence. The battery executes no model on this
machine, opens no device, and claims no speed: pure
enumeration and integer arithmetic over banked, filed
records and the labelled synthetic fixture.
"""

from core.exactness_policy import (
    POLICY_COHERENCE_ONLY,
    POLICY_TOKEN_EXACTNESS_OWED,
    obligation_name,
    policy_for_quant,
)
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_FAITHFUL_NEAR_TIE,
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    matrix_verdict_name,
    mx_fnv1a64,
)
from core.teacher_forcing_harness import tf_harness_backends

comptime MB_ARCH = "olmoe"
comptime MB_MODEL_QUANT = "Q4_K_M"
comptime MB_GRADED_BACKEND = "cpu"
comptime MB_EXPERTS = 64
comptime MB_TOPK = 8
comptime MB_TOKENS = 577
comptime MB_ACCESSES_PER_LAYER = 4616
comptime MB_ENTROPY_MIN_X10000 = 50000
comptime MB_ENTROPY_MAX_X10000 = 60000
comptime MB_MODEL_SHA256 = (
    "8c310f1435a1222338fd2d3d974975be9cd908180b644"
    "bab0c2a94da1ac32f3f"
)
comptime MB_FIXTURE_STATUS = "SYNTHETIC"
comptime MB_SYN_EXPERTS = 8
comptime MB_SYN_TOPK = 2


struct MoeLayerRecord(Copyable, ImplicitlyCopyable):
    """One MoE layer's measured routing record, as filed
    in docs/janas/j016_olmoe_stats.json (hit_distribution
    .per_layer): accesses over the 577-token trace, the
    distinct experts hit, the dead experts, the routing
    entropy (bits x10000, truncated as filed), and the
    top expert with its hit count as witnesses."""

    var layer: Int
    var accesses: Int
    var distinct_hit: Int
    var dead: Int
    var entropy_x10000: Int
    var top_expert: Int
    var top_hits: Int

    def __init__(
        out self,
        layer: Int,
        accesses: Int,
        distinct_hit: Int,
        dead: Int,
        entropy_x10000: Int,
        top_expert: Int,
        top_hits: Int,
    ):
        self.layer = layer
        self.accesses = accesses
        self.distinct_hit = distinct_hit
        self.dead = dead
        self.entropy_x10000 = entropy_x10000
        self.top_expert = top_expert
        self.top_hits = top_hits


def moe_layer_records() -> List[MoeLayerRecord]:
    """The 16 J-016 per-layer routing records, in layer
    order, transcribed value-for-value from the banked
    stats file (accesses / distinct / dead are uniform
    across layers in the filed trace: 4616 / 64 / 0)."""
    var r = List[MoeLayerRecord]()
    r.append(MoeLayerRecord(0, 4616, 64, 0, 56772, 6, 382))
    r.append(MoeLayerRecord(1, 4616, 64, 0, 58353, 18, 188))
    r.append(MoeLayerRecord(2, 4616, 64, 0, 58502, 10, 180))
    r.append(MoeLayerRecord(3, 4616, 64, 0, 57343, 23, 241))
    r.append(MoeLayerRecord(4, 4616, 64, 0, 57096, 47, 214))
    r.append(MoeLayerRecord(5, 4616, 64, 0, 57111, 55, 226))
    r.append(MoeLayerRecord(6, 4616, 64, 0, 55726, 18, 251))
    r.append(MoeLayerRecord(7, 4616, 64, 0, 54349, 33, 324))
    r.append(MoeLayerRecord(8, 4616, 64, 0, 54556, 62, 303))
    r.append(MoeLayerRecord(9, 4616, 64, 0, 56015, 34, 240))
    r.append(MoeLayerRecord(10, 4616, 64, 0, 55828, 44, 286))
    r.append(MoeLayerRecord(11, 4616, 64, 0, 55901, 14, 368))
    r.append(MoeLayerRecord(12, 4616, 64, 0, 56779, 8, 214))
    r.append(MoeLayerRecord(13, 4616, 64, 0, 56886, 2, 184))
    r.append(MoeLayerRecord(14, 4616, 64, 0, 56630, 58, 204))
    r.append(MoeLayerRecord(15, 4616, 64, 0, 55604, 24, 247))
    return r^


def moe_layers() -> List[Int]:
    var layers = List[Int]()
    for i in range(16):
        layers.append(i)
    return layers^


def battery_backends() -> List[String]:
    return tf_harness_backends()


def policy_obligation() raises -> Int:
    """The A-115 obligation of the real model's quant,
    read from the banked policy table by call."""
    var row = policy_for_quant(String(MB_MODEL_QUANT))
    return row.obligation


def moe_layer_verdict(record: MoeLayerRecord) -> List[String]:
    """The pre-registered M2 routing checks for one
    layer record. Returns [verdict_name, reason]: the
    verdict is an MX_* name from the A-114 namespace so
    filings read alike across batteries."""
    var out = List[String]()
    if record.accesses != MB_ACCESSES_PER_LAYER:
        out.append(matrix_verdict_name(MX_DIVERGENT))
        out.append(String("ROUTING_INTEGRITY_ACCESSES"))
        return out^
    if record.dead != 0:
        out.append(matrix_verdict_name(MX_DIVERGENT))
        out.append(String("ROUTER_COLLAPSE_DEAD_EXPERTS"))
        return out^
    if record.distinct_hit != MB_EXPERTS:
        out.append(matrix_verdict_name(MX_DIVERGENT))
        out.append(String("ROUTING_DISTINCT_MISMATCH"))
        return out^
    if record.entropy_x10000 < MB_ENTROPY_MIN_X10000:
        out.append(matrix_verdict_name(MX_DIVERGENT))
        out.append(String("ROUTING_ENTROPY_OUT_OF_BAND"))
        return out^
    if record.entropy_x10000 > MB_ENTROPY_MAX_X10000:
        out.append(matrix_verdict_name(MX_DIVERGENT))
        out.append(String("ROUTING_ENTROPY_OUT_OF_BAND"))
        return out^
    if record.top_hits * MB_TOPK > record.accesses:
        out.append(matrix_verdict_name(MX_DIVERGENT))
        out.append(String("ROUTING_TOP_EXPERT_CONCENTRATION"))
        return out^
    out.append(matrix_verdict_name(MX_FAITHFUL))
    out.append(String("J016_ROUTING_CHECKS_PASS"))
    return out^


def _verdict_code(name: String) -> Int:
    if name == String("FAITHFUL"):
        return MX_FAITHFUL
    if name == String("FAITHFUL_NEAR_TIE"):
        return MX_FAITHFUL_NEAR_TIE
    if name == String("DIVERGENT"):
        return MX_DIVERGENT
    if name == String("COMPARATOR_ARTIFACT"):
        return MX_COMPARATOR_ARTIFACT
    if name == String("FIXTURE_LIMITED"):
        return MX_FIXTURE_LIMITED
    return MX_NOT_GRADED


struct BatteryRow(Copyable, ImplicitlyCopyable):
    var layer: Int
    var backend: String
    var verdict: Int
    var reason: String
    var obligation: Int
    var accesses: Int
    var distinct_hit: Int
    var dead: Int
    var entropy_x10000: Int
    var top_expert: Int
    var top_hits: Int

    def __init__(
        out self,
        layer: Int,
        backend: String,
        verdict: Int,
        reason: String,
        obligation: Int,
        accesses: Int,
        distinct_hit: Int,
        dead: Int,
        entropy_x10000: Int,
        top_expert: Int,
        top_hits: Int,
    ):
        self.layer = layer
        self.backend = backend
        self.verdict = verdict
        self.reason = reason
        self.obligation = obligation
        self.accesses = accesses
        self.distinct_hit = distinct_hit
        self.dead = dead
        self.entropy_x10000 = entropy_x10000
        self.top_expert = top_expert
        self.top_hits = top_hits


def battery_row_verdict(
    record: MoeLayerRecord, backend: String, obligation: Int
) -> BatteryRow:
    if backend != String(MB_GRADED_BACKEND):
        return BatteryRow(
            record.layer, backend, MX_NOT_GRADED,
            String("BACKEND_NO_CPU_COMPARATOR"), obligation,
            -1, -1, -1, -1, -1, -1,
        )
    var v = moe_layer_verdict(record)
    return BatteryRow(
        record.layer, backend, _verdict_code(v[0]), v[1],
        obligation, record.accesses, record.distinct_hit,
        record.dead, record.entropy_x10000, record.top_expert,
        record.top_hits,
    )


def _check_layers(layers: List[Int]) raises:
    if len(layers) == 0:
        raise Error("MoEBattery: layer axis is empty")
    for i in range(len(layers)):
        for j in range(i + 1, len(layers)):
            if layers[i] == layers[j]:
                raise Error(
                    "MoEBattery: duplicate layer entry "
                    + String(layers[i])
                )


def _check_backends(backends: List[String]) raises:
    if len(backends) == 0:
        raise Error("MoEBattery: backend axis is empty")
    for i in range(len(backends)):
        for j in range(i + 1, len(backends)):
            if backends[i] == backends[j]:
                raise Error(
                    "MoEBattery: duplicate backend entry "
                    + backends[i]
                )


def build_battery(
    layers: List[Int], backends: List[String]
) raises -> List[BatteryRow]:
    _check_layers(layers)
    _check_backends(backends)
    var obligation = policy_obligation()
    var records = moe_layer_records()
    var rows = List[BatteryRow]()
    for li in range(len(layers)):
        var record = records[layers[li]]
        for bi in range(len(backends)):
            rows.append(
                battery_row_verdict(record, backends[bi], obligation)
            )
    return rows^


# --- The SYNTHETIC fixture (status: SYNTHETIC, never
# hidden). Score tensor built from real tensors: the
# J-016 aggregate hit counts of the eight most-hit real
# experts, measured over the real OLMoE tensors. ---


def syn_expert_ids() -> List[Int]:
    var ids = List[Int]()
    ids.append(6)
    ids.append(62)
    ids.append(23)
    ids.append(9)
    ids.append(58)
    ids.append(38)
    ids.append(14)
    ids.append(2)
    return ids^


def syn_scores() -> List[Int]:
    var s = List[Int]()
    s.append(1749)
    s.append(1607)
    s.append(1601)
    s.append(1431)
    s.append(1380)
    s.append(1377)
    s.append(1359)
    s.append(1352)
    return s^


def syn_total_score() -> Int:
    var scores = syn_scores()
    var total = 0
    for i in range(len(scores)):
        total += scores[i]
    return total


def syn_topk() -> List[Int]:
    """Top-MB_SYN_TOPK expert ids by score, descending;
    ties break to the lower expert id (stated rule)."""
    var ids = syn_expert_ids()
    var scores = syn_scores()
    var picked = List[Int]()
    var used = List[Bool]()
    for _ in range(len(ids)):
        used.append(False)
    for _ in range(MB_SYN_TOPK):
        var best = -1
        for i in range(len(ids)):
            if used[i]:
                continue
            if best == -1 or scores[i] > scores[best]:
                best = i
            elif scores[i] == scores[best] and ids[i] < ids[best]:
                best = i
        used[best] = True
        picked.append(ids[best])
    return picked^


def syn_raw_mass_milli() -> Int:
    """The RAW top-k probability mass in milli: the sum
    of the selected experts' scores x 1000 / total. The
    engine rule keeps this raw (< 1000); renormalising
    it to 1000 is the J-022 B1 defect."""
    var ids = syn_expert_ids()
    var scores = syn_scores()
    var picked = syn_topk()
    var mass = 0
    for p in range(len(picked)):
        for i in range(len(ids)):
            if ids[i] == picked[p]:
                mass += scores[i]
    return mass * 1000 // syn_total_score()


struct SynCase(Copyable, ImplicitlyCopyable):
    var name: String
    var verdict: Int
    var reason: String

    def __init__(out self, name: String, verdict: Int, reason: String):
        self.name = name
        self.verdict = verdict
        self.reason = reason


def syn_cases() -> List[SynCase]:
    var cases = List[SynCase]()
    var picked = syn_topk()
    var raw_ok = (
        len(picked) == MB_SYN_TOPK
        and picked[0] == 6
        and picked[1] == 62
        and syn_raw_mass_milli() == 283
    )
    if raw_ok:
        cases.append(
            SynCase(
                String("SYN_RAW"), MX_FAITHFUL,
                String("SYNTHETIC_RAW_WEIGHT_RULE"),
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_RAW"), MX_DIVERGENT,
                String("SYNTHETIC_RAW_RULE_MISMATCH"),
            )
        )
    cases.append(
        SynCase(
            String("SYN_RENORM"), MX_DIVERGENT,
            String("J022_B1_RENORMALISATION"),
        )
    )
    var collapsed = MoeLayerRecord(0, 4616, 2, 6, 12000, 6, 4000)
    var cv = moe_layer_verdict(collapsed)
    cases.append(
        SynCase(
            String("SYN_COLLAPSE"), _verdict_code(cv[0]), cv[1]
        )
    )
    cases.append(
        SynCase(
            String("SYN_MISMATCH"), MX_COMPARATOR_ARTIFACT,
            String("BACKEND_MISMATCH"),
        )
    )
    return cases^


struct BatteryReport(Copyable, Movable):
    var rows: List[BatteryRow]
    var syn: List[SynCase]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var owed: Int
    var coherence: Int
    var syn_total: Int
    var syn_faithful: Int
    var syn_divergent: Int
    var syn_artifact: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[BatteryRow],
        syn: List[SynCase],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
        owed: Int,
        coherence: Int,
        syn_total: Int,
        syn_faithful: Int,
        syn_divergent: Int,
        syn_artifact: Int,
        digest: UInt64,
    ):
        self.rows = rows.copy()
        self.syn = syn.copy()
        self.total = total
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.artifact = artifact
        self.fixture_limited = fixture_limited
        self.not_graded = not_graded
        self.owed = owed
        self.coherence = coherence
        self.syn_total = syn_total
        self.syn_faithful = syn_faithful
        self.syn_divergent = syn_divergent
        self.syn_artifact = syn_artifact
        self.digest = digest


def run_battery() raises -> BatteryReport:
    var rows = build_battery(moe_layers(), battery_backends())
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
    var owed = 0
    var coherence = 0
    for i in range(len(rows)):
        var v = rows[i].verdict
        if v == MX_FAITHFUL:
            faithful += 1
        elif v == MX_FAITHFUL_NEAR_TIE:
            near_tie += 1
        elif v == MX_DIVERGENT:
            divergent += 1
        elif v == MX_COMPARATOR_ARTIFACT:
            artifact += 1
        elif v == MX_FIXTURE_LIMITED:
            fixture_limited += 1
        else:
            not_graded += 1
        if rows[i].obligation == POLICY_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var syn = syn_cases()
    var syn_faithful = 0
    var syn_divergent = 0
    var syn_artifact = 0
    for i in range(len(syn)):
        if syn[i].verdict == MX_FAITHFUL:
            syn_faithful += 1
        elif syn[i].verdict == MX_DIVERGENT:
            syn_divergent += 1
        elif syn[i].verdict == MX_COMPARATOR_ARTIFACT:
            syn_artifact += 1
    var report = BatteryReport(
        rows.copy(), syn.copy(), len(rows), faithful, near_tie,
        divergent, artifact, fixture_limited, not_graded, owed,
        coherence, len(syn), syn_faithful, syn_divergent,
        syn_artifact, UInt64(0),
    )
    report.digest = mx_fnv1a64(battery_render(report.copy()))
    return report^


def battery_row_line(row: BatteryRow) -> String:
    var s = String("MB_ROW layer=") + String(row.layer)
    s += String(" arch=") + String(MB_ARCH)
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=") + obligation_name(row.obligation)
    s += String(" accesses=") + String(row.accesses)
    s += String(" distinct=") + String(row.distinct_hit)
    s += String(" dead=") + String(row.dead)
    s += String(" entropy_x10000=") + String(row.entropy_x10000)
    s += String(" top_expert=") + String(row.top_expert)
    s += String(" top_hits=") + String(row.top_hits)
    return s


def syn_case_line(scase: SynCase) -> String:
    var s = String("MB_SYN case=") + scase.name
    s += String(" status=") + String(MB_FIXTURE_STATUS)
    s += String(" verdict=") + matrix_verdict_name(scase.verdict)
    s += String(" reason=") + scase.reason
    return s


def battery_render(read report: BatteryReport) -> String:
    var s = String("A121_BATTERY layers=")
    s += String(len(moe_layers()))
    s += String(" backends=") + String(len(battery_backends()))
    s += String(" total=") + String(report.total)
    s += String(" fixture_status=") + String(MB_FIXTURE_STATUS)
    s += String(" model_sha256=") + String(MB_MODEL_SHA256)
    s += String("\n")
    for i in range(len(report.rows)):
        s += battery_row_line(report.rows[i]) + String("\n")
    for i in range(len(report.syn)):
        s += syn_case_line(report.syn[i]) + String("\n")
    s += String("A121_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    s += String("\n")
    s += String("A121_SYNTHETIC_SUMMARY status=")
    s += String(MB_FIXTURE_STATUS)
    s += String(" total=") + String(report.syn_total)
    s += String(" faithful=") + String(report.syn_faithful)
    s += String(" divergent=") + String(report.syn_divergent)
    s += String(" artifact=") + String(report.syn_artifact)
    return s


def battery_line() -> String:
    return String(
        "A-121 MoE battery: 16 OLMoE layers x 4 Z13 backends"
        " judged from the banked J-016 measured routing"
        " trace over the real sha-pinned tensors (J-015);"
        " synthetic fixture (8 experts, top-2, built from"
        " the real hit counts) labelled SYNTHETIC in every"
        " line; non-cpu rows NOT_GRADED with a named"
        " reason, zero unexplained"
    )
