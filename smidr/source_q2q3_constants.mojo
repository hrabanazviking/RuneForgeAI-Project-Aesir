# Original source fields from HAILO10H_Q2Q3_SOURCE_LAYOUT.md.
# No floating product/subtraction, device packing or model evaluation.
from loader.packed_gguf import PackedGGUF, packed_row_bytes, packed_block_geometry
from smidr.source_inventory import SourceTensorBinding
from smidr.semantic_plan import checked_product
from smidr.source_float_constants import binary16_to_binary32_bits


@fieldwise_init
struct Q2Q3Constant(ImplicitlyCopyable, Movable):
    var d_bits: UInt16
    var dmin_bits: UInt16
    var d_binary32_bits: UInt32
    var dmin_binary32_bits: UInt32
    var minimum_present: Bool
    var scale: Int8
    var minimum: UInt8
    var q: Int8


@fieldwise_init
struct Q2Q3ConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var components: List[Q2Q3Constant]


def _block_byte(source: PackedGGUF, block: Int, index: Int) raises -> Int:
    var pair = source.source._read_u16(block + (index // 2) * 2)
    return Int((pair >> UInt16((index % 2) * 8)) & 255)


def read_q2q3_constants(source: PackedGGUF, name: String, first: Int,
                             count: Int, host_element_bound: Int) raises -> Q2Q3ConstantWindow:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceQ2Q3Constants: live mapped source owner required")
    if name not in source.tensors:
        raise Error("SourceQ2Q3Constants: source tensor is missing")
    var tensor = source.tensors[name]
    var kind = tensor.kind
    if kind != 10 and kind != 11:
        raise Error("SourceQ2Q3Constants: Q2_K/Q3_K source kind required")
    _ = source.tensor_shape(name)
    var elements = checked_product(tensor.columns, tensor.rows)
    var row_bytes = packed_row_bytes(kind, tensor.columns)
    var bytes = checked_product(row_bytes, tensor.rows)
    var file_bytes = Int(source.source.file_size)
    if source.data_offset < 0 or source.data_offset > file_bytes or tensor.offset < source.data_offset or tensor.offset > file_bytes or tensor.byte_count != bytes or bytes > file_bytes - tensor.offset:
        raise Error("SourceQ2Q3Constants: source byte extent mismatch")
    source.source._require_range(tensor.offset, bytes)
    if first < 0 or count <= 0 or first >= elements or count > elements - first:
        raise Error("SourceQ2Q3Constants: selection exceeds source elements")
    if host_element_bound <= 0 or count > host_element_bound:
        raise Error("SourceQ2Q3Constants: explicit host element bound exceeded")
    var geometry = packed_block_geometry(kind)
    var minimum_present = kind == 10
    var low_origin = 16 if minimum_present else 32
    var d_origin = 80 if minimum_present else 108
    var result = List[Q2Q3Constant]()
    result.reserve(count)
    for i in range(count):
        var element = first + i
        var block = tensor.offset + (element // geometry.elements) * geometry.bytes
        var lane = element % geometry.elements
        var group = lane // 16
        var low_index = low_origin + 32 * (lane // 128) + lane % 32
        var quant = (_block_byte(source, block, low_index) >> (2 * ((lane % 128) // 32))) & 3
        var scale: Int
        var minimum = 0
        if minimum_present:
            var factors = _block_byte(source, block, group)
            scale = factors & 15
            minimum = factors >> 4
        else:
            var high = (_block_byte(source, block, lane % 32) >> (lane // 32)) & 1
            quant -= 4 if high == 0 else 0
            var low_scale = (_block_byte(source, block, 96 + group % 8) >> (4 * (group // 8))) & 15
            var high_scale = (_block_byte(source, block, 104 + group % 4) >> (2 * (group // 4))) & 3
            scale = low_scale + 16 * high_scale - 32
        var d = source.source._read_u16(block + d_origin)
        var dmin = source.source._read_u16(block + 82) if minimum_present else UInt16(0)
        result.append(Q2Q3Constant(d, dmin, binary16_to_binary32_bits(d),
            binary16_to_binary32_bits(dmin), minimum_present, Int8(scale), UInt8(minimum), Int8(quant)))
    return Q2Q3ConstantWindow(SourceTensorBinding(tensor.offset, tensor.columns,
        tensor.rows, kind, tensor.byte_count), first, result^)


def read_q2q3_constant_window(path: String, name: String, first: Int,
                             count: Int, host_element_bound: Int) raises -> Q2Q3ConstantWindow:
    var source = PackedGGUF(path)
    return read_q2q3_constants(source, name, first, count, host_element_bound)
