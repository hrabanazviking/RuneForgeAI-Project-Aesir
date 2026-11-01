"""NPU prompt preparation account (J-061): the pass law
refused by construction (reply, draft-check, the 64-token
floor), the 8-bit copy pricing on synthetic and filed
shapes (Qwen3-0.6B dense-whole from the tree's own
profile arithmetic; OLMoE resident-products from J-015's
dims), the form rules, the preparation progress
discipline (the census's 25-unit shape included), the
graph-cache hit, and J-048's contention invariant priced
through the real planner on the J-031/J-048 stated
machine -- admitted there, closed one byte below the
floor line, and refused/degraded for a hand-named copy.

Filed inputs restated exactly: Qwen3 0.6B profile
(28 layers, hidden 1024, q 2048, kv 1024, ffn 3072 --
per layer Q/K/V/O/gate/up/down = 15,728,640 elements
and 12,288 rows; two hidden-wide norms per layer plus
the final norm = 58,368 norm elements). OLMoE (J-015:
16 layers, hidden 2048, MHA 16/16 at head_dim 128 --
resident set per layer Q/K/V/O 4,194,304 elements each
plus the 64x2048 router = 16,908,288 elements and
8,256 rows; resident total 270,532,608 elements,
132,096 rows; norms as above = 67,584 elements).
Contention machine (J-031/J-048): pool 5,368,709,120 B,
resident fixed 311,027,712 B, allowances/reserve
352,321,536 B, cache open = body 3,900,702,720 B, floor
487,587,840 B, largest pair 3,809,280 B. No run, no
wall, no device -- the account prices stated inputs.
"""
from core.npu_prompt_prep import (
    NPU_CONTENTION_ADMITTED,
    NPU_CONTENTION_CLOSED,
    NPU_CONTENTION_REFUSED,
    NPU_FORM_DENSE_WHOLE,
    NPU_FORM_RESIDENT_PRODUCTS,
    NPU_FORM_SPLIT_BLOCK,
    NPU_MIN_PROMPT_TOKENS,
    evaluate_npu_contention,
    npu_contention_name,
    npu_form_name,
    npu_prep_boundary_emits,
    npu_prep_records_expected,
    plan_npu_prompt_prep,
    plan_npu_weight_copy,
    render_npu_prep_line,
)
from core.placement_options import PASS_DRAFTS, PASS_PROMPT, PASS_REPLY
from core.placement_pressure import (
    CONTENTION_FULL,
    CONTENTION_NO_CACHE,
    CONTENTION_REFUSE,
    CONTENTION_SHRUNK,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "NpuPromptPrep "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "NpuPromptPrep "
            + what
            + ": expected '"
            + expected
            + "', got '"
            + actual
            + "'"
        )


def test_pass_law_refusals() raises:
    # The NPU may never take a reply pass or a draft-check
    # pass: there is no plan shape for them, at any token
    # count. A prompt below the census's 64-token floor is
    # refused for the NPU (Aesir's general prompt band
    # starts at 17 -- the floor binds the device, not the
    # pass). At exactly 64 the smallest plan stands.
    var refused = 0
    try:
        _ = plan_npu_prompt_prep(
            PASS_REPLY, 1, NPU_FORM_DENSE_WHOLE, 28, 28, 1000, 100, 0, False, False
        )
    except:
        refused += 1
    try:
        _ = plan_npu_prompt_prep(
            PASS_DRAFTS, 8, NPU_FORM_DENSE_WHOLE, 28, 28, 1000, 100, 0, False, False
        )
    except:
        refused += 1
    try:
        _ = plan_npu_prompt_prep(
            PASS_PROMPT, 63, NPU_FORM_DENSE_WHOLE, 28, 28, 1000, 100, 0, False, False
        )
    except:
        refused += 1
    try:
        _ = plan_npu_prompt_prep(
            PASS_PROMPT, 17, NPU_FORM_DENSE_WHOLE, 28, 28, 1000, 100, 0, False, False
        )
    except:
        refused += 1
    expect_eq(refused, 4, "pass-law refusal count")
    expect_eq(NPU_MIN_PROMPT_TOKENS, 64, "NPU floor constant")
    var ok = plan_npu_prompt_prep(
        PASS_PROMPT, 64, NPU_FORM_DENSE_WHOLE, 28, 28, 1000, 100, 0, False, False
    )
    expect_eq(ok.prompt_tokens, 64, "floor-exact prompt planned")
    print("PASS: pass law -- reply/draft-check refused by construction, 64-token floor binds")


