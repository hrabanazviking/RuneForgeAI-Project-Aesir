"""Memory ceiling accounting (J-093): Form A (the
dense ladder's own peak) reproducing J-091 section
5.3's GPU admission totals EXACTLY at every rung and
precision -- the validation gate -- plus the CPU
line's exact sampling difference, the inherited
J-091 verdicts, the pre-registered growth-shape
verdict against Janas's published 2.6->4.9 GiB ratio,
and Form B (the combined-process ceiling under
J-026's shared pool on its stated machine): pool
sizing over summed reserves, the arbiter's floor and
cap, and the combined peaks across the ladder. No
live peak, no wall, no speed claimed here: every
live peak is deferred to the J-098 gate recipe in
the J-093 doc (section 7).
"""
from core.expert_cache import plan_expert_cache_budget
from core.kv_account import kv_bytes_per_token
from core.kv_int8 import kv8_bytes_per_token
from core.kv_ladder import (
    LADDER_ACCOUNTED,
    LADDER_CAP_REFUSED,
    LADDER_INTEGRATION_BLOCKED,
    LADDER_LINE_CPU,
    LADDER_LINE_GPU,
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    LADDER_READ,
    LADDER_WRITE,
)
from core.memory_ceiling import (
    CEILING_SHAPE_FLATTER,
    CEILING_SHAPE_MATCHES,
    CEILING_SHAPE_STEEPER,
    JANAS_SHAPE_RATIO_PPM,
    ceiling_activation_bytes,
    ceiling_arbiter,
    ceiling_cache_resident,
    ceiling_combined_accounted,
    ceiling_combined_peak,
    ceiling_dense_peak,
    ceiling_dense_peak_at_rung,
    ceiling_kv_at_context,
    ceiling_peak_verdict,
    ceiling_pool_sizing,
    ceiling_ratio_ppm,
    ceiling_shape_name,
    ceiling_shape_verdict,
    ceiling_share_ppm,
)

# Witnesses and stated machines (see the module
# header): Coder-7B dense (J-091) and OLMoE (J-015).
comptime LAYERS = 28
comptime KV_HEADS = 4
comptime HEAD_DIM = 128
comptime PROFILE_CAP = 32768
comptime WEIGHTS = 4683074688
comptime ACT_FIXED = 208896
comptime ACT_PER_CONTEXT = 28
comptime SAMPLING = 905728
comptime OLMOE_LAYERS = 16
comptime OLMOE_KV_HEADS = 16
comptime OLMOE_RESIDENT = 311027712
comptime OLMOE_BODY = 3900702720
comptime OLMOE_ROUTED = 487587840
comptime OLMOE_CONTEXT = 512
comptime OLMOE_ACT_ALLOWANCE = 16777216
comptime RESIDENT_TOTAL = 4994102400
comptime STATED_TOTAL = 17179869184


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "MemoryCeiling " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "MemoryCeiling " + what + ": expected " + expected
            + ", got " + actual
        )


def _kv_pt(precision: Int) raises -> Int:
    if precision == LADDER_PRECISION_F16:
        return kv_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM, 2)
    return kv8_bytes_per_token(LAYERS, KV_HEADS, HEAD_DIM)


def _olmoe_kv(precision: Int) raises -> Int:
    if precision == LADDER_PRECISION_F16:
        return kv_bytes_per_token(OLMOE_LAYERS, OLMOE_KV_HEADS, HEAD_DIM, 2) * OLMOE_CONTEXT
    return kv8_bytes_per_token(OLMOE_LAYERS, OLMOE_KV_HEADS, HEAD_DIM) * OLMOE_CONTEXT


def _combined(precision: Int, rung: Int) raises -> Int:
    var session = rung + 128
    var kv_total = ceiling_kv_at_context(
        LAYERS, KV_HEADS, HEAD_DIM, precision, session
    ) + _olmoe_kv(precision)
    var scratch = ceiling_activation_bytes(
        ACT_FIXED, ACT_PER_CONTEXT, session
    ) + OLMOE_ACT_ALLOWANCE
    var sizing = ceiling_pool_sizing(
        STATED_TOTAL, STATED_TOTAL, RESIDENT_TOTAL, kv_total, scratch, OLMOE_ROUTED
    )
    return ceiling_combined_peak(
        RESIDENT_TOTAL, kv_total, scratch, sizing.budget_bytes, OLMOE_BODY
    )


