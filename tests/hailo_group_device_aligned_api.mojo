# Direct API deadline, fresh-owner and move consumer. Host mocks only.
from std.sys import argv
from hailbru.soc_group_device import GroupDeviceDeadline, run_group_device_aligned as run_group_device
from smidr.tools.group_rpc_device_mock import show_group_device
from smidr.tools.program_integrity import _signed


def main() raises:
    var args = argv()
    if len(args) == 5 and args[1] == "clock":
        var deadline = GroupDeviceDeadline(Int64(_signed(args[2])), Int64(_signed(args[3])))
        var moved = deadline^
        var remaining = moved.remaining_ms(Int64(_signed(args[4])))
        print("{\"remaining\":" + String(remaining) + ",\"physical_calls\":false}")
    elif len(args) == 5 and args[1] == "recover" and args[2] != "/sys" and args[3] != "/dev":
        var first = run_group_device(args[2], args[3], Int64(_signed(args[4])))
        show_group_device(first)
        if first.retained_views == 0 and not first.finalization_unconfirmed:
            var next = run_group_device(args[2], args[3], 1000)
            show_group_device(next)
            if not next.success():
                raise Error("GroupDeviceAlignedAPI: fresh owner failed")
    else:
        raise Error("GroupDeviceAlignedAPI: clock start budget now | recover mock-sysfs mock-dev timeout")
