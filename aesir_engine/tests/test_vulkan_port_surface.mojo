"""Vulkan port surface (J-066): the inspected kernel /
infrastructure counts pinned against the machine recount
(docs/janas/j066_inspect.py at this tree), and the
pre-registered verdict rule exercised on every branch --
tonight's true record (all evidence absent) evaluating to
DEFER, BUILD_NOW only on the full conjunction, REFUSE only
on a measured spike that failed faithfulness or bought
nothing. No device, no shader, no speed.
"""
from core.vulkan_port_surface import (
    VERDICT_BUILD_NOW,
    VERDICT_DEFER,
    VERDICT_REFUSE,
    evaluate_vulkan_verdict,
    port_surface,
    verdict_name,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "VulkanPortSurface " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_kernel_family_counts() raises:
    var s = port_surface()
    expect_eq(s.packed_matvec_forms, 2, "packed matvec forms")
    expect_eq(s.llama_kernel_functions, 15, "llama kernel functions")
    expect_eq(s.gemma_kernels, 12, "gemma kernels")
    expect_eq(s.cuda_compute_kernels, 7, "cuda compute kernels")
    expect_eq(s.session_kernels, 1, "session kernels")
    expect_eq(s.fused_matrix_kernels, 3, "fused/matrix kernels")
    print("PASS: kernel family counts match the inspect recount, per file")


def test_totals() raises:
    var s = port_surface()
    expect_eq(s.kernel_families_total, 40, "kernel families total")
    expect_eq(s.session_surfaces, 2, "session surfaces")
    expect_eq(s.infra_items, 8, "infra items I1-I8")
    expect_eq(s.work_items_total, 50, "work items total (40 + 2 + 8)")
    print("PASS: totals -- 40 kernel families, 50 work items in the port")


def test_quant_kinds() raises:
    var s = port_surface()
    expect_eq(s.prefill_quant_kinds, 3, "prefill quant kinds 12/13/14")
    expect_eq(s.dequant_kinds, 2, "dequant kinds Q4_0/Q8_0")
    print("PASS: quant kinds -- 3 prefill (Q4_K/Q5_K/Q6_K) + 2 dequant")


def test_tonight_is_defer() raises:
    # Tonight's true record: no non-NVIDIA hardware in hand,
    # no named consumer, no spike measured anywhere.
    var v = evaluate_vulkan_verdict(False, False, False, False, False)
    expect_eq(v, VERDICT_DEFER, "tonight's verdict")
    print("PASS: tonight's record evaluates to DEFER")


def test_build_now_needs_all_five() raises:
    var v = evaluate_vulkan_verdict(True, True, True, True, True)
    expect_eq(v, VERDICT_BUILD_NOW, "full conjunction")
    print("PASS: BUILD_NOW on the full five-item conjunction only")


def test_each_missing_item_defers() raises:
    var missing = 0
    if evaluate_vulkan_verdict(False, True, True, True, True) == VERDICT_DEFER:
        missing += 1
    if evaluate_vulkan_verdict(True, False, True, True, True) == VERDICT_DEFER:
        missing += 1
    if evaluate_vulkan_verdict(True, True, False, True, True) == VERDICT_DEFER:
        missing += 1
    expect_eq(missing, 3, "single-missing-item defers")
    print("PASS: hardware / consumer / measurement each missing -> DEFER")


def test_unmeasured_flags_earn_nothing() raises:
    # Faithful + competitive merely asserted, never measured:
    # the account treats the spike as absent.
    var v = evaluate_vulkan_verdict(True, True, False, True, True)
    expect_eq(v, VERDICT_DEFER, "unmeasured flags")
    print("PASS: unmeasured faithful/competitive flags earn nothing")


def test_measured_unfaithful_refuses() raises:
    var v = evaluate_vulkan_verdict(True, True, True, False, True)
    expect_eq(v, VERDICT_REFUSE, "measured unfaithful spike")
    var v2 = evaluate_vulkan_verdict(False, False, True, False, False)
    expect_eq(v2, VERDICT_REFUSE, "unfaithful spike refuses anywhere")
    print("PASS: a measured unfaithful spike is REFUSE")


def test_measured_uncompetitive_refuses() raises:
    var v = evaluate_vulkan_verdict(True, True, True, True, False)
    expect_eq(v, VERDICT_REFUSE, "measured faithful but uncompetitive")
    print("PASS: faithful but buys nothing on target hardware -> REFUSE")


def test_verdict_names() raises:
    if verdict_name(VERDICT_DEFER) != String("DEFER"):
        raise Error("VulkanPortSurface: DEFER name")
    if verdict_name(VERDICT_BUILD_NOW) != String("BUILD_NOW"):
        raise Error("VulkanPortSurface: BUILD_NOW name")
    if verdict_name(VERDICT_REFUSE) != String("REFUSE"):
        raise Error("VulkanPortSurface: REFUSE name")
    var refused = 0
    try:
        _ = verdict_name(99)
    except:
        refused += 1
    expect_eq(refused, 1, "unknown verdict code refusal")
    print("PASS: verdict names exact; unknown code refused")


def main() raises:
    test_kernel_family_counts()
    test_totals()
    test_quant_kinds()
    test_tonight_is_defer()
    test_build_now_needs_all_five()
    test_each_missing_item_defers()
    test_unmeasured_flags_earn_nothing()
    test_measured_unfaithful_refuses()
    test_measured_uncompetitive_refuses()
    test_verdict_names()
    print("ALL PASS: vulkan port surface account (10 groups)")
