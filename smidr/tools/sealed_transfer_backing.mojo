from std.sys import argv
from smidr.tools.program_integrity import _hex, _signed
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.hrpc_device import _uint32
from smidr.tools.hrpc_program import _uint64
from smidr.program_payload import ProgramPayloadRequest, stage_program_payload
from smidr.sealed_program_payload import seal_program_payload
from smidr.sealed_transfer_backing import seal_transfer_backing, sealed_transfer_window


def main() raises:
    var args = argv()
    if len(args) != 16:
        raise Error("usage: sealed_transfer_backing message vdevice program-hex name host-bound part first count output-bound program-write program-read metadata-write metadata-read arch close")
    for i in range(1, len(args)):
        if i != 3 and i != 4 and i != 14 and i != 15 and args[i].byte_length() > 20:
            raise Error("SealedTransferBacking: decimal argument exceeds twenty bytes")
    if args[4].byte_length() > 2048 or args[14].byte_length() > 16 or args[15].byte_length() > 16:
        raise Error("SealedTransferBacking: diagnostic text exceeds work bound")
    var request = ProgramPayloadRequest(_uint32(args[1]), _uint32(args[2]), args[4], _uint64(args[5]))
    if args[15] != "explicit" and args[15] != "implicit":
        raise Error("SealedTransferBacking: unknown close mode")
    var staged = stage_program_payload(_hex(args[3]), request)
    var source = seal_program_payload(staged, request, args[14], _signed(args[10]), _signed(args[11]))
    var owner = seal_transfer_backing(source^, request, _signed(args[12]), _signed(args[13]), _signed(args[11]))
    var output = sealed_transfer_window(owner, request, _signed(args[6]), _signed(args[7]), _signed(args[8]), _signed(args[9]), _signed(args[11]), _signed(args[13]))
    if args[15] == "explicit":
        owner.close()
        owner.close()
    print("{\"window_hex\":\"" + _to_hex(output) + "\",\"sealed_parts\":2,\"device_access\":false,\"program_transferred\":false,\"execution_tested\":false}")
