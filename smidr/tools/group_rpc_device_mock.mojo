# Explicit HOST MOCK diagnostic only; synthetic identity is not a device fact.
from std.sys import argv
from hailbru.soc_group_device import GroupDeviceResult, run_group_device
from smidr.tools.program_integrity import _signed
from smidr.tools.hrpc_frame import _to_hex


def _text_hex(text: String) -> String:
    var bytes = List[UInt8]()
    for byte in text.as_bytes():
        bytes.append(byte)
    return _to_hex(bytes)


def _bool(value: Bool) -> String:
    return String("true") if value else String("false")


def show_group_device(result: GroupDeviceResult):
    print("{\"success\":" + _bool(result.success()) + ",\"handle_known\":" + _bool(result.handle_known) + ",\"handle\":" + String(result.handle) + ",\"identity_present\":" + _bool(result.identity_present) + ",\"identity\":[" + String(result.identity.protocol_version) + "," + String(result.identity.firmware_major) + "," + String(result.identity.firmware_minor) + "," + String(result.identity.firmware_revision) + "," + String(result.identity.logger_version) + "," + String(result.identity.architecture) + "],\"firmware_present\":" + _bool(result.identity.firmware_present) + ",\"destroy_attempted\":" + _bool(result.destroy_attempted) + ",\"destroy_confirmed\":" + _bool(result.destroy_confirmed) + ",\"cleanup_attempted\":" + _bool(result.cleanup_attempted) + ",\"attempts\":" + String(result.attempts) + ",\"primary_hex\":\"" + _text_hex(result.primary_error) + "\",\"cleanup_hex\":\"" + _text_hex(result.cleanup_error) + "\",\"close_hex\":\"" + _text_hex(result.close_error) + "\",\"poisoned\":" + _bool(result.transport_poisoned) + ",\"retained_views\":" + String(result.retained_views) + ",\"finalization_unconfirmed\":" + _bool(result.finalization_unconfirmed) + ",\"physical_calls\":false}")


def main() raises:
    var args = argv()
    if len(args) != 5 or args[1] != "host-mock" or args[2] == "/sys" or args[3] == "/dev":
        raise Error("GroupDeviceMock: host-mock mock-sysfs mock-dev timeout-ms")
    for i in range(2, 4):
        if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
            raise Error("GroupDeviceMock: invalid mock root")
    if args[4].byte_length() > 6:
        raise Error("GroupDeviceMock: unbounded timeout argument")
    var result = run_group_device(args[2], args[3], Int64(_signed(args[4])))
    show_group_device(result)
    if not result.success():
        raise Error("GroupDeviceMock: lifecycle or finalization unconfirmed")
