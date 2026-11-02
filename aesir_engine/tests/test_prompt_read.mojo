"""Prompt-read economics accounting (J-094): the
ladder's READ leg priced in work and traffic through
J-091's frame and Part IV's prefill modules -- the
validation gate reproducing J-091 section 5.1's
prefill columns and J-092's KV-read shapes EXACTLY,
the per-surface pass/weight/touch accounts, the
inherited read verdicts and GPU read placement, and
Part IV's priced effects (host chunking, the J-054
block counterfactual cross-checked against its own
planner, J-055's zero-delta whole-layer identity,
J-056's split verdicts through its own rule, the
int8 precision deltas). No wall, no speed claimed
here: every live read is deferred to the J-098 gate
recipe in the J-094 doc (section 7).
"""
from core.attention_share import share_prefill_kv_shape_bytes
from core.gpu_block_prefill import (
    ADMISSION_UNBUILT,
    ADMISSION_WIDTH1_PROVEN,
    plan_gpu_block_prefill,
)
from core.kv_ladder import (
    LADDER_ACCOUNTED,
    LADDER_CAP_REFUSED,
    LADDER_GPU_SPILL,
    LADDER_GPU_WHOLE,
    LADDER_INTEGRATION_BLOCKED,
    LADDER_LINE_CPU,
    LADDER_LINE_GPU,
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    LADDER_WRITE,
    ladder_cell_verdict,
)
from core.prefill_anatomy import (
    SURFACE_CUDA_WIDTH1,
    SURFACE_HOST_BATCHED,
    SURFACE_HOST_PER_TOKEN,
)
from core.prompt_read import (
    READ_HOST_CAP,
    read_attention_share_ppm,
    read_block_cf,
    read_chunk_weight_delta,
    read_gpu_placement,
    read_gpu_required,
    read_head_macs,
    read_kv_read_shape,
    read_kv_written,
    read_pairs,
    read_passes,
    read_precision_kv_shape_delta,
    read_precision_kv_written_delta,
    read_split_plan,
    read_split_verdict,
    read_sync_crossings,
    read_touch_shape,
    read_verdict,
    read_weight_pass_bytes,
    read_work_attention,
    read_work_per_token,
    read_work_projection,
    read_work_total,
)
from core.split_prompt import (
    SPLIT_PARENT_ABSENT,
    SPLIT_REJECTED_DOMINATED,
)

# The ladder witness (J-091): Qwen2.5-Coder-7B.
comptime LAYERS = 28
comptime HIDDEN = 3584
comptime Q_WIDTH = 3584
comptime KV_WIDTH = 512
comptime FFN = 18944
comptime KV_HEADS = 4
comptime HEAD_DIM = 128
comptime VOCAB = 152064
comptime PROFILE_CAP = 32768
comptime WEIGHTS = 4683074688
comptime ACT_FIXED = 208896
comptime ACT_PER_CONTEXT = 28
comptime SAMPLING = 905728
comptime USABLE = 5368709120
comptime KV_F16 = 57344
comptime KV_I8 = 29568


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PromptRead " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def _rungs() -> List[Int]:
    var r = List[Int]()
    r.append(1024)
    r.append(4096)
    r.append(8192)
    r.append(16384)
    r.append(32768)
    return r^


def _work(rung: Int) raises -> Int:
    return read_work_total(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rung)


def test_endpoints() raises:
    expect_eq(
        read_work_projection(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, 1),
        6525288448,
        "projection/token (J-053)",
    )
    expect_eq(read_head_macs(HIDDEN, VOCAB), 544997376, "head pass (J-053)")
    expect_eq(READ_HOST_CAP, 256, "host chunk cap (J-053)")
    expect_eq(
        read_kv_written(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 1),
        KV_F16,
        "kv/token f16 (J-087)",
    )
    expect_eq(
        read_kv_written(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, 1),
        KV_I8,
        "kv/token int8 (J-088)",
    )
    print(
        "PASS: endpoints -- projection/token 6,525,288,448 and head"
        " 544,997,376 (J-053); KV 57,344 f16 / 29,568 int8 per token"
        " (J-087/J-088); host cap 256"
    )


