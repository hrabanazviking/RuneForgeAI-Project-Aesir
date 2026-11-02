"""Draft-check placement (J-081): every combination priced
in bytes per direction, synchronised crossings, contended
bytes, and the J-080 expert-stream account; combinations
whose pieces are unbuilt refused BY NAME in the rule's
order; the kept combination follows the pre-registered
rule (accelerator-first for the check pass, then fewest
synchronised crossings, then fewest crossing bytes, then
fewest contended bytes). Fixtures are stated shapes, never
measurements: no speed is proved or claimed anywhere.
"""
from core.speculative_placement import (
    DC_DEV_CPU,
    DC_DEV_GPU,
    DC_DEV_IGPU,
    DC_MISSING_CONVERSATION_DEVICE,
    DC_MISSING_DEVICE_ABSENT,
    DC_MISSING_IGPU_BACKEND,
    DC_MISSING_MOE_GPU_ADMISSION,
    DC_MISSING_VERIFY_WIDTH,
    DC_VERDICT_PRICED,
    DC_VERDICT_REFUSED_UNBUILT,
    DraftCheckShape,
    choose_draft_check_placement,
    dc_combo_code,
    dc_missing_name,
    plan_draft_check_combo,
)
from core.speculative_verify import (
    PROPOSER_ASSISTANT_MODEL,
    PROPOSER_CONVERSATION,
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "SpeculativePlacement "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("SpeculativePlacement " + what + ": expected true")


def dense_shape(kind: Int, k: Int) raises -> DraftCheckShape:
    return DraftCheckShape(
        kind, k, False, False, True, True, False,
        4096, 2048, 28, 12,
        3_000_000_000, 500_000_000, 0, 0, 0, 0,
    )


def test_both_cpu_zero_account() raises:
    var shape = dense_shape(PROPOSER_CROSS_MODEL, 3)
    var p = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_CPU)
    expect_eq(p.verdict, DC_VERDICT_PRICED, "both-cpu priced")
    expect_eq(p.h2d_bytes, 0, "both-cpu h2d")
    expect_eq(p.d2h_bytes, 0, "both-cpu d2h")
    expect_eq(p.sync_crossings, 0, "both-cpu syncs")
    expect_eq(p.contended_bytes, 0, "both-cpu contended")
    print("PASS: both-on-CPU -- priced, zero crossings, zero syncs")


def test_cpu_draft_gpu_check_exact() raises:
    var shape = dense_shape(PROPOSER_CROSS_MODEL, 3)
    var p = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(p.verdict, DC_VERDICT_PRICED, "cpu/gpu priced at w4 tile")
    expect_eq(p.h2d_bytes, 12, "draft ids h2d = k * 4")
    expect_eq(p.d2h_bytes, 16, "target list d2h = (k+1) * 4")
    expect_eq(p.sync_crossings, 2, "transfer batch + check pass")
    expect_true(p.keep_eligible, "gpu check keep-eligible")
    print("PASS: CPU draft + GPU check -- h2d 12, d2h 16, syncs 2")


def test_both_gpu_and_reverse_exact() raises:
    var shape = dense_shape(PROPOSER_CROSS_MODEL, 3)
    var both = plan_draft_check_combo(shape, DC_DEV_GPU, DC_DEV_GPU)
    expect_eq(both.h2d_bytes, 0, "both-gpu h2d")
    expect_eq(both.d2h_bytes, 16, "both-gpu target list to host")
    expect_eq(both.sync_crossings, 4, "k draft syncs + 1 check sync")
    var rev = plan_draft_check_combo(shape, DC_DEV_GPU, DC_DEV_CPU)
    expect_eq(rev.d2h_bytes, 12, "reverse draft ids d2h")
    expect_eq(rev.sync_crossings, 4, "k draft syncs + 1 transfer")
    expect_eq(rev.verdict, DC_VERDICT_PRICED, "reverse priced")
    print("PASS: both-on-GPU syncs 4 / d2h 16; reverse syncs 4 / d2h 12")


def test_kept_dense_cross_model() raises:
    var shape = dense_shape(PROPOSER_CROSS_MODEL, 3)
    var kept = choose_draft_check_placement(shape)
    expect_eq(kept.draft_device, DC_DEV_CPU, "kept draft is cpu")
    expect_eq(kept.check_device, DC_DEV_GPU, "kept check is gpu")
    expect_eq(kept.sync_crossings, 2, "kept syncs fewest among gpu-check")
    print("PASS: kept (dense cross-model, w4 tile) -- CPU draft + GPU check")