def test_copy_pricing() raises:
    # Synthetic exact: 1,000 elements over 100 rows price
    # at 1,000 payload + 200 scale bytes. Broken shapes
    # are refused, never priced.
    var c = plan_npu_weight_copy(1000, 100)
    expect_eq(c.payload_bytes, 1000, "synthetic payload")
    expect_eq(c.scale_bytes, 200, "synthetic scales (f16 per row)")
    expect_eq(c.copy_bytes, 1200, "synthetic copy total")
    var refused = 0
    try:
        _ = plan_npu_weight_copy(0, 10)
    except:
        refused += 1
    try:
        _ = plan_npu_weight_copy(100, 0)
    except:
        refused += 1
    try:
        _ = plan_npu_weight_copy(100, 101)
    except:
        refused += 1
    expect_eq(refused, 3, "copy-shape refusal count")
    print("PASS: copy pricing -- 1 B/elem payload + 2 B/row scales, broken shapes refused")


def test_qwen3_dense_whole_filed() raises:
    # The census-named dense-whole family at the tree's
    # own profile: Qwen3-0.6B, all 28 layers on the NPU.
    var p = plan_npu_prompt_prep(
        PASS_PROMPT,
        1024,
        NPU_FORM_DENSE_WHOLE,
        28,
        28,
        440401920,
        344064,
        58368,
        False,
        False,
    )
    expect_str(npu_form_name(p.form), String("dense_whole"), "form name")
    expect_eq(p.layers_leftover, 0, "dense-whole leftover")
    expect_eq(p.copy_set.payload_bytes, 440401920, "0.6B payload")
    expect_eq(p.copy_set.scale_bytes, 688128, "0.6B scales")
    expect_eq(p.copy_set.copy_bytes, 441090048, "0.6B copy total")
    expect_eq(p.norm_bytes, 233472, "0.6B norms at f32")
    expect_eq(p.footprint_bytes, 441323520, "0.6B footprint")
    expect_eq(p.prep_units, 28, "0.6B prep units (one graph per layer)")
    expect_eq(p.prep_bytes_to_write, 441323520, "cold open writes the footprint")
    print("PASS: Qwen3-0.6B dense-whole -- filed shape priced exact (441,323,520 B footprint)")


def test_olmoe_resident_products_filed() raises:
    # The MoE form: only the resident set is copied
    # (attention products + router, all 16 layers);
    # routed experts are never in the copy set -- the
    # caller states the resident aggregate, and the
    # account prices exactly that.
    var p = plan_npu_prompt_prep(
        PASS_PROMPT,
        1024,
        NPU_FORM_RESIDENT_PRODUCTS,
        16,
        16,
        270532608,
        132096,
        67584,
        False,
        False,
    )
    expect_str(
        npu_form_name(p.form), String("resident_products"), "MoE form name"
    )
    expect_eq(p.copy_set.payload_bytes, 270532608, "OLMoE resident payload")
    expect_eq(p.copy_set.scale_bytes, 264192, "OLMoE resident scales")
    expect_eq(p.copy_set.copy_bytes, 270796800, "OLMoE copy total")
    expect_eq(p.norm_bytes, 270336, "OLMoE norms at f32")
    expect_eq(p.footprint_bytes, 271067136, "OLMoE footprint")
    expect_eq(p.prep_units, 16, "OLMoE prep units")
    print("PASS: OLMoE resident-products -- filed shape priced exact (271,067,136 B footprint)")


