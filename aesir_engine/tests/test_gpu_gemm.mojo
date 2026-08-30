# tests/test_gpu_gemm.mojo
# GPU-3 opt-in physical CUDA F16 GEMM parity and reuse proof.

from core.compute import gemm_f16_cuda
from core.cuda_compute import CUDAF16GemmExecutor
from core.cuda_gate import CUDAGate
from core.cuda_gemm_plan import CUDAGemmPlan
from core.cuda_resources import CUDADeviceResources
from core.mimir_well import (
    DeviceTopology,
    GPURealmType,
    MimirWell,
    PhysicalDevice,
    RuneTensor,
    Scalar,
    f16,
    f32,
)
from std.sys import argv


comptime DEVICE_BUDGET_BYTES = 1024 * 1024
comptime PINNED_HOST_BUDGET_BYTES = 1024 * 1024
comptime EXECUTION_ROUNDS = 3
comptime ABSOLUTE_TOLERANCE: Scalar[f32] = 0.01
comptime RELATIVE_TOLERANCE: Scalar[f32] = 0.002


def absolute(value: Scalar[f32]) -> Scalar[f32]:
    if value < 0.0:
        return -value
    return value


def exact_input_a(index: Int, execution_round: Int) -> Scalar[f16]:
    return Scalar[f16](((index + execution_round * 3) % 9) - 4) * 0.25


def exact_input_b(index: Int, execution_round: Int) -> Scalar[f16]:
    return Scalar[f16](((index * 3 + execution_round) % 7) - 3) * 0.5


def varied_input_a(index: Int, execution_round: Int) -> Scalar[f16]:
    return Scalar[f16](((index * 5 + execution_round * 7) % 23) - 11) * 0.1


def varied_input_b(index: Int, execution_round: Int) -> Scalar[f16]:
    return Scalar[f16](((index * 7 + execution_round * 2) % 19) - 9) * 0.125


def fill_inputs(
    mut a: RuneTensor[f16],
    mut b: RuneTensor[f16],
    execution_round: Int,
    exact_values: Bool,
):
    for index in range(a.size):
        if exact_values:
            a.data.unsafe_store(index, exact_input_a(index, execution_round))
        else:
            a.data.unsafe_store(index, varied_input_a(index, execution_round))
    for index in range(b.size):
        if exact_values:
            b.data.unsafe_store(index, exact_input_b(index, execution_round))
        else:
            b.data.unsafe_store(index, varied_input_b(index, execution_round))


def expected_cell(
    a: RuneTensor[f16],
    b: RuneTensor[f16],
    row: Int,
    output_column: Int,
) -> Scalar[f32]:
    var total: Scalar[f32] = 0.0
    for inner in range(a.cols):
        total += (
            a.data.unsafe_load(row * a.cols + inner).cast[f32]()
            * b.data.unsafe_load(output_column * b.cols + inner).cast[f32]()
        )
    return total


def validate_output(
    a: RuneTensor[f16],
    b: RuneTensor[f16],
    c: RuneTensor[f16],
    execution_round: Int,
    exact_values: Bool,
    inject_mismatch: Bool,
) raises -> Scalar[f32]:
    var maximum_error: Scalar[f32] = 0.0
    for row in range(c.rows):
        for output_column in range(c.cols):
            var output_index = row * c.cols + output_column
            var expected = expected_cell(a, b, row, output_column)
            if (
                inject_mismatch
                and execution_round == EXECUTION_ROUNDS - 1
                and output_index == 0
            ):
                expected += 1.0
            var actual = c.data.unsafe_load(output_index).cast[f32]()
            var difference = absolute(actual - expected)
            if difference > maximum_error:
                maximum_error = difference
            if exact_values:
                if actual != expected.cast[f16]().cast[f32]():
                    raise Error(
                        "GPU-3 exact GEMM mismatch at output index "
                        + String(output_index)
                        + " in round "
                        + String(execution_round)
                    )
            else:
                var tolerance = (
                    ABSOLUTE_TOLERANCE
                    + RELATIVE_TOLERANCE * absolute(expected)
                )
                if difference > tolerance:
                    raise Error(
                        "GPU-3 GEMM parity mismatch at output index "
                        + String(output_index)
                        + " in round "
                        + String(execution_round)
                    )
    return maximum_error


