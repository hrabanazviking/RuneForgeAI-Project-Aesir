# Host wire diagnostic only; constructed requests are never submitted.
from std.sys import argv
from hailbru.errors import herror
from hailbru.hrpc_frame import encode_hrpc_frame, decode_hrpc_frame
from hailbru.hrpc_program import (
    program_create_request, program_handle_request, program_create_reply,
    program_empty_reply,
)
from smidr.tools.hrpc_device import _uint32
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def _uint64(text: String) raises -> UInt64:
    if text.byte_length() == 0:
        raise herror("BadArgs", "empty UInt64 argument")
    var value = UInt64(0)
    for byte in text.as_bytes():
        if byte < 48 or byte > 57:
            raise herror("BadArgs", "expected a decimal UInt64")
        var digit = UInt64(byte - 48)
        if value > (UInt64(18446744073709551615) - digit) // UInt64(10):
            raise herror("BadArgs", "argument exceeds UInt64")
        value = value * UInt64(10) + digit
    return value


def _packet(data: List[UInt8]) -> String:
    return "{\"packet_hex\":\"" + _to_hex(data) + "\",\"device_access\":false,\"program_transferred\":false,\"execution_tested\":false}"


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise herror("BadArgs", "usage: hrpc_program <mode> <message-id> [arguments]")
    var mode = args[1]
    var message_id = _uint32(args[2])
    if mode == "create-request" and len(args) == 7:
        var frame = program_create_request(message_id, _uint32(args[3]), _uint64(args[4]), args[6], _uint64(args[5]))
        print(_packet(encode_hrpc_frame(frame)))
    elif mode == "handle-request" and len(args) == 5:
        var frame = program_handle_request(message_id, _uint32(args[3]), _uint32(args[4]))
        print(_packet(encode_hrpc_frame(frame)))
    elif mode == "create-reply" and len(args) == 4:
        var frame = decode_hrpc_frame(_from_hex(args[3]))
        var handle = program_create_reply(frame, message_id)
        print("{\"handle\":" + String(handle) + ",\"device_access\":false,\"program_transferred\":false,\"execution_tested\":false}")
    elif mode == "empty-reply" and len(args) == 5:
        var frame = decode_hrpc_frame(_from_hex(args[4]))
        program_empty_reply(frame, message_id, _uint32(args[3]))
        print("{\"remote_status\":0,\"device_access\":false,\"program_transferred\":false,\"execution_tested\":false}")
    elif mode == "ownership" and len(args) == 3:
        var first = program_create_request(message_id, 0, 128, "original-program", 128)
        var saved = first.body.copy()
        first.body[0] = 255
        var fresh = program_create_request(message_id, 0, 128, "original-program", 128)
        if len(saved) != len(fresh.body):
            raise herror("BadProgramRpc", "body ownership drift")
        for i in range(len(saved)):
            if saved[i] != fresh.body[i]:
                raise herror("BadProgramRpc", "returned request aliases another owner")
        # Protobuf UTF-8 strings can contain NUL even though argv cannot.
        var nul_frame = program_create_request(message_id, 0, 1, "a\x00b", 1)
        print(_packet(encode_hrpc_frame(nul_frame)))
    else:
        raise herror("BadArgs", "invalid program codec mode/arguments")
