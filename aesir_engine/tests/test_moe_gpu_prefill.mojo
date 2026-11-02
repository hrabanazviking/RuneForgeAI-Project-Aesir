"""MoE GPU prefill plan (J-058): exact chunk arithmetic under
both forms, the F1 head collapse on the filed OLMoE shapes,
the width-1 HEAD_ONLY row, the cache division's upload
re-payment, the resident-only rejection priced at chunk
width, the CPU-only non-applicability, the expert-bytes
guard, the margin recomputation, refusals.

Filed shapes restated from the record (J-015/J-030/J-031/
J-053, all MEASURED or exact arithmetic on measured dims):
OLMoE-1B-7B Q4_K_M (sha256 8c310f14...f3f, the J-022 model):
16 layers, hidden 2048, top-8 of 64 experts, vocab 50,304,
file context 4,096. Per-token MACs (J-053 section 5):
routed total 1,075,838,976 = resident part (attention
projections 268,435,456 + router 2,097,152 = 270,532,608)
+ routed experts 805,306,368; LM head 103,022,592 per pass.
Resident set 311,027,712 B; KV 131,072 B/token. The streamed
figures passed as cpu_streamed_bytes for the filed prompts
are the J-030 mean-rate projections (prompt_tokens x
32,948,699,136 // 91, the J-053 section 5 SIMULATED cells),
stated by the caller exactly as the host contract requires;
the plan's arithmetic on them is exact. No speed anywhere.
"""
from core.moe_gpu_plan import (
    DIVISION_CPU_ONLY,
    DIVISION_FULL_GPU,
    DIVISION_RESIDENT_GPU,
    DIVISION_RESIDENT_GPU_EXPERT_CACHE,
)
from core.moe_gpu_prefill import (
    MOE_PREFILL_HEAD_ONLY,
    MOE_PREFILL_NOT_APPLICABLE_CPU_ONLY,
    MOE_PREFILL_REJECTED_EXPERT_BYTES,
    MOE_PREFILL_REJECTED_RESIDENT_ONLY,
    MOE_PREFILL_SURVIVES,
    evaluate_moe_gpu_prefill,
    plan_moe_gpu_prefill,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "MoeGpuPrefill " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("MoeGpuPrefill " + what + ": expected true")


def test_chunk_plan_exact() raises:
    # Synthetic: 16 tokens at width 4, 2 layers, top-2,
    # resident 100 + expert 300 MACs/token, head 50, resident
    # weights 1,000 B, KV 40 B/token, FULL division.
    var p = plan_moe_gpu_prefill(
        16, 4, 2, 8, 2, 100, 300, 50, 1000, 40,
        DIVISION_FULL_GPU, 64, 0, 0,
    )
    expect_eq(p.chunks, 4, "chunks")
    expect_eq(p.final_chunk_width, 4, "final width")
    expect_eq(p.cpu_head_passes, 16, "cpu head passes")
    expect_eq(p.gpu_head_passes, 1, "gpu head passes")
    expect_eq(p.cpu_total_macs, 7200, "cpu total macs")
    expect_eq(p.gpu_total_macs, 6450, "gpu total macs")
    expect_eq(p.head_macs_saved, 750, "head macs saved")
    expect_eq(p.cpu_resident_read_bytes, 16000, "cpu resident reads")
    expect_eq(p.gpu_resident_read_bytes, 4000, "gpu resident reads")
    expect_eq(p.resident_read_saving_bp, 7500, "read saving share")
    expect_eq(p.expert_accesses, 64, "accesses conserved")
    expect_eq(p.per_row_attention_calls, 96, "attention calls conserved")
    expect_eq(p.kv_bytes_written, 640, "kv written")
    expect_eq(p.gpu_expert_upload_bytes, 0, "full upload per prompt")
    expect_eq(p.gpu_crossings, 4, "chunk crossings")
    expect_eq(p.width1_gpu_crossings, 16, "width-1 crossings")
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_SURVIVES, "synthetic verdict")
    print("PASS: chunk plan -- both forms exact, verdict survives")


