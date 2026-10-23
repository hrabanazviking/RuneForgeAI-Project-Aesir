# Synthetic wire diagnostic. No model/program file or transport consumer.
from std.sys import argv
from smidr.program_payload import ProgramPayloadRequest, stage_program_payload, program_payload_window
from smidr.tools.program_integrity import _hex, _signed
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.hrpc_device import _uint32
from smidr.tools.hrpc_program import _uint64


def main() raises:
    var args = argv()
    if len(args) != 11:
        raise Error("usage: program_payload <message-id> <vdevice> <program-hex> <name> <host-bound> <part> <first> <count> <output-bound> <expected-name>")
    for i in range(1, len(args)):
        if i != 3 and i != 4 and i != 10 and args[i].byte_length() > 20:
            raise Error("ProgramPayload: decimal argument exceeds twenty bytes")
    if args[4].byte_length() > 2048 or args[10].byte_length() > 2048:
        raise Error("ProgramPayload: diagnostic name exceeds RPC body bound")
    var request = ProgramPayloadRequest(_uint32(args[1]), _uint32(args[2]), args[4], _uint64(args[5]))
    var snapshot = stage_program_payload(_hex(args[3]), request)
    var expected = request.copy()
    expected.name = args[10]
    var window = program_payload_window(snapshot, expected, _signed(args[6]), _signed(args[7]),
                                        _signed(args[8]), _signed(args[9]))
    print("{\"metadata_hex\":\"" + _to_hex(snapshot.metadata) + "\",\"program_hex\":\""
          + _to_hex(snapshot.program) + "\",\"window_hex\":\"" + _to_hex(window)
          + "\",\"metadata_bytes\":" + String(len(snapshot.metadata))
          + ",\"program_bytes\":" + String(len(snapshot.program))
          + ",\"device_access\":false,\"program_transferred\":false,\"executable_verified\":false}")
