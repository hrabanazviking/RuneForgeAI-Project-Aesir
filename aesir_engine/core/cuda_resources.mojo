# core/cuda_resources.mojo
# GPU-2: owned MAX CUDA contexts, F16 buffers, transfers, and budgets.

from max.gpu.host import DeviceBuffer, DeviceContext, HostBuffer
from core.mimir_well import GPURealmType, PhysicalDevice, Scalar, f16


struct CUDAResourceBudget(Copyable):
    """Conservative per-session device and pinned-host byte accounting."""

    var device_limit_bytes: Int
    var pinned_host_limit_bytes: Int
    var device_reserved_bytes: Int
    var pinned_host_reserved_bytes: Int

    def __init__(
        out self, device_limit_bytes: Int, pinned_host_limit_bytes: Int
    ) raises:
        if device_limit_bytes <= 0:
            raise Error("CUDAResourceBudget: device limit must be positive")
        if pinned_host_limit_bytes <= 0:
            raise Error(
                "CUDAResourceBudget: pinned-host limit must be positive"
            )
        self.device_limit_bytes = device_limit_bytes
        self.pinned_host_limit_bytes = pinned_host_limit_bytes
        self.device_reserved_bytes = 0
        self.pinned_host_reserved_bytes = 0

    def __copyinit__(out self, existing: Self):
        self.device_limit_bytes = existing.device_limit_bytes
        self.pinned_host_limit_bytes = existing.pinned_host_limit_bytes
        self.device_reserved_bytes = existing.device_reserved_bytes
        self.pinned_host_reserved_bytes = existing.pinned_host_reserved_bytes

    @staticmethod
    def f16_size_bytes(element_count: Int) raises -> Int:
        """Return an exact positive F16 byte count or reject overflow."""
        if element_count <= 0:
            raise Error("CUDAResourceBudget: element count must be positive")
        var size_bytes = element_count * 2
        if size_bytes <= 0 or size_bytes // 2 != element_count:
            raise Error("CUDAResourceBudget: F16 byte count overflow")
        return size_bytes

    @staticmethod
    def f16_batch3_size_bytes(
        first_element_count: Int,
        second_element_count: Int,
        third_element_count: Int,
    ) raises -> Int:
        """Return the exact byte total for three positive F16 allocations."""
        var first_bytes = Self.f16_size_bytes(first_element_count)
        var second_bytes = Self.f16_size_bytes(second_element_count)
        var third_bytes = Self.f16_size_bytes(third_element_count)
        var first_pair_bytes = first_bytes + second_bytes
        if first_pair_bytes <= first_bytes:
            raise Error("CUDAResourceBudget: F16 batch byte count overflow")
        var total_bytes = first_pair_bytes + third_bytes
        if total_bytes <= first_pair_bytes:
            raise Error("CUDAResourceBudget: F16 batch byte count overflow")
        return total_bytes

    def validate(self) raises:
        if self.device_limit_bytes <= 0:
            raise Error("CUDAResourceBudget: device limit must be positive")
        if self.pinned_host_limit_bytes <= 0:
            raise Error(
                "CUDAResourceBudget: pinned-host limit must be positive"
            )
        if (
            self.device_reserved_bytes < 0
            or self.device_reserved_bytes > self.device_limit_bytes
        ):
            raise Error("CUDAResourceBudget: invalid device reservation")
        if (
            self.pinned_host_reserved_bytes < 0
            or self.pinned_host_reserved_bytes > self.pinned_host_limit_bytes
        ):
            raise Error("CUDAResourceBudget: invalid pinned-host reservation")

    def remaining_device_bytes(self) -> Int:
        return self.device_limit_bytes - self.device_reserved_bytes

    def remaining_pinned_host_bytes(self) -> Int:
        return self.pinned_host_limit_bytes - self.pinned_host_reserved_bytes

    def reserve_f16(mut self, element_count: Int) raises -> Int:
        """Atomically reserve equal device and pinned-host F16 byte spans."""
        self.validate()
        var size_bytes = Self.f16_size_bytes(element_count)
        if size_bytes > self.remaining_device_bytes():
            raise Error("CUDAResourceBudget: device budget exceeded")
        if size_bytes > self.remaining_pinned_host_bytes():
            raise Error("CUDAResourceBudget: pinned-host budget exceeded")
        self.device_reserved_bytes += size_bytes
        self.pinned_host_reserved_bytes += size_bytes
        return size_bytes

    def reserve_f16_batch3(
        mut self,
        first_element_count: Int,
        second_element_count: Int,
        third_element_count: Int,
    ) raises -> Int:
        """Atomically reserve device and host bytes for three F16 buffers."""
        self.validate()
        var total_bytes = Self.f16_batch3_size_bytes(
            first_element_count,
            second_element_count,
            third_element_count,
        )
        if total_bytes > self.remaining_device_bytes():
            raise Error("CUDAResourceBudget: device budget exceeded")
        if total_bytes > self.remaining_pinned_host_bytes():
            raise Error("CUDAResourceBudget: pinned-host budget exceeded")
        self.device_reserved_bytes += total_bytes
        self.pinned_host_reserved_bytes += total_bytes
        return total_bytes

    def rollback_f16(mut self, size_bytes: Int) raises:
        """Undo one failed allocation reservation without underflow."""
        if size_bytes <= 0 or size_bytes % 2 != 0:
            raise Error("CUDAResourceBudget: invalid rollback byte count")
        if (
            size_bytes > self.device_reserved_bytes
            or size_bytes > self.pinned_host_reserved_bytes
        ):
            raise Error("CUDAResourceBudget: rollback exceeds reservation")
        self.device_reserved_bytes -= size_bytes
        self.pinned_host_reserved_bytes -= size_bytes


