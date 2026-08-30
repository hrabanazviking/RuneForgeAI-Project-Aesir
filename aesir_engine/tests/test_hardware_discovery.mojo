# aesir_engine/tests/test_hardware_discovery.mojo
# Deterministic CPU-only verification for physical-device admission contracts.

from core.cuda_gate import CUDAGate
from core.mimir_well import (
    DeviceCapabilities,
    DeviceTopology,
    DiscoveryStatus,
    GPURealmType,
    HardwareDiscoveryResult,
    PhysicalDevice,
)


def make_capabilities(compatible: Bool = True) -> DeviceCapabilities:
    """Build explicitly injected capability data for CPU-only contract tests."""
    return DeviceCapabilities(
        compatible,
        12040,
        UInt(3 * 1024 * 1024),
        UInt(6 * 1024 * 1024),
        7,
        5,
        30,
        1024,
    )


def make_device(
    realm: GPURealmType,
    backend_index: Int,
    runtime_id: Int64,
    stable_id: String,
    api: String,
    compatible: Bool = True,
) -> PhysicalDevice:
    """Build an explicitly injected physical-device record for contract tests.
    """
    return PhysicalDevice(
        realm,
        backend_index,
        runtime_id,
        stable_id,
        "injected-test-device-" + String(backend_index),
        api,
        make_capabilities(compatible),
    )


def test_discovery_status_classification() raises:
    """Prove every required runtime failure has a stable distinct category."""
    if (
        CUDAGate.classify_discovery_error("Permission denied").value
        != DiscoveryStatus.PERMISSION_DENIED
    ):
        raise Error("permission discovery status mismatch")
    if (
        CUDAGate.classify_discovery_error("ptxas compiler tool missing").value
        != DiscoveryStatus.MISSING_COMPILER_TOOL
    ):
        raise Error("compiler-tool discovery status mismatch")
    if (
        CUDAGate.classify_discovery_error("unsupported architecture").value
        != DiscoveryStatus.UNSUPPORTED_ARCHITECTURE
    ):
        raise Error("architecture discovery status mismatch")
    if (
        CUDAGate.classify_discovery_error("incompatible driver version").value
        != DiscoveryStatus.INCOMPATIBLE_DRIVER
    ):
        raise Error("driver discovery status mismatch")
    if (
        CUDAGate.classify_discovery_error("libcuda unavailable").value
        != DiscoveryStatus.UNSUPPORTED_RUNTIME
    ):
        raise Error("runtime discovery status mismatch")
    if (
        CUDAGate.classify_discovery_error("unclassified failure").value
        != DiscoveryStatus.PROBE_FAILED
    ):
        raise Error("generic discovery status mismatch")

    var empty = List[PhysicalDevice]()
    var no_device = HardwareDiscoveryResult(
        DiscoveryStatus(DiscoveryStatus.NO_DEVICE),
        "injected no-device result",
        empty,
    )
    no_device.validate()
    print("discovery failure status classification: PASS")


def test_physical_device_admission() raises:
    """Reject incomplete identity, impossible memory, and contradictory results.
    """
    var valid = make_device(
        GPURealmType(GPURealmType.NVIDIA_CUDA),
        0,
        Int64(17),
        "cuda:max-id:17",
        "cuda",
    )
    valid.validate()

    var bad_identity = make_device(
        GPURealmType(GPURealmType.NVIDIA_CUDA),
        0,
        Int64(17),
        "",
        "cuda",
    )
    var identity_rejected = False
    try:
        bad_identity.validate()
    except error:
        identity_rejected = "stable_id must not be empty" in String(error)
    if not identity_rejected:
        raise Error("PhysicalDevice accepted an empty stable ID")

    var impossible_capabilities = DeviceCapabilities(
        True, 12040, UInt(7), UInt(6), 7, 5, 30, 1024
    )
    var memory_rejected = False
    try:
        impossible_capabilities.validate()
    except error:
        memory_rejected = "free memory exceeds total memory" in String(error)
    if not memory_rejected:
        raise Error("DeviceCapabilities accepted impossible memory telemetry")

    var no_devices = List[PhysicalDevice]()
    var contradictory = HardwareDiscoveryResult(
        DiscoveryStatus(DiscoveryStatus.SUCCESS), "", no_devices
    )
    var result_rejected = False
    try:
        contradictory.validate()
    except error:
        result_rejected = "SUCCESS requires at least one device" in String(
            error
        )
    if not result_rejected:
        raise Error("HardwareDiscoveryResult accepted empty success")
    print("physical device admission invariants: PASS")


