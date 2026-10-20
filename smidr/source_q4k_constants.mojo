# Original static source decoder from HAILO10H_Q4K_SOURCE_LAYOUT.md.
# Only integer representation fields are evaluated; no model arithmetic.
from loader.packed_gguf import PackedGGUF, packed_row_bytes
from smidr.semantic_plan import checked_product
from smidr.source_inventory import SourceTensorBinding
from smidr.source_float_constants import binary16_to_binary32_bits


@fieldwise_init
struct SourceBitField(ImplicitlyCopyable, Movable):
    var byte: Int
    var bit: Int
    var width: Int


@fieldwise_init
struct Q4KGroupFields(ImplicitlyCopyable, Movable):
    var scale_low: SourceBitField
    var scale_high: SourceBitField
    var min_low: SourceBitField
    var min_high: SourceBitField


def _group_schema() -> List[Q4KGroupFields]:
    # Published descriptor rows, interpreted by a generic field reader below.
    var rows = List[Q4KGroupFields]()
    rows.append(Q4KGroupFields(SourceBitField(4, 0, 6), SourceBitField(0, 0, 0), SourceBitField(8, 0, 6), SourceBitField(0, 0, 0)))
    rows.append(Q4KGroupFields(SourceBitField(5, 0, 6), SourceBitField(0, 0, 0), SourceBitField(9, 0, 6), SourceBitField(0, 0, 0)))
    rows.append(Q4KGroupFields(SourceBitField(6, 0, 6), SourceBitField(0, 0, 0), SourceBitField(10, 0, 6), SourceBitField(0, 0, 0)))
    rows.append(Q4KGroupFields(SourceBitField(7, 0, 6), SourceBitField(0, 0, 0), SourceBitField(11, 0, 6), SourceBitField(0, 0, 0)))
    rows.append(Q4KGroupFields(SourceBitField(12, 0, 4), SourceBitField(4, 6, 2), SourceBitField(12, 4, 4), SourceBitField(8, 6, 2)))
    rows.append(Q4KGroupFields(SourceBitField(13, 0, 4), SourceBitField(5, 6, 2), SourceBitField(13, 4, 4), SourceBitField(9, 6, 2)))
    rows.append(Q4KGroupFields(SourceBitField(14, 0, 4), SourceBitField(6, 6, 2), SourceBitField(14, 4, 4), SourceBitField(10, 6, 2)))
    rows.append(Q4KGroupFields(SourceBitField(15, 0, 4), SourceBitField(7, 6, 2), SourceBitField(15, 4, 4), SourceBitField(11, 6, 2)))
    return rows^


def _read_field(source: PackedGGUF, block: Int, field: SourceBitField) raises -> UInt8:
    if field.width == 0:
        return 0
    # A bounded aligned half-word includes the last byte without crossing the
    # 144-byte block. Descriptors are private constants, never source metadata.
    var pair = source.source._read_u16(block + (field.byte // 2) * 2)
    var shift = (field.byte % 2) * 8 + field.bit
    return UInt8((pair >> UInt16(shift)) & UInt16((1 << field.width) - 1))


@fieldwise_init
struct Q4KConstant(ImplicitlyCopyable, Movable):
    var d_bits: UInt16
    var dmin_bits: UInt16
    var d_binary32_bits: UInt32
    var dmin_binary32_bits: UInt32
    var q: UInt8
    var scale_factor: UInt8
    var min_factor: UInt8


@fieldwise_init
struct Q4KConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var components: List[Q4KConstant]


def read_q4k_constants(source: PackedGGUF, name: String, first: Int,
                       count: Int, host_window_limit: Int) raises -> Q4KConstantWindow:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceQ4KConstants: source mapping is closed")
    if name not in source.tensors:
        raise Error("SourceQ4KConstants: missing tensor " + name)
    var tensor = source.tensors[name]
    if tensor.kind != 12:
        raise Error("SourceQ4KConstants: requires Q4_K source kind 12")
    var total = checked_product(tensor.columns, tensor.rows)
    var byte_count = checked_product(packed_row_bytes(tensor.kind, tensor.columns), tensor.rows)
    var source_bytes = Int(source.source.file_size)
    if source.data_offset < 0 or source.data_offset > source_bytes or tensor.offset < source.data_offset or tensor.offset > source_bytes or tensor.byte_count != byte_count or tensor.byte_count > source_bytes - tensor.offset:
        raise Error("SourceQ4KConstants: tensor source extent mismatch")
    if first < 0 or first >= total or count <= 0 or host_window_limit <= 0 or count > host_window_limit or count > total - first:
        raise Error("SourceQ4KConstants: invalid element window or explicit host bound")
    var schema = _group_schema()
    var components = List[Q4KConstant]()
    components.reserve(count)
    for i in range(count):
        var element = first + i
        var block = tensor.offset + (element // 256) * 144
        var local = element % 256
        var group = local // 32
        var fields = schema[group]
        var scale = _read_field(source, block, fields.scale_low) | (_read_field(source, block, fields.scale_high) << 4)
        var minimum = _read_field(source, block, fields.min_low) | (_read_field(source, block, fields.min_high) << 4)
        var qfield = SourceBitField(16 + (group // 2) * 32 + local % 32, (group % 2) * 4, 4)
        var q = _read_field(source, block, qfield)
        var d = source.source._read_u16(block)
        var dmin = source.source._read_u16(block + 2)
        components.append(Q4KConstant(d, dmin, binary16_to_binary32_bits(d),
                                     binary16_to_binary32_bits(dmin), q, scale, minimum))
    return Q4KConstantWindow(SourceTensorBinding(tensor.offset, tensor.columns, tensor.rows,
                             tensor.kind, tensor.byte_count), first, components^)


def read_q4k_constant_window(path: String, name: String, first: Int,
                             count: Int, host_window_limit: Int) raises -> Q4KConstantWindow:
    var source = PackedGGUF(path)
    return read_q4k_constants(source, name, first, count, host_window_limit)