def test_form_rules() raises:
    # Dense-whole with layers left over is refused (the
    # partial forms must be named); split-block carries
    # its leftover openly at half the 0.6B copy set;
    # 8-bit activations are dense-only.
    var refused = 0
    try:
        _ = plan_npu_prompt_prep(
            PASS_PROMPT, 256, NPU_FORM_DENSE_WHOLE, 28, 14,
            220200960, 172032, 28672, False, False,
        )
    except:
        refused += 1
    try:
        _ = plan_npu_prompt_prep(
            PASS_PROMPT, 256, NPU_FORM_RESIDENT_PRODUCTS, 16, 16,
            270532608, 132096, 67584, False, True,
        )
    except:
        refused += 1
    expect_eq(refused, 2, "form-rule refusal count")
    var split = plan_npu_prompt_prep(
        PASS_PROMPT, 256, NPU_FORM_SPLIT_BLOCK, 28, 14,
        220200960, 172032, 28672, False, False,
    )
    expect_str(npu_form_name(split.form), String("split_block"), "split name")
    expect_eq(split.layers_leftover, 14, "split leftover stays on CPU")
    expect_eq(split.copy_set.copy_bytes, 220545024, "split copy total")
    expect_eq(split.footprint_bytes, 220659712, "split footprint")
    var dense_int8 = plan_npu_prompt_prep(
        PASS_PROMPT, 256, NPU_FORM_DENSE_WHOLE, 28, 28,
        440401920, 344064, 58368, False, True,
    )
    expect_eq(dense_int8.footprint_bytes, 441323520, "int8 activations change no copy byte")
    print("PASS: form rules -- partial dense-whole refused, split leftover open, int8 dense-only")


def test_prep_progress_discipline() raises:
    # The census's own shape: a 25-unit preparation emits
    # exactly 10 records under the step throttle. The
    # filed shapes agree (28 and 16 units also emit 10);
    # 4 units emit 4 (every boundary crosses a step, the
    # final included once); 3 units are silent.
    expect_eq(npu_prep_records_expected(25), 10, "25-unit records")
    expect_eq(npu_prep_records_expected(28), 10, "28-unit records")
    expect_eq(npu_prep_records_expected(16), 10, "16-unit records")
    expect_eq(npu_prep_records_expected(4), 4, "4-unit records")
    expect_eq(npu_prep_records_expected(3), 0, "3-unit silence")
    # Boundary spots on the 25-unit shape: unit 1 crosses
    # no step, unit 3 crosses the first, the final emits.
    if npu_prep_boundary_emits(25, 1):
        raise Error("NpuPromptPrep: unit 1 of 25 must not emit")
    if not npu_prep_boundary_emits(25, 3):
        raise Error("NpuPromptPrep: unit 3 of 25 must emit")
    if not npu_prep_boundary_emits(25, 25):
        raise Error("NpuPromptPrep: the final unit must emit")
    if npu_prep_boundary_emits(3, 3):
        raise Error("NpuPromptPrep: an unwatched preparation never emits")
    # The plan carries the same count the walker states.
    var p = plan_npu_prompt_prep(
        PASS_PROMPT, 128, NPU_FORM_DENSE_WHOLE, 28, 28,
        440401920, 344064, 58368, False, False,
    )
    expect_eq(p.prep_records_expected, 10, "plan-carried record count")
    print("PASS: prep progress -- 25/28/16 units emit 10, 4 emit 4, 3 silent, final once")


def test_prep_render() raises:
    # The census's documented status-line shape, verbatim
    # arithmetic: no time unless the caller supplies one.
    expect_str(
        render_npu_prep_line(12, 25),
        String("preparing the NPU 12/25"),
        "prep line without a time",
    )
    expect_str(
        render_npu_prep_line(12, 25, 8),
        String("preparing the NPU 12/25, 8 s"),
        "prep line with the caller's seconds",
    )
    expect_str(
        render_npu_prep_line(25, 25, 53),
        String("preparing the NPU 25/25, 53 s"),
        "prep final line",
    )
    print("PASS: prep render -- the census status-line shape, time only when supplied")


def test_graph_cache_hit() raises:
    # A cached preparation writes nothing new -- but the
    # footprint is still the footprint: the copies
    # occupy the pool either way, and contention charges
    # them either way (the contention groups below use
    # the cold footprint for exactly this reason).
    var hit = plan_npu_prompt_prep(
        PASS_PROMPT, 128, NPU_FORM_DENSE_WHOLE, 28, 28,
        440401920, 344064, 58368, True, False,
    )
    expect_eq(hit.prep_bytes_to_write, 0, "cache hit writes nothing")
    expect_eq(hit.footprint_bytes, 441323520, "cache hit footprint unchanged")
    expect_eq(hit.prep_records_expected, 10, "cache hit record count unchanged")
    print("PASS: graph cache hit -- zero bytes to write, footprint still charged in full")