def test_filed_olmoe_full_1024() raises:
    # The headline filed shape: OLMoE, 1,024-token prompt at
    # width 256 under the FULL division (J-031's outcome for
    # this model on the stated card).
    var p = plan_moe_gpu_prefill(
        1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_FULL_GPU, 4096, 370763383684, 0,
    )
    expect_eq(p.chunks, 4, "chunks")
    expect_eq(p.cpu_head_passes, 1024, "cpu head passes")
    expect_eq(p.gpu_head_passes, 1, "gpu head passes")
    expect_eq(p.cpu_total_macs, 1207154245632, "cpu total macs")
    expect_eq(p.gpu_total_macs, 1101762134016, "gpu total macs")
    expect_eq(p.head_macs_saved, 105392111616, "head macs saved")
    expect_eq(p.cpu_resident_read_bytes, 318492377088, "cpu reads")
    expect_eq(p.gpu_resident_read_bytes, 1244110848, "gpu reads")
    expect_eq(p.resident_read_saving_bp, 9960, "read saving 99.60%")
    expect_eq(p.expert_accesses, 131072, "accesses 1024 x 128")
    expect_eq(p.per_row_attention_calls, 49152, "attention calls")
    expect_eq(p.kv_bytes_written, 134217728, "kv written")
    expect_eq(p.gpu_crossings, 4, "crossings = chunks")
    expect_eq(p.width1_gpu_crossings, 1024, "width-1 crossings")
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_SURVIVES, "filed verdict")
    if v.verdict_name() != String("survives_accounting"):
        raise Error("MoeGpuPrefill verdict name: expected survives")
    print("PASS: filed OLMoE FULL 1024/256 -- survives accounting")


def test_f1_head_collapse() raises:
    # J-053 F1, priced at two prompt lengths: the CPU form
    # pays the head per token; the planned form pays it once.
    # The 67-token row is the J-030 leg's own prompt length
    # (its CPU wall is the measured anchor in the slice doc).
    var p256 = plan_moe_gpu_prefill(
        256, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_FULL_GPU, 4096, 92690845921, 0,
    )
    expect_eq(p256.cpu_head_passes, 256, "256 head passes on CPU form")
    expect_eq(p256.head_macs_saved, 26270760960, "256 head saving")
    expect_eq(p256.cpu_total_macs, 301788561408, "256 cpu macs")
    expect_eq(p256.gpu_total_macs, 275517800448, "256 gpu macs")
    var p67 = plan_moe_gpu_prefill(
        67, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_FULL_GPU, 4096, 24258932330, 0,
    )
    expect_eq(p67.chunks, 1, "67 tokens is one chunk at width 256")
    expect_eq(p67.head_macs_saved, 6799491072, "67 head saving")
    expect_eq(p67.cpu_resident_read_bytes, 20838856704, "67 cpu reads")
    expect_eq(p67.gpu_resident_read_bytes, 311027712, "67 gpu reads")
    expect_eq(p67.resident_read_saving_bp, 9850, "67 read saving")
    var v67 = evaluate_moe_gpu_prefill(p67)
    expect_eq(v67.verdict, MOE_PREFILL_SURVIVES, "67 verdict")
    print("PASS: F1 head collapse -- 256 and 67-token prompts priced")


def test_width1_head_only() raises:
    # The width-1 GPU form carries the pure-prefill head
    # discipline (passes = 1, like the CUDA sessions'
    # need_logits discipline) but no chunk economy: resident
    # reads tie the CPU form exactly and crossings equal the
    # width-1 count. The rule names it HEAD_ONLY, keeping the
    # head saving and the chunk saving apart.
    var p = plan_moe_gpu_prefill(
        1024, 1, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_FULL_GPU, 4096, 370763383684, 0,
    )
    expect_eq(p.chunks, 1024, "width-1 chunks")
    expect_eq(p.gpu_head_passes, 1, "width-1 head still once")
    expect_eq(p.gpu_resident_read_bytes, p.cpu_resident_read_bytes, "reads tie")
    expect_eq(p.resident_read_saving_bp, 0, "no read saving")
    expect_eq(p.gpu_crossings, 1024, "width-1 crossings")
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_HEAD_ONLY, "width-1 verdict")
    if v.verdict_name() != String("head_only"):
        raise Error("MoeGpuPrefill verdict name: expected head only")
    print("PASS: width-1 GPU form -- head only, no chunk economy")


def test_cache_division_uploads() raises:
    # The bigger-than-device form at the same filed shape:
    # every streamed byte is re-paid as an upload (J-031),
    # crossings add one batch per (chunk, layer) miss pair;
    # a warm prompt pays neither.
    var p = plan_moe_gpu_prefill(
        1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_RESIDENT_GPU_EXPERT_CACHE,
        4096, 370763383684, 40,
    )
    expect_eq(p.gpu_expert_upload_bytes, 370763383684, "upload == streamed")
    expect_eq(p.gpu_crossings, 44, "crossings = chunks + miss batches")
    expect_eq(p.gpu_hidden_bytes, 0, "cache form crosses no hidden")
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_SURVIVES, "cache verdict on bytes")
    var warm = plan_moe_gpu_prefill(
        1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_RESIDENT_GPU_EXPERT_CACHE,
        4096, 0, 0,
    )
    expect_eq(warm.gpu_expert_upload_bytes, 0, "warm upload zero")
    expect_eq(warm.gpu_crossings, 4, "warm crossings = chunks")
    print("PASS: cache division -- uploads re-pay streamed bytes exactly")


