# tests/test_hip_errors_a089.mojo
# A-089: HIP error semantics. Every mapped HIP error code is
# fault-injected and must raise the ERROR_TAXONOMY code filed in
# core/hip_errors.mojo, with the symbolic hipError_t name preserved
# in the raised text. Real gateway paths are checked for the same
# structured shape (never the pre-A-089 blanket GPU-001/GPU-004).

from core.hip_errors import (
    hip_error_is_mapped,
    hip_error_name,
    hip_error_text,
    hip_taxonomy_code,
    inject_hip_failure,
)
from core.structured_errors import (
    FAIL_INIT,
    FAIL_SYNC,
    backend_error_code,
    is_known_taxonomy_code,
    structured_code_of,
    taxonomy_name_for_structured_code,
)
from core.hip_memory import HipMemory
from core.hip_transfer import HipTransfer


def expect_map(rc: Int, expected_code: String, expected_name: String) raises:
    var code = hip_taxonomy_code(rc)
    if code != expected_code:
        raise Error("A-089 mapping rc=" + String(rc) + ": expected " + expected_code + ", got " + code)
    if hip_error_name(rc) != expected_name:
        raise Error("A-089 name rc=" + String(rc) + ": expected " + expected_name + ", got " + hip_error_name(rc))
    if not is_known_taxonomy_code(code):
        raise Error("A-089 mapping produced unknown taxonomy code " + code)
    if not hip_error_is_mapped(rc):
        raise Error("A-089 rc=" + String(rc) + " should be mapped")
    var text = hip_error_text(rc, "probe")
    if structured_code_of(text) != expected_code:
        raise Error("A-089 rendered text lost its code: " + text)
    if expected_name not in text:
        raise Error("A-089 rendered text lost the HIP name: " + text)


def expect_inject(rc: Int, expected_code: String, expected_name: String) raises:
    var raised = False
    try:
        inject_hip_failure(rc)
    except error:
        raised = True
        var text = String(error)
        if expected_code not in text:
            raise Error("A-089 injection rc=" + String(rc) + ": expected code " + expected_code + " in: " + text)
        if expected_name not in text:
            raise Error("A-089 injection rc=" + String(rc) + ": lost HIP name in: " + text)
        if "fault_injection" not in text:
            raise Error("A-089 injection lost operation field: " + text)
    if not raised:
        raise Error("A-089 injection did not raise for rc=" + String(rc))


def test_hip_errors_mapping_table() raises:
    print("--- Testing A-089 HIP code -> taxonomy mapping table ---")
    expect_map(1, "VAL-003", "hipErrorInvalidValue")
    expect_map(2, "MEM-003", "hipErrorOutOfMemory")
    expect_map(3, "GPU-012", "hipErrorNotInitialized")
    expect_map(4, "GPU-012", "hipErrorDeinitialized")
    expect_map(9, "VAL-003", "hipErrorInvalidConfiguration")
    expect_map(17, "VAL-003", "hipErrorInvalidDevicePointer")
    expect_map(21, "VAL-003", "hipErrorInvalidMemcpyDirection")
    expect_map(35, "GPU-006", "hipErrorInsufficientDriver")
    expect_map(53, "GPU-003", "hipErrorPriorLaunchFailure")
    expect_map(98, "GPU-003", "hipErrorInvalidDeviceFunction")
    expect_map(100, "GPU-002", "hipErrorNoDevice")
    expect_map(101, "VAL-003", "hipErrorInvalidDevice")
    expect_map(400, "VAL-003", "hipErrorInvalidHandle")
    expect_map(600, "GPU-004", "hipErrorNotReady")
    expect_map(700, "GPU-005", "hipErrorIllegalAddress")
    expect_map(701, "GPU-003", "hipErrorLaunchOutOfResources")
    expect_map(702, "GPU-004", "hipErrorLaunchTimeOut")
    expect_map(712, "VAL-003", "hipErrorHostMemoryAlreadyRegistered")
    expect_map(713, "VAL-003", "hipErrorHostMemoryNotRegistered")
    expect_map(719, "GPU-003", "hipErrorLaunchFailure")
    expect_map(720, "GPU-003", "hipErrorCooperativeLaunchTooLarge")
    expect_map(801, "GPU-002", "hipErrorNotSupported")
    expect_map(999, "INT-001", "hipErrorUnknown")
    expect_map(1052, "MEM-003", "hipErrorRuntimeMemory")
    expect_map(1053, "INT-001", "hipErrorRuntimeOther")
    expect_map(52, "VAL-003", "hipErrorMissingConfiguration")
    expect_map(201, "GPU-001", "hipErrorInvalidContext")
    expect_map(209, "GPU-002", "hipErrorNoBinaryForGpu")
    expect_map(214, "GPU-005", "hipErrorECCNotCorrectable")
    expect_map(215, "GPU-002", "hipErrorUnsupportedLimit")
    expect_map(401, "INT-001", "hipErrorIllegalState")
    expect_map(709, "GPU-001", "hipErrorContextIsDestroyed")
    expect_map(710, "GPU-003", "hipErrorAssert")
    print("A-089 mapping table (33 mapped codes): PASS")


