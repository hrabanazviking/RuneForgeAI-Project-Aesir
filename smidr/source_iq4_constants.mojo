# Original source fields from HAILO10H_IQ4_SOURCE_LAYOUT.md.
# No floating product/subtraction, device packing or model evaluation.
from loader.packed_gguf import PackedGGUF, packed_row_bytes, packed_block_geometry
from smidr.source_inventory import SourceTensorBinding
from smidr.semantic_plan import checked_product
from smidr.source_float_constants import binary16_to_binary32_bits


@fieldwise_init
struct IQ4Constant(ImplicitlyCopyable, Movable):
    var d_bits: UInt16
    var d_binary32_bits: UInt32
    var group_scale_present: Bool
    var scale: Int8
    var code: UInt8
    var q: Int8


@fieldwise_init
struct IQ4ConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var components: List[IQ4Constant]


# Public source-format data, ggml MIT pin a05c9922613c6a2230dbb1d0de679519ecafb4f0.
# Attribution/license: docs/evidence/iq4-source-contract-2026-10-22/LICENSE.
# This original lookup preserves code identity; it performs no floating product.
def _source_code_value(code: Int) -> Int8:
    if code == 0:
        return Int8(-127)
    if code == 1:
        return Int8(-104)
    if code == 2:
        return Int8(-83)
    if code == 3:
        return Int8(-65)
    if code == 4:
        return Int8(-49)
    if code == 5:
        return Int8(-35)
    if code == 6:
        return Int8(-22)
    if code == 7:
        return Int8(-10)
    if code == 8:
        return Int8(1)
    if code == 9:
        return Int8(13)
    if code == 10:
        return Int8(25)
    if code == 11:
        return Int8(38)
    if code == 12:
        return Int8(53)
    if code == 13:
        return Int8(69)
    if code == 14:
        return Int8(89)
    return Int8(113)


def _block_byte(source: PackedGGUF, block: Int, index: Int) raises -> Int:
    var pair = source.source._read_u16(block + (index // 2) * 2)
    return Int((pair >> UInt16((index % 2) * 8)) & 255)


def read_iq4_constants(source: PackedGGUF, name: String, first: Int,
                             count: Int, host_element_bound: Int) raises -> IQ4ConstantWindow:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceIQ4Constants: live mapped source owner required")
    if name not in source.tensors:
        raise Error("SourceIQ4Constants: source tensor is missing")
    var tensor = source.tensors[name]
    var kind = tensor.kind
    if kind != 20 and kind != 23:
        raise Error("SourceIQ4Constants: IQ4_NL/IQ4_XS source kind required")
    _ = source.tensor_shape(name)
    var elements = checked_product(tensor.columns, tensor.rows)
    var row_bytes = packed_row_bytes(kind, tensor.columns)
    var bytes = checked_product(row_bytes, tensor.rows)
    var file_bytes = Int(source.source.file_size)
    if source.data_offset < 0 or source.data_offset > file_bytes or tensor.offset < source.data_offset or tensor.offset > file_bytes or tensor.byte_count != bytes or bytes > file_bytes - tensor.offset:
        raise Error("SourceIQ4Constants: source byte extent mismatch")
    source.source._require_range(tensor.offset, bytes)
    if first < 0 or count <= 0 or first >= elements or count > elements - first:
        raise Error("SourceIQ4Constants: selection exceeds source elements")
    if host_element_bound <= 0 or count > host_element_bound:
        raise Error("SourceIQ4Constants: explicit host element bound exceeded")
    var geometry = packed_block_geometry(kind)
    var group_scale_present = kind == 23
    var quant_origin = 8 if group_scale_present else 2
    var result = List[IQ4Constant]()
    result.reserve(count)
    for i in range(count):
        var element = first + i
        var block = tensor.offset + (element // geometry.elements) * geometry.bytes
        var lane = element % geometry.elements
        var group = lane // 32
        var quant_index = quant_origin + 16 * group + lane % 16
        var code = (_block_byte(source, block, quant_index) >> (4 * ((lane % 32) // 16))) & 15
        var scale = 1
        if group_scale_present:
            var low = (_block_byte(source, block, 4 + group // 2) >> (4 * (group % 2))) & 15
            var high = Int((source.source._read_u16(block + 2) >> UInt16(2 * group)) & 3)
            scale = low + 16 * high - 32
        var d = source.source._read_u16(block)
        result.append(IQ4Constant(d, binary16_to_binary32_bits(d),
            group_scale_present, Int8(scale), UInt8(code), _source_code_value(code)))
    return IQ4ConstantWindow(SourceTensorBinding(tensor.offset, tensor.columns,
        tensor.rows, kind, tensor.byte_count), first, result^)


def read_iq4_constant_window(path: String, name: String, first: Int,
                            count: Int, host_element_bound: Int) raises -> IQ4ConstantWindow:
    var source = PackedGGUF(path)
    return read_iq4_constants(source, name, first, count, host_element_bound)
