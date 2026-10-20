# Copied source-shape metadata and mutation checks, never tensor values.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.tools.semantic_plan import _integers


def main() raises:
    var args = argv()
    if len(args) != 4:
        raise Error("ShapesApi: expected source/name/mode")
    var source = PackedGGUF(args[1])
    var name = String(args[2])
    var original = source.tensor_shape(name)
    if args[3] == "ownership":
        var modified = source.tensor_shape(name)
        modified[0] = 999
        if source.tensor_shape(name) != original:
            raise Error("ShapesApi: returned shape aliases source")
        source.tensor_shapes[name][0] = 777
        source.source.close()
        print(_integers(original))
        return
    if args[3] == "missing_shape":
        _ = source.tensor_shapes.pop(name)
    elif args[3] == "missing_tensor":
        _ = source.tensors.pop(name)
    elif args[3] == "empty":
        source.tensor_shapes[name].clear()
    elif args[3] == "rank":
        source.tensor_shapes[name].append(1)
        source.tensor_shapes[name].append(1)
    elif args[3] == "columns":
        source.tensor_shapes[name][0] += 1
    elif args[3] == "rows":
        var replacement: List[Int] = [original[0], 999]
        source.tensor_shapes[name] = replacement^
    elif args[3] == "vector_rows":
        source.tensors[name].rows = 2
        var replacement: List[Int] = [original[0]]
        source.tensor_shapes[name] = replacement^
    elif args[3] == "zero_columns":
        source.tensors[name].columns = 0
        source.tensor_shapes[name][0] = 0
    else:
        raise Error("ShapesApi: unknown mode")
    print(_integers(source.tensor_shape(name)))
