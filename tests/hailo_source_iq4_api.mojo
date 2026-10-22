# Test-only ownership/mutable-descriptor and source field seam; no LLM math.
from std.sys import argv
from loader.packed_gguf import PackedGGUF, packed_block_geometry, packed_row_bytes
from smidr.source_iq4_constants import read_iq4_constants
from smidr.tools.source_iq4_constants import describe_iq4


def main() raises:
    var args = argv()
    if len(args) == 4 and args[1] == "geometry":
        var kind = Int(args[2])
        var geometry = packed_block_geometry(kind)
        var bytes = packed_row_bytes(kind, Int(args[3]))
        print("[" + String(geometry.elements) + "," + String(geometry.bytes) + "," + String(bytes) + "]")
        return
    if len(args) != 3:
        raise Error("usage: hailo_source_iq4_api source mode")
    var source = PackedGGUF(args[1])
    var mode = args[2]
    var name = String("matrix\0tail.weight") if mode == "nul_name" else String("matrix.weight")
    var count = 1
    var bound = 4
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
        source.tensor_shapes[name][0] += 256
    elif mode == "shape_missing":
        _ = source.tensor_shapes.pop(name)
    elif mode == "rank":
        source.tensor_shapes[name].append(1)
    elif mode == "file_size":
        source.source.file_size -= 1
    elif mode == "rows":
        source.tensors[name].rows = -1
    elif mode == "overflow":
        source.tensors[name].columns = 9223372036854775776
        source.tensors[name].rows = 2
        source.tensor_shapes[name][0] = source.tensors[name].columns
        source.tensor_shapes[name][1] = 2
    elif mode == "alignment":
        source.tensors[name].columns = 255
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
                _ = read_iq4_constants(source, name, 0, 1, 1)
            except:
                refused = True
            if not refused:
                raise Error("SourceIQ4Test: invalid mutable source was used")
            source.tensors[name] = saved
            var fresh = read_iq4_constants(source, name, 0, 1, 1)
            if len(fresh.components) != 1:
                raise Error("SourceIQ4Test: fresh source read failed after refusal")
    elif mode != "ownership" and mode != "nul_name":
        raise Error("SourceIQ4Test: unknown test mutation")
    var window = read_iq4_constants(source, name, 0, count, bound)
    if mode == "ownership":
        var other = read_iq4_constants(source, name, 0, 1, 1)
        var saved_q = other.components[0].q
        window.components[0].q = Int8(0) if saved_q != 0 else Int8(1)
        window.components[0].d_bits = 0
        window.components[0].group_scale_present = not window.components[0].group_scale_present
        window.components[0].scale = 0
        window.components[0].code = 0
        window.binding.file_offset = -1
        if other.components[0].q != saved_q or other.binding.file_offset < 0:
            raise Error("SourceIQ4Test: source windows alias")
        source.source.close()
        source.tensors[name].offset = -1
        print(describe_iq4(other))
        return
    print(describe_iq4(window))