def test_endpoints() raises:
    # Per-token endpoints ARE J-087's census and
    # J-088's store prices, on both witnesses.
    expect_eq(_kv_pt(LADDER_PRECISION_F16), 57344, "Coder f16/token (J-087)")
    expect_eq(_kv_pt(LADDER_PRECISION_INT8), 29568, "Coder int8/token (J-088)")
    expect_eq(
        kv_bytes_per_token(OLMOE_LAYERS, OLMOE_KV_HEADS, HEAD_DIM, 2),
        131072,
        "OLMoE f16/token (J-087)",
    )
    expect_eq(
        kv8_bytes_per_token(OLMOE_LAYERS, OLMOE_KV_HEADS, HEAD_DIM),
        67584,
        "OLMoE int8/token (J-088)",
    )
    expect_eq(_olmoe_kv(LADDER_PRECISION_F16), 67108864, "OLMoE KV @512 f16")
    expect_eq(_olmoe_kv(LADDER_PRECISION_INT8), 34603008, "OLMoE KV @512 int8 CF")
    # Activation shape: the profile's own fixed +
    # per-context split, at 4 bytes.
    expect_eq(ceiling_activation_bytes(ACT_FIXED, ACT_PER_CONTEXT, 1152), 964608, "activation @1152")
    expect_eq(ceiling_activation_bytes(ACT_FIXED, ACT_PER_CONTEXT, 32896), 4519936, "activation @32896")
    expect_eq(RESIDENT_TOTAL, WEIGHTS + OLMOE_RESIDENT, "summed residents")
    print(
        "PASS: endpoints -- Coder 57,344 f16 / 29,568 int8 (J-087/J-088);"
        " OLMoE 131,072 / 67,584, @512 67,108,864 / 34,603,008;"
        " activation 964,608 @1152 .. 4,519,936 @32896"
    )


def test_validation_gate_gpu() raises:
    # THE GATE: Form A's GPU session peaks reproduce
    # J-091 section 5.3's admission totals EXACTLY,
    # every rung, both precisions (int8 = J-091's CF).
    var f16 = List[Int]()
    f16.append(4751005312)
    f16.append(4927510144)
    f16.append(5162849920)
    f16.append(5633529472)
    f16.append(6574888576)
    var i8 = List[Int]()
    i8.append(4719007360)
    i8.append(4810184320)
    i8.append(4931753600)
    i8.append(5174892160)
    i8.append(5661169280)
    var rungs = List[Int]()
    rungs.append(1024)
    rungs.append(4096)
    rungs.append(8192)
    rungs.append(16384)
    rungs.append(32768)
    for i in range(5):
        expect_eq(
            ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16,
                rungs[i], LADDER_WRITE, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING,
                LADDER_LINE_GPU,
            ),
            f16[i],
            "GPU f16 session peak == J-091 5.3",
        )
        expect_eq(
            ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_INT8,
                rungs[i], LADDER_WRITE, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING,
                LADDER_LINE_GPU,
            ),
            i8[i],
            "GPU int8 session peak == J-091 5.3 CF",
        )
    print(
        "PASS: validation gate -- GPU session peaks reproduce J-091"
        " section 5.3 EXACTLY at all 5 rungs, both precisions"
    )


def test_cpu_line_and_read_leg() raises:
    # CPU peak = GPU peak - sampling (905,728), every
    # cell; the read leg (at the rung) is priced and
    # is never the peak.
    var rungs = List[Int]()
    rungs.append(1024)
    rungs.append(4096)
    rungs.append(8192)
    rungs.append(16384)
    rungs.append(32768)
    for i in range(5):
        var precisions = List[Int]()
        precisions.append(LADDER_PRECISION_F16)
        precisions.append(LADDER_PRECISION_INT8)
        for precision in precisions:
            var gpu = ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, precision, rungs[i],
                LADDER_WRITE, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, LADDER_LINE_GPU,
            )
            var cpu = ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, precision, rungs[i],
                LADDER_WRITE, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, LADDER_LINE_CPU,
            )
            expect_eq(gpu - cpu, SAMPLING, "CPU == GPU - sampling")
            var read = ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, precision, rungs[i],
                LADDER_READ, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, LADDER_LINE_GPU,
            )
            if read >= gpu:
                raise Error("MemoryCeiling: read leg must stay below the session peak")
    expect_eq(
        ceiling_dense_peak_at_rung(
            WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, 16384,
            LADDER_READ, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, LADDER_LINE_GPU,
        ),
        5626175104,
        "read @16384 == J-091 cross-check context total",
    )
    print(
        "PASS: CPU line + read leg -- CPU == GPU - 905,728 at all 10"
        " session cells; read totals below the peak; read @16384"
        " 5,626,175,104 (J-091's cross-check figure)"
    )


