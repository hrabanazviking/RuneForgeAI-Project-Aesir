"""Injected memory and device policy evidence; no physical hardware claims."""
from core.native_hardware import parse_linux_memory, bounded_decimal
from core.inference_memory import InferenceMemoryPlan, llama3_memory_plan, gemma4_memory_plan
from core.runtime_plan import explain_device_fit, explain_host_fit, select_planned_cuda, next_automatic_context
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
    if gemma.kv_bytes != 1115684864 or gemma.activation_bytes != 3699200:
        raise Error("Gemma local/global buffer accounting mismatch")
    if llama.host_upload_bytes != 4759777828 or llama.host_staging_bytes != 67108864:
        raise Error("Host admission must account for mapped weights and bounded staging")


def test_native_memory_rejection() raises:
    var plan = InferenceMemoryPlan(100, 200, 300)
    plan.admit(704, 304, 100)
    var exact_device = explain_device_fit(plan, 704, 100)
    var exact_host = explain_host_fit(plan, 304, 100)
    if (not exact_device.fits or exact_device.reason_code != "device_fit"
            or exact_device.usable_bytes != 604 or exact_device.headroom_bytes != 0
            or not exact_host.fits or exact_host.reason_code != "host_fit"
            or exact_host.usable_bytes != 204 or exact_host.headroom_bytes != 0):
        raise Error("Exact-fit memory explanation mismatch")
    var device_short = explain_device_fit(plan, 703, 100)
    var device_reserve = explain_device_fit(plan, 100, 101)
    var host_short = explain_host_fit(plan, 303, 100)
    if (device_short.reason_code != "device_required_exceeds_usable"
            or device_short.deficit_bytes != 1 or device_short.usable_bytes != 603
            or device_reserve.reason_code != "device_reserve_exceeds_available"
            or device_reserve.usable_bytes != 0 or device_reserve.deficit_bytes != 604
            or host_short.reason_code != "host_required_exceeds_usable"
            or host_short.deficit_bytes != 1 or host_short.usable_bytes != 203):
        raise Error("Rejected memory explanation lost exact arithmetic")
    var wide = explain_device_fit(plan, 9223372036854775807, 100)
    if not wide.fits or wide.headroom_bytes != 9223372036854775103:
        raise Error("Memory explanation overflow boundary mismatch")
    var admission_detail = String("")
    try:
        plan.admit(703, 304, 100)
    except error:
        admission_detail = String(error)
    if ("code=device_required_exceeds_usable" not in admission_detail
            or "deficit_bytes=1" not in admission_detail):
        raise Error("CUDA session admission did not use shared fit evidence")
    admission_detail = ""
    try:
        plan.admit(704, 303, 100)
    except error:
        admission_detail = String(error)
    if ("code=host_required_exceeds_usable" not in admission_detail
            or "deficit_bytes=1" not in admission_detail):
        raise Error("Host session admission did not use shared fit evidence")
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
    var hip = make_device(
        GPURealmType(GPURealmType.AMD_ROCM_HIP), 3, Int64(3),
        "injected:3", "hip"
    )
    devices.append(hip^)
    var huge = make_device(
        GPURealmType(GPURealmType.NVIDIA_CUDA), 4, Int64(4),
        "injected:4", "cuda"
    )
    huge.capabilities.total_memory_bytes = UInt(9223372036854775808)
    huge.capabilities.free_memory_bytes = UInt(9223372036854775808)
    devices.append(huge^)
    var discovered = HardwareDiscoveryResult(DiscoveryStatus(DiscoveryStatus.SUCCESS), "injected devices", devices)
    var memory = InferenceMemoryPlan(100, 200, 300)
    if select_planned_cuda(memory, discovered, -1, 100) != 1 or select_planned_cuda(memory, discovered, 0, 100) != 0:
        raise Error("Explicit/automatic selection mismatch")
    var bad: List[Int] = [2, 3, 4, 5, -2]
    for index in bad:
        var rejected = False
        try:
            _ = select_planned_cuda(memory, discovered, index, 100)
        except:
            rejected = True
        if not rejected:
            raise Error("Unavailable/incompatible device selected")
    var detail = String("")
    try:
        _ = select_planned_cuda(memory, discovered, 0, 397)
    except error:
        detail = String(error)
    if ("code=device_required_exceeds_usable" not in detail
            or "required_bytes=604" not in detail
            or "available_bytes=1000" not in detail
            or "reserve_bytes=397" not in detail
            or "usable_bytes=603" not in detail
            or "deficit_bytes=1" not in detail):
        raise Error("Device rejection did not retain exact fit evidence")
    detail = ""
    try:
        _ = select_planned_cuda(memory, discovered, 9, 100)
    except error:
        detail = String(error)
    if "requested_device_not_found" not in detail:
        raise Error("Missing requested device reason was not retained")
    var reason_cases: List[Int] = [2, 3, 4, 0]
    var expected: List[String] = [
        "device_incompatible", "device_api_not_cuda(api=hip)",
        "device_memory_exceeds_native_range",
        "code=device_reserve_exceeds_available"
    ]
    for i in range(len(reason_cases)):
        detail = ""
        try:
            _ = select_planned_cuda(
                memory, discovered, reason_cases[i],
                1001 if reason_cases[i] == 0 else 100
            )
        except error:
            detail = String(error)
        if expected[i] not in detail:
            raise Error("Device rejection reason was not retained: " + expected[i])


def test_automatic_context_sequence() raises:
    if (next_automatic_context(32768) != 16384
            or next_automatic_context(8192) != 4096
            or next_automatic_context(3000) != 2048
            or next_automatic_context(2048) != 0):
        raise Error("Automatic context fallback sequence drifted")
    var rejected = False
    try:
        _ = next_automatic_context(1)
    except:
        rejected = True
    if not rejected:
        raise Error("Automatic context accepted an invalid starting value")


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
