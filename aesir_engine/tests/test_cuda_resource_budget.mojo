# tests/test_cuda_resource_budget.mojo
# Deterministic CPU-only GPU-2 budget and admission verification.

from core.cuda_resources import (
    CUDAResourceBudget,
    validate_cuda_resource_policy,
)
from core.mimir_well import (
    DeviceCapabilities,
    GPURealmType,
    PhysicalDevice,
)


def make_policy_device(
    realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    api: String = "cuda",
    compatible: Bool = True,
) -> PhysicalDevice:
    return PhysicalDevice(
        realm,
        0,
        Int64(0),
        "injected:cuda:max-id:0",
        "injected-policy-device",
        api,
        DeviceCapabilities(
            compatible,
            13020,
            UInt(8 * 1024 * 1024),
            UInt(16 * 1024 * 1024),
            7,
            5,
            30,
            1024,
        ),
    )


def test_cuda_budget_accounting() raises:
    var budget = CUDAResourceBudget(4096, 2048)
    var first_bytes = budget.reserve_f16(257)
    var second_bytes = budget.reserve_f16(128)
    if first_bytes != 514 or second_bytes != 256:
        raise Error("CUDA budget produced an incorrect F16 byte count")
    if budget.device_reserved_bytes != 770:
        raise Error("CUDA device reservation accounting mismatch")
    if budget.pinned_host_reserved_bytes != 770:
        raise Error("CUDA pinned-host reservation accounting mismatch")
    if budget.remaining_device_bytes() != 3326:
        raise Error("CUDA remaining device budget mismatch")
    if budget.remaining_pinned_host_bytes() != 1278:
        raise Error("CUDA remaining pinned-host budget mismatch")
    print("CUDA resource budget accounting: PASS")


def test_cuda_budget_rejection_is_transactional() raises:
    var budget = CUDAResourceBudget(1024, 256)
    var zero_rejected = False
    try:
        _ = budget.reserve_f16(0)
    except error:
        zero_rejected = "element count must be positive" in String(error)
    if not zero_rejected:
        raise Error("CUDA budget accepted a nonpositive allocation")

    var pinned_rejected = False
    try:
        _ = budget.reserve_f16(129)
    except error:
        pinned_rejected = "pinned-host budget exceeded" in String(error)
    if not pinned_rejected:
        raise Error("CUDA budget accepted an over-budget pinned allocation")
    if (
        budget.device_reserved_bytes != 0
        or budget.pinned_host_reserved_bytes != 0
    ):
        raise Error("CUDA rejected request mutated budget accounting")
    print("CUDA resource budget transactional rejection: PASS")


def test_cuda_budget_overflow_and_rollback() raises:
    var overflow_rejected = False
    try:
        _ = CUDAResourceBudget.f16_size_bytes(1 << 62)
    except error:
        overflow_rejected = "overflow" in String(error)
    if not overflow_rejected:
        raise Error("CUDA budget accepted a wrapped F16 byte count")

    var budget = CUDAResourceBudget(2048, 2048)
    var size_bytes = budget.reserve_f16(300)
    budget.rollback_f16(size_bytes)
    if (
        budget.device_reserved_bytes != 0
        or budget.pinned_host_reserved_bytes != 0
    ):
        raise Error("CUDA budget rollback did not restore accounting")
    var underflow_rejected = False
    try:
        budget.rollback_f16(size_bytes)
    except error:
        underflow_rejected = "rollback exceeds reservation" in String(error)
    if not underflow_rejected:
        raise Error("CUDA budget accepted rollback underflow")
    print("CUDA resource budget overflow and rollback: PASS")


def test_cuda_resource_policy_admission() raises:
    var budget = CUDAResourceBudget(1024 * 1024, 1024 * 1024)
    validate_cuda_resource_policy(make_policy_device(), budget)

    var incompatible_rejected = False
    try:
        validate_cuda_resource_policy(
            make_policy_device(compatible=False), budget
        )
    except error:
        incompatible_rejected = "incompatible" in String(error)
    if not incompatible_rejected:
        raise Error("CUDA resource policy accepted an incompatible device")

    var non_cuda_rejected = False
    try:
        validate_cuda_resource_policy(
            make_policy_device(GPURealmType(GPURealmType.APPLE_METAL), "metal"),
            budget,
        )
    except error:
        non_cuda_rejected = "not CUDA" in String(error)
    if not non_cuda_rejected:
        raise Error("CUDA resource policy accepted a non-CUDA device")

    var oversized_budget = CUDAResourceBudget(32 * 1024 * 1024, 1024 * 1024)
    var oversized_rejected = False
    try:
        validate_cuda_resource_policy(make_policy_device(), oversized_budget)
    except error:
        oversized_rejected = "exceeds total memory" in String(error)
    if not oversized_rejected:
        raise Error("CUDA resource policy accepted an impossible budget")
    print("CUDA resource policy admission: PASS")


def main() raises:
    test_cuda_budget_accounting()
    test_cuda_budget_rejection_is_transactional()
    test_cuda_budget_overflow_and_rollback()
    test_cuda_resource_policy_admission()