def test_resident_only_rejected() raises:
    # J-031's rejected split, priced at chunk width: hidden
    # bytes are width-invariant (131,072 B/token on this
    # shape); batching only shrinks the crossing count, from
    # 32,768 to 128 at this shape -- still 32x the surviving
    # forms' crossings, with the stack split at every layer.
    var p = plan_moe_gpu_prefill(
        1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_RESIDENT_GPU, 4096, 370763383684, 0,
    )
    expect_eq(p.gpu_hidden_bytes, 134217728, "hidden bytes at 1024 tokens")
    expect_eq(p.gpu_crossings, 128, "crossings 2 x layers x chunks")
    expect_eq(p.width1_gpu_crossings, 32768, "width-1 crossings")
    expect_eq(p.gpu_expert_upload_bytes, 0, "resident form uploads none")
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_REJECTED_RESIDENT_ONLY, "verdict")
    if v.verdict_name() != String("rejected_resident_only"):
        raise Error("MoeGpuPrefill verdict name: expected resident only")
    print("PASS: resident-only split -- priced at width, still rejected")


def test_cpu_only_not_applicable() raises:
    # CPU_ONLY restates the CPU account: no GPU form is
    # specified, the head is still paid per token, and the
    # rule grades nothing.
    var p = plan_moe_gpu_prefill(
        256, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_CPU_ONLY, 4096, 92690845921, 0,
    )
    expect_eq(p.gpu_head_passes, 256, "cpu-only gpu field restates cpu")
    expect_eq(p.gpu_total_macs, p.cpu_total_macs, "cpu-only totals equal")
    expect_eq(p.head_macs_saved, 0, "cpu-only saves nothing")
    expect_eq(p.gpu_crossings, 0, "cpu-only crossings")
    expect_eq(p.width1_gpu_crossings, 0, "cpu-only width-1 crossings")
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_NOT_APPLICABLE_CPU_ONLY, "verdict")
    print("PASS: CPU-only division -- not applicable, account restated")


def test_expert_bytes_guard() raises:
    # The pure rule on a mutated account: a form whose
    # uploads exceeded the CPU form's streamed bytes for the
    # same routing is rejected, whatever its other axes say.
    var p = plan_moe_gpu_prefill(
        1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_FULL_GPU, 4096, 370763383684, 0,
    )
    p.gpu_expert_upload_bytes = 370763383685
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_REJECTED_EXPERT_BYTES, "guard verdict")
    if v.verdict_name() != String("rejected_expert_bytes"):
        raise Error("MoeGpuPrefill verdict name: expected expert bytes")
    print("PASS: expert-bytes guard -- uploads above streamed rejected")


def test_margin_recomputed_from_fields() raises:
    # The rule recomputes the saving from the plan's read
    # fields: erasing the pass economy on an otherwise
    # surviving account demotes it to HEAD_ONLY.
    var p = plan_moe_gpu_prefill(
        1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
        311027712, 131072, DIVISION_FULL_GPU, 4096, 370763383684, 0,
    )
    p.gpu_resident_read_bytes = p.cpu_resident_read_bytes
    var v = evaluate_moe_gpu_prefill(p)
    expect_eq(v.verdict, MOE_PREFILL_HEAD_ONLY, "demoted verdict")
    expect_eq(v.resident_read_saving_bp, 0, "recomputed saving zero")
    print("PASS: margin -- saving recomputed from fields, demotion exact")


def test_refusals() raises:
    var refused = 0
    try:
        _ = plan_moe_gpu_prefill(
            0, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 0, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 256, 0, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 256, 16, 2048, 8, 270532608, 805306368, 0,
            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            8192, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, 9, 4096, 0, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_FULL_GPU, 4096, -1, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 1)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_RESIDENT_GPU_EXPERT_CACHE,
            4096, 1000, 0)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            1024, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_RESIDENT_GPU_EXPERT_CACHE,
            4096, 0, 3)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 256, 16, 2048, 8, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_RESIDENT_GPU_EXPERT_CACHE,
            4096, 1000, 9999)
    except:
        refused += 1
    try:
        _ = plan_moe_gpu_prefill(
            256, 256, 16, 2048, 0, 270532608, 805306368, 103022592,
            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 0)
    except:
        refused += 1
    expect_eq(refused, 12, "refusal count")
    print("PASS: refusals -- shapes, context, division, miss facts")


def main() raises:
    test_chunk_plan_exact()
    test_filed_olmoe_full_1024()
    test_f1_head_collapse()
    test_width1_head_only()
    test_cache_division_uploads()
    test_resident_only_rejected()
    test_cpu_only_not_applicable()
    test_expert_bytes_guard()
    test_margin_recomputed_from_fields()
    test_refusals()
    print("ALL PASS: MoE GPU prefill plan (10 groups)")
