# Original source fields from HAILO10H_CLASSIC32_SOURCE_LAYOUT.md.
# No floating product/addition, device packing or model evaluation.
from loader.packed_gguf import PackedGGUF, packed_row_bytes, packed_block_geometry
from smidr.source_inventory import SourceTensorBinding
from smidr.semantic_plan import checked_product
from smidr.source_float_constants import binary16_to_binary32_bits


@fieldwise_init
struct Classic32Constant(ImplicitlyCopyable, Movable):
    var d_bits: UInt16
    var m_bits: UInt16
    var d_binary32_bits: UInt32
    var m_binary32_bits: UInt32
    var bias_present: Bool
    var q: Int8


@fieldwise_init
struct Classic32ConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var components: List[Classic32Constant]


def read_classic32_constants(source: PackedGGUF, name: String, first: Int,
                             count: Int, host_element_bound: Int) raises -> Classic32ConstantWindow:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceClassic32Constants: live mapped source owner required")
    if name not in source.tensors:
        raise Error("SourceClassic32Constants: source tensor is missing")
    var tensor = source.tensors[name]
    var kind = tensor.kind
    if kind != 2 and kind != 3 and kind != 6 and kind != 7:
        raise Error("SourceClassic32Constants: classic Q4/Q5 source kind required")
    _ = source.tensor_shape(name)
    var elements = checked_product(tensor.columns, tensor.rows)
    var row_bytes = packed_row_bytes(kind, tensor.columns)
    var bytes = checked_product(row_bytes, tensor.rows)
    var file_bytes = Int(source.source.file_size)
    if source.data_offset < 0 or source.data_offset > file_bytes or tensor.offset < source.data_offset or tensor.offset > file_bytes or tensor.byte_count != bytes or bytes > file_bytes - tensor.offset:
        raise Error("SourceClassic32Constants: source byte extent mismatch")
    source.source._require_range(tensor.offset, bytes)
    if first < 0 or count <= 0 or first >= elements or count > elements - first:
        raise Error("SourceClassic32Constants: selection exceeds source elements")
    if host_element_bound <= 0 or count > host_element_bound:
        raise Error("SourceClassic32Constants: explicit host element bound exceeded")
    var geometry = packed_block_geometry(kind)
    var bias_present = kind == 3 or kind == 7
    var high_present = kind == 6 or kind == 7
    var high_origin = 4 if bias_present else 2
    var nibble_origin = high_origin + (4 if high_present else 0)
    var centering = 0 if bias_present else (16 if high_present else 8)
    var result = List[Classic32Constant]()
    result.reserve(count)
    for i in range(count):
        var element = first + i
        var block = tensor.offset + (element // geometry.elements) * geometry.bytes
        var lane = element % geometry.elements
        # Half-word accesses stay inside the already proven complete block.
        var nibble_index = lane % 16
        var pair = source.source._read_u16(block + nibble_origin + (nibble_index // 2) * 2)
        var packed_byte = Int((pair >> UInt16((nibble_index % 2) * 8)) & 255)
        var quant = (packed_byte >> ((lane // 16) * 4)) & 15
        if high_present:
            var high = source.source._read_u16(block + high_origin + (lane // 16) * 2)
            quant += Int((high >> UInt16(lane % 16)) & 1) * 16
        var d = source.source._read_u16(block)
        var m = source.source._read_u16(block + 2) if bias_present else UInt16(0)
        result.append(Classic32Constant(d, m, binary16_to_binary32_bits(d),
            binary16_to_binary32_bits(m), bias_present, Int8(quant - centering)))
    return Classic32ConstantWindow(SourceTensorBinding(tensor.offset, tensor.columns,
        tensor.rows, kind, tensor.byte_count), first, result^)


def read_classic32_constant_window(path: String, name: String, first: Int,
                                  count: Int, host_element_bound: Int) raises -> Classic32ConstantWindow:
    var source = PackedGGUF(path)
    return read_classic32_constants(source, name, first, count, host_element_bound)