def test_validation_gate_work() raises:
    # THE GATE: the read's work columns reproduce
    # J-091 section 5.1's prefill attention and
    # projection columns EXACTLY at every rung.
    var attn = List[Int]()
    attn.append(105329459200)
    attn.append(1684038221824)
    attn.append(6735330803712)
    attn.append(26939679047680)
    attn.append(107755427856384)
    var proj = List[Int]()
    proj.append(6681895370752)
    proj.append(26727581483008)
    proj.append(53455162966016)
    proj.append(106910325932032)
    proj.append(213820651864064)
    var total = List[Int]()
    total.append(6787224829952)
    total.append(28411619704832)
    total.append(60190493769728)
    total.append(133850004979712)
    total.append(321576079720448)
    var avg = List[Int]()
    avg.append(6628149248)
    avg.append(6936430592)
    avg.append(7347472384)
    avg.append(8169555968)
    avg.append(9813723136)
    var rungs = _rungs()
    for i in range(5):
        expect_eq(
            read_work_attention(LAYERS, Q_WIDTH, rungs[i]),
            attn[i],
            "prefill attention == J-091 5.1",
        )
        expect_eq(
            read_work_projection(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rungs[i]),
            proj[i],
            "prefill projection == J-091 5.1",
        )
        expect_eq(_work(rungs[i]), total[i], "read work total")
        expect_eq(
            read_work_per_token(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, rungs[i]),
            avg[i],
            "read work per token",
        )
    # The head is the hand-off, never part of the
    # read: the total above excludes it at every
    # rung (J-091's projection column does too).
    expect_eq(
        read_attention_share_ppm(LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, 32768),
        335085,
        "attention share of read work @32768 (head excluded)",
    )
    print(
        "PASS: validation gate -- work columns reproduce J-091 section"
        " 5.1 EXACTLY at all 5 rungs (@8192 attention == J-053 filed;"
        " total @32768 321,576,079,720,448, mean 9,813,723,136/token;"
        " head excluded and priced separately)"
    )


def test_kv_columns() raises:
    # KV written reproduces J-091's totals; the KV
    # read shape reproduces J-092 section 4.3's
    # prefill KV shapes, both precisions.
    var wf = List[Int]()
    wf.append(58720256)
    wf.append(234881024)
    wf.append(469762048)
    wf.append(939524096)
    wf.append(1879048192)
    var wi = List[Int]()
    wi.append(30277632)
    wi.append(121110528)
    wi.append(242221056)
    wi.append(484442112)
    wi.append(968884224)
    var rf = List[Int]()
    rf.append(30094131200)
    rf.append(481153777664)
    rf.append(1924380229632)
    rf.append(7697051156480)
    rf.append(30787265101824)
    var ri = List[Int]()
    ri.append(15517286400)
    ri.append(248094916608)
    ri.append(992258555904)
    ri.append(3968792002560)
    ri.append(15874683568128)
    var pairs = List[Int]()
    pairs.append(524800)
    pairs.append(8390656)
    pairs.append(33558528)
    pairs.append(134225920)
    pairs.append(536887296)
    var rungs = _rungs()
    for i in range(5):
        expect_eq(read_pairs(rungs[i]), pairs[i], "causal pairs/layer")
        expect_eq(
            read_kv_written(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, rungs[i]),
            wf[i],
            "KV written f16 == J-091",
        )
        expect_eq(
            read_kv_written(LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8, rungs[i]),
            wi[i],
            "KV written int8 == J-091",
        )
        expect_eq(read_kv_read_shape(KV_F16, rungs[i]), rf[i], "KV read shape f16 == J-092")
        expect_eq(read_kv_read_shape(KV_I8, rungs[i]), ri[i], "KV read shape int8 == J-092")
        expect_eq(
            read_kv_read_shape(KV_F16, rungs[i]),
            share_prefill_kv_shape_bytes(KV_F16, rungs[i]),
            "KV read shape through attention_share",
        )
    print(
        "PASS: KV columns -- written == J-091 totals (f16 58,720,256 .."
        " 1,879,048,192; int8 roughly half); read shape == J-092"
        " section 4.3 (f16 @32768 30,787,265,101,824)"
    )


