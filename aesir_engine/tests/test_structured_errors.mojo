# tests/test_structured_errors.mojo
# A-033: Structured errors everywhere. Fault-injection tests per
# backend (cpu, hip, vulkan, npu, cuda) produce taxonomy-coded errors
# from ERROR_TAXONOMY.md, and real backend failure paths carry the
# same codes while preserving their original message text.

from core.structured_errors import (
    FAIL_ALLOC,
    FAIL_INIT,
    FAIL_INVALID,
    FAIL_LAUNCH,
    FAIL_SHAPE,
    FAIL_SYNC,
    FAIL_TRANSFER,
    FAIL_UNAVAILABLE,
    FAIL_UNSUPPORTED,
    backend_error_code,
    backend_failure,
    coded_error_text,
    error_text_is_structured,
    inject_backend_failure,
    is_known_taxonomy_code,
    structured_code_of,
    taxonomy_name_for_structured_code,
    translate_backend_error,
)
from core.amd_gate import AMDGate
from core.hip_memory import HipMemory
from core.vulkan_buffers import VulkanBuffers
from core.vulkan_context import taxonomy_code_for_vk_result
from core.backend_registry import build_backend_registry, RawBackendProbe
from core.mimir_well import MimirWell, RuneTensor, NPUBackendType, f16
from core.compute import gemm_f16_npu


def expect_code(backend: String, kind: Int, expected: String) raises:
    var got = backend_error_code(backend, kind)
    if got != expected:
        raise Error("A-033 mapping " + backend + ": expected " + expected + ", got " + got)
    if not is_known_taxonomy_code(got):
        raise Error("A-033 mapping produced unknown taxonomy code " + got)


def expect_injection(backend: String, kind: Int, expected: String) raises:
    var raised = False
    try:
        inject_backend_failure(backend, kind)
    except error:
        raised = True
        var text = String(error)
        if expected not in text:
            raise Error("A-033 injection " + backend + ": expected code " + expected + " in: " + text)
        if "backend=" + backend not in text:
            raise Error("A-033 injection lost backend field: " + text)
        if "fault_injection" not in text:
            raise Error("A-033 injection lost operation field: " + text)
    if not raised:
        raise Error("A-033 injection did not raise for backend " + backend)


def test_structured_errors_mapping_table() raises:
    print("--- Testing A-033 backend -> taxonomy mapping table ---")
    expect_code("cpu", FAIL_ALLOC, "MEM-001")
    expect_code("cpu", FAIL_LAUNCH, "INF-001")
    expect_code("cpu", FAIL_UNSUPPORTED, "MDL-010")
    expect_code("cpu", FAIL_INVALID, "VAL-003")
    expect_code("cpu", FAIL_UNAVAILABLE, "INT-002")
    expect_code("hip", FAIL_INIT, "GPU-012")
    expect_code("hip", FAIL_UNAVAILABLE, "GPU-002")
    expect_code("hip", FAIL_ALLOC, "MEM-002")
    expect_code("hip", FAIL_LAUNCH, "GPU-003")
    expect_code("hip", FAIL_SYNC, "GPU-004")
    expect_code("vulkan", FAIL_UNAVAILABLE, "GPU-002")
    expect_code("vulkan", FAIL_ALLOC, "MEM-002")
    expect_code("vulkan", FAIL_LAUNCH, "GPU-003")
    expect_code("npu", FAIL_UNAVAILABLE, "GPU-002")
    expect_code("npu", FAIL_INIT, "GPU-001")
    expect_code("npu", FAIL_UNSUPPORTED, "GPU-002")
    expect_code("cuda", FAIL_INIT, "GPU-001")
    expect_code("cuda", FAIL_UNAVAILABLE, "GPU-002")
    expect_code("cuda", FAIL_ALLOC, "MEM-002")
    expect_code("cuda", FAIL_SHAPE, "VAL-003")
    expect_code("cuda", FAIL_TRANSFER, "GPU-004")
    print("A-033 mapping table (21 rows): PASS")


def test_structured_errors_fault_injection() raises:
    print("--- Testing A-033 fault injection per backend ---")
    expect_injection("cpu", FAIL_ALLOC, "MEM-001")
    expect_injection("cpu", FAIL_LAUNCH, "INF-001")
    expect_injection("hip", FAIL_UNAVAILABLE, "GPU-002")
    expect_injection("hip", FAIL_INIT, "GPU-012")
    expect_injection("hip", FAIL_ALLOC, "MEM-002")
    expect_injection("vulkan", FAIL_LAUNCH, "GPU-003")
    expect_injection("vulkan", FAIL_SYNC, "GPU-004")
    expect_injection("npu", FAIL_UNAVAILABLE, "GPU-002")
    expect_injection("npu", FAIL_INVALID, "VAL-003")
    expect_injection("cuda", FAIL_INIT, "GPU-001")
    expect_injection("cuda", FAIL_ALLOC, "MEM-002")
    print("A-033 fault injection (5 backends, 11 injections): PASS")