def test_peak_verdicts() raises:
    # Verdicts are J-091's, inherited unchanged: the
    # peak cell of a rung is its write-leg cell.
    expect_eq(
        ceiling_peak_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, 8192, LADDER_WRITE, False, False, PROFILE_CAP),
        LADDER_ACCOUNTED, "cpu f16 peak @8192",
    )
    expect_eq(
        ceiling_peak_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, 16384, LADDER_WRITE, False, False, PROFILE_CAP),
        LADDER_CAP_REFUSED, "cpu f16 peak @16384 (host cap 16000)",
    )
    expect_eq(
        ceiling_peak_verdict(LADDER_LINE_CPU, LADDER_PRECISION_F16, 32768, LADDER_READ, False, False, PROFILE_CAP),
        LADDER_CAP_REFUSED, "cpu f16 read @32768",
    )
    expect_eq(
        ceiling_peak_verdict(LADDER_LINE_GPU, LADDER_PRECISION_F16, 32768, LADDER_READ, False, False, PROFILE_CAP),
        LADDER_ACCOUNTED, "gpu f16 read @32768",
    )
    expect_eq(
        ceiling_peak_verdict(LADDER_LINE_GPU, LADDER_PRECISION_F16, 32768, LADDER_WRITE, False, False, PROFILE_CAP),
        LADDER_CAP_REFUSED, "gpu f16 peak @32768 (session 32896 > cap)",
    )
    var blocked = 0
    var lines = List[Int]()
    lines.append(LADDER_LINE_CPU)
    lines.append(LADDER_LINE_GPU)
    var vrungs = List[Int]()
    vrungs.append(1024)
    vrungs.append(4096)
    vrungs.append(8192)
    vrungs.append(16384)
    vrungs.append(32768)
    var directions = List[Int]()
    directions.append(LADDER_READ)
    directions.append(LADDER_WRITE)
    for line in lines:
        for rung in vrungs:
            for direction in directions:
                if ceiling_peak_verdict(line, LADDER_PRECISION_INT8, rung, direction, False, False, PROFILE_CAP) == LADDER_INTEGRATION_BLOCKED:
                    blocked += 1
    expect_eq(blocked, 20, "int8 INTEGRATION_BLOCKED in all 20 cells")
    print(
        "PASS: peak verdicts -- J-091's inherited: cpu f16 CAP_REFUSED"
        " @16384/32768, gpu write @32768 CAP_REFUSED, int8"
        " INTEGRATION_BLOCKED in all 20 line x rung x direction cells"
    )


def test_growth_shape() raises:
    # The shape test, exact: per line and precision,
    # top/base session-peak ratio vs Janas's 1,884,615.
    expect_eq(JANAS_SHAPE_RATIO_PPM, 1884615, "Janas ratio ppm (49/26 floored)")
    var gpu_f16 = ceiling_ratio_ppm(6574888576, 4751005312)
    var cpu_f16 = ceiling_ratio_ppm(6573982848, 4750099584)
    var gpu_i8 = ceiling_ratio_ppm(5661169280, 4719007360)
    var cpu_i8 = ceiling_ratio_ppm(5660263552, 4718101632)
    expect_eq(gpu_f16, 1383894, "gpu f16 growth ppm")
    expect_eq(cpu_f16, 1383967, "cpu f16 growth ppm")
    expect_eq(gpu_i8, 1199652, "gpu int8 growth ppm")
    expect_eq(cpu_i8, 1199690, "cpu int8 growth ppm")
    var ratios = List[Int]()
    ratios.append(gpu_f16)
    ratios.append(cpu_f16)
    ratios.append(gpu_i8)
    ratios.append(cpu_i8)
    for ratio in ratios:
        expect_eq(ceiling_shape_verdict(ratio), CEILING_SHAPE_FLATTER, "Aesir shape verdict")
    expect_eq(ceiling_shape_verdict(1884615), CEILING_SHAPE_MATCHES, "shape MATCHES at Janas ratio")
    expect_eq(ceiling_shape_verdict(1884616), CEILING_SHAPE_STEEPER, "shape STEEPER above Janas ratio")
    expect_str(ceiling_shape_name(CEILING_SHAPE_FLATTER), String("FLATTER"), "shape name")
    # The driver, in bytes: KV share of the GPU peak.
    expect_eq(ceiling_share_ppm(66060288, 4751005312), 13904, "kv share base f16 gpu")
    expect_eq(ceiling_share_ppm(1886388224, 6574888576), 286908, "kv share top f16 gpu")
    expect_eq(ceiling_share_ppm(34062336, 4719007360), 7218, "kv share base int8 gpu")
    expect_eq(ceiling_share_ppm(972668928, 5661169280), 171814, "kv share top int8 gpu")
    expect_eq(ceiling_share_ppm(WEIGHTS, 4751005312), 985701, "weights share base f16 gpu")
    expect_eq(ceiling_share_ppm(WEIGHTS, 6574888576), 712266, "weights share top f16 gpu")
    print(
        "PASS: growth shape -- gpu/cpu f16 1,383,894 / 1,383,967 ppm,"
        " gpu/cpu int8 1,199,652 / 1,199,690 ppm, all FLATTER than"
        " Janas's 1,884,615; KV share 13,904 -> 286,908 ppm (f16 gpu)"
    )


