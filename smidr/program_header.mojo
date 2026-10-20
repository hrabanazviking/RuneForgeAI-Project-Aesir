# Original output-builder primitive from HAILO10H_ORIGINAL_PROGRAM_STRUCTURE.md.
# Header values/section arithmetic only; no file I/O, checksum or execution.
from hailbru.errors import herror

comptime PROGRAM_HEADER_V3_BYTES = UInt64(56)
comptime PROGRAM_HEADER_MAGIC = UInt32(0x01484546)


@fieldwise_init
struct ProgramHeaderV3(ImplicitlyCopyable, Movable):
    var protobuf_bytes: UInt32
    var residue_hash: UInt64
    var ccw_bytes_with_padding: UInt64
    var padding_bytes: UInt32
    var additional_bytes: UInt64
    var protobuf_hash: UInt64


@fieldwise_init
struct ProgramSectionLayout(ImplicitlyCopyable, Movable):
    var protobuf_offset: UInt64
    var protobuf_bytes: UInt64
    var padding_offset: UInt64
    var padding_bytes: UInt64
    var ccw_offset: UInt64
    var ccw_bytes: UInt64
    var additional_offset: UInt64
    var additional_bytes: UInt64
    var total_bytes: UInt64


def _checked_sum(a: UInt64, b: UInt64) raises -> UInt64:
    if b > UInt64(18446744073709551615) - a:
        raise herror("BadProgramHeader", "section arithmetic exceeds UInt64")
    return a + b


def _validate_header(header: ProgramHeaderV3) raises:
    if UInt64(header.padding_bytes) > header.ccw_bytes_with_padding:
        raise herror("BadProgramHeader", "padding exceeds CCW section including padding")


def layout_program_sections(header: ProgramHeaderV3, host_buffer_limit: UInt64,
                            actual_total_bytes: UInt64) raises -> ProgramSectionLayout:
    _validate_header(header)
    if host_buffer_limit == 0:
        raise herror("BadProgramHeader", "explicit positive host buffer bound required")
    var proto_end = _checked_sum(PROGRAM_HEADER_V3_BYTES, UInt64(header.protobuf_bytes))
    var ccw_start = _checked_sum(proto_end, UInt64(header.padding_bytes))
    var ccw_end = _checked_sum(proto_end, header.ccw_bytes_with_padding)
    var total = _checked_sum(ccw_end, header.additional_bytes)
    if total > host_buffer_limit or total != actual_total_bytes:
        raise herror("BadProgramHeader", "total extent differs from actual bytes or exceeds host bound")
    return ProgramSectionLayout(PROGRAM_HEADER_V3_BYTES, UInt64(header.protobuf_bytes),
                                proto_end, UInt64(header.padding_bytes), ccw_start,
                                header.ccw_bytes_with_padding - UInt64(header.padding_bytes),
                                ccw_end, header.additional_bytes, total)


def _append_be(mut data: List[UInt8], value: UInt64, width: Int):
    for i in range(width):
        data.append(UInt8((value >> UInt64((width - 1 - i) * 8)) & UInt64(255)))


def encode_program_header(header: ProgramHeaderV3) raises -> List[UInt8]:
    _validate_header(header)
    var data = List[UInt8]()
    data.reserve(Int(PROGRAM_HEADER_V3_BYTES))
    _append_be(data, UInt64(PROGRAM_HEADER_MAGIC), 4)
    _append_be(data, 3, 4)
    _append_be(data, UInt64(header.protobuf_bytes), 4)
    _append_be(data, header.residue_hash, 8)
    _append_be(data, header.ccw_bytes_with_padding, 8)
    _append_be(data, UInt64(header.padding_bytes), 4)
    _append_be(data, header.additional_bytes, 8)
    _append_be(data, header.protobuf_hash, 8)
    _append_be(data, 0, 8)
    return data^


def _read_be(data: List[UInt8], offset: Int, width: Int) -> UInt64:
    # Callers supply constant field spans only after the exact size check.
    var value = UInt64(0)
    for i in range(width):
        value = (value << UInt64(8)) | UInt64(data[offset + i])
    return value


def decode_program_header(data: List[UInt8]) raises -> ProgramHeaderV3:
    if len(data) != Int(PROGRAM_HEADER_V3_BYTES):
        raise herror("BadProgramHeader", "expected exactly 56 header bytes")
    if _read_be(data, 0, 4) != UInt64(PROGRAM_HEADER_MAGIC) or _read_be(data, 4, 4) != 3:
        raise herror("BadProgramHeader", "wrong magic or unsupported outer version")
    if _read_be(data, 48, 8) != 0:
        raise herror("BadProgramHeader", "reserved bytes must be zero in this original-output profile")
    var header = ProgramHeaderV3(UInt32(_read_be(data, 8, 4)), _read_be(data, 12, 8),
                                 _read_be(data, 20, 8), UInt32(_read_be(data, 28, 4)),
                                 _read_be(data, 32, 8), _read_be(data, 40, 8))
    _validate_header(header)
    return header
