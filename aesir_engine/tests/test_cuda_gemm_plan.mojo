# tests/test_cuda_gemm_plan.mojo
# Deterministic hardware-independent GPU-3 planning verification.

from core.cuda_gemm_plan import (
    CUDA_GEMM_BLOCK_SIZE,
    CUDA_GEMM_MAX_KERNEL_VALUE,
    CUDAGemmPlan,
)
from core.cuda_resources import CUDAResourceBudget


def test_cuda_gemm_plan_counts_and_launch() raises:
    var plan = CUDAGemmPlan(17, 19, 23)
    if plan.a_element_count != 323:
        raise Error("CUDA GEMM plan A element count mismatch")
    if plan.b_element_count != 437:
        raise Error("CUDA GEMM plan B element count mismatch")
    if plan.c_element_count != 391:
        raise Error("CUDA GEMM plan C element count mismatch")
    if plan.total_element_count != 1151 or plan.total_size_bytes != 2302:
        raise Error("CUDA GEMM plan total allocation mismatch")
    if plan.block_size != CUDA_GEMM_BLOCK_SIZE or plan.grid_size != 4:
        raise Error("CUDA GEMM plan launch-tail calculation mismatch")
    plan.validate_tensor_shapes(17, 19, 23, 19, 17, 23)
    print("CUDA GEMM plan counts and launch: PASS")


def test_cuda_gemm_plan_shape_rejection() raises:
    var nonpositive_rejected = False
    try:
        _ = CUDAGemmPlan(0, 8, 8)
    except error:
        nonpositive_rejected = "dimensions must be positive" in String(error)
    if not nonpositive_rejected:
        raise Error("CUDA GEMM plan accepted a nonpositive dimension")

    var plan = CUDAGemmPlan(2, 3, 4)
    var a_rejected = False
    try:
        plan.validate_tensor_shapes(2, 4, 4, 3, 2, 4)
    except error:
        a_rejected = "A tensor shape mismatch" in String(error)
    if not a_rejected:
        raise Error("CUDA GEMM plan accepted an invalid A shape")

    var b_rejected = False
    try:
        plan.validate_tensor_shapes(2, 3, 3, 3, 2, 4)
    except error:
        b_rejected = "B tensor shape mismatch" in String(error)
    if not b_rejected:
        raise Error("CUDA GEMM plan accepted an invalid B shape")

    var c_rejected = False
    try:
        plan.validate_tensor_shapes(2, 3, 4, 3, 4, 2)
    except error:
        c_rejected = "C tensor shape mismatch" in String(error)
    if not c_rejected:
        raise Error("CUDA GEMM plan accepted an invalid C shape")
    print("CUDA GEMM plan shape rejection: PASS")


def test_cuda_gemm_plan_overflow_and_abi_rejection() raises:
    var abi_rejected = False
    try:
        _ = CUDAGemmPlan(CUDA_GEMM_MAX_KERNEL_VALUE + 1, 1, 1)
    except error:
        abi_rejected = "dimension exceeds Int32 kernel ABI" in String(error)
    if not abi_rejected:
        raise Error("CUDA GEMM plan accepted an out-of-range kernel dimension")

    var output_rejected = False
    try:
        _ = CUDAGemmPlan(65536, 1, 65536)
    except error:
        output_rejected = "output count exceeds Int32 kernel ABI" in String(error)
    if not output_rejected:
        raise Error("CUDA GEMM plan accepted an out-of-range output count")

    var product_rejected = False
    try:
        _ = CUDAGemmPlan(1 << 62, 4, 1)
    except error:
        product_rejected = (
            "dimension exceeds Int32 kernel ABI" in String(error)
            or "product overflow" in String(error)
        )
    if not product_rejected:
        raise Error("CUDA GEMM plan accepted overflowing dimensions")
    print("CUDA GEMM plan overflow and ABI rejection: PASS")


def test_cuda_gemm_batch_budget_transaction() raises:
    var plan = CUDAGemmPlan(17, 19, 23)
    var budget = CUDAResourceBudget(4096, 4096)
    plan.validate_budget(budget)
    var reserved_bytes = budget.reserve_f16_batch3(
        plan.a_element_count,
        plan.b_element_count,
        plan.c_element_count,
    )
    if reserved_bytes != plan.total_size_bytes:
        raise Error("CUDA GEMM batch reservation byte mismatch")
    budget.rollback_f16(reserved_bytes)
    if (
        budget.device_reserved_bytes != 0
        or budget.pinned_host_reserved_bytes != 0
    ):
        raise Error("CUDA GEMM batch rollback did not restore accounting")

    var constrained = CUDAResourceBudget(4096, plan.total_size_bytes - 1)
    var rejected = False
    try:
        _ = constrained.reserve_f16_batch3(
            plan.a_element_count,
            plan.b_element_count,
            plan.c_element_count,
        )
    except error:
        rejected = "pinned-host budget exceeded" in String(error)
    if not rejected:
        raise Error("CUDA GEMM batch accepted an insufficient host budget")
    if (
        constrained.device_reserved_bytes != 0
        or constrained.pinned_host_reserved_bytes != 0
    ):
        raise Error("CUDA GEMM rejected batch mutated budget accounting")
    print("CUDA GEMM batch budget transaction: PASS")


def main() raises:
    test_cuda_gemm_plan_counts_and_launch()
    test_cuda_gemm_plan_shape_rejection()
    test_cuda_gemm_plan_overflow_and_abi_rejection()
    test_cuda_gemm_batch_budget_transaction()
