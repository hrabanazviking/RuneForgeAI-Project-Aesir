# Explicit HOST MOCK aligned diagnostic only; synthetic identity is not a device fact.
from std.sys import argv
from hailbru.soc_group_device import run_group_device_aligned
from smidr.tools.group_rpc_device_mock import show_group_device
from smidr.tools.program_integrity import _signed


def main() raises:
    var args = argv()
    if len(args) != 5 or args[1] != "host-mock-aligned" or args[2] == "/sys" or args[3] == "/dev":
        raise Error("GroupDeviceAlignedMock: host-mock-aligned mock-sysfs mock-dev timeout-ms")
    for i in range(2, 4):
        if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
            raise Error("GroupDeviceAlignedMock: invalid mock root")
    if args[4].byte_length() > 6:
        raise Error("GroupDeviceAlignedMock: unbounded timeout argument")
    var result = run_group_device_aligned(args[2], args[3], Int64(_signed(args[4])))
    show_group_device(result)
    if not result.success():
        raise Error("GroupDeviceAlignedMock: lifecycle or finalization unconfirmed")
