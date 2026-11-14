"""HIP native-serve admission: injected device policy evidence only.

No physical hardware claims: discovery records are fabricated with the
same helpers as the CUDA planning tests, and the config gate is pure.
The live HIP proof lives in the serve run, not in this file.
"""
from core.runtime_plan import select_planned_device_with_fit, select_planned_hip
from core.inference_memory import InferenceMemoryPlan
from core.mimir_well import HardwareDiscoveryResult, PhysicalDevice, GPURealmType, DiscoveryStatus
from core.amd_gate import AMDGate
from config import AesirConfig
from cli.native_settings import native_config_sampling
from tests.test_hardware_discovery import make_device


def _mixed_discovery() -> HardwareDiscoveryResult:
    var devices = List[PhysicalDevice]()
    for i in range(3):
        var device = make_device(GPURealmType(GPURealmType.NVIDIA_CUDA), i, Int64(i), "injected:" + String(i), "cuda", i != 2)
        device.capabilities.free_memory_bytes = UInt((i + 1) * 1000)
        devices.append(device^)
    var hip = make_device(
        GPURealmType(GPURealmType.AMD_ROCM_HIP), 3, Int64(3),
        "injected:3", "hip"
    )
    devices.append(hip^)
    return HardwareDiscoveryResult(DiscoveryStatus(DiscoveryStatus.SUCCESS), "injected devices", devices)


def test_hip_device_selection() raises:
    var discovered = _mixed_discovery()
    var memory = InferenceMemoryPlan(100, 200, 300)
    if select_planned_hip(memory, discovered, -1, 100) != 3 or select_planned_hip(memory, discovered, 3, 100) != 3:
        raise Error("HIP selection must land on the HIP device, automatic or explicit")
    var bad: List[Int] = [0, 1, 2, 4, -2]
    for index in bad:
        var rejected = False
        try:
            _ = select_planned_hip(memory, discovered, index, 100)
        except:
            rejected = True
        if not rejected:
            raise Error("CUDA/incompatible/absent device selected for HIP")


def test_hip_selection_refusal_names_hip() raises:
    var devices = List[PhysicalDevice]()
    var cuda_only = make_device(GPURealmType(GPURealmType.NVIDIA_CUDA), 0, Int64(0), "injected:0", "cuda")
    devices.append(cuda_only^)
    var discovered = HardwareDiscoveryResult(DiscoveryStatus(DiscoveryStatus.SUCCESS), "injected devices", devices)
    var memory = InferenceMemoryPlan(100, 200, 300)
    var message = String("")
    try:
        _ = select_planned_device_with_fit(memory, discovered, -1, 100, "hip")
    except error:
        message = String(error)
    if "No compatible HIP device fits" not in message or "device_api_not_hip" not in message:
        raise Error("HIP refusal must name the HIP realm and the api mismatch: " + message)


def test_hip_config_gate() raises:
    for backend in List[String](["auto", "cuda", "hip"]):
        var config = AesirConfig()
        config.acceleration_backend = backend
        _ = native_config_sampling(config)
    var bad = AesirConfig()
    bad.acceleration_backend = "tpu"
    var message = String("")
    try:
        _ = native_config_sampling(bad)
    except error:
        message = String(error)
    if "auto, cuda or hip" not in message:
        raise Error("Config gate must admit hip and name the admitted set: " + message)


def test_amd_discovery_classification() raises:
    if AMDGate.classify_discovery_error("open: permission denied").value != DiscoveryStatus.PERMISSION_DENIED:
        raise Error("Permission classification mismatch")
    if AMDGate.classify_discovery_error("libamdhip64.so.7: cannot open shared object").value != DiscoveryStatus.UNSUPPORTED_RUNTIME:
        raise Error("HIP runtime classification mismatch")
    if AMDGate.classify_discovery_error("unsupported architecture gfx9999").value != DiscoveryStatus.UNSUPPORTED_ARCHITECTURE:
        raise Error("Architecture classification mismatch")
    if AMDGate.classify_discovery_error("something else entirely").value != DiscoveryStatus.PROBE_FAILED:
        raise Error("Fallback classification mismatch")