def exercise_shape(
    mut resources: CUDADeviceResources,
    plan: CUDAGemmPlan,
    exact_values: Bool,
    inject_mismatch: Bool,
) raises -> Scalar[f32]:
    var well = MimirWell(plan.total_size_bytes + 4096)
    var a = RuneTensor[f16].checked(
        plan.m, plan.k, well.allocate(plan.a_element_count), False
    )
    var b = RuneTensor[f16].checked(
        plan.n, plan.k, well.allocate(plan.b_element_count), False
    )
    var c = RuneTensor[f16].checked(
        plan.m, plan.n, well.allocate(plan.c_element_count), False
    )
    var executor = CUDAF16GemmExecutor.create(resources, plan)
    var allocation_count = resources.allocation_count
    var maximum_error: Scalar[f32] = 0.0

    for execution_round in range(EXECUTION_ROUNDS):
        fill_inputs(a, b, execution_round, exact_values)
        for index in range(c.size):
            c.data.unsafe_store(index, -999.0)
        gemm_f16_cuda(executor, a, b, c)
        var round_error = validate_output(
            a,
            b,
            c,
            execution_round,
            exact_values,
            inject_mismatch,
        )
        if round_error > maximum_error:
            maximum_error = round_error
        if resources.allocation_count != allocation_count:
            raise Error("GPU-3 execution allocated additional resources")

    if executor.execution_count != EXECUTION_ROUNDS:
        raise Error("GPU-3 executor reuse accounting mismatch")
    return maximum_error


def prove_insufficient_budget_rejection(
    physical_device: PhysicalDevice, plan: CUDAGemmPlan
) raises:
    var resources = CUDADeviceResources(
        physical_device,
        plan.total_size_bytes,
        plan.total_size_bytes - 1,
    )
    var rejected = False
    try:
        _ = CUDAF16GemmExecutor.create(resources, plan)
    except error:
        rejected = "pinned-host budget is insufficient" in String(error)
    if not rejected:
        raise Error("GPU-3 physical executor accepted insufficient host budget")
    if (
        resources.budget.device_reserved_bytes != 0
        or resources.budget.pinned_host_reserved_bytes != 0
        or resources.allocation_count != 0
    ):
        raise Error("GPU-3 rejected executor changed resource accounting")


def main() raises:
    var inject_mismatch = False
    var arguments = argv()
    if len(arguments) == 2 and arguments[1] == "--negative-control":
        inject_mismatch = True
    elif len(arguments) != 1:
        raise Error("usage: test_gpu_gemm.mojo [--negative-control]")

    var discovery = CUDAGate.discover_physical_devices()
    discovery.validate()
    if not discovery.status.has_devices():
        raise Error("GPU-3 requires an observed compatible CUDA device")

    var topology = DeviceTopology(1)
    topology.apply_gpu_discovery(discovery^)
    var physical_device = topology.select_gpu_by_index(
        GPURealmType(GPURealmType.NVIDIA_CUDA),
        topology.physical_devices[0].backend_index,
    )
    var resources = CUDADeviceResources(
        physical_device,
        DEVICE_BUDGET_BYTES,
        PINNED_HOST_BUDGET_BYTES,
    )

    var exact_plan = CUDAGemmPlan(2, 3, 4)
    var tail_plan = CUDAGemmPlan(17, 19, 23)
    prove_insufficient_budget_rejection(physical_device, tail_plan)
    var exact_error = exercise_shape(
        resources, exact_plan, True, inject_mismatch
    )
    var tail_error = exercise_shape(resources, tail_plan, False, False)

    if resources.allocation_count != 6:
        raise Error("GPU-3 expected two three-buffer executors")
    resources.synchronize()
    print("[GPU3] device:", physical_device.name)
    print("[GPU3] stable-id:", physical_device.stable_id)
    print("[GPU3] exact-shape: 2x3x4")
    print("[GPU3] tail-shape: 17x19x23")
    print("[GPU3] executions-per-shape:", EXECUTION_ROUNDS)
    print("[GPU3] exact-max-error:", exact_error)
    print("[GPU3] tail-max-error:", tail_error)
    print("[GPU3] transactional-budget-rejection: pass")
    print("[GPU3] reusable-executor-no-reallocation: pass")
    print("[GPU3] result: PASS")
