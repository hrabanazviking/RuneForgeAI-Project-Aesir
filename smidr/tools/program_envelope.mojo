# Synthetic original-output inspector. No device/model/program file access.
from std.sys import argv
from hailbru.errors import herror
from smidr.program_envelope import build_program_envelope, plan_program_envelope, _select_protobuf_hash
from smidr.program_integrity import validate_program_integrity
from smidr.program_header import decode_program_header, layout_program_sections
from smidr.tools.program_integrity import _hex
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.hrpc_device import _uint32
from smidr.tools.hrpc_program import _uint64


def _report(data: List[UInt8], bound: UInt64) raises:
    var checked = validate_program_integrity(data, bound)
    var header_bytes = List[UInt8]()
    for i in range(56):
        header_bytes.append(data[i])
    var header = decode_program_header(header_bytes)
    var layout = layout_program_sections(header, bound, UInt64(len(data)))
    var mode = String("full-residue")
    if checked.protobuf_only:
        mode = "protobuf-only"
    print("{\"envelope_hex\":\"" + _to_hex(data) + "\",\"domain\":\"" + mode
          + "\",\"protobuf_offset\":" + String(layout.protobuf_offset)
          + ",\"padding_offset\":" + String(layout.padding_offset)
          + ",\"ccw_offset\":" + String(layout.ccw_offset)
          + ",\"additional_offset\":" + String(layout.additional_offset)
          + ",\"total_bytes\":" + String(layout.total_bytes)
          + ",\"device_access\":false,\"complete_program\":false,\"execution_tested\":false}")


def _mode(text: String) raises -> Bool:
    if text == "protobuf-only":
        return True
    if text == "full-residue":
        return False
    raise herror("BadArgs", "explicit protobuf-only or full-residue mode required")


def _owned_output() raises -> List[UInt8]:
    var protobuf = _hex("010203")
    var ccws = _hex("04050607")
    var additional = _hex("0809")
    var output = build_program_envelope(protobuf, ccws, additional, 5, False, 70)
    if _to_hex(protobuf) != "010203" or _to_hex(ccws) != "04050607" or _to_hex(additional) != "0809":
        raise herror("BadProgramEnvelope", "constructor mutated an input")
    protobuf[0] = 255
    ccws[0] = 255
    additional[0] = 255
    if output[56] != 1 or output[64] != 4 or output[68] != 8:
        raise herror("BadProgramEnvelope", "output aliases an input")
    return output^


def main() raises:
    var args = argv()
    if len(args) == 8 and args[1] == "build":
        var proto = _hex(args[2])
        var ccws = _hex(args[3])
        var extra = _hex(args[4])
        var padding = _uint32(args[5])
        var bound = _uint64(args[7])
        # Prevent oversized diagnostic allocation; production uses caller bound.
        if bound > 262144:
            raise herror("BadArgs", "diagnostic output bound exceeds 256 KiB")
        var data = build_program_envelope(proto, ccws, extra, padding, _mode(args[6]), bound)
        _report(data, bound)
    elif len(args) == 4 and args[1] == "selector":
        var selected = _select_protobuf_hash(_mode(args[2]), _uint64(args[3]))
        print("{\"protobuf_hash\":" + String(selected) + ",\"device_access\":false,\"complete_program\":false,\"execution_tested\":false}")
    elif len(args) == 7 and args[1] == "extent":
        var layout = plan_program_envelope(_uint64(args[2]), _uint64(args[3]),
                                           _uint64(args[4]), _uint32(args[5]), _uint64(args[6]))
        print("{\"protobuf_offset\":" + String(layout.protobuf_offset)
              + ",\"padding_offset\":" + String(layout.padding_offset)
              + ",\"ccw_offset\":" + String(layout.ccw_offset)
              + ",\"additional_offset\":" + String(layout.additional_offset)
              + ",\"total_bytes\":" + String(layout.total_bytes)
              + ",\"device_access\":false,\"complete_program\":false,\"execution_tested\":false}")
    elif len(args) == 2 and args[1] == "ownership":
        var data = _owned_output()
        var second = _owned_output()
        second[56] = 255
        if data[56] != 1:
            raise herror("BadProgramEnvelope", "independent outputs alias")
        _report(data, 70)
    else:
        raise herror("BadArgs", "expected build or ownership mode")
