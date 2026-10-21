# Test-only GGUF source-word/bias recipe integration; no payload evaluation.
from std.sys import argv
from std.memory import bitcast
from smidr.scaling_policy import DecoderScalingPolicy
from smidr.tools.hrpc_program import _uint64
from smidr.tools.typed_decoder import _from_file
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.bias_policy import DecoderBiasPolicy
from smidr.session_policy import DecoderSessionPolicy
from smidr.window_policy import DecoderWindowPolicy
from smidr.tools.window_policy import parse_window_widths
from smidr.activation_policy import DecoderActivationPolicy
from smidr.tools.decoder_activation_graph import parse_activation_kinds
from smidr.source_scalars import DecoderScalars, ScalarWord
from smidr.semantic_plan import decoder_geometry, DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph


def main() raises:
    var args = argv()
    if len(args) != 15:
        raise Error("expected source.gguf attention_mask mlp_mask rope_mask scalar_mode kinds mode returned past capacity widths kind factor_width factor_bits")
    var input = _from_file(args[1])
    var source = input.take_inventory()
    var output = String("output.weight") if "output.weight" in source.bindings else String("token_embd.weight")
    var decoder = DecoderGraphPolicy(parse_rotary_flags(args[4]), output,
        "explicit synthetic GGUF recipe; no architecture execution certificate")
    var bias = DecoderBiasPolicy(parse_rotary_flags(args[2]), parse_rotary_flags(args[3]),
        "GGUF bias source test", 1000000)
    var activation = DecoderActivationPolicy(parse_activation_kinds(args[6]), "GGUF activation test", 1000000)
    var session = DecoderSessionPolicy(args[7], Int(args[8]), 0, "invocation", "GGUF session test", 1000000)
    var window = DecoderWindowPolicy(parse_window_widths(args[11]), "invocation", "GGUF window test", 1000000)
    var scaling = DecoderScalingPolicy(args[12], ScalarWord(Int(args[13]), _uint64(args[14])), "invocation", "GGUF scaling test", 1000000)
    var rotary = RotaryLoweringPolicy("adjacent", "explicit synthetic GGUF bias basis", 10000, 10000000)
    if args[5] == "source32":
        var scalars = DecoderScalars(ScalarWord(32, UInt64(bitcast[DType.uint32](input.parameters.rms_epsilon))),
            ScalarWord(32, UInt64(bitcast[DType.uint32](input.parameters.rope_base))),
            "exact original GGUF binary32 words", 1000000)
        var plan = build_decoder_semantic_plan(source^, decoder_geometry(input.parameters), scalars,
            decoder, bias, activation, session, window, scaling, 2, Int(args[9]), Int(args[10]))
        var graph = expand_semantic_graph(plan^, rotary)
        print(describe_rotary_graph(graph, rotary))
    elif args[5] == "legacy32":
        var plan = build_decoder_semantic_plan(source^, input.parameters, decoder, bias, activation, session, window, scaling, 2, Int(args[9]), Int(args[10]))
        var graph = expand_semantic_graph(plan^, rotary)
        print(describe_rotary_graph(graph, rotary))
    else:
        raise Error("unknown GGUF scalar mode")