def test_surfaces() raises:
    # Passes, weight-pass bytes, touch shapes and
    # syncs per surface, exact at every rung.
    var ph = List[Int]()
    ph.append(4)
    ph.append(16)
    ph.append(32)
    ph.append(64)
    ph.append(128)
    var wh = List[Int]()
    wh.append(18732298752)
    wh.append(74929195008)
    wh.append(149858390016)
    wh.append(299716780032)
    wh.append(599433560064)
    var wg = List[Int]()
    wg.append(4795468480512)
    wg.append(19181873922048)
    wg.append(38363747844096)
    wg.append(76727495688192)
    wg.append(153454991376384)
    var thf = List[Int]()
    thf.append(48885150208)
    thf.append(556317853696)
    thf.append(2074708381696)
    thf.append(7997707460608)
    thf.append(31388577710080)
    var thi = List[Int]()
    thi.append(34279862784)
    thi.append(323145222144)
    thi.append(1142359166976)
    thi.append(4268993224704)
    thi.append(16475086012416)
    var tgf = List[Int]()
    tgf.append(4825621331968)
    tgf.append(19663262580736)
    tgf.append(40288597835776)
    tgf.append(84425486368768)
    tgf.append(184244135526400)
    var tgi = List[Int]()
    tgi.append(4811016044544)
    tgi.append(19430089949184)
    tgi.append(39356248621056)
    tgi.append(80696772132864)
    tgi.append(169330643828736)
    var rungs = _rungs()
    for i in range(5):
        expect_eq(read_passes(SURFACE_HOST_BATCHED, rungs[i]), ph[i], "host batched passes")
        expect_eq(read_passes(SURFACE_HOST_PER_TOKEN, rungs[i]), rungs[i], "host per-token passes")
        expect_eq(read_passes(SURFACE_CUDA_WIDTH1, rungs[i]), rungs[i], "gpu width-1 passes")
        expect_eq(
            read_weight_pass_bytes(SURFACE_HOST_BATCHED, rungs[i], WEIGHTS),
            wh[i],
            "host weight-pass bytes",
        )
        expect_eq(
            read_weight_pass_bytes(SURFACE_CUDA_WIDTH1, rungs[i], WEIGHTS),
            wg[i],
            "gpu weight-pass bytes",
        )
        expect_eq(
            read_touch_shape(KV_F16, SURFACE_HOST_BATCHED, rungs[i], WEIGHTS),
            thf[i],
            "host touch shape f16",
        )
        expect_eq(
            read_touch_shape(KV_I8, SURFACE_HOST_BATCHED, rungs[i], WEIGHTS),
            thi[i],
            "host touch shape int8 CF",
        )
        expect_eq(
            read_touch_shape(KV_F16, SURFACE_CUDA_WIDTH1, rungs[i], WEIGHTS),
            tgf[i],
            "gpu touch shape f16",
        )
        expect_eq(
            read_touch_shape(KV_I8, SURFACE_CUDA_WIDTH1, rungs[i], WEIGHTS),
            tgi[i],
            "gpu touch shape int8 CF",
        )
        expect_eq(read_sync_crossings(SURFACE_HOST_BATCHED, rungs[i]), 0, "host syncs")
        expect_eq(
            read_sync_crossings(SURFACE_CUDA_WIDTH1, rungs[i]),
            rungs[i],
            "gpu syncs (one per token)",
        )
    print(
        "PASS: surfaces -- host passes 4..128 vs width-1 1,024..32,768;"
        " touch shapes exact per surface/precision (@32768 f16: host"
        " 31,388,577,710,080 vs gpu 184,244,135,526,400)"
    )


