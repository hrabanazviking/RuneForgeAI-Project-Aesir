# HAILBRU named errors (H061+).
#
# Every fail-closed path in HAILBRU raises a named error of the form
#   HailbruError[<Code>]: <message>
# The PRÓF suite (H078) asserts these exact codes — never a bare non-zero
# exit. Codes are stable API (H079).

def herror(code: String, msg: String) -> Error:
    return Error("HailbruError[" + code + "]: " + msg)


def errno_error(op: String, path: String, e: Int64) -> Error:
    # Import cycle note: errno_name lives in syscall.mojo; this module is
    # imported alongside it and callers pass the formatted name. To keep
    # the dependency one-directional (errors <- syscall), callers in
    # syscall-adjacent code format via hailbru.syscall.errno_name.
    return herror("OsError", op + " " + path + ": errno " + String(e))


# Code catalogue (mirrors hailbru/API.md § errors):
#   DeviceNotFound, MultipleDevices, BadBdf, BadSysfs, ConfigReadFailed,
#   IdentityMismatch, BarParseFailed, MechanismUnavailable, WrongMechanism,
#   VfioError, UioError, BindError, PrivilegeRequired, DmaError, DmaLockFailed,
#   DoubleFree, UnknownBuffer, RegOutOfRange, RegUnaligned, ReadbackMismatch,
#   IrqTimeout, IrqSetupFailed, FirmwareMissing, FirmwareCorrupt,
#   FirmwareBootTimeout, DeviceNotReady, OsError
# Campaign 5 additions (H081-H100):
#   PowerTransitionFailed, PowerManagementUnsupported, DriverBindingMismatch,
#   VendorMirrorMismatch, StepOmitted, BootHang, FirmwareBootBanked,
#   DeviceRemoved, DeviceBusy
# Source-model transport additions:
#   BadRpcFrame, BadRpcHex, BadRpcProtobuf, RpcReplyMismatch, RpcRemoteFailure
#   BadSocAbi
