# API range/extent/ownership refusals; static constants only.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.source_q4k_constants import read_q4k_constants, read_q4k_constant_window


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_source_q4k_api <source.gguf> <case>")
    var mode = args[2]
    if mode == "ownership":
        var first = read_q4k_constant_window(args[1], "matrix.weight", 250, 12, 12)
        var saved = first.components.copy()
        first.components[0].q ^= 15
        first.components[0].d_bits ^= 65535
        var fresh = read_q4k_constant_window(args[1], "matrix.weight", 250, 12, 12)
        for i in range(12):
            var a = fresh.components[i]
            var b = saved[i]
            if a.q != b.q or a.d_bits != b.d_bits or a.dmin_bits != b.dmin_bits or a.scale_factor != b.scale_factor or a.min_factor != b.min_factor or a.d_binary32_bits != b.d_binary32_bits or a.dmin_binary32_bits != b.dmin_binary32_bits:
                raise Error("SourceQ4KConstants: retained window aliases another owner")
        print("owned-q4k-constants-pass")
        return
    var source = PackedGGUF(args[1])
    var bound = 4
    var count = 1
    if mode == "closed":
        source.source.close()
    elif mode == "byte_count":
        source.tensors["matrix.weight"].byte_count -= 1
    elif mode == "offset":
        source.tensors["matrix.weight"].offset = Int(source.source.file_size)
    elif mode == "metadata_offset":
        source.tensors["matrix.weight"].offset = 0
    elif mode == "data_offset":
        source.data_offset = -1
    elif mode == "data_tail":
        source.data_offset = Int(source.source.file_size) + 1
    elif mode == "negative_shape":
        source.tensors["matrix.weight"].rows = -1
    elif mode == "overflow_shape":
        source.tensors["matrix.weight"].columns = 9223372036854775552
        source.tensors["matrix.weight"].rows = 2
    elif mode == "unaligned_columns":
        source.tensors["matrix.weight"].columns = 255
    elif mode == "kind":
        source.tensors["matrix.weight"].kind = 13
    elif mode == "limit":
        bound = 0
    elif mode == "negative_limit":
        bound = -1
    elif mode == "narrow_limit":
        bound = 1
        count = 2
    else:
        raise Error("unknown test mode")
    var window = read_q4k_constants(source, "matrix.weight", 0, count, bound)
    print(len(window.components))