def test_hip_errors_fault_injection() raises:
    print("--- Testing A-089 fault injection per mapped HIP code ---")
    expect_inject(1, "VAL-003", "hipErrorInvalidValue")
    expect_inject(2, "MEM-003", "hipErrorOutOfMemory")
    expect_inject(3, "GPU-012", "hipErrorNotInitialized")
    expect_inject(4, "GPU-012", "hipErrorDeinitialized")
    expect_inject(9, "VAL-003", "hipErrorInvalidConfiguration")
    expect_inject(17, "VAL-003", "hipErrorInvalidDevicePointer")
    expect_inject(21, "VAL-003", "hipErrorInvalidMemcpyDirection")
    expect_inject(35, "GPU-006", "hipErrorInsufficientDriver")
    expect_inject(53, "GPU-003", "hipErrorPriorLaunchFailure")
    expect_inject(98, "GPU-003", "hipErrorInvalidDeviceFunction")
    expect_inject(100, "GPU-002", "hipErrorNoDevice")
    expect_inject(101, "VAL-003", "hipErrorInvalidDevice")
    expect_inject(400, "VAL-003", "hipErrorInvalidHandle")
    expect_inject(600, "GPU-004", "hipErrorNotReady")
    expect_inject(700, "GPU-005", "hipErrorIllegalAddress")
    expect_inject(701, "GPU-003", "hipErrorLaunchOutOfResources")
    expect_inject(702, "GPU-004", "hipErrorLaunchTimeOut")
    expect_inject(712, "VAL-003", "hipErrorHostMemoryAlreadyRegistered")
    expect_inject(713, "VAL-003", "hipErrorHostMemoryNotRegistered")
    expect_inject(719, "GPU-003", "hipErrorLaunchFailure")
    expect_inject(720, "GPU-003", "hipErrorCooperativeLaunchTooLarge")
    expect_inject(801, "GPU-002", "hipErrorNotSupported")
    expect_inject(999, "INT-001", "hipErrorUnknown")
    expect_inject(1052, "MEM-003", "hipErrorRuntimeMemory")
    expect_inject(1053, "INT-001", "hipErrorRuntimeOther")
    expect_inject(52, "VAL-003", "hipErrorMissingConfiguration")
    expect_inject(201, "GPU-001", "hipErrorInvalidContext")
    expect_inject(209, "GPU-002", "hipErrorNoBinaryForGpu")
    expect_inject(214, "GPU-005", "hipErrorECCNotCorrectable")
    expect_inject(215, "GPU-002", "hipErrorUnsupportedLimit")
    expect_inject(401, "INT-001", "hipErrorIllegalState")
    expect_inject(709, "GPU-001", "hipErrorContextIsDestroyed")
    expect_inject(710, "GPU-003", "hipErrorAssert")
    print("A-089 fault injection (33 mapped codes): PASS")


