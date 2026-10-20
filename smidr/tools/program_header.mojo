# Synthetic header/layout inspector. Never opens a model/program/device file.
from std.sys import argv
from hailbru.errors import herror
from smidr.program_header import (
    ProgramHeaderV3, ProgramSectionLayout, encode_program_header,
    decode_program_header, layout_program_sections,
)
from smidr.tools.hrpc_frame import _from_hex, _to_hex
from smidr.tools.hrpc_device import _uint32
from smidr.tools.hrpc_program import _uint64


def _report(header: ProgramHeaderV3, layout: ProgramSectionLayout) raises:
    var text = String("{\"header_hex\":\"") + _to_hex(encode_program_header(header)) + "\",\"schema_version\":1,\"outer_version\":3"
    text += ",\"protobuf_bytes\":" + String(header.protobuf_bytes) + ",\"residue_hash\":" + String(header.residue_hash)
    text += ",\"ccw_bytes_with_padding\":" + String(header.ccw_bytes_with_padding) + ",\"padding_bytes\":" + String(header.padding_bytes)
    text += ",\"additional_bytes\":" + String(header.additional_bytes) + ",\"protobuf_hash\":" + String(header.protobuf_hash)
    text += ",\"protobuf_offset\":" + String(layout.protobuf_offset) + ",\"padding_offset\":" + String(layout.padding_offset)
    text += ",\"ccw_offset\":" + String(layout.ccw_offset) + ",\"ccw_bytes\":" + String(layout.ccw_bytes)
    text += ",\"additional_offset\":" + String(layout.additional_offset) + ",\"total_bytes\":" + String(layout.total_bytes)
    print(text + ",\"payload_integrity_verified\":false,\"complete_program\":false,\"execution_tested\":false,\"device_access\":false}")


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise herror("BadArgs", "usage: program_header <encode|decode|ownership> [values]")
    if args[1] == "encode" and len(args) == 10:
        var header = ProgramHeaderV3(_uint32(args[2]), _uint64(args[6]), _uint64(args[3]),
                                     _uint32(args[4]), _uint64(args[5]), _uint64(args[7]))
        var layout = layout_program_sections(header, _uint64(args[8]), _uint64(args[9]))
        _report(header, layout)
    elif args[1] == "decode" and len(args) == 5:
        var header = decode_program_header(_from_hex(args[2]))
        var layout = layout_program_sections(header, _uint64(args[3]), _uint64(args[4]))
        _report(header, layout)
    elif args[1] == "ownership" and len(args) == 2:
        var header = ProgramHeaderV3(17, 123, 32, 7, 5, 456)
        var bytes = encode_program_header(header)
        var decoded = decode_program_header(bytes)
        bytes[8] = 255
        header.protobuf_hash = 0
        var fresh = encode_program_header(decoded)
        if fresh[8] != 0 or decoded.protobuf_hash != 456:
            raise herror("BadProgramHeader", "returned header aliases its input")
        _report(decoded, layout_program_sections(decoded, 110, 110))
    else:
        raise herror("BadArgs", "invalid header codec mode/arguments")
