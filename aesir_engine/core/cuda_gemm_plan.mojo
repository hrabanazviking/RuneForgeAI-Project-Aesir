# core/cuda_gemm_plan.mojo
# Hardware-independent GPU-3 CUDA F16 GEMM shape and launch planning.

from core.cuda_resources import CUDAResourceBudget


comptime CUDA_GEMM_BLOCK_SIZE = 128
comptime CUDA_GEMM_MAX_KERNEL_VALUE = (1 << 31) - 1


def _checked_positive_product(lhs: Int, rhs: Int, label: String) raises -> Int:
    if lhs <= 0 or rhs <= 0:
        raise Error("CUDAGemmPlan: " + label + " dimensions must be positive")
    var product = lhs * rhs
    if product <= 0 or product // lhs != rhs:
        raise Error("CUDAGemmPlan: " + label + " product overflow")
    return product


def _checked_positive_sum(lhs: Int, rhs: Int, label: String) raises -> Int:
    if lhs <= 0 or rhs <= 0:
        raise Error("CUDAGemmPlan: " + label + " values must be positive")
    var total = lhs + rhs
    if total <= lhs:
        raise Error("CUDAGemmPlan: " + label + " sum overflow")
    return total


struct CUDAGemmPlan(Copyable):
    """Validated fixed-shape plan for A[M,K] x B[N,K] -> C[M,N]."""

    var m: Int
    var k: Int
    var n: Int
    var a_element_count: Int
    var b_element_count: Int
    var c_element_count: Int
    var total_element_count: Int
    var a_size_bytes: Int
    var b_size_bytes: Int
    var c_size_bytes: Int
    var total_size_bytes: Int
    var block_size: Int
    var grid_size: Int

    def __init__(out self, m: Int, k: Int, n: Int) raises:
        if m <= 0 or k <= 0 or n <= 0:
            raise Error("CUDAGemmPlan: dimensions must be positive")
        if (
            m > CUDA_GEMM_MAX_KERNEL_VALUE
            or k > CUDA_GEMM_MAX_KERNEL_VALUE
            or n > CUDA_GEMM_MAX_KERNEL_VALUE
        ):
            raise Error("CUDAGemmPlan: dimension exceeds Int32 kernel ABI")

        var a_element_count = _checked_positive_product(m, k, "A")
        var b_element_count = _checked_positive_product(n, k, "B")
        var c_element_count = _checked_positive_product(m, n, "C")
        if c_element_count > CUDA_GEMM_MAX_KERNEL_VALUE:
            raise Error("CUDAGemmPlan: output count exceeds Int32 kernel ABI")

        var input_element_count = _checked_positive_sum(
            a_element_count, b_element_count, "input element"
        )
        var total_element_count = _checked_positive_sum(
            input_element_count, c_element_count, "total element"
        )
        var a_size_bytes = CUDAResourceBudget.f16_size_bytes(a_element_count)
        var b_size_bytes = CUDAResourceBudget.f16_size_bytes(b_element_count)
        var c_size_bytes = CUDAResourceBudget.f16_size_bytes(c_element_count)
        var input_size_bytes = _checked_positive_sum(
            a_size_bytes, b_size_bytes, "input byte"
        )
        var total_size_bytes = _checked_positive_sum(
            input_size_bytes, c_size_bytes, "total byte"
        )
        var grid_size = (
            c_element_count + CUDA_GEMM_BLOCK_SIZE - 1
        ) // CUDA_GEMM_BLOCK_SIZE
        if grid_size <= 0:
            raise Error("CUDAGemmPlan: launch grid must be positive")

        self.m = m
        self.k = k
        self.n = n
        self.a_element_count = a_element_count
        self.b_element_count = b_element_count
        self.c_element_count = c_element_count
        self.total_element_count = total_element_count
        self.a_size_bytes = a_size_bytes
        self.b_size_bytes = b_size_bytes
        self.c_size_bytes = c_size_bytes
        self.total_size_bytes = total_size_bytes
        self.block_size = CUDA_GEMM_BLOCK_SIZE
        self.grid_size = grid_size

    def __copyinit__(out self, existing: Self):
        self.m = existing.m
        self.k = existing.k
        self.n = existing.n
        self.a_element_count = existing.a_element_count
        self.b_element_count = existing.b_element_count
        self.c_element_count = existing.c_element_count
        self.total_element_count = existing.total_element_count
        self.a_size_bytes = existing.a_size_bytes
        self.b_size_bytes = existing.b_size_bytes
        self.c_size_bytes = existing.c_size_bytes
        self.total_size_bytes = existing.total_size_bytes
        self.block_size = existing.block_size
        self.grid_size = existing.grid_size

    def validate_tensor_shapes(
        self,
        a_rows: Int,
        a_cols: Int,
        b_rows: Int,
        b_cols: Int,
        c_rows: Int,
        c_cols: Int,
    ) raises:
        if a_rows != self.m or a_cols != self.k:
            raise Error("CUDAGemmPlan: A tensor shape mismatch")
        if b_rows != self.n or b_cols != self.k:
            raise Error("CUDAGemmPlan: B tensor shape mismatch")
        if c_rows != self.m or c_cols != self.n:
            raise Error("CUDAGemmPlan: C tensor shape mismatch")

    def validate_budget(self, budget: CUDAResourceBudget) raises:
        budget.validate()
        if self.total_size_bytes > budget.remaining_device_bytes():
            raise Error("CUDAGemmPlan: device budget is insufficient")
        if self.total_size_bytes > budget.remaining_pinned_host_bytes():
            raise Error("CUDAGemmPlan: pinned-host budget is insufficient")
