# Ordinary source representation windows for compilation, never model math.
from armvegr.safetensors import SafetensorsLoader
from smidr.safetensors_inventory import SafetensorsTensor
from smidr.source_float_constants import binary16_to_binary32_bits, bfloat16_to_binary32_bits


@fieldwise_init
struct SafetensorsConstantWindow(Movable):
    var binding: SafetensorsTensor
    var source_bytes: Int64
    var data_offset: Int64
    var first: Int
    var count: Int
    var raw_words: List[UInt32]
    var binary32_words: List[UInt32]


def _binding(source: SafetensorsLoader, name: String) raises -> SafetensorsTensor:
    if not source.opened or source.fd < 0:
        raise Error("SafetensorsConstants: live mapped source owner required")
    if source.file_size < 8 or source.header_size < 2 or source.header_size > source.file_size - 8:
        raise Error("SafetensorsConstants: invalid source/header extent")
    var index = source.find(name)
    ref tensor = source.descs[index]
    if tensor.dtype > 2:
        raise Error("SafetensorsConstants: source dtype conversion not implemented")
    var elements = tensor.element_count()
    var width = Int64(4) if tensor.dtype == 2 else Int64(2)
    if elements > Int64(9223372036854775807) // width:
        raise Error("SafetensorsConstants: tensor byte count overflows")
    var start = Int64(tensor.data_start)
    var end = Int64(tensor.data_end)
    if start < source.header_size + 8 or start > end or end > source.file_size:
        raise Error("SafetensorsConstants: tensor span outside source payload")
    var bytes = end - start
    if bytes != elements * width:
        raise Error("SafetensorsConstants: tensor extent differs from shape")
    return SafetensorsTensor(tensor.name, tensor.dtype, tensor.shape.copy(), elements,
                              tensor.data_start, Int(bytes))


def _word(source: SafetensorsLoader, offset: Int, width: Int) raises -> UInt32:
    source._req(Int64(offset), Int64(width))
    var value = UInt32(0)
    for byte in range(width):
        value |= UInt32(source.map.unsafe_offset(offset + byte).unsafe_load()) << UInt32(8 * byte)
    return value


def read_safetensors_constants(source: SafetensorsLoader, name: String,
                               first: Int, count: Int,
                               element_bound: Int) raises -> SafetensorsConstantWindow:
    var binding = _binding(source, name)
    if first < 0 or count < 0 or Int64(first) > binding.elements or Int64(count) > binding.elements - Int64(first):
        raise Error("SafetensorsConstants: element window outside tensor")
    if element_bound <= 0 or count > element_bound:
        raise Error("SafetensorsConstants: explicit positive element bound exceeded")
    var width = 4 if binding.dtype == 2 else 2
    # The whole shape/span was checked, so window products and sums fit it.
    var start = binding.file_offset + first * width
    var raw = List[UInt32]()
    var expanded = List[UInt32]()
    raw.reserve(count)
    expanded.reserve(count)
    for i in range(count):
        var value = _word(source, start + i * width, width)
        raw.append(value)
        if binding.dtype == 0:
            expanded.append(binary16_to_binary32_bits(UInt16(value)))
        elif binding.dtype == 1:
            expanded.append(bfloat16_to_binary32_bits(UInt16(value)))
        else:
            expanded.append(value)
    return SafetensorsConstantWindow(binding^, source.file_size, source.header_size + 8,
                                      first, count, raw^, expanded^)


def read_safetensors_constant_window(path: String, name: String, first: Int,
                                     count: Int, element_bound: Int,
                                     header_bound: Int, tensor_bound: Int,
                                     rank_bound: Int, work_bound: Int,
                                     depth_bound: Int) raises -> SafetensorsConstantWindow:
    var source = SafetensorsLoader()
    source.open(path, header_bound, tensor_bound, rank_bound, work_bound, depth_bound)
    try:
        var result = read_safetensors_constants(source, name, first, count, element_bound)
        source.close()
        return result^
    except e:
        source.close()
        raise e
