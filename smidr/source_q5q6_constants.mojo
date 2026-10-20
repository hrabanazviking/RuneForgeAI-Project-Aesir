# Original source field readers from HAILO10H_Q5Q6_SOURCE_LAYOUT.md.
# Integer source representation only. No floating model evaluation or packing.
from loader.packed_gguf import PackedGGUF, packed_row_bytes
from smidr.source_inventory import SourceTensorBinding
from smidr.semantic_plan import checked_product
from smidr.source_float_constants import binary16_to_binary32_bits
from smidr.source_q4k_constants import SourceBitField, _read_field, _group_schema


@fieldwise_init
struct Q5KConstant(ImplicitlyCopyable, Movable):
    var d_bits: UInt16
    var dmin_bits: UInt16
    var d_binary32_bits: UInt32
    var dmin_binary32_bits: UInt32
    var q: UInt8
    var scale_factor: UInt8
    var min_factor: UInt8


@fieldwise_init
struct Q6KConstant(ImplicitlyCopyable, Movable):
    var d_bits: UInt16
    var d_binary32_bits: UInt32
    var q: Int8
    var scale_factor: Int8


@fieldwise_init
struct Q5KConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var components: List[Q5KConstant]


@fieldwise_init
struct Q6KConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var components: List[Q6KConstant]


def _window_binding(source: PackedGGUF, name: String, kind: Int,
                    first: Int, count: Int, host_bound: Int) raises -> SourceTensorBinding:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceKConstants: live mapped source owner required")
    if name not in source.tensors:
        raise Error("SourceKConstants: missing source weight")
    var tensor = source.tensors[name]
    if tensor.kind != kind:
        raise Error("SourceKConstants: source packed kind differs from requested decoder")
    var elements = checked_product(tensor.columns, tensor.rows)
    var extent = checked_product(packed_row_bytes(kind, tensor.columns), tensor.rows)
    var source_bytes = Int(source.source.file_size)
    if source.data_offset < 0 or source.data_offset > source_bytes or tensor.offset < source.data_offset or tensor.byte_count != extent:
        raise Error("SourceKConstants: invalid source byte extent")
    source.source._require_range(tensor.offset, extent)
    if first < 0 or count <= 0 or first >= elements or count > elements - first:
        raise Error("SourceKConstants: source window outside tensor")
    if host_bound <= 0 or count > host_bound:
        raise Error("SourceKConstants: explicit host element bound exceeded")
    return SourceTensorBinding(tensor.offset, tensor.columns, tensor.rows,
        tensor.kind, tensor.byte_count)


def read_q5k_constants(source: PackedGGUF, name: String, first: Int,
                       count: Int, host_bound: Int) raises -> Q5KConstantWindow:
    var binding = _window_binding(source, name, 13, first, count, host_bound)
    var factors = _group_schema()
    var components = List[Q5KConstant]()
    components.reserve(count)
    for offset in range(count):
        var element = first + offset
        var local = element % 256
        var block = binding.file_offset + (element // 256) * 176
        var group = local // 32
        var lane = local % 32
        var fields = factors[group]
        var scale = _read_field(source, block, fields.scale_low) | (_read_field(source, block, fields.scale_high) << 4)
        var minimum = _read_field(source, block, fields.min_low) | (_read_field(source, block, fields.min_high) << 4)
        var low = _read_field(source, block, SourceBitField(48 + (group // 2) * 32 + lane, (group % 2) * 4, 4))
        var high = _read_field(source, block, SourceBitField(16 + lane, group, 1))
        var d = source.source._read_u16(block)
        var dmin = source.source._read_u16(block + 2)
        components.append(Q5KConstant(d, dmin, binary16_to_binary32_bits(d),
            binary16_to_binary32_bits(dmin), low | (high << 4), scale, minimum))
    return Q5KConstantWindow(binding, first, components^)


def read_q6k_constants(source: PackedGGUF, name: String, first: Int,
                       count: Int, host_bound: Int) raises -> Q6KConstantWindow:
    var binding = _window_binding(source, name, 14, first, count, host_bound)
    var components = List[Q6KConstant]()
    components.reserve(count)
    # Original field descriptors for the four quadrants of each source half.
    var low_origins: List[Int] = [0, 32, 0, 32]
    var low_bits: List[Int] = [0, 0, 4, 4]
    var high_bits: List[Int] = [0, 2, 4, 6]
    for offset in range(count):
        var element = first + offset
        var local = element % 256
        var block = binding.file_offset + (element // 256) * 210
        var half = local // 128
        var quadrant = (local % 128) // 32
        var lane = local % 32
        var low = _read_field(source, block, SourceBitField(half * 64 + low_origins[quadrant] + lane, low_bits[quadrant], 4))
        var high = _read_field(source, block, SourceBitField(128 + half * 32 + lane, high_bits[quadrant], 2))
        var centered = Int(low | (high << 4)) - 32
        var scale_byte = Int(_read_field(source, block, SourceBitField(192 + local // 16, 0, 8)))
        var signed_scale = scale_byte - (256 if scale_byte >= 128 else 0)
        var d = source.source._read_u16(block + 208)
        components.append(Q6KConstant(d, binary16_to_binary32_bits(d),
            Int8(centered), Int8(signed_scale)))
    return Q6KConstantWindow(binding, first, components^)


def read_q5k_constant_window(path: String, name: String, first: Int,
                            count: Int, host_bound: Int) raises -> Q5KConstantWindow:
    var source = PackedGGUF(path)
    return read_q5k_constants(source, name, first, count, host_bound)


def read_q6k_constant_window(path: String, name: String, first: Int,
                            count: Int, host_bound: Int) raises -> Q6KConstantWindow:
    var source = PackedGGUF(path)
    return read_q6k_constants(source, name, first, count, host_bound)
