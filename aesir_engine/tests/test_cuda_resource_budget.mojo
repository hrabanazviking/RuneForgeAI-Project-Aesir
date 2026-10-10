# tests/test_cuda_resource_budget.mojo
# Deterministic CPU-only GPU-2 budget and admission verification.

from core.cuda_resources import (
    CUDAAllocationTracker,
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


def test_cuda_allocation_tracker_adversarial() raises:
    var tracker = CUDAAllocationTracker()
    var first_id = tracker.reserve_id()
    var second_id = tracker.reserve_id()
    if first_id != 1 or second_id != 2:
        raise Error("CUDA allocation IDs are not monotonic and unique")

    tracker.validate_registration(2, 48)
    tracker.register(16)
    tracker.register(32)
    if tracker.live_count != 2 or tracker.live_bytes != 48:
        raise Error("CUDA allocation tracker live accounting mismatch")

    var count_before = tracker.live_count
    var bytes_before = tracker.live_bytes
    var count_overflow_rejected = False
    tracker.live_count = 9223372036854775807
    try:
        tracker.validate_registration(1, 2)
    except error:
        count_overflow_rejected = True
    if not count_overflow_rejected or tracker.live_count != 9223372036854775807:
        raise Error("CUDA tracker count overflow mutated the count")
    tracker.live_count = count_before

    var byte_overflow_rejected = False
    tracker.live_bytes = 9223372036854775806
    try:
        tracker.validate_registration(1, 2)
    except error:
        byte_overflow_rejected = True
    if not byte_overflow_rejected or tracker.live_bytes != 9223372036854775806:
        raise Error("CUDA tracker byte overflow mutated live bytes")
    tracker.live_bytes = bytes_before

    var id_before = tracker.next_id
    tracker.next_id = 9223372036854775807
    var id_exhaustion_rejected = False
    try:
        _ = tracker.reserve_id()
    except error:
        id_exhaustion_rejected = True
    if not id_exhaustion_rejected or tracker.next_id != 9223372036854775807:
        raise Error("CUDA tracker ID exhaustion mutated next ID")
    tracker.next_id = id_before

    tracker.owner_destroyed(16, 0)
    tracker.owner_destroyed(32, 0)
    if (
        tracker.live_count != 0
        or tracker.live_bytes != 0
        or tracker.fenced_owner_destroyed_count != 2
        or tracker.fenced_owner_destroyed_bytes != 48
        or tracker.accounting_error
    ):
        raise Error("CUDA tracker fenced owner destruction mismatch")

    tracker.validate_registration(1, 8)
    tracker.register(8)
    tracker.owner_destroyed(8, 1)
    if (
        tracker.unfenced_owner_destroyed_count != 1
        or tracker.fenced_owner_destroyed_count != 2
        or tracker.live_count != 0
        or tracker.accounting_error
    ):
        raise Error("CUDA tracker did not separate unfenced owner destruction")

    var invalid_pending = CUDAAllocationTracker()
    invalid_pending.register(8)
    invalid_pending.owner_destroyed(8, -1)
    if (
        invalid_pending.live_count != 1
        or invalid_pending.live_bytes != 8
        or not invalid_pending.accounting_error
    ):
        raise Error("CUDA tracker accepted a negative pending-work count")

    tracker.owner_destroyed(8, 0)
    if not tracker.accounting_error:
        raise Error("CUDA tracker failed to detect owner underflow")
    print("CUDA allocation tracker adversarial contracts: PASS")


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
    test_cuda_allocation_tracker_adversarial()
    test_cuda_resource_policy_admission()
