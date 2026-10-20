# Declared source axes only; no weight conversion, graph or inference.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.tools.semantic_plan import _integers
from smidr.tools.source_inventory import _quote


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: gguf_shapes <source.gguf>")
    var source = PackedGGUF(args[1])
    try:
        var text = String("{\"execution_tested\":false,\"shapes\":{")
        var first = True
        for name in source.tensors:
            if not first:
                text += ","
            first = False
            text += _quote(name) + ":" + _integers(source.tensor_shape(name))
        source.source.close()
        print(text + "}}")
    except e:
        source.source.close()
        raise e
