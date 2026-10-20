# Synthetic host bytes only; no device or model input.
from std.sys import argv
from hailbru.errors import herror
from smidr.program_integrity import xxh3_64_window, validate_program_integrity, _fold_product
from smidr.tools.hrpc_frame import _nibble
from smidr.tools.hrpc_program import _uint64


def _integer(text: String) raises -> Int:
    var value = _uint64(text)
    if value > UInt64(9223372036854775807):
        raise herror("BadArgs", "argument exceeds Int64")
    return Int(value)


def _signed(text: String) raises -> Int:
    if text.byte_length() > 0 and text.as_bytes()[0] == 45:
        var magnitude = _uint64(String(text[byte=1:]))
        if magnitude > UInt64(9223372036854775808):
            raise herror("BadArgs", "argument below Int64 minimum")
        if magnitude == UInt64(9223372036854775808):
            return -9223372036854775807 - 1
        return -Int(magnitude)
    return _integer(text)


def _hex(text: String) raises -> List[UInt8]:
    var bytes = text.as_bytes()
    if len(bytes) > 65536 or len(bytes) % 2 != 0:
        raise herror("BadArgs", "diagnostic hex input exceeds 32768 bytes or is odd")
    var result = List[UInt8]()
    for i in range(0, len(bytes), 2):
        result.append((_nibble(bytes[i]) << 4) | _nibble(bytes[i + 1]))
    return result^


def main() raises:
    var args = argv()
    var checksum: UInt64
    var selected = String("raw-window")
    var offset = 0
    var count = 0
    if len(args) == 6 and args[1] == "hash":
        var data = _hex(args[2])
        offset = _signed(args[3])
        count = _signed(args[4])
        checksum = xxh3_64_window(data, offset, count, _signed(args[5]))
    elif len(args) == 7 and args[1] == "generated":
        var length = _integer(args[2])
        var seed = _integer(args[6])
        # Diagnostic allocation limit only; production hash has no such limit.
        if length > 8388608 or seed > 255:
            raise herror("BadArgs", "generated diagnostic size or byte seed exceeded")
        var data = List[UInt8]()
        data.reserve(length)
        for i in range(length):
            data.append(UInt8((i * 197 + seed) % 256))
        offset = _signed(args[3])
        count = _signed(args[4])
        checksum = xxh3_64_window(data, offset, count, _signed(args[5]))
    elif len(args) == 4 and args[1] == "validate":
        var result = validate_program_integrity(_hex(args[2]), _uint64(args[3]))
        selected = "full-residue"
        if result.protobuf_only:
            selected = "protobuf-only"
        checksum = result.checksum
        offset = result.offset
        count = result.count
    elif len(args) == 4 and args[1] == "fold":
        checksum = _fold_product(_uint64(args[2]), _uint64(args[3]))
    elif len(args) == 2 and args[1] == "ownership":
        var data = _hex("010203040506070809")
        var saved = xxh3_64_window(data, 1, 7, 7)
        data[0] = 255
        if saved != xxh3_64_window(data, 1, 7, 7):
            raise herror("BadProgramIntegrity", "outside-window mutation changed hash")
        data[1] = 255
        if saved == xxh3_64_window(data, 1, 7, 7):
            raise herror("BadProgramIntegrity", "inside-window mutation not observed")
        checksum = saved
    else:
        raise herror("BadArgs", "expected hash, validate, fold or ownership")
    print("{\"checksum\":" + String(checksum) + ",\"domain\":\"" + selected + "\",\"offset\":" + String(offset) + ",\"count\":" + String(count) + ",\"device_access\":false,\"complete_program\":false,\"execution_tested\":false}")