def test_topology_discovery_accumulation() raises:
    """Prove later backend results do not erase earlier observed devices."""
    var cuda_devices = List[PhysicalDevice]()
    cuda_devices.append(
        make_device(
            GPURealmType(GPURealmType.NVIDIA_CUDA),
            0,
            Int64(10),
            "cuda:max-id:10",
            "cuda",
        )
    )
    cuda_devices.append(
        make_device(
            GPURealmType(GPURealmType.NVIDIA_CUDA),
            1,
            Int64(11),
            "cuda:max-id:11",
            "cuda",
        )
    )
    var cuda_result = HardwareDiscoveryResult(
        DiscoveryStatus(DiscoveryStatus.SUCCESS), "", cuda_devices
    )

    var metal_devices = List[PhysicalDevice]()
    metal_devices.append(
        make_device(
            GPURealmType(GPURealmType.APPLE_METAL),
            0,
            Int64(20),
            "metal:max-id:20",
            "metal",
        )
    )
    var metal_result = HardwareDiscoveryResult(
        DiscoveryStatus(DiscoveryStatus.SUCCESS), "", metal_devices
    )

    var topology = DeviceTopology(1)
    topology.apply_gpu_discovery(cuda_result^)
    topology.apply_gpu_discovery(metal_result^)
    if len(topology.physical_devices) != 3:
        raise Error("DeviceTopology erased an earlier physical device")
    if len(topology.gpu_realms) != 2:
        raise Error("DeviceTopology failed to deduplicate discovered realms")
    if topology.gpu_realms[0] != GPURealmType.NVIDIA_CUDA:
        raise Error("DeviceTopology changed CUDA discovery order")
    if topology.gpu_realms[1] != GPURealmType.APPLE_METAL:
        raise Error("DeviceTopology mislabeled the Metal realm")

    var duplicate_devices = List[PhysicalDevice]()
    duplicate_devices.append(
        make_device(
            GPURealmType(GPURealmType.NVIDIA_CUDA),
            2,
            Int64(10),
            "cuda:max-id:10",
            "cuda",
        )
    )
    var duplicate_result = HardwareDiscoveryResult(
        DiscoveryStatus(DiscoveryStatus.SUCCESS), "", duplicate_devices
    )
    var duplicate_rejected = False
    try:
        topology.apply_gpu_discovery(duplicate_result^)
    except error:
        duplicate_rejected = "duplicate physical stable_id" in String(error)
    if not duplicate_rejected:
        raise Error("DeviceTopology accepted a duplicate stable ID")
    print("topology discovery accumulation: PASS")


def test_topology_stable_selection() raises:
    """Select compatible devices and reject absent or incompatible requests."""
    var devices = List[PhysicalDevice]()
    devices.append(
        make_device(
            GPURealmType(GPURealmType.NVIDIA_CUDA),
            0,
            Int64(30),
            "cuda:max-id:30",
            "cuda",
        )
    )
    devices.append(
        make_device(
            GPURealmType(GPURealmType.NVIDIA_CUDA),
            1,
            Int64(31),
            "cuda:max-id:31",
            "cuda",
            False,
        )
    )
    var result = HardwareDiscoveryResult(
        DiscoveryStatus(DiscoveryStatus.SUCCESS), "", devices
    )
    var topology = DeviceTopology(1)
    topology.apply_gpu_discovery(result^)

    var by_index = topology.select_gpu_by_index(
        GPURealmType(GPURealmType.NVIDIA_CUDA), 0
    )
    var by_stable_id = topology.select_gpu_by_stable_id("cuda:max-id:30")
    if by_index.runtime_id != Int64(30) or by_stable_id.backend_index != 0:
        raise Error("DeviceTopology stable selection returned the wrong device")

    var absent_rejected = False
    try:
        _ = topology.select_gpu_by_stable_id("cuda:max-id:missing")
    except:
        absent_rejected = True
    if not absent_rejected:
        raise Error("DeviceTopology accepted an unknown stable ID")

    var incompatible_rejected = False
    try:
        _ = topology.select_gpu_by_index(
            GPURealmType(GPURealmType.NVIDIA_CUDA), 1
        )
    except error:
        incompatible_rejected = "incompatible with MAX" in String(error)
    if not incompatible_rejected:
        raise Error("DeviceTopology selected an incompatible GPU")
    print("topology stable device selection: PASS")


def main() raises:
    test_discovery_status_classification()
    test_physical_device_admission()
    test_topology_discovery_accumulation()
    test_topology_stable_selection()
