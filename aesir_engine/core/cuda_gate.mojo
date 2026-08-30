# core/cuda_gate.mojo
# CUDAGate: Native POSIX FFI Gateway & Memory Management for NVIDIA CUDA Realm (Alfheim)

from std.ffi import external_call
from std.memory import Pointer
from std.collections import Optional
from max.gpu.host import DeviceAttribute, DeviceContext
from core.mimir_well import (
    Scalar,
    f16,
    RuneTensor,
    GPURealmType,
    DiscoveryStatus,
    DeviceCapabilities,
    PhysicalDevice,
    HardwareDiscoveryResult,
)
from core.cuda_gemm_plan import CUDAGemmPlan
from core.cuda_resources import CUDADeviceResources
from core.cuda_compute import CUDAF16GemmExecutor

comptime RTLD_NOW = 2


struct CUDAGate:
    """
    ᚲᛢᛞᚨ·ᚷᚨᛏᛖ — The Alfheim Gateway to CUDA Silicon (CUDAGate)
    ═══════════════════════════════════════════════════════════

    Native bare-metal POSIX FFI interface to libcudart.so / libcuda.so.
    Probes whether a CUDA runtime library can be loaded and uses MAX 26.5 for
    physical device discovery. Production VRAM ownership, transfers, and
    engine kernel launch remain deliberately unsupported.
    """

    @staticmethod
    def get_handle() -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads libcudart.so or libcuda.so handle via dlopen, or returns None.
        """
        var path1 = InlineArray[Int8, 32](fill=0)
        var p1_bytes = String("libcudart.so").as_bytes()
        for i in range(len(p1_bytes)):
            path1[i] = Int8(p1_bytes[i])
        var h1 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](
            path1.unsafe_ptr(), Int32(RTLD_NOW)
        )
        if Int(h1) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h1)

        var path2 = InlineArray[Int8, 32](fill=0)
        var p2_bytes = String("libcuda.so").as_bytes()
        for i in range(len(p2_bytes)):
            path2[i] = Int8(p2_bytes[i])
        var h2 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](
            path2.unsafe_ptr(), Int32(RTLD_NOW)
        )
        if Int(h2) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h2)

        var path3 = InlineArray[Int8, 32](fill=0)
        var p3_bytes = String("libcuda.so.1").as_bytes()
        for i in range(len(p3_bytes)):
            path3[i] = Int8(p3_bytes[i])
        var h3 = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](
            path3.unsafe_ptr(), Int32(RTLD_NOW)
        )
        if Int(h3) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h3)

        return None

    @staticmethod
    def is_available() -> Bool:
        """Returns whether a CUDA runtime library is loadable, not whether a GPU exists.
        """
        var opt_h = CUDAGate.get_handle()
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def get_device_count() -> Int:
        """Returns the MAX-observed CUDA device count, or zero on probe failure.
        """
        return DeviceContext.number_of_devices(api="cuda")

    @staticmethod
    def classify_discovery_error(message: String) -> DiscoveryStatus:
        """Classify a runtime error without converting it into device success.
        """
        if (
            "permission" in message
            or "Permission" in message
            or "not permitted" in message
        ):
            return DiscoveryStatus(DiscoveryStatus.PERMISSION_DENIED)
        if "ptxas" in message or "compiler tool" in message:
            return DiscoveryStatus(DiscoveryStatus.MISSING_COMPILER_TOOL)
        if "architecture" in message or "compute capability" in message:
            return DiscoveryStatus(DiscoveryStatus.UNSUPPORTED_ARCHITECTURE)
        if "driver" in message or "Driver" in message:
            return DiscoveryStatus(DiscoveryStatus.INCOMPATIBLE_DRIVER)
        if (
            "libcuda" in message
            or "CUDA runtime" in message
            or "unsupported runtime" in message
        ):
            return DiscoveryStatus(DiscoveryStatus.UNSUPPORTED_RUNTIME)
        return DiscoveryStatus(DiscoveryStatus.PROBE_FAILED)

    @staticmethod
    def discover_physical_devices() -> HardwareDiscoveryResult:
        """Enumerate and inspect every CUDA device exposed by MAX 26.5."""
        var devices = List[PhysicalDevice]()
        if not CUDAGate.is_available():
            return HardwareDiscoveryResult(
                DiscoveryStatus(DiscoveryStatus.UNSUPPORTED_RUNTIME),
                "CUDA runtime library is not loadable",
                devices,
            )

        var device_count = DeviceContext.number_of_devices(api="cuda")

        if device_count <= 0:
            return HardwareDiscoveryResult(
                DiscoveryStatus(DiscoveryStatus.NO_DEVICE),
                "MAX reported no CUDA devices",
                devices,
            )

        for backend_index in range(device_count):
            try:
                with DeviceContext(backend_index, api="cuda") as context:
                    var memory = context.get_memory_info()
                    var runtime_id = context.id()
                    var capabilities = DeviceCapabilities(
                        context.is_compatible(),
                        context.get_api_version(),
                        memory[0],
                        memory[1],
                        context.get_attribute(
                            DeviceAttribute.COMPUTE_CAPABILITY_MAJOR
                        ),
                        context.get_attribute(
                            DeviceAttribute.COMPUTE_CAPABILITY_MINOR
                        ),
                        context.get_attribute(
                            DeviceAttribute.MULTIPROCESSOR_COUNT
                        ),
                        context.get_attribute(
                            DeviceAttribute.MAX_THREADS_PER_BLOCK
                        ),
                    )
                    var device = PhysicalDevice(
                        GPURealmType(GPURealmType.NVIDIA_CUDA),
                        backend_index,
                        runtime_id,
                        "cuda:max-id:" + String(runtime_id),
                        context.name(),
                        context.api(),
                        capabilities,
                    )
                    device.validate()
                    devices.append(device^)
            except error:
                var message = String(error)
                if len(devices) > 0:
                    return HardwareDiscoveryResult(
                        DiscoveryStatus(DiscoveryStatus.PARTIAL),
                        "CUDA discovery stopped after backend index "
                        + String(backend_index)
                        + ": "
                        + message,
                        devices,
                    )
                return HardwareDiscoveryResult(
                    CUDAGate.classify_discovery_error(message), message, devices
                )

        return HardwareDiscoveryResult(
            DiscoveryStatus(DiscoveryStatus.SUCCESS),
            "MAX CUDA discovery completed",
            devices,
        )

    @staticmethod
    def allocate_vram(
        size_bytes: Int,
    ) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Rejects simulated VRAM allocation until cudaMalloc is integrated."""
        if size_bytes <= 0:
            raise Error("CUDAGate.allocate_vram: size_bytes must be positive")
        raise Error(
            "CUDAGate.allocate_vram: physical CUDA VRAM allocation is not"
            " implemented"
        )

    @staticmethod
    def free_vram(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Rejects simulated cudaFree until CUDA-owned pointers exist."""
        _ = ptr
        raise Error(
            "CUDAGate.free_vram: physical CUDA VRAM ownership is not"
            " implemented"
        )

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """Rejects simulated host-to-device transfer until cudaMemcpy is integrated.
        """
        _ = dst_dev
        _ = src_host
        if size_bytes <= 0:
            return
        raise Error(
            "CUDAGate.memcpy_host_to_device: physical CUDA transfer is not"
            " implemented"
        )

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int,
    ) raises:
        """Rejects simulated device-to-host transfer until cudaMemcpy is integrated.
        """
        _ = dst_host
        _ = src_dev
        if size_bytes <= 0:
            return
        raise Error(
            "CUDAGate.memcpy_device_to_host: physical CUDA transfer is not"
            " implemented"
        )

    @staticmethod
    def launch_gemm_cuda(
        A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
    ) raises:
        """
        Launches a real CUDA F16 GEMM kernel on the physical NVIDIA GPU.
        """
        if (
            A.rows <= 0
            or A.cols <= 0
            or B.rows <= 0
            or B.cols <= 0
            or C.rows <= 0
            or C.cols <= 0
        ):
            raise Error(
                "CUDAGate.launch_gemm_cuda: non-positive matrix dimensions are"
                " prohibited"
            )
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error("CUDAGate.launch_gemm_cuda: GEMM shape mismatch")

        var discovery = CUDAGate.discover_physical_devices()
        if not discovery.status.has_devices():
            raise Error("CUDAGate.launch_gemm_cuda: no compatible CUDA device discovered")

        var physical_device = discovery.devices[0].copy()
        var plan = CUDAGemmPlan(A.rows, A.cols, C.cols)
        var budget_bytes = plan.total_size_bytes + 1024 * 1024
        var resources = CUDADeviceResources(physical_device, budget_bytes, budget_bytes)
        var executor = CUDAF16GemmExecutor.create(resources, plan)
        executor.execute(A, B, C)