def test_structured_errors_real_paths() raises:
    print("--- Testing A-033 real backend failure paths are coded ---")
    var cases = 0
    try:
        _ = AMDGate.allocate_vram(0)
    except error:
        cases += 1
        if "VAL-003" not in String(error) or "must be positive" not in String(error):
            raise Error("AMD allocate_vram(0) not VAL-003 coded: " + String(error))
    try:
        _ = AMDGate.allocate_vram(16)
    except error:
        cases += 1
        if "GPU-002" not in String(error) or "not implemented" not in String(error):
            raise Error("AMD allocate_vram(16) not GPU-002 coded: " + String(error))
    try:
        _ = HipMemory.allocate(0)
    except error:
        cases += 1
        if "VAL-003" not in String(error):
            raise Error("HipMemory.allocate(0) not VAL-003 coded: " + String(error))
    try:
        _ = VulkanBuffers.allocate(0)
    except error:
        cases += 1
        if "VAL-003" not in String(error):
            raise Error("VulkanBuffers.allocate(0) not VAL-003 coded: " + String(error))
    var reg = build_backend_registry(RawBackendProbe(), RawBackendProbe(), RawBackendProbe(), RawBackendProbe())
    try:
        _ = reg.capability_named("bogus")
    except error:
        cases += 1
        if "VAL-003" not in String(error) or "unknown backend runtime" not in String(error):
            raise Error("registry unknown runtime not VAL-003 coded: " + String(error))
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(4 * 32)
    var A = RuneTensor[f16](4, 32, a_ptr)
    var b_ptr = well.allocate(4 * 32)
    var B = RuneTensor[f16](4, 32, b_ptr)
    var c_ptr = well.allocate(4 * 4)
    var C = RuneTensor[f16](4, 4, c_ptr)
    try:
        gemm_f16_npu(A, B, C, NPUBackendType(NPUBackendType.INTEL_NPU))
    except error:
        cases += 1
        if "GPU-002" not in String(error) or "not implemented" not in String(error):
            raise Error("gemm_f16_npu not GPU-002 coded: " + String(error))
    if cases != 6:
        raise Error("A-033 real paths: expected 6 coded failures, saw " + String(cases))
    print("A-033 real backend paths (6 coded failures): PASS")


def test_structured_errors_translation() raises:
    print("--- Testing A-033 error translation and rendering ---")
    var bare = translate_backend_error("hip", "allocate", "something bare failed")
    if bare.code != "INT-002":
        raise Error("bare error did not translate to INT-002")
    var coded = translate_backend_error("hip", "allocate", "MEM-002 DEVICE_ALLOC_FAILED: hipMalloc returned null")
    if coded.code != "MEM-002":
        raise Error("coded error code was not preserved in translation")
    var rendered = backend_failure("vulkan", FAIL_LAUNCH, "dispatch", "vkQueueSubmit failed").render()
    if "GPU-003" not in rendered or "KERNEL_LAUNCH_FAILED" not in rendered:
        raise Error("render lost code or name: " + rendered)
    if "backend=vulkan" not in rendered or "op=dispatch" not in rendered or "severity=" not in rendered:
        raise Error("render lost structured fields: " + rendered)
    if not error_text_is_structured(rendered):
        raise Error("rendered error not recognised as structured")
    if structured_code_of("plain failure") != "":
        raise Error("plain text was falsely recognised as structured")
    if coded_error_text("GPU-002", "x") != "GPU-002 DEVICE_NOT_FOUND: x":
        raise Error("coded_error_text shape drifted")
    if taxonomy_name_for_structured_code("GPU-012") != "ROCM_INIT_FAILED":
        raise Error("GPU-012 taxonomy name drifted")
    print("A-033 translation/render: PASS")


def test_structured_errors_vulkan_cpu_consistency() raises:
    print("--- Testing A-033 Vulkan/CPU taxonomy consistency ---")
    if taxonomy_code_for_vk_result(-2) != backend_error_code("vulkan", FAIL_ALLOC):
        raise Error("Vulkan VkResult alloc mapping disagrees with A-033 table")
    if taxonomy_code_for_vk_result(-1000) != backend_error_code("vulkan", FAIL_UNAVAILABLE):
        raise Error("Vulkan absent mapping disagrees with A-033 table")
    var cpu_render = backend_failure("cpu", FAIL_ALLOC, "malloc", "host allocation failed").render()
    if "MEM-001" not in cpu_render or "HOST_MALLOC_FAILED" not in cpu_render:
        raise Error("CPU alloc render not MEM-001 coded: " + cpu_render)
    print("A-033 Vulkan/CPU consistency: PASS")
