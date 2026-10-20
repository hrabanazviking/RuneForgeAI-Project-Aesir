# Native values/ownership only; not an inference path.
from std.sys import argv
from std.memory import bitcast
from smidr.tools.program_integrity import _signed
from smidr.tools.semantic_plan import _integers
from smidr.tools.typed_decoder import _synthetic
from smidr.semantic_plan import build_dense_semantic_plan, gguf_dense_decoder_parameters, _check_disjoint_spans
from smidr.tools.semantic_plan import describe_semantic_plan
from loader.packed_gguf import PackedGGUF


def main() raises:
    var args = argv()
    if len(args) >= 2 and args[1] == "spans":
        if (len(args) - 2) % 2 != 0:
            raise Error("TypedDecoderApi: expected start/end pairs")
        var starts = List[Int]()
        var ends = List[Int]()
        for i in range(2, len(args), 2):
            var start = _signed(args[i])
            var end = _signed(args[i + 1])
            if start < 0 or end <= start:
                raise Error("TypedDecoderApi: invalid positive span")
            starts.append(start)
            ends.append(end)
        _check_disjoint_spans(starts, ends)
        print("{\"starts\":" + _integers(starts) + ",\"ends\":" + _integers(ends) + "}")
        return
    if len(args) == 2:
        var source = PackedGGUF(args[1])
        source.source.close()
        var refused = False
        try:
            _ = gguf_dense_decoder_parameters(source)
        except:
            refused = True
        if not refused:
            raise Error("TypedDecoderApi: closed metadata owner accepted")
    # Exact Float32 bits survive typed construction, including subnormals.
    var words: List[UInt32] = [1, 2, 0x007FFFFF, 0x00800000, 0x00800001,
        0x3F000001, 0x3F800000, 0x40000001, 0x477FE001, 0x7F7FFFFF]
    for word in words:
        var input = _synthetic()
        input.parameters.rope_base = bitcast[DType.float32](word)
        input.parameters.rms_epsilon = bitcast[DType.float32](word)
        var inventory = input.take_inventory()
        var graph = build_dense_semantic_plan(inventory^, input.parameters, 3, 0, 16)
        if bitcast[DType.uint32](graph.rope_base) != word or bitcast[DType.uint32](graph.rms_epsilon) != word:
            raise Error("TypedDecoderApi: Float32 parameter bits changed")
    var first = _synthetic()
    var first_inventory = first.take_inventory()
    var graph = build_dense_semantic_plan(first_inventory^, first.parameters, 3, 0, 16)
    var second = _synthetic()
    var second_inventory = second.take_inventory()
    var other = build_dense_semantic_plan(second_inventory^, second.parameters, 3, 0, 16)
    var snapshot = describe_semantic_plan(other)
    var graph_snapshot = describe_semantic_plan(graph)
    first.parameters.hidden = 999
    first.parameters.source_layout = "changed"
    if describe_semantic_plan(graph) != graph_snapshot:
        raise Error("TypedDecoderApi: graph borrows parameters")
    graph.tensors[0].shape[0] = 100
    graph.source.bindings["token_embd.weight"].file_offset = 0
    if describe_semantic_plan(other) != snapshot or other.source_layout != "reference":
        raise Error("TypedDecoderApi: typed graph retains borrowed input/output storage")
    print("{\"float32_bits_checked\":20,\"ownership_checked\":true,\"device_access\":false,\"execution_tested\":false}")
