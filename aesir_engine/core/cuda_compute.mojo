# core/cuda_compute.mojo
# GPU-3: reusable selected-device CUDA F16 GEMM execution.

from max.gpu.host import DeviceContext
from std.gpu import global_idx
from std.memory import Pointer

from core.cuda_gemm_plan import CUDAGemmPlan
from core.cuda_resources import CUDADeviceResources, CUDAF16Allocation
from core.mimir_well import RuneTensor, Scalar, f16, f32


def _cuda_f16_gemm_kernel[
    a_origin: Origin[mut=False],
    b_origin: Origin[mut=False],
    c_origin: MutOrigin,
](
    a: Pointer[Scalar[f16], a_origin],
    b: Pointer[Scalar[f16], b_origin],
    c: Pointer[Scalar[f16], c_origin],
    m_count: Int32,
    k_count: Int32,
    n_count: Int32,
    output_count: Int32,
):
    """Compute one row-major A[M,K] x B[N,K] output cell per thread."""
    var output_index = Int(global_idx.x)
    if output_index < Int(output_count):
        var n = Int(n_count)
        var k = Int(k_count)
        var row = output_index // n
        var output_column = output_index - row * n
        if row < Int(m_count):
            var accumulator: Scalar[f32] = 0.0
            for inner in range(k):
                accumulator += (
                    a.unsafe_load(row * k + inner).cast[f32]()
                    * b.unsafe_load(output_column * k + inner).cast[f32]()
                )
            c.unsafe_store(output_index, accumulator.cast[f16]())


struct CUDAF16GemmExecutor:
    """Move-only reusable CUDA executor for one validated GEMM shape."""

    var plan: CUDAGemmPlan
    var context: DeviceContext
    var stable_device_id: String
    var a_allocation: CUDAF16Allocation
    var b_allocation: CUDAF16Allocation
    var c_allocation: CUDAF16Allocation
    var execution_count: Int
    var is_usable: Bool
    var last_failure_message: String

    def __init__(
        out self,
        plan: CUDAGemmPlan,
        context: DeviceContext,
        stable_device_id: String,
        var a_allocation: CUDAF16Allocation,
        var b_allocation: CUDAF16Allocation,
        var c_allocation: CUDAF16Allocation,
    ):
        self.plan = plan.copy()
        self.context = context
        self.stable_device_id = stable_device_id
        self.a_allocation = a_allocation^
        self.b_allocation = b_allocation^
        self.c_allocation = c_allocation^
        self.execution_count = 0
        self.is_usable = True
        self.last_failure_message = ""

    @staticmethod
    def create(
        mut resources: CUDADeviceResources, plan: CUDAGemmPlan
    ) raises -> Self:
        """Transactionally allocate the three fixed-shape F16 buffer pairs."""
        plan.validate_budget(resources.budget)
        var reserved_bytes = resources.budget.reserve_f16_batch3(
            plan.a_element_count,
            plan.b_element_count,
            plan.c_element_count,
        )
        try:
            var a_allocation = CUDAF16Allocation(
                resources.context,
                resources.physical_device.stable_id,
                plan.a_element_count,
                plan.a_size_bytes,
            )
            var b_allocation = CUDAF16Allocation(
                resources.context,
                resources.physical_device.stable_id,
                plan.b_element_count,
                plan.b_size_bytes,
            )
            var c_allocation = CUDAF16Allocation(
                resources.context,
                resources.physical_device.stable_id,
                plan.c_element_count,
                plan.c_size_bytes,
            )
            resources.context.synchronize()
            resources.allocation_count += 3
            return Self(
                plan,
                resources.context,
                resources.physical_device.stable_id,
                a_allocation^,
                b_allocation^,
                c_allocation^,
            )
        except error:
            resources.budget.rollback_f16(reserved_bytes)
            raise error

    def _validate_tensor_storage(
        self,
        tensor: RuneTensor[f16],
        expected_element_count: Int,
        label: String,
    ) raises:
        if tensor.is_quantized:
            raise Error("CUDAF16GemmExecutor: " + label + " must be plain F16")
        if tensor.size != expected_element_count:
            raise Error(
                "CUDAF16GemmExecutor: " + label + " element count mismatch"
            )
        var address = Int(tensor.data)
        if address == 0 or address == 1:
            raise Error("CUDAF16GemmExecutor: " + label + " pointer is invalid")

    def _validate_live_contract(
        self,
        a: RuneTensor[f16],
        b: RuneTensor[f16],
        c: RuneTensor[f16],
    ) raises:
        self.plan.validate_tensor_shapes(
            a.rows, a.cols, b.rows, b.cols, c.rows, c.cols
        )
        self._validate_tensor_storage(a, self.plan.a_element_count, "A")
        self._validate_tensor_storage(b, self.plan.b_element_count, "B")
        self._validate_tensor_storage(c, self.plan.c_element_count, "C")
        if self.stable_device_id.byte_length() == 0:
            raise Error("CUDAF16GemmExecutor: selected device ID is empty")
        if (
            self.a_allocation.stable_device_id != self.stable_device_id
            or self.b_allocation.stable_device_id != self.stable_device_id
            or self.c_allocation.stable_device_id != self.stable_device_id
        ):
            raise Error("CUDAF16GemmExecutor: allocation device identity mismatch")
        if self.context.api() != "cuda" or not self.context.is_compatible():
            raise Error("CUDAF16GemmExecutor: live CUDA context is incompatible")

    def execute(
        mut self,
        a: RuneTensor[f16],
        b: RuneTensor[f16],
        mut c: RuneTensor[f16],
    ) raises:
        """Upload, launch, download, synchronize, and publish one GEMM result."""
        if not self.is_usable:
            raise Error(
                "CUDAF16GemmExecutor: executor is unusable after device failure: "
                + self.last_failure_message
            )
        self._validate_live_contract(a, b, c)

        for index in range(self.plan.a_element_count):
            self.a_allocation.set_host(index, a.data.unsafe_load(index))
        for index in range(self.plan.b_element_count):
            self.b_allocation.set_host(index, b.data.unsafe_load(index))

        try:
            self.a_allocation.enqueue_upload()
            self.b_allocation.enqueue_upload()
            self.context.enqueue_function[
                _cuda_f16_gemm_kernel[
                    origin_of(self.a_allocation.device_buffer),
                    origin_of(self.b_allocation.device_buffer),
                    origin_of(self.c_allocation.device_buffer),
                ]
            ](
                self.a_allocation.device_buffer.unsafe_ptr(),
                self.b_allocation.device_buffer.unsafe_ptr(),
                self.c_allocation.device_buffer.unsafe_ptr(),
                Int32(self.plan.m),
                Int32(self.plan.k),
                Int32(self.plan.n),
                Int32(self.plan.c_element_count),
                grid_dim=self.plan.grid_size,
                block_dim=self.plan.block_size,
            )
            self.c_allocation.enqueue_download()
            self.context.synchronize()
        except error:
            self.is_usable = False
            self.last_failure_message = String(error)
            raise Error(
                "CUDAF16GemmExecutor: CUDA operation failed; executor poisoned: "
                + self.last_failure_message
            )

        for index in range(self.plan.c_element_count):
            c.data.unsafe_store(index, self.c_allocation.get_host(index))
        self.execution_count += 1
