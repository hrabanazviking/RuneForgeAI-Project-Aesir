# Original source field reader from HAILO10H_Q8_SOURCE_LAYOUT.md.
# Source representation only; no floating product, model or device evaluation.
from loader.packed_gguf import PackedGGUF, packed_row_bytes
from smidr.source_inventory import SourceTensorBinding
from smidr.semantic_plan import checked_product
from smidr.source_float_constants import binary16_to_binary32_bits


@fieldwise_init
struct Q8Constant(ImplicitlyCopyable, Movable):
    var d_bits: UInt16
    var d_binary32_bits: UInt32
    var q: Int8


@fieldwise_init
struct Q8ConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var components: List[Q8Constant]


def read_q8_constants(source: PackedGGUF, name: String, first: Int,
                      count: Int, host_element_bound: Int) raises -> Q8ConstantWindow:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceQ8Constants: live mapped source owner required")
    if name not in source.tensors:
        raise Error("SourceQ8Constants: source tensor is missing")
    var tensor = source.tensors[name]
    if tensor.kind != 8:
        raise Error("SourceQ8Constants: Q8_0 source kind required")
    # Revalidate original admitted axes as well as mutable packed extents.
    _ = source.tensor_shape(name)
    var elements = checked_product(tensor.columns, tensor.rows)
    var row_bytes = packed_row_bytes(8, tensor.columns)
    var bytes = checked_product(row_bytes, tensor.rows)
    var file_bytes = Int(source.source.file_size)
    if source.data_offset < 0 or source.data_offset > file_bytes or tensor.offset < source.data_offset or tensor.offset > file_bytes or tensor.byte_count != bytes or bytes > file_bytes - tensor.offset:
        raise Error("SourceQ8Constants: source byte extent mismatch")
    source.source._require_range(tensor.offset, bytes)
    if first < 0 or count <= 0 or first >= elements or count > elements - first:
        raise Error("SourceQ8Constants: selection exceeds source elements")
    if host_element_bound <= 0 or count > host_element_bound:
        raise Error("SourceQ8Constants: explicit host element bound exceeded")
    var result = List[Q8Constant]()
    result.reserve(count)
    for i in range(count):
        var element = first + i
        var block = tensor.offset + (element // 32) * 34
        var lane = element % 32
        var word = source.source._read_u16(block + 2 + (lane // 2) * 2)
        var quant_byte = Int((word >> UInt16((lane % 2) * 8)) & 255)
        var signed_quant = quant_byte - (256 if quant_byte >= 128 else 0)
        var d = source.source._read_u16(block)
        result.append(Q8Constant(d, binary16_to_binary32_bits(d), Int8(signed_quant)))
    return Q8ConstantWindow(SourceTensorBinding(tensor.offset, tensor.columns,
        tensor.rows, tensor.kind, tensor.byte_count), first, result^)


def read_q8_constant_window(path: String, name: String, first: Int,
                           count: Int, host_element_bound: Int) raises -> Q8ConstantWindow:
    var source = PackedGGUF(path)
    return read_q8_constants(source, name, first, count, host_element_bound)
