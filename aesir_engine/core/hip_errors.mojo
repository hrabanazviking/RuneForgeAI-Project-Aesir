# core/hip_errors.mojo
# A-089: HIP error semantics. Every HIP error code (hipError_t, as
# returned through the A-011/A-012 shim as a plain Int32) mapped into
# the repo ERROR_TAXONOMY, extending the A-033 structured-errors
# table with per-code semantics for the HIP backend.
#
# Before A-089 the two HIP gateways collapsed every runtime code
# into one blanket code (HipMemory: GPU-001, HipTransfer: GPU-004),
# so an out-of-memory, an invalid argument and a dead device were
# indistinguishable in logs and tests. This module is the single
# mapping authority for raw HIP codes: hip_error_name (the symbolic
# hipError_t name), hip_taxonomy_code (the taxonomy code), and
# hip_error_text / raise_hip_error used by both gateways so a raised
# error always reads "CODE NAME: <site>: HIP error <rc>
# (<hipErrorName>)". Fault injection (inject_hip_failure) is the
# A-089 test entry point, one injection per mapped code.
#
# Mapping rationale (taxonomy text governs):
# - Invalid-argument family (InvalidValue, InvalidConfiguration,
#   InvalidDevicePointer, InvalidMemcpyDirection, InvalidHandle,
#   host-registration state) -> VAL-003 VALUE_OUT_OF_RANGE.
# - hipErrorOutOfMemory and the HSA runtime-memory error ->
#   MEM-003 OUT_OF_MEMORY (the exhausted-memory entry; MEM-002 stays
#   the null-return allocation entry used by the alloc sites).
# - Runtime init family (NotInitialized, Deinitialized) -> GPU-012
#   ROCM_INIT_FAILED, the HIP-specific init entry A-033 already
#   used for hip FAIL_INIT.
# - No-device family (NoDevice, InvalidDevice, NotSupported per the
#   A-033 unsupported precedent) -> GPU-002 DEVICE_NOT_FOUND.
# - Launch family (PriorLaunchFailure, InvalidDeviceFunction,
#   LaunchOutOfResources, LaunchFailure, CooperativeLaunchTooLarge)
#   -> GPU-003 KERNEL_LAUNCH_FAILED.
# - Completion/timeout family (LaunchTimeOut; NotReady when a
#   caller raises on it) -> GPU-004 DEVICE_SYNCHRONIZE_TIMEOUT.
#   NOTE: hipStreamQuery treats 600 (hipErrorNotReady) as a normal
#   poll result, never an error; the mapping applies only where a
#   600 is actually raised on (synchronize-style paths).
# - hipErrorIllegalAddress -> GPU-005 ILLEGAL_MEMORY_ACCESS (the
#   taxonomy entry A-033 did not need; named in structured_errors
#   by this slice).
# - hipErrorInsufficientDriver -> GPU-006 DRIVER_VERSION_MISMATCH.
# - Context lifecycle (InvalidContext, ContextIsDestroyed) ->
#   GPU-001 (the generic GPU init entry); kernel assert (710) ->
#   GPU-003; ECC-not-correctable (214) -> GPU-005 (device memory
#   hardware error); NoBinaryForGpu / UnsupportedLimit -> GPU-002
#   (unsupported precedent); MissingConfiguration (52) and
#   InvalidDevice (101, an out-of-range device ordinal) ->
#   VAL-003; IllegalState (401) -> the INT-001 fallback below.
# - Unknown / HSA runtime-other / any unmapped positive code ->
#   INT-001 INVARIANT_VIOLATED as a fail-closed fallback: an
#   unmapped HIP code is a defect in this table, never silently
#   re-labelled as an init or sync failure.
# Shim sentinels are NOT HIP codes and stay ahead of this mapping
# in the gateways: -1 (runtime not loadable) -> GPU-002, and the
# A-022 ownership codes -22004..-22016 -> VAL-003.

from core.structured_errors import taxonomy_name_for_structured_code

comptime HIP_SUCCESS = 0
comptime HIP_SHIM_ABSENT = -1


