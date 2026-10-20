# Constant representation/range/ownership checks only; no numerical kernels.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.source_float_constants import read_floating_constants, read_floating_constant_window


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_source_float_api <source.gguf> <case>")
    var mode = args[2]
    if mode == "ownership":
        var first = read_floating_constant_window(args[1], "matrix.weight", 1, 4, 4)
        var saved = first.bits.copy()
        first.bits[0] = 0
        var fresh = read_floating_constant_window(args[1], "matrix.weight", 1, 4, 4)
        for i in range(4):
            if fresh.bits[i] != saved[i]:
                raise Error("SourceFloatConstants: retained window aliases another owner")
        print("owned-source-constants-pass")
        return
    var source = PackedGGUF(args[1])
    if mode == "closed":
        source.source.close()
    elif mode == "byte_count":
        source.tensors["matrix.weight"].byte_count -= 1
    elif mode == "offset":
        source.tensors["matrix.weight"].offset = Int(source.source.file_size)
    elif mode == "metadata_offset":
        source.tensors["matrix.weight"].offset = 0
    elif mode == "negative_shape":
        source.tensors["matrix.weight"].columns = -1
    elif mode == "overflow_shape":
        source.tensors["matrix.weight"].columns = 9223372036854775807
        source.tensors["matrix.weight"].rows = 2
    elif mode == "kind":
        source.tensors["matrix.weight"].kind = 99
    elif mode == "limit":
        var window = read_floating_constants(source, "matrix.weight", 0, 1, 0)
        print(len(window.bits))
        return
    elif mode == "u16_negative":
        print(source.source._read_u16(-1))
        return
    elif mode == "u16_tail":
        print(source.source._read_u16(Int(source.source.file_size) - 1))
        return
    elif mode == "u16_closed":
        source.source.close()
        print(source.source._read_u16(0))
        return
    else:
        raise Error("unknown test mode")
    var window = read_floating_constants(source, "matrix.weight", 0, 1, 4)
    print(len(window.bits))