def test_contention_admitted_stated_machine() raises:
    # J-048's invariant on the road's stated machine:
    # the OLMoE footprint, charged as an automatic
    # duplicate copy, is admitted and the expert cache
    # still holds its whole body -- FULL, with the
    # planner's own headroom.
    var v = evaluate_npu_contention(
        5368709120, 311027712, 352321536, 3900702720, 487587840,
        3809280, 3900702720, 271067136, False, True,
    )
    expect_eq(v.verdict, NPU_CONTENTION_ADMITTED, "stated-machine verdict")
    expect_str(
        npu_contention_name(v.verdict), String("admitted"), "verdict name"
    )
    expect_eq(v.decision, CONTENTION_FULL, "planner decision FULL")
    expect_eq(v.copy_charged_bytes, 271067136, "copy charged in full")
    expect_eq(v.cache_target_bytes, 3900702720, "cache keeps the whole body")
    expect_eq(v.headroom_bytes, 533590016, "planner headroom")
    print("PASS: contention admitted -- stated machine, cache FULL, headroom 533,590,016 B")


def test_contention_closed_and_manual() raises:
    # One byte below the floor line the automatic copy
    # CLOSES and the cache keeps its bytes (shrunk, not
    # starved). A hand-named copy in the same pool
    # charges as fixed instead: with a required cache
    # the open REFUSES whole (J-047's shape); with an
    # optional cache the copy stands and the cache
    # degrades to zero.
    var pool = 663349248 + 487587840 + 271067136 - 1
    var closed = evaluate_npu_contention(
        pool, 311027712, 352321536, 3900702720, 487587840,
        3809280, 3900702720, 271067136, False, True,
    )
    expect_eq(closed.verdict, NPU_CONTENTION_CLOSED, "floor-minus-one verdict")
    expect_eq(closed.decision, CONTENTION_SHRUNK, "closed case planner decision")
    expect_eq(closed.copy_charged_bytes, 0, "closed copy charges nothing")
    expect_eq(closed.cache_target_bytes, 758654975, "cache keeps the pool remainder")
    var refused = evaluate_npu_contention(
        pool, 311027712, 352321536, 3900702720, 487587840,
        3809280, 3900702720, 271067136, True, True,
    )
    expect_eq(refused.verdict, NPU_CONTENTION_REFUSED, "hand copy + required cache")
    expect_eq(refused.decision, CONTENTION_REFUSE, "refusal is the planner's")
    var degraded = evaluate_npu_contention(
        pool, 311027712, 352321536, 3900702720, 487587840,
        3809280, 3900702720, 271067136, True, False,
    )
    expect_eq(degraded.verdict, NPU_CONTENTION_ADMITTED, "hand copy + optional cache")
    expect_eq(degraded.decision, CONTENTION_NO_CACHE, "optional cache degrades")
    expect_eq(degraded.copy_charged_bytes, 271067136, "hand copy charged as fixed")
    expect_eq(degraded.cache_target_bytes, 0, "optional cache at zero")
    # Planner garbage stays refused through this gate.
    var garbage = 0
    try:
        _ = evaluate_npu_contention(
            5368709120, 311027712, 352321536, 100, 487587840,
            3809280, 3900702720, 271067136, False, True,
        )
    except:
        garbage += 1
    try:
        _ = evaluate_npu_contention(
            5368709120, 311027712, 352321536, 3900702720, 487587840,
            3809280, 3900702720, 0, False, True,
        )
    except:
        garbage += 1
    expect_eq(garbage, 2, "contention garbage refusal count")
    print("PASS: contention closed at floor-1; hand copy refuses (required) / degrades (optional)")


def main() raises:
    test_pass_law_refusals()
    test_copy_pricing()
    test_qwen3_dense_whole_filed()
    test_olmoe_resident_products_filed()
    test_form_rules()
    test_prep_progress_discipline()
    test_prep_render()
    test_graph_cache_hit()
    test_contention_admitted_stated_machine()
    test_contention_closed_and_manual()
    print("ALL PASS: NPU prompt preparation account (10 groups)")
