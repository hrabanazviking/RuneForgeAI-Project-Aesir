# core/amd_gate.mojo
# AMDGate: Native POSIX FFI Gateway & Memory Management for AMD ROCm / HIP Realm (Jötunheim)
#
# A-010 (Z13 roadmap): the HIP device gate is real.
#
# Library probe -- the A-010 bug fix: Ubuntu runtime packages ship
# only the VERSIONED soname libamdhip64.so.7 (the unversioned
# libamdhip64.so symlink belongs to -dev packages), so the pre-A-010
# probe, which tried unversioned names only, reported a false absent
# on this machine while a working HIP runtime was installed. The
# probe now tries the versioned soname first.
#
# Device queries -- count, name, compute capability, multiprocessor
# count, thread limits, wavefront size, clock rate, runtime version,
# and device-visible memory are read live from the HIP runtime
# through MAX DeviceContext(api="hip"), the same discovery mechanism
# CUDAGate uses for CUDA. Every value MAX reports on purpleraider was
# cross-checked against direct hipGetDeviceProperties /
# hipDeviceGetAttribute calls and matched (name, major 11, minor 5,
# multiProcessorCount 20, maxThreadsPerBlock 1024,
# maxThreadsPerMultiProcessor 2048, wavefront 32, clockRate
# 2900000 kHz, runtime version 71500000; transcript in the team-01
# campaign log hidden_files/a010_offset_check.log). The gfx target
# string and the memory clock / bus width come from the kernel KFD
# topology through the A-001 census parsers -- the same sources the
# census itself uses.
#
# Why not OwnedDLHandle for the HIP calls: its internal dlopen /
# dlclose declarations cannot coexist in one compilation archive
# with the sibling gates' hand-declared external_call dlopen /
# dlclose (Mojo rejects them as conflicting signatures; three
# compile attempts in the A-010 session failed on exactly this, in
# both directions). The hand-declared probe below matches the
# sibling gates' convention, and MAX carries the runtime queries.
#
# Memory provenance: on this unified-memory part MAX reports the
# GPU-addressable total -- 56,657,969,152 bytes in the A-010 probe,
# 58,700,595,200 in the acceptance run; the figure tracks the
# currently addressable share and moves with system reservations --
# while hipDeviceProp_t.totalGlobalMem states the full unified pool
# (137,439,150,080 bytes). total_memory_bytes carries the MAX
# figure -- the memory the device can actually address -- and the
# difference is recorded here rather than hidden.
#
# HIP allocation, transfers, and kernel launch remain unsupported
# and fail closed.

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
from core.hardware_census import (
    format_gfx_target,
    parse_kfd_gfx_target_version,
    parse_mem_bank_clock_mhz,
    parse_mem_bank_width,
)
from core.posix_process import run_checked_argv
from core.structured_errors import coded_error_text

comptime RTLD_NOW = 2

comptime HIP_GATE_ABSENT = 0
comptime HIP_GATE_PRESENT = 1
comptime HIP_GATE_ERROR = 2


def _read_text_or_empty(path: String) -> String:
    """Whole file as text, or empty when unreadable (census idiom)."""
    try:
        var text: String
        with open(path, "r") as source:
            text = source.read()
        return text
    except:
        return String("")


struct HipDeviceProperties(Copyable, ImplicitlyCopyable):
    """One HIP device's properties, as the runtime itself reports them.

    Fields are -1 / empty when no source supplied them; a properties
    record is only trusted after plausible() accepts it.
    """

    var name: String
    var gfx_arch: String
    var gcn_arch: Int
    var total_memory_bytes: Int
    var wavefront_size: Int
    var max_threads_per_block: Int
    var max_threads_per_multi_processor: Int
    var multi_processor_count: Int
    var compute_major: Int
    var compute_minor: Int
    var clock_rate_khz: Int
    var memory_clock_rate_khz: Int
    var memory_bus_width_bits: Int

    def __init__(out self):
        self.name = String()
        self.gfx_arch = String()
        self.gcn_arch = -1
        self.total_memory_bytes = -1
        self.wavefront_size = -1
        self.max_threads_per_block = -1
        self.max_threads_per_multi_processor = -1
        self.multi_processor_count = -1
        self.compute_major = -1
        self.compute_minor = -1
        self.clock_rate_khz = -1
        self.memory_clock_rate_khz = -1
        self.memory_bus_width_bits = -1

    def plausible(self) -> Bool:
        """Sanity gate: every field the A-010 acceptance relies on must
        sit inside the range a real HIP device could report."""
        if self.name.byte_length() == 0:
            return False
        if self.gcn_arch <= 0:
            return False
        if self.total_memory_bytes < 1073741824:
            return False
        if self.wavefront_size != 32 and self.wavefront_size != 64:
            return False
        if self.multi_processor_count <= 0:
            return False
        if self.max_threads_per_block <= 0:
            return False
        return True


