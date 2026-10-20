# Original owned outer-envelope construction from already published field facts.
# Opaque sections: this neither validates nor generates executable instructions.
from hailbru.errors import herror
from smidr.program_header import (
    ProgramHeaderV3, ProgramSectionLayout, _checked_sum, encode_program_header, layout_program_sections,
)
from smidr.program_integrity import xxh3_64_window, validate_program_integrity


def plan_program_envelope(protobuf_bytes: UInt64, ccw_bytes: UInt64,
                          additional_bytes: UInt64, padding_bytes: UInt32,
                          host_output_bound: UInt64) raises -> ProgramSectionLayout:
    """Checked host-output extent arithmetic without allocating declared bytes."""
    if protobuf_bytes > UInt64(4294967295):
        raise herror("BadProgramEnvelope", "protobuf length exceeds UInt32 header field")
    var padded_ccws = _checked_sum(UInt64(padding_bytes), ccw_bytes)
    var total = _checked_sum(_checked_sum(_checked_sum(56, protobuf_bytes), padded_ccws), additional_bytes)
    if total > UInt64(9223372036854775807):
        raise herror("BadProgramEnvelope", "output cannot be represented by host Int")
    var header = ProgramHeaderV3(UInt32(protobuf_bytes), 0, padded_ccws,
                                 padding_bytes, additional_bytes, 0)
    return layout_program_sections(header, host_output_bound, total)


def _select_protobuf_hash(protobuf_only: Bool, checksum: UInt64) raises -> UInt64:
    if not protobuf_only:
        return 0
    if checksum == 0:
        raise herror("BadProgramEnvelope", "zero protobuf checksum cannot select protobuf-only mode")
    return checksum


def build_program_envelope(protobuf: List[UInt8], ccws: List[UInt8],
                           additional: List[UInt8], padding_bytes: UInt32,
                           protobuf_only: Bool, host_output_bound: UInt64) raises -> List[UInt8]:
    """Copy opaque sections into one bounded owned v3 output with computed hashes."""
    var layout = plan_program_envelope(UInt64(len(protobuf)), UInt64(len(ccws)),
                                       UInt64(len(additional)), padding_bytes, host_output_bound)
    var total = layout.total_bytes
    var header = ProgramHeaderV3(UInt32(len(protobuf)), 0, layout.padding_bytes + layout.ccw_bytes,
                                 padding_bytes, UInt64(len(additional)), 0)
    # All declared extents and the explicit bound are checked before allocation.
    var output = List[UInt8]()
    output.reserve(Int(total))
    for _ in range(56):
        output.append(0)
    for byte in protobuf:
        output.append(byte)
    for _ in range(Int(padding_bytes)):
        output.append(0)
    for byte in ccws:
        output.append(byte)
    for byte in additional:
        output.append(byte)
    header.residue_hash = xxh3_64_window(output, 56, len(output) - 56, len(output))
    var protobuf_hash = xxh3_64_window(output, 56, Int(layout.protobuf_bytes), len(output))
    header.protobuf_hash = _select_protobuf_hash(protobuf_only, protobuf_hash)
    var encoded = encode_program_header(header)
    for i in range(56):
        output[i] = encoded[i]
    var checked = validate_program_integrity(output, host_output_bound)
    if checked.protobuf_only != protobuf_only:
        raise herror("BadProgramEnvelope", "constructed envelope changed requested checksum domain")
    return output^
