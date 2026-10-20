# Direct consumer of the production result handler. No device access.
from hailbru.soc_driver import _checked_ioctl_result


def rejected(operation: String, result: Int64, errno: Int64, code: String) raises:
    var caught = False
    try:
        _ = _checked_ioctl_result(operation, result, errno)
    except error:
        if String(error).find(code) >= 0:
            caught = True
        else:
            raise error
    if not caught:
        raise Error("result was unexpectedly admitted: " + operation)


def main() raises:
    if _checked_ioctl_result("transfer", 5, 0) != 5:
        raise Error("observed descriptor count was lost")
    if _checked_ioctl_result("transfer", 0, 5) != 0:
        raise Error("raw nonnegative transfer result was reinterpreted")
    if _checked_ioctl_result("transfer", 65535, 5) != 65535:
        raise Error("positive count was narrowed or stale errno used")
    if _checked_ioctl_result("driver-info", 0, 5) != 0:
        raise Error("successful query used stale errno")
    rejected("driver-info", 5, 0, "SocDriverMismatch")
    rejected("transfer", -1, 5, "SocIoctlFailed")
    rejected("properties", -1, 9, "SocIoctlFailed")
    print("PASS: observed positive count, raw nonnegative counts, stale errno and negative/unexpected results")
