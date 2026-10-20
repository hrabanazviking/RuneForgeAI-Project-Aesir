# Static compiler constants only. Integer bit decoding, not model execution.
from loader.packed_gguf import PackedGGUF
from smidr.source_inventory import SourceTensorBinding
from smidr.semantic_plan import checked_product


def binary16_to_binary32_bits(bits: UInt16) -> UInt32:
    var sign = UInt32(bits & 32768) << 16
    var exponent = Int((bits >> 10) & 31)
    var fraction = UInt32(bits & 1023)
    if exponent == 0:
        if fraction == 0:
            return sign
        var unbiased = -14
        while (fraction & 1024) == 0:
            fraction <<= 1
            unbiased -= 1
        return sign | (UInt32(unbiased + 127) << 23) | ((fraction & 1023) << 13)
    if exponent == 31:
        # Representation-only payload/signaling-bit placement; no FP evaluation
        # or NaN quieting is performed. This is not a device NaN behavior claim.
        return sign | UInt32(0x7f800000) | (fraction << 13)
    return sign | (UInt32(exponent + 112) << 23) | (fraction << 13)


def bfloat16_to_binary32_bits(bits: UInt16) -> UInt32:
    return UInt32(bits) << 16


@fieldwise_init
struct FloatingConstantWindow(Movable):
    var binding: SourceTensorBinding
    var first: Int
    var bits: List[UInt32]


def read_floating_constants(source: PackedGGUF, name: String, first: Int,
                            count: Int, host_window_limit: Int) raises -> FloatingConstantWindow:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceFloatConstants: source mapping is closed")
    if name not in source.tensors:
        raise Error("SourceFloatConstants: missing tensor " + name)
    var tensor = source.tensors[name]
    if tensor.kind != 0 and tensor.kind != 1 and tensor.kind != 30:
        raise Error("SourceFloatConstants: packed source conversion unresolved for kind " + String(tensor.kind))
    var total = checked_product(tensor.columns, tensor.rows)
    var width = 4 if tensor.kind == 0 else 2
    var byte_count = checked_product(total, width)
    var source_bytes = Int(source.source.file_size)
    if source.data_offset < 0 or source.data_offset > source_bytes or tensor.offset < source.data_offset or tensor.offset > source_bytes or tensor.byte_count != byte_count or tensor.byte_count > source_bytes - tensor.offset:
        raise Error("SourceFloatConstants: tensor source extent mismatch")
    if first < 0 or first >= total or count <= 0 or host_window_limit <= 0 or count > host_window_limit or count > total - first:
        raise Error("SourceFloatConstants: invalid element window or explicit host bound")
    # Full extent was checked first, so these products/offsets fit within it.
    var offset = tensor.offset + first * width
    var bits = List[UInt32]()
    bits.reserve(count)
    for i in range(count):
        var cursor = offset + i * width
        if tensor.kind == 0:
            bits.append(source.source._read_u32(cursor))
        elif tensor.kind == 1:
            bits.append(binary16_to_binary32_bits(source.source._read_u16(cursor)))
        else:
            bits.append(bfloat16_to_binary32_bits(source.source._read_u16(cursor)))
    var binding = SourceTensorBinding(tensor.offset, tensor.columns, tensor.rows,
                                     tensor.kind, tensor.byte_count)
    return FloatingConstantWindow(binding, first, bits^)


def read_floating_constant_window(path: String, name: String, first: Int,
                                  count: Int, host_window_limit: Int) raises -> FloatingConstantWindow:
    var source = PackedGGUF(path)
    # Source mapping is closed on return; only copied values and bits escape.
    return read_floating_constants(source, name, first, count, host_window_limit)
