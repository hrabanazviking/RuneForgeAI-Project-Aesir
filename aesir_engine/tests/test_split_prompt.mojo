"""Split prompt plan (J-056): even and ragged block halves,
ragged final chunks, the width-1 shape, join accounting on
filed shapes, the pre-registered accounted survival rule
(dominated where both parents exist, not graded where the
whole-GPU parent is absent), refusals.

Filed shapes restated from the record: Llama 3 8B -- 32 layers,
hidden 4,096, projection MACs 6,979,321,856 per token, KV
131,072 B/token (J-053 section 5); its attention MACs at 256
tokens 8,623,489,024 (J-053 section 5). Gemma 4 E2B -- 35
layers, projection MACs 1,238,630,400 per token (J-053 section
5, dense part). Stheno L3-8B Q4_K_M tensor-byte total
4,912,898,048 B (J-021 section 3), split at its floor half in
the parent-absent group (the per-half directory bytes are the
caller's to state; the floor half of a filed total is the
stated synthetic split of it, never a measured directory
figure). No speed anywhere.
"""
from core.split_prompt import (
    SPLIT_PARENT_ABSENT,
    SPLIT_REJECTED_DOMINATED,
    SPLIT_SURVIVES,
    evaluate_split_accounting,
    plan_split_prompt,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SplitPrompt " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SplitPrompt " + what + ": expected true")


def test_even_halves_plan() raises:
    # 32 layers split 16/16; 1,024 tokens at chunk width 256.
    var p = plan_split_prompt(
        1024, 256, 32, 4096, 4, 1000, 0, 2000000, 2000000, True
    )
    expect_eq(p.gpu_layers, 16, "gpu layers even")
    expect_eq(p.cpu_layers, 16, "cpu layers even")
    expect_eq(p.chunks, 4, "chunks at 1024/256")
    expect_eq(p.final_chunk_width, 256, "final chunk full")
    expect_eq(p.total_macs, 1024000, "total macs")
    expect_eq(p.gpu_macs, 512000, "gpu macs half")
    expect_eq(p.cpu_macs, 512000, "cpu macs half")
    expect_eq(p.bottleneck_macs, 512000, "bottleneck is the half")
    expect_eq(p.gpu_weight_read_bytes, 8000000, "gpu weight reads")
    expect_eq(p.cpu_weight_read_bytes, 8000000, "cpu weight reads")
    expect_eq(p.split_weight_read_bytes, 16000000, "split weight reads")
    expect_eq(p.parent_weight_read_bytes, 16000000, "parent weight reads")
    print("PASS: even halves -- 16/16 blocks, MACs and weight reads conserve")


def test_join_accounting() raises:
    # The join: hidden state crosses once per chunk at the one
    # boundary; parents cross nothing.
    var p = plan_split_prompt(
        1024, 256, 32, 4096, 4, 1000, 0, 2000000, 2000000, True
    )
    expect_eq(p.boundary_transfers, 4, "one transfer per chunk")
    expect_eq(p.join_bytes_per_full_chunk, 4194304, "join bytes per chunk")
    expect_eq(p.join_bytes, 16777216, "join bytes over the prompt")
    expect_eq(p.gpu_side_syncs, 4, "gpu side syncs")
    expect_eq(p.cpu_side_syncs, 4, "cpu side syncs")
    expect_eq(p.split_crossings, 12, "split crossings 3 per chunk")
    expect_eq(p.parent_gpu_crossings, 4, "gpu parent crossings")
    expect_eq(p.parent_cpu_crossings, 0, "cpu parent crossings")
    print("PASS: join accounting -- transfers, bytes and crossings exact")


def test_odd_layers_ragged_halves() raises:
    # Gemma 4 E2B shape: 35 layers split 18/17 (GPU takes the
    # extra block); per-side MACs conserve the total exactly,
    # floor to the GPU side, remainder to the CPU side.
    var p = plan_split_prompt(
        1024, 256, 35, 2048, 4, 1238630400, 0, 1000000, 1000000, True
    )
    expect_eq(p.gpu_layers, 18, "gpu layers odd")
    expect_eq(p.cpu_layers, 17, "cpu layers odd")
    expect_eq(p.total_macs, 1268357529600, "gemma proj total")
    expect_eq(p.gpu_macs, 652298158080, "gemma gpu macs floor share")
    expect_eq(p.cpu_macs, 616059371520, "gemma cpu macs remainder")
    expect_eq(p.gpu_macs + p.cpu_macs, p.total_macs, "mac conservation")
    expect_eq(p.bottleneck_macs, 652298158080, "bottleneck is gpu side")
    print("PASS: ragged halves -- 35 blocks split 18/17, MACs conserve")


def test_ragged_final_chunk() raises:
    # 67 tokens at width 4: 17 chunks, final width 3; the join
    # is priced on tokens, not on padded chunks.
    var p = plan_split_prompt(67, 4, 28, 2048, 4, 1000, 0, 500, 500, True)
    expect_eq(p.chunks, 17, "ceil chunks at 67/4")
    expect_eq(p.final_chunk_width, 3, "final chunk width")
    expect_eq(p.join_bytes, 548864, "join bytes on real tokens only")
    expect_eq(p.boundary_transfers, 17, "transfers follow chunks")
    expect_eq(p.split_weight_read_bytes, 17000, "weight reads follow chunks")
    print("PASS: ragged final chunk -- 67/4, join priced on real tokens")


