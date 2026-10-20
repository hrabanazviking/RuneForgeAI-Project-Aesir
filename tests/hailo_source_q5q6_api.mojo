# Test-only source mutation/ownership seam, static fields only.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.source_q5q6_constants import read_q5k_constants, read_q6k_constants
from smidr.tools.source_q5q6_constants import describe_q5k, describe_q6k


def main() raises:
    var args = argv()
    if len(args) != 4:
        raise Error("usage: hailo_source_q5q6_api source case kind")
    var source = PackedGGUF(args[1])
    var mode = args[2]
    var kind = Int(args[3])
    var bound = 4
    var count = 1
    if mode == "closed":
        source.source.close()
    elif mode == "bytes":
        source.tensors["matrix.weight"].byte_count -= 1
    elif mode == "offset":
        source.tensors["matrix.weight"].offset = Int(source.source.file_size)
    elif mode == "metadata":
        source.tensors["matrix.weight"].offset = 0
    elif mode == "data_offset":
        source.data_offset = -1
    elif mode == "data_tail":
        source.data_offset = Int(source.source.file_size) + 1
    elif mode == "shape":
        source.tensors["matrix.weight"].rows = -1
    elif mode == "overflow":
        source.tensors["matrix.weight"].columns = 9223372036854775552
        source.tensors["matrix.weight"].rows = 2
    elif mode == "alignment":
        source.tensors["matrix.weight"].columns = 255
    elif mode == "kind":
        source.tensors["matrix.weight"].kind = 14 if kind == 13 else 13
    elif mode == "bound_zero":
        bound = 0
    elif mode == "bound_negative":
        bound = -1
    elif mode == "bound_short":
        bound = 1
        count = 2
    elif mode != "ownership":
        raise Error("SourceKConstants: unknown test mutation")
    if kind == 13:
        var window = read_q5k_constants(source, "matrix.weight", 0, count, bound)
        if mode == "ownership":
            var other = read_q5k_constants(source, "matrix.weight", 0, 1, 1)
            var saved = other.components[0].q
            window.components[0].q ^= 31
            if other.components[0].q != saved:
                raise Error("SourceKConstants: Q5 window aliases another owner")
            source.source.close()
            print(describe_q5k(other))
            return
        print(describe_q5k(window))
    elif kind == 14:
        var window = read_q6k_constants(source, "matrix.weight", 0, count, bound)
        if mode == "ownership":
            var other = read_q6k_constants(source, "matrix.weight", 0, 1, 1)
            var saved = other.components[0].q
            window.components[0].q = 31
            if other.components[0].q != saved:
                raise Error("SourceKConstants: Q6 window aliases another owner")
            source.source.close()
            print(describe_q6k(other))
            return
        print(describe_q6k(window))
    else:
        raise Error("SourceKConstants: unknown test kind")