def test_pool_sizing_base() raises:
    # Form B at the base rung (f16): the pool sizes
    # ONCE over summed reserves; headroom charged once.
    var kv_total = 66060288 + 67108864
    var scratch = 964608 + OLMOE_ACT_ALLOWANCE
    var sizing = ceiling_pool_sizing(
        STATED_TOTAL, STATED_TOTAL, RESIDENT_TOTAL, kv_total, scratch, OLMOE_ROUTED
    )
    expect_eq(sizing.reserve_bytes, 8580987212, "pool reserve @base f16")
    expect_eq(sizing.budget_bytes, 8598881972, "pool budget @base f16")
    expect_eq(sizing.os_headroom_bytes, 3435973836, "headroom charged once")
    if sizing.below_floor:
        raise Error("MemoryCeiling: base pool must not be below floor")
    if sizing.capped:
        raise Error("MemoryCeiling: stated machine has no hard cap")
    # The over-commit the pool rule exists to refuse:
    # the dense tenant alone under J-018 sizing would
    # take a budget against the same free snapshot.
    var solo_dense = plan_expert_cache_budget(
        STATED_TOTAL, STATED_TOTAL, 0, WEIGHTS, 66060288, 964608, OLMOE_ROUTED
    )
    if solo_dense.budget_bytes + 8598881972 <= STATED_TOTAL:
        raise Error("MemoryCeiling: independent sizing premise broken")
    var arbiter = ceiling_arbiter(sizing.budget_bytes, 2)
    expect_eq(arbiter.floor_bytes, 2149720493, "arbiter floor = pool / 4")
    var residents = List[Int]()
    residents.append(0)
    residents.append(0)
    var actives = List[Bool]()
    actives.append(True)
    actives.append(True)
    expect_eq(
        arbiter.cap_for(1, residents, actives),
        sizing.budget_bytes,
        "MoE tenant cap == whole pool (dense tenant protects 0 cache bytes)",
    )
    print(
        "PASS: pool sizing @base f16 -- reserve 8,580,987,212, pool"
        " 8,598,881,972, floor 2,149,720,493, MoE cap == pool;"
        " independent J-018 sizing over-commits the stated machine"
    )


def test_combined_peaks() raises:
    # Form B across the ladder, both precisions
    # (int8 = CF for both tenants), exact.
    var f16 = List[Int]()
    f16.append(9045716096)
    f16.append(9222220928)
    f16.append(9457560704)
    f16.append(9928240256)
    f16.append(10869599360)
    var i8 = List[Int]()
    i8.append(8981212288)
    i8.append(9072389248)
    i8.append(9193958528)
    i8.append(9437097088)
    i8.append(9923374208)
    var rungs = List[Int]()
    rungs.append(1024)
    rungs.append(4096)
    rungs.append(8192)
    rungs.append(16384)
    rungs.append(32768)
    for i in range(5):
        expect_eq(_combined(LADDER_PRECISION_F16, rungs[i]), f16[i], "combined peak f16")
        expect_eq(_combined(LADDER_PRECISION_INT8, rungs[i]), i8[i], "combined peak int8 CF")
    expect_eq(ceiling_ratio_ppm(f16[4], f16[0]), 1201629, "combined growth f16 ppm")
    expect_eq(ceiling_ratio_ppm(i8[4], i8[0]), 1104903, "combined growth int8 ppm")
    expect_eq(ceiling_shape_verdict(1201629), CEILING_SHAPE_FLATTER, "combined shape f16")
    expect_eq(ceiling_shape_verdict(1104903), CEILING_SHAPE_FLATTER, "combined shape int8")
    print(
        "PASS: combined peaks -- f16 9,045,716,096 .. 10,869,599,360"
        " (growth 1,201,629 ppm FLATTER); int8 CF 8,981,212,288 .."
        " 9,923,374,208 (1,104,903 ppm FLATTER)"
    )