def test_width1_shape() raises:
    # At width 1 the split pays a boundary transfer per token:
    # crossings 3x the whole-GPU width-1 parent's per-token sync.
    var p = plan_split_prompt(256, 1, 32, 4096, 4, 1000, 0, 500, 500, True)
    expect_eq(p.chunks, 256, "width1 chunks are tokens")
    expect_eq(p.split_crossings, 768, "width1 split crossings")
    expect_eq(p.parent_gpu_crossings, 256, "width1 gpu parent crossings")
    expect_eq(p.join_bytes, 4194304, "width1 join bytes")
    print("PASS: width-1 shape -- one transfer per token, crossings 3x parent")


def test_filed_llama_accounting() raises:
    # Llama 3 8B on J-053's filed figures at 256 tokens: total
    # MACs are the filed projection total plus the filed
    # attention total; the halves are exactly equal at 16/16.
    var p = plan_split_prompt(
        256, 256, 32, 4096, 4, 6979321856, 8623489024, 2000000, 2000000, True
    )
    expect_eq(p.total_macs, 1795329884160, "llama total macs at 256")
    expect_eq(p.gpu_macs, 897664942080, "llama gpu half")
    expect_eq(p.cpu_macs, 897664942080, "llama cpu half")
    expect_eq(p.chunks, 1, "one chunk at 256/256")
    expect_eq(p.join_bytes, 4194304, "llama join bytes at 256")
    print("PASS: filed Llama 3 8B accounting -- J-053 totals split exactly")


def test_survival_rule_rejects_where_parents_exist() raises:
    # The pre-registered rule: where both parents exist, the
    # split ties both parents on MACs and weight reads and is
    # strictly worse on crossings and join bytes -- dominated
    # by BOTH, kept nowhere. Checked at block width and width 1.
    var p = plan_split_prompt(
        1024, 256, 32, 4096, 4, 1000, 0, 2000000, 2000000, True
    )
    var v = evaluate_split_accounting(p)
    expect_eq(v.verdict, SPLIT_REJECTED_DOMINATED, "block verdict rejected")
    expect_true(v.dominated_by_gpu, "dominated by gpu parent")
    expect_true(v.dominated_by_cpu, "dominated by cpu parent")
    expect_true(not v.beats_gpu_parent, "beats no gpu parent")
    expect_true(not v.beats_cpu_parent, "beats no cpu parent")
    if v.verdict_name() != String("accounted_and_rejected_dominated"):
        raise Error("SplitPrompt verdict name: expected accounted rejection")
    var w = plan_split_prompt(256, 1, 32, 4096, 4, 1000, 0, 500, 500, True)
    var vw = evaluate_split_accounting(w)
    expect_eq(vw.verdict, SPLIT_REJECTED_DOMINATED, "width1 verdict rejected")
    expect_true(vw.verdict != SPLIT_SURVIVES, "no width survives")
    print("PASS: survival rule -- dominated by both parents at both widths")


def test_survival_rule_not_graded_when_parent_absent() raises:
    # Stheno at a no-fit context (J-055): the whole-GPU parent
    # does not exist, so the rule grades nothing -- the shape
    # is the residency fallback (J-021 spill), not a win and
    # not a rejection.
    var p = plan_split_prompt(
        1024, 256, 32, 4096, 4, 1000, 0, 2456449024, 2456449024, False
    )
    var v = evaluate_split_accounting(p)
    expect_eq(v.verdict, SPLIT_PARENT_ABSENT, "parent absent verdict")
    expect_true(not v.dominated_by_gpu, "no gpu domination graded")
    expect_true(not v.dominated_by_cpu, "no cpu domination graded")
    if v.verdict_name() != String("parent_absent_spill_fallback_shape"):
        raise Error("SplitPrompt verdict name: expected parent absent")
    print("PASS: survival rule -- not graded where the GPU parent is absent")


def test_refusals() raises:
    var refused = 0
    try:
        _ = plan_split_prompt(0, 256, 32, 4096, 4, 1000, 0, 500, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 0, 32, 4096, 4, 1000, 0, 500, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 256, 1, 4096, 4, 1000, 0, 500, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 256, 32, 0, 4, 1000, 0, 500, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 256, 32, 4096, 0, 1000, 0, 500, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 256, 32, 4096, 4, 0, 0, 500, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 256, 32, 4096, 4, 1000, -1, 500, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 256, 32, 4096, 4, 1000, 0, 0, 500, True)
    except:
        refused += 1
    try:
        _ = plan_split_prompt(256, 256, 32, 4096, 4, 1000, 0, 500, 0, True)
    except:
        refused += 1
    expect_eq(refused, 9, "refusal count")
    print("PASS: refusals -- tokens, width, one-block, hidden, MACs, empty side")


def main() raises:
    test_even_halves_plan()
    test_join_accounting()
    test_odd_layers_ragged_halves()
    test_ragged_final_chunk()
    test_width1_shape()
    test_filed_llama_accounting()
    test_survival_rule_rejects_where_parents_exist()
    test_survival_rule_not_graded_when_parent_absent()
    test_refusals()
    print("ALL PASS: split prompt plan (9 groups)")
