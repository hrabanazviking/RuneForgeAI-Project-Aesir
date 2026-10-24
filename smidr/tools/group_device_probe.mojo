# Original explicit one-child grouped control diagnostic. No model operation.
from std.sys import argv
from hailbru.soc_group_device import run_group_device
from hailbru.syscall import os_page_size


def _json_bool(value: Bool) -> String:
    return String("true") if value else String("false")


def main() raises:
    var args = argv()
    var physical = len(args) == 2 and args[1] == "physical-once"
    var sysfs = String("/sys")
    var devices = String("/dev")
    if not physical:
        if len(args) != 4 or args[1] != "host-mock" or args[2] == "/sys" or args[3] == "/dev":
            raise Error("GroupDeviceProbe: physical-once OR host-mock mock-sysfs mock-dev")
        for i in range(2, 4):
            if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
                raise Error("GroupDeviceProbe: invalid mock root")
        sysfs = args[2]
        devices = args[3]
    # Admission precedes the fresh owner. Driver/device properties are checked
    # by open_soc_driver before descriptor allocation, mapping or launch.
    if os_page_size() != 16384:
        raise Error("GroupDeviceProbe: expected qualified host page size 16384")
    var result = run_group_device(sysfs, devices, 5000)
    # Check the firmware identity only after the helper's bounded destruction
    # and local finalization. Never launch another context to recheck a failure.
    var matched = result.identity_present and result.identity.firmware_present and result.identity.protocol_version == 2 and result.identity.architecture == 6 and result.identity.firmware_major == 5 and result.identity.firmware_minor == 3 and result.identity.firmware_revision == 0
    var accepted = result.success() and matched and result.attempts == 3 and not result.transport_poisoned and result.retained_views == 0 and not result.finalization_unconfirmed
    # No handle, identity-bearing wire, serial or logger value is printed.
    print("{\"accepted\":" + _json_bool(accepted) + ",\"physical_mode\":" + _json_bool(physical) + ",\"identity_matched\":" + _json_bool(matched) + ",\"handle_known\":" + _json_bool(result.handle_known) + ",\"destroy_attempted\":" + _json_bool(result.destroy_attempted) + ",\"destroy_confirmed\":" + _json_bool(result.destroy_confirmed) + ",\"cleanup_attempted\":" + _json_bool(result.cleanup_attempted) + ",\"attempts\":" + String(result.attempts) + ",\"primary_error\":" + _json_bool(result.primary_error.byte_length() != 0) + ",\"cleanup_error\":" + _json_bool(result.cleanup_error.byte_length() != 0) + ",\"close_error\":" + _json_bool(result.close_error.byte_length() != 0) + ",\"poisoned\":" + _json_bool(result.transport_poisoned) + ",\"retained_views\":" + String(result.retained_views) + ",\"finalization_unconfirmed\":" + _json_bool(result.finalization_unconfirmed) + "}")
    if not accepted:
        raise Error("GroupDeviceProbe: lifecycle, identity or finalization unconfirmed")
