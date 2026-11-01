"""GPU block prefill plan (J-054): chunk plans at the J-053
baseline lengths, width-1 and tile-4 equivalences against the
proven shapes, weight-traffic pass-count effect, the F2 attention
count, activation/scores sizing, staging pricing cross-checked
against J-031's filed chunk counts, admission codes, refusals.

Shapes restated from the record: Llama 3 8B DenseBufferLayout
stride 51,200 f32 elements (hidden 4096, q 4096, kv 1024, ffn
14336, per core/dense_buffers.mojo's layout arithmetic), 32
layers, 32 heads, context 8192; Llama 3.2 3B 28 layers for the
tile rows; J-031's OLMoE resident 311,027,712 B (5 staging chunks)
and expert body 3,900,702,720 B (59 chunks). Weight bytes in the
plan rows are a stated synthetic 1,000,000 B so the pass-count
arithmetic is checked without inventing a file size. No speed.
"""
from core.gpu_block_prefill import (
    ADMISSION_TILE4_PROVEN,
    ADMISSION_UNBUILT,
    ADMISSION_WIDTH1_PROVEN,
    gpu_block_upload_chunks,
    plan_gpu_block_prefill,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "GpuBlockPrefill " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_baseline_chunk_plans() raises:
    var p256 = plan_gpu_block_prefill(256, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(p256.chunks, 1, "256 chunks")
    expect_eq(p256.pure_prefill_chunks, 0, "256 pure")
    expect_eq(p256.final_chunk_width, 256, "256 final width")
    expect_eq(p256.lm_head_passes, 1, "256 head passes")
    expect_eq(p256.sync_crossings, 1, "256 syncs")
    var p1024 = plan_gpu_block_prefill(1024, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(p1024.chunks, 4, "1024 chunks")
    expect_eq(p1024.pure_prefill_chunks, 3, "1024 pure")
    var p4096 = plan_gpu_block_prefill(4096, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(p4096.chunks, 16, "4096 chunks")
    var p8192 = plan_gpu_block_prefill(8192, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(p8192.chunks, 32, "8192 chunks")
    expect_eq(p8192.sync_crossings, 32, "8192 syncs")
    print("PASS: baseline chunk plans at 256/1024/4096/8192, width 256")


def test_width1_equivalence() raises:
    # Width 1 IS the proven decode shape: one chunk per token, one
    # sync per token, weight traffic identical to the width-1 line.
    var p = plan_gpu_block_prefill(256, 1, 32, 1000000, 51200, 32, 8192)
    expect_eq(p.chunks, 256, "width1 chunks")
    expect_eq(p.sync_crossings, 256, "width1 syncs")
    expect_eq(p.weight_read_bytes, 256000000, "width1 weight read")
    expect_eq(p.weight_read_bytes, p.width1_weight_read_bytes, "width1 identity")
    expect_eq(p.admission, ADMISSION_WIDTH1_PROVEN, "width1 admission")
    print("PASS: width-1 plan equals the proven decode shape exactly")


def test_tile4_shape() raises:
    # The block plan at width 4 chunks ceil(N/4): 256 -> 64, 67 ->
    # 17 with final width 3. (The PROVEN tile loop files 67 passes
    # at 256 and 19 at 67 because it reserves the last tokens to
    # width-1 singles; the delta is the final-chunk head discipline
    # and is recorded in the slice doc, not hidden here.)
    var p = plan_gpu_block_prefill(256, 4, 28, 1000000, 38400, 32, 8192)
    expect_eq(p.chunks, 64, "tile-width chunks at 256")
    expect_eq(p.admission, ADMISSION_TILE4_PROVEN, "tile admission")
    var p67 = plan_gpu_block_prefill(67, 4, 28, 1000000, 38400, 32, 8192)
    expect_eq(p67.chunks, 17, "tile-width chunks at 67")
    expect_eq(p67.final_chunk_width, 3, "tile-width final at 67")
    print("PASS: width-4 block shape (ceil chunks, final chunk carries head)")


def test_weight_traffic_effect() raises:
    # The pass-count effect, exact: at width 256 a 1024-token
    # prompt re-reads the stated weights 4 times, not 1024.
    var p = plan_gpu_block_prefill(1024, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(p.weight_read_bytes, 4000000, "block weight read")
    expect_eq(p.width1_weight_read_bytes, 1024000000, "width1 weight read")
    expect_eq(
        p.width1_weight_read_bytes // p.weight_read_bytes, 256, "traffic ratio"
    )
    print("PASS: weight traffic scales with chunks, not tokens (256x at width 256)")


def test_f2_attention_count() raises:
    # F2 priced: projections batch (224 GEMM calls for one 256-wide
    # chunk x 32 layers) while attention stays per-row (24,576
    # kernel calls for the same prompt) on every surface today.
    var p = plan_gpu_block_prefill(256, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(p.batched_gemm_calls, 224, "gemm calls one chunk")
    expect_eq(p.per_row_attention_calls, 24576, "attention calls at 256")
    var big = plan_gpu_block_prefill(8192, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(big.batched_gemm_calls, 7168, "gemm calls at 8192")
    expect_eq(big.per_row_attention_calls, 786432, "attention calls at 8192")
    print("PASS: F2 -- attention kernel calls dominate GEMM calls at every length")


def test_scratch_and_scores_sizing() raises:
    var p = plan_gpu_block_prefill(256, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(p.activation_scratch_bytes, 52428800, "activation scratch")
    # A truly batched attention at width 256, 32 heads, context
    # 8192 needs 256 MiB of f32 scores -- the sizing fact that
    # makes batched attention a build, not a flag.
    expect_eq(p.batched_attention_scores_bytes, 268435456, "batched scores")
    print("PASS: chunk activation scratch + batched-attention scores sizing")


def test_staging_chunks_crosscheck() raises:
    expect_eq(gpu_block_upload_chunks(0), 0, "zero upload")
    expect_eq(gpu_block_upload_chunks(67108864), 1, "one staging chunk")
    expect_eq(gpu_block_upload_chunks(67108865), 2, "two staging chunks")
    # J-031's filed counts, reproduced: OLMoE resident -> 5, body -> 59.
    expect_eq(gpu_block_upload_chunks(311027712), 5, "J-031 resident chunks")
    expect_eq(gpu_block_upload_chunks(3900702720), 59, "J-031 body chunks")
    print("PASS: staging chunks reproduce J-031's filed 5 / 59")


def test_admission_codes() raises:
    var w8 = plan_gpu_block_prefill(256, 8, 32, 1000000, 51200, 32, 8192)
    expect_eq(w8.admission, ADMISSION_UNBUILT, "width 8 unbuilt")
    var w256 = plan_gpu_block_prefill(256, 256, 32, 1000000, 51200, 32, 8192)
    expect_eq(w256.admission, ADMISSION_UNBUILT, "width 256 unbuilt")
    print("PASS: admission stated in-plan -- widths above 4 are UNBUILT")


def test_refusals() raises:
    var refused = 0
    try:
        _ = plan_gpu_block_prefill(0, 256, 32, 1000000, 51200, 32, 8192)
    except:
        refused += 1
    try:
        _ = plan_gpu_block_prefill(256, 0, 32, 1000000, 51200, 32, 8192)
    except:
        refused += 1
    try:
        _ = plan_gpu_block_prefill(8193, 256, 32, 1000000, 51200, 32, 8192)
    except:
        refused += 1
    try:
        _ = plan_gpu_block_prefill(256, 256, 0, 1000000, 51200, 32, 8192)
    except:
        refused += 1
    try:
        _ = gpu_block_upload_chunks(-1)
    except:
        refused += 1
    expect_eq(refused, 5, "refusal count")
    print("PASS: refusals -- tokens, width, over-context, layers, upload bytes")


def main() raises:
    test_baseline_chunk_plans()
    test_width1_equivalence()
    test_tile4_shape()
    test_weight_traffic_effect()
    test_f2_attention_count()
    test_scratch_and_scores_sizing()
    test_staging_chunks_crosscheck()
    test_admission_codes()
    test_refusals()
    print("ALL PASS: gpu block prefill plan (9 groups)")
