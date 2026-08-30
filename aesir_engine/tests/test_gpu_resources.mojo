# tests/test_gpu_resources.mojo
# GPU-2 opt-in physical MAX CUDA resource ownership proof.

from core.cuda_gate import CUDAGate
from core.cuda_resources import CUDADeviceResources, CUDAF16Allocation
from core.mimir_well import (
    DeviceTopology,
    GPURealmType,
    PhysicalDevice,
    Scalar,
    f16,
)
from std.sys import argv


comptime DEVICE_BUDGET_BYTES = 1024 * 1024
comptime PINNED_HOST_BUDGET_BYTES = 1024 * 1024
comptime FIRST_ELEMENT_COUNT = 257
comptime SECOND_ELEMENT_COUNT = 1025
comptime TRANSFER_ROUNDS = 3


def expected_value(
    index: Int, transfer_round: Int, allocation_tag: Int, session_round: Int
) -> Scalar[f16]:
    """Return a binary-exact F16 value independent of device output."""
    return (
        Scalar[f16]((index % 257) - 128) * 0.25
        + Scalar[f16](transfer_round)
        + Scalar[f16](allocation_tag * 4)
        + Scalar[f16](session_round * 16)
    )


def exercise_allocation(
    mut allocation: CUDAF16Allocation,
    allocation_tag: Int,
    session_round: Int,
    inject_mismatch: Bool,
) raises:
    """Prove repeated synchronized H2D/D2H identity for one owned resource."""
    for transfer_round in range(TRANSFER_ROUNDS):
        for index in range(allocation.element_count):
            allocation.set_host(
                index,
                expected_value(
                    index, transfer_round, allocation_tag, session_round
                ),
            )
        allocation.upload_and_synchronize()

        for index in range(allocation.element_count):
            allocation.set_host(index, -1.0)
        allocation.download_and_synchronize()

        for index in range(allocation.element_count):
            var expected = expected_value(
                index, transfer_round, allocation_tag, session_round
            )
            if (
                inject_mismatch
                and session_round == 1
                and allocation_tag == 1
                and transfer_round == TRANSFER_ROUNDS - 1
                and index == 0
            ):
                expected += 1.0
            if allocation.get_host(index) != expected:
                raise Error(
                    "GPU-2 transfer mismatch at index "
                    + String(index)
                    + " in session "
                    + String(session_round)
                    + ", allocation "
                    + String(allocation_tag)
                    + ", round "
                    + String(transfer_round)
                )
    if allocation.synchronization_count != TRANSFER_ROUNDS * 2:
        raise Error("GPU-2 synchronization accounting mismatch")


def run_resource_session(
    physical_device: PhysicalDevice,
    session_round: Int,
    inject_mismatch: Bool,
) raises:
    """Open, exercise, and scope-release one selected-device resource session.
    """
    var resources = CUDADeviceResources(
        physical_device,
        DEVICE_BUDGET_BYTES,
        PINNED_HOST_BUDGET_BYTES,
    )
    var first = resources.allocate_f16(FIRST_ELEMENT_COUNT)
    var second = resources.allocate_f16(SECOND_ELEMENT_COUNT)

    if first.stable_device_id != physical_device.stable_id:
        raise Error("GPU-2 first allocation lost selected-device identity")
    if second.stable_device_id != physical_device.stable_id:
        raise Error("GPU-2 second allocation lost selected-device identity")
    if resources.allocation_count != 2:
        raise Error("GPU-2 allocation count mismatch")

    var reserved_device_before_failure = resources.budget.device_reserved_bytes
    var reserved_host_before_failure = (
        resources.budget.pinned_host_reserved_bytes
    )
    var allocations_before_failure = resources.allocation_count

    var zero_rejected = False
    try:
        _ = resources.allocate_f16(0)
    except error:
        zero_rejected = "element count must be positive" in String(error)
    if not zero_rejected:
        raise Error("GPU-2 physical session accepted zero elements")

    var over_budget_rejected = False
    try:
        _ = resources.allocate_f16(DEVICE_BUDGET_BYTES)
    except error:
        over_budget_rejected = "budget exceeded" in String(error)
    if not over_budget_rejected:
        raise Error("GPU-2 physical session accepted an over-budget request")

    if (
        resources.budget.device_reserved_bytes != reserved_device_before_failure
        or resources.budget.pinned_host_reserved_bytes
        != reserved_host_before_failure
        or resources.allocation_count != allocations_before_failure
    ):
        raise Error("GPU-2 failed allocation changed committed accounting")

    exercise_allocation(first, 0, session_round, inject_mismatch)
    exercise_allocation(second, 1, session_round, inject_mismatch)
    resources.synchronize()


def main() raises:
    var inject_mismatch = False
    var arguments = argv()
    if len(arguments) == 2 and arguments[1] == "--negative-control":
        inject_mismatch = True
    elif len(arguments) != 1:
        raise Error("usage: test_gpu_resources.mojo [--negative-control]")

    var discovery = CUDAGate.discover_physical_devices()
    discovery.validate()
    if not discovery.status.has_devices():
        raise Error("GPU-2 requires an observed compatible CUDA device")

    var topology = DeviceTopology(1)
    topology.apply_gpu_discovery(discovery^)
    var physical_device = topology.select_gpu_by_index(
        GPURealmType(GPURealmType.NVIDIA_CUDA),
        topology.physical_devices[0].backend_index,
    )

    print("[GPU2] device:", physical_device.name)
    print("[GPU2] stable-id:", physical_device.stable_id)
    print("[GPU2] context-and-budget-policy: admitted")

    run_resource_session(physical_device, 0, inject_mismatch)
    print("[GPU2] first-session: pass")
    run_resource_session(physical_device, 1, inject_mismatch)
    print("[GPU2] second-session-after-scope-cleanup: pass")
    print("[GPU2] allocations-per-session: 2")
    print("[GPU2] transfer-rounds-per-allocation:", TRANSFER_ROUNDS)
    print("[GPU2] synchronized-h2d-d2h: pass")
    print("[GPU2] transactional-budget-rejection: pass")
    print("[GPU2] result: PASS")