def test_moe_gpu_check_refused_and_both_cpu_kept() raises:
    var shape = DraftCheckShape(
        PROPOSER_CROSS_MODEL, 4, True, False, True, True, False,
        4096, 2048, 16, 12,
        3_900_000_000, 500_000_000, 1_000_000, 2, 0, 0,
    )
    var split = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(split.verdict, DC_VERDICT_REFUSED_UNBUILT, "moe gpu check refused")
    expect_eq(split.missing, DC_MISSING_MOE_GPU_ADMISSION, "moe admission named")
    expect_eq(split.expert_h2d_bytes, 1_000_000, "expert bytes re-paid as upload")
    expect_eq(split.h2d_bytes, 1_000_016, "expert + draft ids h2d")
    expect_eq(split.d2h_bytes, 20, "target list d2h at w5")
    expect_eq(split.sync_crossings, 4, "transfer + check + 2 miss layers")
    var cpu = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_CPU)
    expect_eq(cpu.host_streamed_bytes, 1_000_000, "cpu check streams on host")
    expect_eq(cpu.expert_h2d_bytes, 0, "cpu check re-pays nothing")
    var kept = choose_draft_check_placement(shape)
    expect_eq(dc_combo_code(kept.draft_device, kept.check_device), 0, "moe kept is both-cpu")
    print("PASS: MoE GPU check REFUSED (J-031 admission); expert re-pay priced; MoE kept = both-on-CPU")