def test_pool_absorbs_growth() raises:
    # On the stated machine the accounted ceiling is
    # constant: as KV grows the pool shrinks by
    # exactly the KV + scratch growth, and the cache's
    # peak residency stays capped at the body.
    var accounted_base = 0
    var accounted_top = 0
    var pool_base = 0
    var pool_top = 0
    var rungs = List[Int]()
    rungs.append(1024)
    rungs.append(32768)
    for i in range(2):
        var rung = rungs[i]
        var session = rung + 128
        var kv_total = ceiling_kv_at_context(
            LAYERS, KV_HEADS, HEAD_DIM, LADDER_PRECISION_F16, session
        ) + _olmoe_kv(LADDER_PRECISION_F16)
        var scratch = ceiling_activation_bytes(
            ACT_FIXED, ACT_PER_CONTEXT, session
        ) + OLMOE_ACT_ALLOWANCE
        var sizing = ceiling_pool_sizing(
            STATED_TOTAL, STATED_TOTAL, RESIDENT_TOTAL, kv_total, scratch, OLMOE_ROUTED
        )
        if sizing.below_floor:
            raise Error("MemoryCeiling: pool below floor on the stated machine")
        if i == 0:
            pool_base = sizing.budget_bytes
            accounted_base = ceiling_combined_accounted(
                RESIDENT_TOTAL, kv_total, scratch, sizing.budget_bytes
            )
        else:
            pool_top = sizing.budget_bytes
            accounted_top = ceiling_combined_accounted(
                RESIDENT_TOTAL, kv_total, scratch, sizing.budget_bytes
            )
    expect_eq(accounted_base, 13743895348, "accounted ceiling @base")
    expect_eq(accounted_top, 13743895348, "accounted ceiling @top (constant)")
    expect_eq(pool_base - pool_top, 1823903264, "pool shrink == KV + scratch growth")
    expect_eq(ceiling_cache_resident(pool_top, OLMOE_BODY), OLMOE_BODY, "cache residency capped at body")
    expect_eq(ceiling_cache_resident(1000, OLMOE_BODY), 1000, "cache residency == budget below body")
    print(
        "PASS: pool absorbs growth -- accounted ceiling constant"
        " 13,743,895,348 (free - headroom); pool shrinks"
        " 1,823,903,264 == KV + scratch growth; residency capped at body"
    )


def test_below_floor_shape() raises:
    # The pool's refusal shape: on a small stated
    # machine the sizing says below_floor instead of
    # granting a cache under one token's routed demand.
    var sizing = ceiling_pool_sizing(
        10000, 10000, 300, 200, 100, OLMOE_ROUTED
    )
    if not sizing.below_floor:
        raise Error("MemoryCeiling: tiny machine must size below floor")
    expect_eq(sizing.budget_bytes, 7400, "tiny machine pool budget")
    print(
        "PASS: below-floor shape -- tiny stated machine sizes 7,400"
        " against a 487,587,840 floor demand: below_floor stated, not hidden"
    )


def test_refusals() raises:
    var refused = 0
    try:
        _ = ceiling_dense_peak(WEIGHTS, 57344, 1152, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, 7)
    except:
        refused += 1
    try:
        _ = ceiling_activation_bytes(ACT_FIXED, ACT_PER_CONTEXT, 0)
    except:
        refused += 1
    try:
        _ = ceiling_ratio_ppm(0, 100)
    except:
        refused += 1
    try:
        _ = ceiling_share_ppm(-1, 100)
    except:
        refused += 1
    try:
        _ = ceiling_shape_verdict(0)
    except:
        refused += 1
    try:
        _ = ceiling_cache_resident(0, OLMOE_BODY)
    except:
        refused += 1
    try:
        _ = ceiling_combined_peak(-1, 0, 0, 100, OLMOE_BODY)
    except:
        refused += 1
    try:
        _ = ceiling_pool_sizing(STATED_TOTAL, STATED_TOTAL, RESIDENT_TOTAL, 100, 100, 0)
    except:
        refused += 1
    expect_eq(refused, 8, "refusal count")
    print("PASS: refusals -- unknown line, zero context/ratio, negative share/component, zero pool/body, zero routed demand")


def main() raises:
    test_endpoints()
    test_validation_gate_gpu()
    test_cpu_line_and_read_leg()
    test_peak_verdicts()
    test_growth_shape()
    test_pool_sizing_base()
    test_combined_peaks()
    test_pool_absorbs_growth()
    test_below_floor_shape()
    test_refusals()
    print("ALL PASS: memory ceiling (10 groups)")
