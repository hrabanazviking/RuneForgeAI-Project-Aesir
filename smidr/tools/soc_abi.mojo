# Native consumer for packed session ABI codecs. No device access.
from std.sys import argv
from hailbru.errors import herror
from hailbru.soc_abi import (
    soc_ioctl, soc_desc_create, soc_desc_release, soc_connect, soc_close,
    soc_channel_masks, soc_transfer, soc_properties_json, soc_driver_info_json,
    soc_interrupts_json, soc_connect_reply, soc_desc_reply,
)
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def _uint64(text: String) raises -> UInt64:
    if text.byte_length() == 0:
        raise herror("BadArgs", "empty UInt64")
    var value = UInt64(0)
    for byte in text.as_bytes():
        if byte < 48 or byte > 57:
            raise herror("BadArgs", "expected a decimal UInt64")
        var digit = UInt64(byte - 48)
        if value > (UInt64(18446744073709551615) - digit) // UInt64(10):
            raise herror("BadArgs", "argument exceeds UInt64")
        value = value * UInt64(10) + digit
    return value


def _boolean(text: String) raises -> Bool:
    if text == "0":
        return False
    if text == "1":
        return True
    raise herror("BadArgs", "expected boolean 0 or 1")


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise herror("BadArgs", "usage: soc_abi <operation> [values|hex]")
    var mode = args[1]
    if mode == "ioctls" and len(args) == 2:
        print("{")
        var operations: List[String] = ["properties", "driver-info", "desc-create", "desc-release", "connect", "close", "enable-channels", "disable-channels", "interrupts", "transfer", "prepare-transfer", "cancel-prepared"]
        for index in range(len(operations)):
            print("\"" + operations[index] + "\":" + String(soc_ioctl(operations[index])) + (String(",") if index + 1 < len(operations) else String("")))
        print("}")
        return
    var data = List[UInt8]()
    if mode == "desc-create" and len(args) == 5:
        data = soc_desc_create(_uint64(args[2]), _uint64(args[3]), _boolean(args[4]))
    elif mode == "desc-release" and len(args) == 3:
        data = soc_desc_release(_uint64(args[2]))
    elif mode == "connect" and len(args) == 5:
        data = soc_connect(_uint64(args[2]), _uint64(args[3]), _uint64(args[4]))
    elif mode == "close" and len(args) == 4:
        data = soc_close(_uint64(args[2]), _uint64(args[3]))
    elif mode == "channels" and len(args) == 5:
        data = soc_channel_masks(_uint64(args[2]), _uint64(args[3]), _uint64(args[4]))
    elif mode == "transfer" and len(args) == 7:
        data = soc_transfer(_uint64(args[2]), _uint64(args[3]), _uint64(args[4]), _uint64(args[5]), _boolean(args[6]))
    elif len(args) == 3:
        if mode != "properties" and mode != "driver-info" and mode != "interrupts" and mode != "connect-reply" and mode != "desc-reply":
            raise herror("BadArgs", "unknown decode operation")
        data = _from_hex(args[2])
        if mode == "properties":
            print(soc_properties_json(data))
        elif mode == "driver-info":
            print(soc_driver_info_json(data))
        elif mode == "interrupts":
            print(soc_interrupts_json(data))
        elif mode == "connect-reply":
            var channels = soc_connect_reply(data)
            print("{\"input_channel\":" + String(channels[0]) + ",\"output_channel\":" + String(channels[1]) + "}")
        elif mode == "desc-reply":
            var descriptor = soc_desc_reply(data)
            print("{\"handle\":" + String(descriptor[0]) + ",\"dma_address\":" + String(descriptor[1]) + "}")
        else:
            raise herror("BadArgs", "unknown decode operation")
        return
    else:
        raise herror("BadArgs", "unknown operation or incorrect argument count")
    print(_to_hex(data))