def validate_cuda_resource_policy(
    device: PhysicalDevice, budget: CUDAResourceBudget
) raises:
    """Validate a selected device and caller policy without opening hardware."""
    device.validate()
    budget.validate()
    if device.realm.value != GPURealmType.NVIDIA_CUDA or device.api != "cuda":
        raise Error("CUDADeviceResources: selected device is not CUDA")
    if not device.capabilities.is_compatible:
        raise Error("CUDADeviceResources: selected device is incompatible")
    if UInt(budget.device_limit_bytes) > device.capabilities.total_memory_bytes:
        raise Error("CUDADeviceResources: device budget exceeds total memory")


struct CUDAF16Allocation:
    """Move-only owner of matched pinned-host and device-resident F16 buffers.
    """

    var context: DeviceContext
    var host_buffer: HostBuffer[DType.float16]
    var device_buffer: DeviceBuffer[DType.float16]
    var element_count: Int
    var size_bytes: Int
    var stable_device_id: String
    var synchronization_count: Int

    def __init__(
        out self,
        context: DeviceContext,
        stable_device_id: String,
        element_count: Int,
        size_bytes: Int,
    ) raises:
        if stable_device_id.byte_length() == 0:
            raise Error("CUDAF16Allocation: stable device ID must not be empty")
        var expected_bytes = CUDAResourceBudget.f16_size_bytes(element_count)
        if size_bytes != expected_bytes:
            raise Error("CUDAF16Allocation: byte count mismatch")
        self.context = context
        self.host_buffer = self.context.enqueue_create_host_buffer[
            DType.float16
        ](element_count)
        self.device_buffer = self.context.enqueue_create_buffer[DType.float16](
            element_count
        )
        self.element_count = element_count
        self.size_bytes = size_bytes
        self.stable_device_id = stable_device_id
        self.synchronization_count = 0

    def validate_index(self, index: Int) raises:
        if index < 0 or index >= self.element_count:
            raise Error("CUDAF16Allocation: host index out of bounds")

    def set_host(mut self, index: Int, value: Scalar[f16]) raises:
        self.validate_index(index)
        self.host_buffer[index] = value

    def get_host(self, index: Int) raises -> Scalar[f16]:
        self.validate_index(index)
        return self.host_buffer[index]

    def enqueue_upload(self) raises:
        """Enqueue an asynchronous full-buffer host-to-device copy."""
        self.context.enqueue_copy(self.device_buffer, self.host_buffer)

    def enqueue_download(self) raises:
        """Enqueue an asynchronous full-buffer device-to-host copy."""
        self.context.enqueue_copy(self.host_buffer, self.device_buffer)

    def synchronize(mut self) raises:
        """Wait for this allocation's owning context stream to complete."""
        self.context.synchronize()
        self.synchronization_count += 1

    def upload_and_synchronize(mut self) raises:
        self.enqueue_upload()
        self.synchronize()

    def download_and_synchronize(mut self) raises:
        self.enqueue_download()
        self.synchronize()


struct CUDADeviceResources:
    """Move-only selected-device context and monotonic resource budget."""

    var context: DeviceContext
    var physical_device: PhysicalDevice
    var budget: CUDAResourceBudget
    var allocation_count: Int

    def __init__(
        out self,
        physical_device: PhysicalDevice,
        device_limit_bytes: Int,
        pinned_host_limit_bytes: Int,
    ) raises:
        var budget = CUDAResourceBudget(
            device_limit_bytes, pinned_host_limit_bytes
        )
        validate_cuda_resource_policy(physical_device, budget)
        self.context = DeviceContext(physical_device.backend_index, api="cuda")
        if self.context.api() != "cuda":
            raise Error("CUDADeviceResources: context API mismatch")
        if self.context.id() != physical_device.runtime_id:
            raise Error("CUDADeviceResources: context runtime ID mismatch")
        if not self.context.is_compatible():
            raise Error("CUDADeviceResources: live context is incompatible")
        var live_memory = self.context.get_memory_info()
        if UInt(device_limit_bytes) > live_memory[0]:
            raise Error(
                "CUDADeviceResources: device budget exceeds live free memory"
            )
        self.physical_device = physical_device.copy()
        self.budget = budget^
        self.allocation_count = 0

    def allocate_f16(mut self, element_count: Int) raises -> CUDAF16Allocation:
        """Reserve policy bytes, allocate both buffers, or roll back fully."""
        var size_bytes = self.budget.reserve_f16(element_count)
        try:
            var allocation = CUDAF16Allocation(
                self.context,
                self.physical_device.stable_id,
                element_count,
                size_bytes,
            )
            self.context.synchronize()
            self.allocation_count += 1
            return allocation^
        except error:
            self.budget.rollback_f16(size_bytes)
            raise error

    def synchronize(self) raises:
        self.context.synchronize()