def hip_error_name(rc: Int) -> String:
    if rc == 0:
        return String("hipSuccess")
    if rc == 1:
        return String("hipErrorInvalidValue")
    if rc == 2:
        return String("hipErrorOutOfMemory")
    if rc == 3:
        return String("hipErrorNotInitialized")
    if rc == 4:
        return String("hipErrorDeinitialized")
    if rc == 9:
        return String("hipErrorInvalidConfiguration")
    if rc == 17:
        return String("hipErrorInvalidDevicePointer")
    if rc == 21:
        return String("hipErrorInvalidMemcpyDirection")
    if rc == 35:
        return String("hipErrorInsufficientDriver")
    if rc == 52:
        return String("hipErrorMissingConfiguration")
    if rc == 53:
        return String("hipErrorPriorLaunchFailure")
    if rc == 98:
        return String("hipErrorInvalidDeviceFunction")
    if rc == 100:
        return String("hipErrorNoDevice")
    if rc == 101:
        return String("hipErrorInvalidDevice")
    if rc == 201:
        return String("hipErrorInvalidContext")
    if rc == 209:
        return String("hipErrorNoBinaryForGpu")
    if rc == 214:
        return String("hipErrorECCNotCorrectable")
    if rc == 215:
        return String("hipErrorUnsupportedLimit")
    if rc == 400:
        return String("hipErrorInvalidHandle")
    if rc == 401:
        return String("hipErrorIllegalState")
    if rc == 600:
        return String("hipErrorNotReady")
    if rc == 700:
        return String("hipErrorIllegalAddress")
    if rc == 701:
        return String("hipErrorLaunchOutOfResources")
    if rc == 702:
        return String("hipErrorLaunchTimeOut")
    if rc == 712:
        return String("hipErrorHostMemoryAlreadyRegistered")
    if rc == 713:
        return String("hipErrorHostMemoryNotRegistered")
    if rc == 709:
        return String("hipErrorContextIsDestroyed")
    if rc == 710:
        return String("hipErrorAssert")
    if rc == 719:
        return String("hipErrorLaunchFailure")
    if rc == 720:
        return String("hipErrorCooperativeLaunchTooLarge")
    if rc == 801:
        return String("hipErrorNotSupported")
    if rc == 999:
        return String("hipErrorUnknown")
    if rc == 1052:
        return String("hipErrorRuntimeMemory")
    if rc == 1053:
        return String("hipErrorRuntimeOther")
    return String("hipErrorUnmapped")


def hip_taxonomy_code(rc: Int) -> String:
    if rc == HIP_SHIM_ABSENT:
        return String("GPU-002")
    if rc == 1 or rc == 9 or rc == 17 or rc == 21 or rc == 52 or rc == 101:
        return String("VAL-003")
    if rc == 400 or rc == 712 or rc == 713:
        return String("VAL-003")
    if rc == 2 or rc == 1052:
        return String("MEM-003")
    if rc == 3 or rc == 4:
        return String("GPU-012")
    if rc == 35:
        return String("GPU-006")
    if rc == 53 or rc == 98 or rc == 701 or rc == 719 or rc == 720:
        return String("GPU-003")
    if rc == 100 or rc == 209 or rc == 215 or rc == 801:
        return String("GPU-002")
    if rc == 600 or rc == 702:
        return String("GPU-004")
    if rc == 700 or rc == 214:
        return String("GPU-005")
    if rc == 201 or rc == 709:
        return String("GPU-001")
    if rc == 710:
        return String("GPU-003")
    return String("INT-001")


def hip_error_is_mapped(rc: Int) -> Bool:
    if rc == 0:
        return False
    return hip_error_name(rc) != "hipErrorUnmapped"


def hip_error_text(rc: Int, site: String) -> String:
    var code = hip_taxonomy_code(rc)
    return (
        code + " " + taxonomy_name_for_structured_code(code) + ": "
        + site + ": HIP error " + String(rc) + " (" + hip_error_name(rc) + ")"
    )


def raise_hip_error(site: String, rc: Int32) raises:
    raise Error(hip_error_text(Int(rc), site))


def inject_hip_failure(rc: Int) raises:
    raise_hip_error("fault_injection", Int32(rc))
