# Test-only ownership/mutable-descriptor and integer digest seam; no LLM math.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.source_q8_constants import read_q8_constants
from smidr.tools.source_q8_constants import describe_q8


def _digest(source: PackedGGUF) raises:
    # Caller supplies a synthetic table of32*65536 elements, not model weights.
    if source.tensors["matrix.weight"].columns != 1024 or source.tensors["matrix.weight"].rows != 2048:
        raise Error("SourceQ8Test: exact synthetic exhaustive geometry required")
    var digest = UInt64(14695981039346656037)
    for block in range(65536):
        var window = read_q8_constants(source, "matrix.weight", block * 32, 32, 32)
        for c in window.components:
            digest = (digest ^ UInt64(c.d_bits)) * UInt64(1099511628211)
            digest = (digest ^ UInt64(c.d_binary32_bits)) * UInt64(1099511628211)
            digest = (digest ^ UInt64(Int(c.q) + 128)) * UInt64(1099511628211)
    print("{\"components\":2097152,\"scale_words\":65536,\"digest\":" + String(digest)
          + ",\"execution_tested\":false,\"device_access\":false}")


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_source_q8_api source mode")
    var source = PackedGGUF(args[1])
    var mode = args[2]
    var name = String("matrix\0tail.weight") if mode == "nul_name" else String("matrix.weight")
    var count = 1
    var bound = 4
    if mode == "digest":
        _digest(source)
        return
    if mode == "closed":
        source.source.close()
    elif mode == "bytes":
        source.tensors[name].byte_count -= 1
    elif mode == "offset":
        source.tensors[name].offset = Int(source.source.file_size)
    elif mode == "metadata":
        source.tensors[name].offset = 0
    elif mode == "data_offset":
        source.data_offset = -1
    elif mode == "data_tail":
        source.data_offset = Int(source.source.file_size) + 1
    elif mode == "shape":
        source.tensor_shapes[name][0] += 32
    elif mode == "rows":
        source.tensors[name].rows = -1
    elif mode == "overflow":
        source.tensors[name].columns = 9223372036854775776
        source.tensors[name].rows = 2
    elif mode == "alignment":
        source.tensors[name].columns = 31
    elif mode == "kind":
        source.tensors[name].kind = 1
    elif mode == "bound_zero":
        bound = 0
    elif mode == "bound_negative":
        bound = -1
    elif mode == "bound_short":
        bound = 1
        count = 2
    elif mode == "recover":
        var saved = source.tensors[name]
        for field in range(4):
            if field == 0:
                source.tensors[name].offset = -1
            elif field == 1:
                source.tensors[name].byte_count = -1
            elif field == 2:
                source.tensors[name].columns = -1
            else:
                source.tensors[name].kind = -1
            var refused = False
            try:
                _ = read_q8_constants(source, name, 0, 1, 1)
            except:
                refused = True
            if not refused:
                raise Error("SourceQ8Test: invalid mutable source was used")
            source.tensors[name] = saved
            var fresh = read_q8_constants(source, name, 0, 1, 1)
            if len(fresh.components) != 1:
                raise Error("SourceQ8Test: fresh source read failed after refusal")
    elif mode != "ownership" and mode != "nul_name":
        raise Error("SourceQ8Test: unknown test mutation")
    var window = read_q8_constants(source, name, 0, count, bound)
    if mode == "ownership":
        var other = read_q8_constants(source, name, 0, 1, 1)
        var saved_q = other.components[0].q
        window.components[0].q = Int8(0) if saved_q != 0 else Int8(1)
        window.binding.file_offset = -1
        if other.components[0].q != saved_q or other.binding.file_offset < 0:
            raise Error("SourceQ8Test: source windows alias")
        source.source.close()
        source.tensors[name].offset = -1
        print(describe_q8(other))
        return
    print(describe_q8(window))