def test_hip_errors_fallback_and_success() raises:
    print("--- Testing A-089 fallback, sentinel and success handling ---")
    if hip_error_name(0) != "hipSuccess":
        raise Error("A-089 rc=0 must name hipSuccess")
    if hip_error_is_mapped(0):
        raise Error("A-089 rc=0 (hipSuccess) must not count as a mapped error")
    if hip_taxonomy_code(-1) != "GPU-002":
        raise Error("A-089 shim-absent sentinel -1 must map to GPU-002")
    if hip_taxonomy_code(4242) != "INT-001":
        raise Error("A-089 unmapped code must fail closed to INT-001")
    if hip_error_name(4242) != "hipErrorUnmapped":
        raise Error("A-089 unmapped code must name hipErrorUnmapped")
    if hip_error_is_mapped(4242):
        raise Error("A-089 unmapped code must not claim to be mapped")
    expect_inject(4242, "INT-001", "hipErrorUnmapped")
    if taxonomy_name_for_structured_code("GPU-005") != "ILLEGAL_MEMORY_ACCESS":
        raise Error("A-089 GPU-005 taxonomy name missing in structured_errors")
    print("A-089 fallback/sentinel/success: PASS")


def test_hip_errors_gateway_consistency() raises:
    print("--- Testing A-089 consistency with the A-033 table ---")
    if backend_error_code("hip", FAIL_INIT) != hip_taxonomy_code(3):
        raise Error("A-089/A-033 init disagreement: A-033 hip init vs rc=3")
    if backend_error_code("hip", FAIL_SYNC) != hip_taxonomy_code(702):
        raise Error("A-089/A-033 sync disagreement: A-033 hip sync vs rc=702")
    if hip_taxonomy_code(700) != "GPU-005":
        raise Error("A-089 illegal address must be GPU-005")
    var cases = 0
    try:
        _ = HipMemory.allocate(0)
    except error:
        cases += 1
        if "VAL-003" not in String(error):
            raise Error("HipMemory.allocate(0) lost its VAL-003 code: " + String(error))
    try:
        _ = HipTransfer.host_allocate(0)
    except error:
        cases += 1
        if "VAL-003" not in String(error):
            raise Error("HipTransfer.host_allocate(0) lost its VAL-003 code: " + String(error))
    if cases != 2:
        raise Error("A-089 gateway consistency: expected 2 coded rejections, saw " + String(cases))
    print("A-089 gateway consistency: PASS")


def test_hip_errors_real_paths() raises:
    print("--- Testing A-089 real HIP gateway failure paths ---")
    var huge = 1152921504606846976
    var mem_raised = False
    try:
        var ptr = HipMemory.allocate(huge)
        HipMemory.free(ptr)
    except error:
        mem_raised = True
        var text = String(error)
        if "HipMemory.allocate" not in text:
            raise Error("A-089 real alloc path lost its site: " + text)
        if structured_code_of(text) == "":
            raise Error("A-089 real alloc path raised an uncoded error: " + text)
        if HipMemory.runtime_available() and "MEM-003" not in text:
            raise Error("A-089 real OOM path must be MEM-003 coded on this host: " + text)
    if not mem_raised:
        raise Error("A-089 real alloc path: a 1 EiB allocation unexpectedly succeeded")
    var xfer_raised = False
    try:
        var ptr2 = HipTransfer.host_allocate(huge)
        HipTransfer.host_free(ptr2)
    except error:
        xfer_raised = True
        var text2 = String(error)
        if "HipTransfer.host_allocate" not in text2:
            raise Error("A-089 real host-alloc path lost its site: " + text2)
        if structured_code_of(text2) == "":
            raise Error("A-089 real host-alloc path raised an uncoded error: " + text2)
        if HipMemory.runtime_available() and "MEM-003" not in text2 and "MEM-001" not in text2:
            raise Error("A-089 real host OOM path must be memory coded on this host: " + text2)
    if not xfer_raised:
        raise Error("A-089 real host-alloc path: a 1 EiB allocation unexpectedly succeeded")
    print("A-089 real gateway paths (OOM fault injection, live runtime): PASS")