def test_verify_width_refusals() raises:
    var wide = dense_shape(PROPOSER_CROSS_MODEL, 4)
    var p = plan_draft_check_combo(wide, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(p.verdict, DC_VERDICT_REFUSED_UNBUILT, "w5 gpu check refused")
    expect_eq(p.missing, DC_MISSING_VERIFY_WIDTH, "width named")
    var kept = choose_draft_check_placement(wide)
    expect_eq(kept.check_device, DC_DEV_CPU, "w5 kept falls to cpu check")
    var notile = DraftCheckShape(
        PROPOSER_CROSS_MODEL, 3, False, False, False, True, False,
        4096, 2048, 28, 12, 3_000_000_000, 500_000_000, 0, 0, 0, 0,
    )
    var q = plan_draft_check_combo(notile, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(q.missing, DC_MISSING_VERIFY_WIDTH, "w4 off the tile profile refused")
    print("PASS: GPU verify width -- w5 refused, w4 off-tile refused (J-054), kept falls to CPU")


def test_conversation_draft_refused_off_cpu() raises:
    var shape = dense_shape(PROPOSER_CONVERSATION, 3)
    var gpu_draft = plan_draft_check_combo(shape, DC_DEV_GPU, DC_DEV_GPU)
    expect_eq(gpu_draft.missing, DC_MISSING_CONVERSATION_DEVICE, "conversation gpu draft named")
    var host = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(host.verdict, DC_VERDICT_PRICED, "conversation draft on host priced")
    var kept = choose_draft_check_placement(shape)
    expect_eq(kept.draft_device, DC_DEV_CPU, "conversation kept draft host")
    expect_eq(kept.check_device, DC_DEV_GPU, "conversation kept check gpu")
    print("PASS: conversation proposer -- off-host draft refused by name; host draft + GPU check kept")


def test_igpu_priced_zero_copy_refused_backend() raises:
    var shape = DraftCheckShape(
        PROPOSER_CROSS_MODEL, 3, False, False, True, False, True,
        4096, 2048, 28, 12, 3_000_000_000, 500_000_000, 0, 0, 0, 0,
    )
    var p = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_IGPU)
    expect_eq(p.verdict, DC_VERDICT_REFUSED_UNBUILT, "igpu check refused")
    expect_eq(p.missing, DC_MISSING_IGPU_BACKEND, "igpu backend named")
    expect_eq(p.h2d_bytes, 0, "igpu no copy h2d")
    expect_eq(p.d2h_bytes, 0, "igpu no copy d2h")
    expect_eq(p.sync_crossings, 0, "igpu no copy crossings")
    expect_eq(p.contended_bytes, 3_000_000_012, "target weights + token ids contended")
    var both = plan_draft_check_combo(shape, DC_DEV_IGPU, DC_DEV_IGPU)
    expect_eq(both.contended_bytes, 4_500_000_000, "draft k x weights + target weights contended")
    var kept = choose_draft_check_placement(shape)
    expect_eq(dc_combo_code(kept.draft_device, kept.check_device), 0, "igpu-only set kept is both-cpu")
    print("PASS: iGPU -- 0 copy bytes, contended priced, REFUSED (no backend, J-066); kept = both-on-CPU")


def test_device_absent_refused_first() raises:
    var shape = dense_shape(PROPOSER_CROSS_MODEL, 3)
    var p = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(p.verdict, DC_VERDICT_PRICED, "gpu present in this shape")
    var no_gpu = DraftCheckShape(
        PROPOSER_CROSS_MODEL, 3, False, False, True, False, False,
        4096, 2048, 28, 12, 3_000_000_000, 500_000_000, 0, 0, 0, 0,
    )
    var q = plan_draft_check_combo(no_gpu, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(q.missing, DC_MISSING_DEVICE_ABSENT, "absent gpu named first")
    expect_true(
        dc_missing_name(DC_MISSING_DEVICE_ABSENT)
        == String("device absent from the stated device set"),
        "absent name exact",
    )
    var kept = choose_draft_check_placement(no_gpu)
    expect_eq(kept.check_device, DC_DEV_CPU, "cpu-only set kept cpu check")
    print("PASS: device absent -- refused first by name; CPU-only set keeps both-on-CPU")


def test_coupled_proposers_split_tax_and_mtp_kept_both_gpu() raises:
    var shape = dense_shape(PROPOSER_MTP_HEAD, 3)
    var split = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(split.sync_crossings, 5, "coupled split: transfer + check + k state crossings")
    expect_eq(split.d2h_bytes, 12_304, "k x hidden state + target list d2h")
    expect_eq(split.h2d_bytes, 12, "draft ids h2d")
    var kept = choose_draft_check_placement(shape)
    expect_eq(kept.draft_device, DC_DEV_GPU, "mtp kept draft with target")
    expect_eq(kept.check_device, DC_DEV_GPU, "mtp kept check gpu")
    expect_eq(kept.sync_crossings, 4, "mtp both-gpu syncs")
    var assistant = dense_shape(PROPOSER_ASSISTANT_MODEL, 3)
    var a = plan_draft_check_combo(assistant, DC_DEV_CPU, DC_DEV_GPU)
    expect_eq(a.d2h_bytes, 12_304, "assistant reads target KV: same split tax")
    print("PASS: coupled proposers -- split crosses hidden per draft step; MTP kept = both-on-GPU")


def test_draft_moe_on_gpu_refused() raises:
    var shape = DraftCheckShape(
        PROPOSER_CROSS_MODEL, 3, False, True, True, True, False,
        4096, 2048, 28, 16, 3_000_000_000, 900_000_000, 0, 0, 5_000, 1,
    )
    var p = plan_draft_check_combo(shape, DC_DEV_GPU, DC_DEV_CPU)
    expect_eq(p.missing, DC_MISSING_MOE_GPU_ADMISSION, "draft moe gpu named")
    expect_eq(p.expert_h2d_bytes, 5_000, "draft expert re-pay priced")
    var cpu = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_CPU)
    expect_eq(cpu.host_streamed_bytes, 5_000, "draft moe streams on host at cpu")
    print("PASS: MoE draft on GPU REFUSED (J-031 admission); its re-pay priced as a plan")


def test_enumeration_counts_and_determinism() raises:
    var shape = dense_shape(PROPOSER_CROSS_MODEL, 3)
    var priced = 0
    var refused = 0
    for draft in range(3):
        for check in range(3):
            var p = plan_draft_check_combo(shape, draft, check)
            if p.verdict == DC_VERDICT_PRICED:
                priced += 1
            else:
                refused += 1
    expect_eq(priced, 4, "dense gpu set: 4 priced combinations")
    expect_eq(refused, 5, "dense gpu set: 5 refused (all igpu, device absent)")
    var a = choose_draft_check_placement(shape)
    var b = choose_draft_check_placement(shape)
    expect_eq(
        dc_combo_code(a.draft_device, a.check_device),
        dc_combo_code(b.draft_device, b.check_device),
        "choose is deterministic",
    )
    print("PASS: enumeration -- 4 priced / 5 refused on the dense GPU set; choose deterministic")


def test_input_refusals() raises:
    var refused = 0
    try:
        _ = plan_draft_check_combo(dense_shape(PROPOSER_CROSS_MODEL, 0), DC_DEV_CPU, DC_DEV_CPU)
    except:
        refused += 1
    try:
        _ = plan_draft_check_combo(dense_shape(PROPOSER_CONVERSATION, 9), DC_DEV_CPU, DC_DEV_CPU)
    except:
        refused += 1
    try:
        var bad = DraftCheckShape(
            PROPOSER_CROSS_MODEL, 3, True, False, True, True, False,
            4096, 2048, 16, 12, 3_000_000_000, 500_000_000, 100, 17, 0, 0,
        )
        _ = plan_draft_check_combo(bad, DC_DEV_CPU, DC_DEV_CPU)
    except:
        refused += 1
    try:
        var bad2 = DraftCheckShape(
            PROPOSER_CROSS_MODEL, 3, False, False, True, True, False,
            4096, 2048, 28, 12, 3_000_000_000, 500_000_000, -1, 0, 0, 0,
        )
        _ = plan_draft_check_combo(bad2, DC_DEV_CPU, DC_DEV_CPU)
    except:
        refused += 1
    expect_eq(refused, 4, "k=0 / over-cap / miss>layers / negative streamed refused")
    print("PASS: input refusals -- k bounds, proposer cap, miss layers, negative bytes (4/4)")


def main() raises:
    test_both_cpu_zero_account()
    test_cpu_draft_gpu_check_exact()
    test_both_gpu_and_reverse_exact()
    test_kept_dense_cross_model()
    test_moe_gpu_check_refused_and_both_cpu_kept()
    test_verify_width_refusals()
    test_conversation_draft_refused_off_cpu()
    test_igpu_priced_zero_copy_refused_backend()
    test_device_absent_refused_first()
    test_coupled_proposers_split_tax_and_mtp_kept_both_gpu()
    test_draft_moe_on_gpu_refused()
    test_enumeration_counts_and_determinism()
    test_input_refusals()
    print("ALL PASS: speculative placement (13 groups)")
