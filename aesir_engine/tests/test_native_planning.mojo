"""Injected memory and device policy evidence; no physical hardware claims."""
from core.native_hardware import parse_linux_memory, bounded_decimal
from core.inference_memory import InferenceMemoryPlan, llama3_memory_plan, gemma4_memory_plan
from core.runtime_plan import select_planned_cuda
from core.mimir_well import HardwareDiscoveryResult, PhysicalDevice, GPURealmType, DiscoveryStatus
from tests.test_hardware_discovery import make_device
from cli.hardware import dispatch_compute, dispatch_hardware


def test_host_memory_observations() raises:
    var memory = parse_linux_memory("MemTotal:   16384 kB\nMemFree: 100 kB\nMemAvailable:\t12000 kB\n")
    if memory.total_bytes != 16777216 or memory.available_bytes != 12288000:
        raise Error("Linux memory unit conversion failed")
    var bad: List[String] = ["", "MemTotal: 16 kB\n", "MemTotal: 16 kB\nMemAvailable: 17 kB",
                             "MemTotal: 16 MB\nMemAvailable: 10 kB", "MemTotal: 16 kB\nMemTotal: 16 kB\nMemAvailable: 10 kB",
                             "MemTotal: 9223372036854775807 kB\nMemAvailable: 1 kB"]
    for text in bad:
        var rejected = False
        try:
            _ = parse_linux_memory(text)
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed host observation accepted")


def test_native_memory_counts() raises:
    var llama = llama3_memory_plan(4692668960, 8192)
    if llama.kv_bytes != 1073741824 or llama.activation_bytes != 2576896 or llama.device_bytes != 5768987684:
        raise Error("Llama 8K buffer accounting mismatch")
    var gemma = gemma4_memory_plan(4977171584, 32768)
    if gemma.kv_bytes != 1115684864 or gemma.activation_bytes != 3682816:
        raise Error("Gemma local/global buffer accounting mismatch")
    if llama.host_upload_bytes != 4759777828 or llama.host_staging_bytes != 67108864:
        raise Error("Host admission must account for mapped weights and bounded staging")


def test_native_memory_rejection() raises:
    var plan = InferenceMemoryPlan(100, 200, 300)
    plan.admit(704, 304, 100)
    if plan.fits(703, 100) or plan.fits(100, 101):
        raise Error("Memory admission ignored reserve")
    var cases: List[Int] = [0, 1, 2]
    for choice in cases:
        var rejected = False
        try:
            if choice == 0:
                plan.admit(704, 303, 100)
            elif choice == 1:
                _ = InferenceMemoryPlan(9223372036854775807, 1, 1)
            else:
                _ = plan.fits(1000, -1)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid inference memory plan accepted")


def test_native_device_selection() raises:
    var devices = List[PhysicalDevice]()
    for i in range(3):
        var device = make_device(GPURealmType(GPURealmType.NVIDIA_CUDA), i, Int64(i), "injected:" + String(i), "cuda", i != 2)
        device.capabilities.free_memory_bytes = UInt((i + 1) * 1000)
        devices.append(device^)
    var discovered = HardwareDiscoveryResult(DiscoveryStatus(DiscoveryStatus.SUCCESS), "injected devices", devices)
    var memory = InferenceMemoryPlan(100, 200, 300)
    if select_planned_cuda(memory, discovered, -1, 100) != 1 or select_planned_cuda(memory, discovered, 0, 100) != 0:
        raise Error("Explicit/automatic selection mismatch")
    var bad: List[Int] = [2, 3, -2]
    for index in bad:
        var rejected = False
        try:
            _ = select_planned_cuda(memory, discovered, index, 100)
        except:
            rejected = True
        if not rejected:
            raise Error("Unavailable/incompatible device selected")


def test_native_planning_cli_rejection() raises:
    var cases: List[String] = ["compute plan missing --device -1", "compute plan missing --reserve-mib 9999999999999999999",
        "compute plan missing --context 0", "compute plan missing --context 8 --context 9",
        "compute plan missing --unknown x", "hardware list --pretend"]
    for text in cases:
        var args = List[String]()
        for word in text.split(" "):
            args.append(String(word))
        var rejected = False
        try:
            if args[0] == "hardware":
                dispatch_hardware(args)
            else:
                dispatch_compute(args)
        except error:
            if "Failed to open GGUF" in String(error):
                raise Error("Invalid planning option reached model I/O")
            rejected = True
        if not rejected:
            raise Error("Invalid planning CLI accepted")