struct AMDGate:
    """
    ᛁᛟ·ᚷᚨᛏᛖ — The Jötunheim Gateway to AMD ROCm / HIP Silicon (AMDGate)
    ════════════════════════════════════════════════════════════════════

    Native POSIX FFI interface to libamdhip64 / libhipblas.
    The library probe is hand-declared dlopen in the sibling gates'
    convention, versioned soname first (A-010). Device count and
    device properties are queried live through the HIP runtime.
    HIP allocation, transfers, and kernel launch are unsupported
    and fail closed.
    """

    @staticmethod
    def _dlopen(
        name: String,
    ) -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """dlopen one soname, or None when the loader cannot find it."""
        var path = InlineArray[Int8, 32](fill=0)
        var bytes = name.as_bytes()
        for i in range(len(bytes)):
            if i >= 31:
                break
            path[i] = Int8(bytes[i])
        var h = external_call["dlopen", Pointer[Int8, MutUntrackedOrigin]](
            path.unsafe_ptr(), Int32(RTLD_NOW)
        )
        if Int(h) != 0:
            return Optional[Pointer[Int8, MutUntrackedOrigin]](h)
        return None

    @staticmethod
    def get_handle() -> Optional[Pointer[Int8, MutUntrackedOrigin]]:
        """Loads libamdhip64.so.7, libamdhip64.so, or libhipblas.so
        handle via dlopen, or returns None (versioned name first)."""
        var h = AMDGate._dlopen(String("libamdhip64.so.7"))
        if h:
            return h
        h = AMDGate._dlopen(String("libamdhip64.so"))
        if h:
            return h
        return AMDGate._dlopen(String("libhipblas.so"))

    @staticmethod
    def hip_soname() -> String:
        """First loadable libamdhip64 soname, or empty when absent."""
        var h = AMDGate._dlopen(String("libamdhip64.so.7"))
        if h:
            _ = external_call["dlclose", Int32](h.value())
            return String("libamdhip64.so.7")
        h = AMDGate._dlopen(String("libamdhip64.so"))
        if h:
            _ = external_call["dlclose", Int32](h.value())
            return String("libamdhip64.so")
        return String()

    @staticmethod
    def is_available() -> Bool:
        """Checks if a HIP runtime library is present on host system."""
        var opt_h = AMDGate.get_handle()
        if opt_h:
            _ = external_call["dlclose", Int32](opt_h.value())
            return True
        return False

    @staticmethod
    def _max_device_count() -> Tuple[Bool, Int]:
        """(ok, count) from MAX's HIP device enumeration.

        ok is False when MAX itself failed to enumerate, so callers
        can tell a runtime error apart from an honest zero.
        """
        try:
            var count = DeviceContext.number_of_devices(api="hip")
            if count < 0:
                return (False, Int(0))
            return (True, count)
        except:
            return (False, Int(0))

    @staticmethod
    def get_device_count() -> Int:
        """Live HIP device count; zero when absent or on error."""
        var q = AMDGate._max_device_count()
        if not q[0]:
            return 0
        return q[1]

    @staticmethod
    def gate_status() -> Int:
        """HIP_GATE_PRESENT / HIP_GATE_ABSENT / HIP_GATE_ERROR."""
        if AMDGate.hip_soname().byte_length() == 0:
            return HIP_GATE_ABSENT
        var q = AMDGate._max_device_count()
        if not q[0]:
            return HIP_GATE_ERROR
        if q[1] > 0:
            return HIP_GATE_PRESENT
        return HIP_GATE_ABSENT

    @staticmethod
    def classify_discovery_error(message: String) -> DiscoveryStatus:
        """Classify a runtime error without converting it into device success."""
        if (
            "permission" in message
            or "Permission" in message
            or "not permitted" in message
        ):
            return DiscoveryStatus(DiscoveryStatus.PERMISSION_DENIED)
        if "architecture" in message or "compute capability" in message:
            return DiscoveryStatus(DiscoveryStatus.UNSUPPORTED_ARCHITECTURE)
        if "driver" in message or "Driver" in message:
            return DiscoveryStatus(DiscoveryStatus.INCOMPATIBLE_DRIVER)
        if (
            "libamdhip64" in message
            or "HIP runtime" in message
            or "unsupported runtime" in message
        ):
            return DiscoveryStatus(DiscoveryStatus.UNSUPPORTED_RUNTIME)
        return DiscoveryStatus(DiscoveryStatus.PROBE_FAILED)

    @staticmethod
    def discover_physical_devices() -> HardwareDiscoveryResult:
        """Enumerate and inspect every HIP device exposed by MAX.

        Mirrors CUDAGate.discover_physical_devices for the AMD realm:
        MAX DeviceContext(api="hip") supplies identity, compatibility,
        and memory; the fit selector downstream consumes the same
        HardwareDiscoveryResult shape as the CUDA road.
        """
        var devices = List[PhysicalDevice]()
        if not AMDGate.is_available():
            return HardwareDiscoveryResult(
                DiscoveryStatus(DiscoveryStatus.UNSUPPORTED_RUNTIME),
                "HIP runtime library is not loadable",
                devices,
            )
        var counted = AMDGate._max_device_count()
        if not counted[0]:
            return HardwareDiscoveryResult(
                DiscoveryStatus(DiscoveryStatus.PROBE_FAILED),
                "MAX HIP device enumeration failed",
                devices,
            )
        var device_count = counted[1]
        if device_count <= 0:
            return HardwareDiscoveryResult(
                DiscoveryStatus(DiscoveryStatus.NO_DEVICE),
                "MAX reported no HIP devices",
                devices,
            )
        for backend_index in range(device_count):
            try:
                with DeviceContext(backend_index, api="hip") as context:
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
                        GPURealmType(GPURealmType.AMD_ROCM_HIP),
                        backend_index,
                        runtime_id,
                        "hip:max-id:" + String(runtime_id),
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
                        "HIP discovery stopped after backend index "
                        + String(backend_index)
                        + ": "
                        + message,
                        devices,
                    )
                return HardwareDiscoveryResult(
                    AMDGate.classify_discovery_error(message), message, devices
                )
        return HardwareDiscoveryResult(
            DiscoveryStatus(DiscoveryStatus.SUCCESS),
            "MAX HIP discovery completed",
            devices,
        )

    @staticmethod
    def runtime_version() -> Int:
        """HIP runtime version integer, or -1 when unavailable."""
        try:
            with DeviceContext(0, api="hip") as context:
                return context.get_api_version()
        except:
            return -1

    @staticmethod
    def _kfd_gpu_node() -> Tuple[String, Int]:
        """(node name, gfx_target_version) of the first KFD GPU node.

        ("", -1) when the KFD topology is absent or states no gfx
        target. Node 0 is the CPU node (version 0); GPU nodes carry
        a positive gfx_target_version.
        """
        try:
            var nodes = run_checked_argv(
                ["ls", "/sys/class/kfd/kfd/topology/nodes"], 4096
            )
            for raw_node in nodes.split("\n"):
                var node = String(raw_node.strip())
                if node.byte_length() == 0:
                    continue
                var props = _read_text_or_empty(
                    "/sys/class/kfd/kfd/topology/nodes/"
                    + node
                    + "/properties"
                )
                if props.byte_length() == 0:
                    continue
                var version = -1
                try:
                    version = parse_kfd_gfx_target_version(props)
                except:
                    version = -1
                if version > 0:
                    return (node, version)
        except:
            pass
        return (String(""), Int(-1))

    @staticmethod
    def kfd_gfx_target_version() -> Int:
        """The kernel-stated gfx_target_version, or -1 when absent."""
        return AMDGate._kfd_gpu_node()[1]

    @staticmethod
    def get_device_properties(device: Int) -> HipDeviceProperties:
        """Live properties for one HIP device index.

        Runtime fields come from MAX DeviceContext(api="hip"); the
        gfx target and memory clock / bus width come from the KFD
        topology. Returns the all--1 record when the runtime is
        absent, the index is out of range, or the query fails;
        trust the record only when plausible() accepts it.
        """
        var props = HipDeviceProperties()
        if device < 0:
            return props
        try:
            with DeviceContext(device, api="hip") as context:
                props.name = context.name()
                var memory = context.get_memory_info()
                props.total_memory_bytes = Int(memory[1])
                props.compute_major = context.get_attribute(
                    DeviceAttribute.COMPUTE_CAPABILITY_MAJOR
                )
                props.compute_minor = context.get_attribute(
                    DeviceAttribute.COMPUTE_CAPABILITY_MINOR
                )
                props.multi_processor_count = context.get_attribute(
                    DeviceAttribute.MULTIPROCESSOR_COUNT
                )
                props.max_threads_per_block = context.get_attribute(
                    DeviceAttribute.MAX_THREADS_PER_BLOCK
                )
                props.max_threads_per_multi_processor = (
                    context.get_attribute(
                        DeviceAttribute.MAX_THREADS_PER_MULTIPROCESSOR
                    )
                )
                props.wavefront_size = context.get_attribute(
                    DeviceAttribute.WARP_SIZE
                )
                props.clock_rate_khz = context.get_attribute(
                    DeviceAttribute.CLOCK_RATE
                )
        except:
            return HipDeviceProperties()
        var node = AMDGate._kfd_gpu_node()
        if node[1] > 0:
            props.gfx_arch = format_gfx_target(node[1])
            props.gcn_arch = (
                (node[1] // 10000) * 100
                + ((node[1] // 100) % 100) * 10
                + (node[1] % 100)
            )
            var bank = _read_text_or_empty(
                "/sys/class/kfd/kfd/topology/nodes/"
                + node[0]
                + "/mem_banks/0/properties"
            )
            if bank.byte_length() > 0:
                try:
                    var mhz = parse_mem_bank_clock_mhz(bank)
                    if mhz > 0:
                        props.memory_clock_rate_khz = mhz * 1000
                except:
                    pass
                try:
                    var width = parse_mem_bank_width(bank)
                    if width > 0:
                        props.memory_bus_width_bits = width
                except:
                    pass
        return props

    @staticmethod
    def allocate_vram(size_bytes: Int) raises -> Pointer[Scalar[f16], MutUntrackedOrigin]:
        """Rejects simulated HIP allocation until hipMalloc is integrated."""
        if size_bytes <= 0:
            raise Error(coded_error_text("VAL-003", "AMDGate.allocate_vram: size_bytes must be positive"))
        raise Error(coded_error_text("GPU-002", "AMDGate.allocate_vram: physical HIP VRAM allocation is not implemented"))

    @staticmethod
    def free_vram(ptr: Pointer[Scalar[f16], MutUntrackedOrigin]) raises:
        """Reserved AMD free entry point; always fails closed."""
        _ = ptr
        raise Error(coded_error_text("GPU-002", "AMDGate.free_vram: physical HIP VRAM ownership is not implemented"))

    @staticmethod
    def memcpy_host_to_device(
        dst_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Reserved AMD host-to-device transfer; always fails closed."""
        _ = dst_dev
        _ = src_host
        if size_bytes <= 0:
            return
        raise Error(coded_error_text("GPU-002", "AMDGate.memcpy_host_to_device: physical HIP transfer is not implemented"))

    @staticmethod
    def memcpy_device_to_host(
        dst_host: Pointer[Scalar[f16], MutUntrackedOrigin],
        src_dev: Pointer[Scalar[f16], MutUntrackedOrigin],
        size_bytes: Int
    ) raises:
        """Reserved AMD device-to-host transfer; always fails closed."""
        _ = dst_host
        _ = src_dev
        if size_bytes <= 0:
            return
        raise Error(coded_error_text("GPU-002", "AMDGate.memcpy_device_to_host: physical HIP transfer is not implemented"))

    @staticmethod
    def launch_gemm_amd(
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16]
    ) raises:
        """
        Validates shapes and rejects execution until a real HIP kernel exists.
        """
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0 or C.rows <= 0 or C.cols <= 0:
            raise Error(coded_error_text("VAL-003", "AMDGate.launch_gemm_amd: non-positive matrix dimensions are prohibited"))
        if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
            raise Error(coded_error_text("VAL-003", "AMDGate.launch_gemm_amd: GEMM shape mismatch"))

        raise Error(coded_error_text("GPU-002", "AMD ROCm HIP GPU execution is not implemented: no physical HIP kernel was launched"))
