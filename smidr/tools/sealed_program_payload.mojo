# Bounded synthetic program bytes only. No model file or device consumer.
from std.sys import argv
from smidr.sealed_program_payload import seal_program_payload, sealed_program_window
from smidr.program_payload import ProgramPayloadRequest, stage_program_payload
from smidr.tools.program_integrity import _hex, _signed
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.hrpc_device import _uint32
from smidr.tools.hrpc_program import _uint64


def main() raises:
    var args = argv()
    if len(args) != 13:
        raise Error("usage: sealed_program_payload message-id vdevice program-hex name host-bound part first count output-bound write-calls read-calls arch")
    for i in range(1, len(args)):
        if i != 3 and i != 4 and i != 12 and args[i].byte_length() > 20:
            raise Error("SealedProgramPayload: decimal argument exceeds twenty bytes")
    if args[4].byte_length() > 2048 or args[12].byte_length() > 16:
        raise Error("SealedProgramPayload: diagnostic text exceeds work bound")
    var request = ProgramPayloadRequest(_uint32(args[1]), _uint32(args[2]), args[4], _uint64(args[5]))
    var staged = stage_program_payload(_hex(args[3]), request)
    var owner = seal_program_payload(staged, request, args[12], _signed(args[10]), _signed(args[11]))
    var output = sealed_program_window(owner, request, _signed(args[6]), _signed(args[7]), _signed(args[8]), _signed(args[9]), _signed(args[11]))
    owner.close()
    owner.close()
    print("{\"window_hex\":\"" + _to_hex(output) + "\",\"program_bytes\":" + String(len(staged.program)) + ",\"sealed_kernel_bytes\":true,\"device_access\":false,\"program_transferred\":false,\"executable_verified\":false}")
