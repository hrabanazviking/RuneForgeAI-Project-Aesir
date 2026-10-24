# Internal retained source-sharing inspector. No model conversion or execution.
from std.sys import argv
from smidr.owned_tied_output_compiler import load_owned_indexed_tied_output, load_owned_unindexed_tied_output
from smidr.tools.owned_ordinary_binding import _binding_policy, _root_policy, _copy_policy
from smidr.tools.owned_ordinary_compiler import _request, _report
from smidr.tools.sealed_source_collection import describe_indexed, describe_unindexed
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.tools.ordinary_tensor_identity import describe_comparison


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) == 61 and args[1] == "indexed":
        var policy = _binding_policy(args, 2, True)
        var request = _request(args, 46)
        var context = load_owned_indexed_tied_output(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 29), policy, request, Int(args[59]), Int(args[60]))
        var text = _report(describe_indexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
        var observed = describe_comparison(context.observation)
        context.close()
        print(text)
        print(observed)
    elif len(args) == 56 and args[1] == "unindexed":
        var policy = _binding_policy(args, 2, False)
        var request = _request(args, 41)
        var context = load_owned_unindexed_tied_output(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 24), policy, request, Int(args[54]), Int(args[55]))
        var text = _report(describe_unindexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
        var observed = describe_comparison(context.observation)
        context.close()
        print(text)
        print(observed)
    else:
        raise Error("expected indexed|unindexed ordinary compiler arguments then total-elements chunk-elements")