def test_verdicts_and_placement() raises:
    # Read verdicts are J-091's at LADDER_READ:
    # CPU f16 refused at 16k/32k (host cap), GPU f16
    # accounted at every rung (its read session is
    # the rung itself), int8 blocked in all 10 read
    # cells; the write cell at 32768 stays refused.
    var rungs = _rungs()
    for i in range(5):
        var cpu = read_verdict(
            LADDER_LINE_CPU, LADDER_PRECISION_F16, rungs[i], False, False, PROFILE_CAP
        )
        if i < 3:
            expect_eq(cpu, LADDER_ACCOUNTED, "cpu f16 read accounted")
        else:
            expect_eq(cpu, LADDER_CAP_REFUSED, "cpu f16 read cap-refused")
        expect_eq(
            read_verdict(
                LADDER_LINE_GPU, LADDER_PRECISION_F16, rungs[i], False, False, PROFILE_CAP
            ),
            LADDER_ACCOUNTED,
            "gpu f16 read accounted",
        )
    var blocked = 0
    var lines = List[Int]()
    lines.append(LADDER_LINE_CPU)
    lines.append(LADDER_LINE_GPU)
    for line in lines:
        for rung in rungs:
            if read_verdict(line, LADDER_PRECISION_INT8, rung, False, False, PROFILE_CAP) == LADDER_INTEGRATION_BLOCKED:
                blocked += 1
    expect_eq(blocked, 10, "int8 INTEGRATION_BLOCKED in all 10 read cells")
    expect_eq(
        ladder_cell_verdict(
            LADDER_LINE_GPU, LADDER_PRECISION_F16, 32768, LADDER_WRITE,
            False, False, PROFILE_CAP,
        ),
        LADDER_CAP_REFUSED,
        "gpu f16 write @32768 still CAP_REFUSED (unchanged)",
    )
    # GPU read placement at session context = rung.
    var reqf = List[Int]()
    reqf.append(4743650944)
    reqf.append(4920155776)
    reqf.append(5155495552)
    reqf.append(5626175104)
    reqf.append(6567534208)
    var reqi = List[Int]()
    reqi.append(4715208320)
    reqi.append(4806385280)
    reqi.append(4927954560)
    reqi.append(5171093120)
    reqi.append(5657370240)
    for i in range(5):
        expect_eq(
            read_gpu_required(WEIGHTS, KV_F16, rungs[i], ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
            reqf[i],
            "gpu read required f16",
        )
        expect_eq(
            read_gpu_required(WEIGHTS, KV_I8, rungs[i], ACT_FIXED, ACT_PER_CONTEXT, SAMPLING),
            reqi[i],
            "gpu read required int8 CF",
        )
        var place_f = read_gpu_placement(reqf[i], USABLE)
        var place_i = read_gpu_placement(reqi[i], USABLE)
        if i < 3:
            expect_eq(place_f, LADDER_GPU_WHOLE, "f16 read whole")
        else:
            expect_eq(place_f, LADDER_GPU_SPILL, "f16 read spill")
        if i < 4:
            expect_eq(place_i, LADDER_GPU_WHOLE, "int8 read whole CF")
        else:
            expect_eq(place_i, LADDER_GPU_SPILL, "int8 read spill CF")
    print(
        "PASS: verdicts + placement -- cpu f16 read CAP_REFUSED"
        " @16384/32768; gpu f16 read ACCOUNTED all rungs, WHOLE through"
        " 8192 then SPILL (5,626,175,104 @16384 == J-091 cross-check);"
        " int8 blocked 10/10 read cells, CF placement whole through 16384"
    )


def test_chunk_effect() raises:
    # (a) Host chunking: the ONLY accounted quantity
    # it moves is weight-pass bytes -- the touch
    # shapes differ by exactly the chunk delta, and
    # the work/KV columns carry no surface at all.
    var rungs = _rungs()
    for rung in rungs:
        var delta = read_chunk_weight_delta(rung, WEIGHTS)
        expect_eq(
            delta,
            read_weight_pass_bytes(SURFACE_HOST_PER_TOKEN, rung, WEIGHTS)
            - read_weight_pass_bytes(SURFACE_HOST_BATCHED, rung, WEIGHTS),
            "chunk delta definition",
        )
        expect_eq(
            read_touch_shape(KV_F16, SURFACE_HOST_PER_TOKEN, rung, WEIGHTS)
            - read_touch_shape(KV_F16, SURFACE_HOST_BATCHED, rung, WEIGHTS),
            delta,
            "touch difference == chunk delta (work/KV unchanged)",
        )
    expect_eq(
        read_chunk_weight_delta(32768, WEIGHTS),
        152855557816320,
        "chunk delta @32768",
    )
    expect_eq(
        read_chunk_weight_delta(1024, WEIGHTS),
        4776736181760,
        "chunk delta @1024",
    )
    print(
        "PASS: chunk effect (J-053) -- weight-pass delta @32768"
        " 152,855,557,816,320 (32,640 fewer passes x the file); the"
        " touch-shape difference equals it exactly at every rung, so"
        " chunking's work and KV deltas are zero by construction"
    )


def test_precision_effect() raises:
    # (e) Precision moves bytes exactly and work
    # not at all: the work functions take no
    # precision (by construction); the KV deltas
    # are 27,776 B/token x L (written) and x pairs
    # (read shape).
    var rungs = _rungs()
    for rung in rungs:
        expect_eq(
            read_precision_kv_written_delta(LAYERS, KV_HEADS, HEAD_DIM, rung),
            27776 * rung,
            "kv written delta = 27,776 x L",
        )
        expect_eq(
            read_precision_kv_shape_delta(LAYERS, KV_HEADS, HEAD_DIM, rung),
            27776 * read_pairs(rung),
            "kv shape delta = 27,776 x pairs",
        )
    expect_eq(
        read_precision_kv_written_delta(LAYERS, KV_HEADS, HEAD_DIM, 32768),
        910163968,
        "kv written delta @32768",
    )
    expect_eq(
        read_precision_kv_shape_delta(LAYERS, KV_HEADS, HEAD_DIM, 32768),
        14912581533696,
        "kv shape delta @32768",
    )
    print(
        "PASS: precision effect -- written delta 910,163,968 and read-"
        " shape delta 14,912,581,533,696 @32768; work delta exactly"
        " zero (the work account is precision-free by construction)"
    )


def test_block_cf() raises:
    # (b) J-054's plan at width 256, cross-checked
    # field-by-field against plan_gpu_block_prefill
    # itself (stated stride = hidden, for the
    # cross-check only: the filed fields are the
    # stride-independent ones; no Coder layout
    # exists, M2).
    var cf = read_block_cf(32768, 256, LAYERS, WEIGHTS)
    expect_eq(cf.chunks, 128, "block cf chunks @32768")
    expect_eq(cf.sync_crossings, 128, "block cf syncs")
    expect_eq(cf.batched_gemm_calls, 25088, "block cf gemm calls")
    expect_eq(cf.per_row_attention_calls, 2752512, "block cf attention calls")
    expect_eq(cf.weight_read_bytes, 599433560064, "block cf weight bytes")
    expect_eq(cf.width1_weight_read_bytes, 153454991376384, "block cf width-1 weight")
    expect_eq(cf.admission, ADMISSION_UNBUILT, "block cf admission UNBUILT")
    var plan = plan_gpu_block_prefill(32768, 256, LAYERS, WEIGHTS, HIDDEN, 28, PROFILE_CAP)
    expect_eq(plan.chunks, cf.chunks, "plan chunks == cf")
    expect_eq(plan.sync_crossings, cf.sync_crossings, "plan syncs == cf")
    expect_eq(plan.batched_gemm_calls, cf.batched_gemm_calls, "plan gemm == cf")
    expect_eq(plan.per_row_attention_calls, cf.per_row_attention_calls, "plan attn == cf")
    expect_eq(plan.weight_read_bytes, cf.weight_read_bytes, "plan weight == cf")
    expect_eq(plan.width1_weight_read_bytes, cf.width1_weight_read_bytes, "plan w1 == cf")
    expect_eq(plan.admission, ADMISSION_UNBUILT, "plan admission UNBUILT")
    var plan1 = plan_gpu_block_prefill(1024, 1, LAYERS, WEIGHTS, HIDDEN, 28, PROFILE_CAP)
    expect_eq(plan1.admission, ADMISSION_WIDTH1_PROVEN, "width-1 admission proven")
    var cf1 = read_block_cf(1024, 256, LAYERS, WEIGHTS)
    expect_eq(cf1.chunks, 4, "block cf chunks @1024")
    expect_eq(cf1.batched_gemm_calls, 784, "block cf gemm @1024")
    expect_eq(cf1.per_row_attention_calls, 86016, "block cf attn @1024")
    print(
        "PASS: block CF (J-054, UNBUILT) -- @32768 width 256: 128"
        " chunks/syncs, 25,088 GEMM calls, 2,752,512 per-row attention"
        " calls, weight 599,433,560,064 vs width-1 153,454,991,376,384;"
        " every field == plan_gpu_block_prefill's own"
    )


def test_split_effect() raises:
    # (d) J-056's plan + rule through its own
    # module: conservation (the split's total MACs
    # ARE the read's work total), the join/crossing
    # deltas, REJECTED where the whole-GPU parent
    # exists (read placement whole), PARENT-ABSENT
    # where it does not (spill rungs).
    var plan = read_split_plan(
        8192, 256, LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, WEIGHTS, True
    )
    expect_eq(plan.total_macs, _work(8192), "split total == read work (conservation)")
    expect_eq(plan.gpu_macs, plan.total_macs // 2, "split halves 14/14 layers")
    expect_eq(plan.join_bytes, 117440512, "split join @8192")
    expect_eq(plan.boundary_transfers, 32, "split transfers @8192")
    expect_eq(plan.split_crossings, 96, "split crossings @8192 (3/chunk)")
    expect_eq(plan.parent_gpu_crossings, 32, "gpu parent crossings @8192")
    expect_eq(plan.parent_cpu_crossings, 0, "cpu parent crossings")
    expect_eq(
        plan.split_weight_read_bytes,
        plan.parent_weight_read_bytes,
        "split weight == parent weight (conservation)",
    )
    var verdict = read_split_verdict(plan)
    expect_eq(verdict.verdict, SPLIT_REJECTED_DOMINATED, "split @8192 rejected")
    if not verdict.dominated_by_gpu or not verdict.dominated_by_cpu:
        raise Error("PromptRead: split @8192 must be dominated by both parents")
    var plan32 = read_split_plan(
        32768, 256, LAYERS, HIDDEN, Q_WIDTH, KV_WIDTH, FFN, WEIGHTS, False
    )
    expect_eq(plan32.total_macs, _work(32768), "split total @32768 == read work")
    expect_eq(plan32.join_bytes, 469762048, "split join @32768")
    expect_eq(plan32.boundary_transfers, 128, "split transfers @32768")
    expect_eq(plan32.split_crossings, 384, "split crossings @32768")
    expect_eq(
        read_split_verdict(plan32).verdict,
        SPLIT_PARENT_ABSENT,
        "split @32768 parent-absent (spill rung)",
    )
    print(
        "PASS: split (J-056, not kept/unbuilt) -- total MACs and weight"
        " bytes conserve exactly; @8192 REJECTED (dominated by both"
        " parents: crossings 96 vs 32/0, join 117,440,512 added);"
        " @32768 PARENT-ABSENT, join 469,762,048, crossings 384"
    )


def test_whole_layer_identity() raises:
    # (c) J-055 whole-layer at width 1 IS the GPU
    # line's account: passes == syncs == L at every
    # rung, so there is no delta to file -- the
    # identity itself is the pinned fact.
    var rungs = _rungs()
    for rung in rungs:
        expect_eq(read_passes(SURFACE_CUDA_WIDTH1, rung), rung, "whole-layer passes")
        expect_eq(
            read_sync_crossings(SURFACE_CUDA_WIDTH1, rung),
            rung,
            "whole-layer syncs (one per token)",
        )
    print(
        "PASS: whole-layer identity (J-055) -- the GPU line's width-1"
        " account is the whole-layer account at every rung; accounted"
        " delta of whole-layer placement on the read: exactly zero"
    )


def test_refusals() raises:
    var refused = 0
    try:
        _ = _work(0)
    except:
        refused += 1
    try:
        _ = read_passes(99, 1024)
    except:
        refused += 1
    try:
        _ = read_sync_crossings(2, 1024)
    except:
        refused += 1
    try:
        _ = read_kv_written(LAYERS, KV_HEADS, HEAD_DIM, 7, 1024)
    except:
        refused += 1
    try:
        _ = read_chunk_weight_delta(1024, 0)
    except:
        refused += 1
    try:
        _ = read_touch_shape(0, SURFACE_HOST_BATCHED, 1024, WEIGHTS)
    except:
        refused += 1
    try:
        _ = read_block_cf(1024, 0, LAYERS, WEIGHTS)
    except:
        refused += 1
    expect_eq(refused, 7, "refusal count")
    print(
        "PASS: refusals -- zero rung, unknown surface (incl. tile-4,"
        " not a Coder surface), unknown precision, zero weights/KV"
        " price, zero block width"
    )


def main() raises:
    test_endpoints()
    test_validation_gate_work()
    test_kv_columns()
    test_surfaces()
    test_verdicts_and_placement()
    test_chunk_effect()
    test_precision_effect()
    test_block_cf()
    test_split_effect()
    test_whole_layer_identity()
    test_refusals()
    print("ALL PASS: prompt read (11 groups)")
