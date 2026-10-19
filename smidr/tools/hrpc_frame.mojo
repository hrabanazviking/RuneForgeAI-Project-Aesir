# Native, non-device inspector for recorded integrated-device RPC envelopes.
# This tool never opens a model/device or submits an operation.

from std.sys import argv
from hailbru.errors import herror
from hailbru.hrpc_frame import decode_hrpc_frame, encode_hrpc_frame


def _nibble(byte: UInt8) raises -> UInt8:
    if byte >= 48 and byte <= 57:
        return byte - 48
    if byte >= 65 and byte <= 70:
        return byte - 55
    if byte >= 97 and byte <= 102:
        return byte - 87
    raise herror("BadRpcHex", "frame must contain only hexadecimal pairs")


def _from_hex(text: String) raises -> List[UInt8]:
    var bytes = text.as_bytes()
    # Check size before decoding/allocation, including excessive argument data.
    if len(bytes) > 4136 or len(bytes) % 2 != 0:
        raise herror("BadRpcHex", "expected at most 2068 complete hexadecimal byte pairs")
    var result = List[UInt8]()
    result.reserve(len(bytes) // 2)
    for index in range(0, len(bytes), 2):
        result.append((_nibble(bytes[index]) << 4) | _nibble(bytes[index + 1]))
    return result^


def _to_hex(data: List[UInt8]) -> String:
    var digits = String("0123456789abcdef")
    var result = String("")
    for byte in data:
        var high = Int(byte >> 4)
        var low = Int(byte & 15)
        result += String(digits[byte=high:high + 1])
        result += String(digits[byte=low:low + 1])
    return result


def main() raises:
    var args = argv()
    if len(args) != 2 and len(args) != 3:
        raise herror("BadArgs", "usage: hrpc_frame <packet-hex> [--dma-buffer]")
    var padded = False
    if len(args) == 3:
        if args[2] != "--dma-buffer":
            raise herror("BadArgs", "the only mode flag is --dma-buffer")
        padded = True
    var data = _from_hex(args[1])
    var frame = decode_hrpc_frame(data, padded)
    var canonical = encode_hrpc_frame(frame)
    print("{\"message_id\":" + String(frame.message_id)
          + ",\"action_id\":" + String(frame.action_id)
          + ",\"remote_status\":" + String(frame.remote_status)
          + ",\"body_hex\":\"" + _to_hex(frame.body)
          + "\",\"padding_bytes\":" + String(frame.padding_bytes)
          + ",\"canonical_hex\":\"" + _to_hex(canonical)
          + "\",\"device_access\":false}")
