# Native typed-message constructor/inspector. This never contacts a device.
from std.sys import argv
from hailbru.errors import herror
from hailbru.hrpc_frame import decode_hrpc_frame, encode_hrpc_frame
from hailbru.hrpc_device import (
    device_create_request, device_identify_request, device_destroy_request,
    device_create_reply, device_identify_reply, device_destroy_reply,
)
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def _uint32(text: String) raises -> UInt32:
    if text.byte_length() == 0:
        raise herror("BadArgs", "empty UInt32 argument")
    var value = UInt32(0)
    for byte in text.as_bytes():
        if byte < 48 or byte > 57:
            raise herror("BadArgs", "expected a decimal UInt32")
        var digit = UInt32(byte - 48)
        if value > (UInt32(4294967295) - digit) // UInt32(10):
            raise herror("BadArgs", "argument exceeds UInt32")
        value = value * UInt32(10) + digit
    return value


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise herror("BadArgs", "usage: hrpc_device <create|identify|destroy>-<request|reply> <message-id> [handle|frame-hex]")
    var mode = args[1]
    var message_id = _uint32(args[2])
    if mode == "create-request":
        if len(args) != 3:
            raise herror("BadArgs", "create-request accepts only a message ID")
        var frame = device_create_request(message_id)
        print("{\"packet_hex\":\"" + _to_hex(encode_hrpc_frame(frame)) + "\",\"device_access\":false}")
        return
    if len(args) != 4:
        raise herror("BadArgs", "this operation requires a handle or reply frame")
    if mode == "identify-request" or mode == "destroy-request":
        var handle = _uint32(args[3])
        if mode == "identify-request":
            var frame = device_identify_request(message_id, handle)
            print("{\"packet_hex\":\"" + _to_hex(encode_hrpc_frame(frame)) + "\",\"device_access\":false}")
        else:
            var frame = device_destroy_request(message_id, handle)
            print("{\"packet_hex\":\"" + _to_hex(encode_hrpc_frame(frame)) + "\",\"device_access\":false}")
        return
    var frame = decode_hrpc_frame(_from_hex(args[3]))
    if mode == "create-reply":
        var handle = device_create_reply(frame, message_id)
        print("{\"handle\":" + String(handle) + ",\"device_access\":false}")
    elif mode == "destroy-reply":
        device_destroy_reply(frame, message_id)
        print("{\"reply_kind\":\"destroy\",\"remote_status\":0,\"device_access\":false}")
    elif mode == "identify-reply":
        var identity = device_identify_reply(frame, message_id)
        var present = String("true") if identity.firmware_present else String("false")
        print("{\"protocol_version\":" + String(identity.protocol_version)
              + ",\"firmware_major\":" + String(identity.firmware_major)
              + ",\"firmware_minor\":" + String(identity.firmware_minor)
              + ",\"firmware_revision\":" + String(identity.firmware_revision)
              + ",\"firmware_present\":" + present
              + ",\"logger_version\":" + String(identity.logger_version)
              + ",\"architecture\":" + String(identity.architecture)
              + ",\"device_access\":false}")
    else:
        raise herror("BadArgs", "unknown typed device operation")
