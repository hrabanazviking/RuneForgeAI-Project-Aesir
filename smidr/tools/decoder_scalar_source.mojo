# Ordinary scalar facts plus explicitly synthetic graph geometry; no inference.
from std.sys import argv
from smidr.source_config import SourceConfigPolicy, read_source_config
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers
from smidr.decoder_architecture import DecoderArchitecturePolicy, source_decoder_architecture
from smidr.decoder_scalar_source import source_decoder_scalars
from smidr.semantic_plan import decoder_geometry, DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.tools.typed_decoder import _from_file
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.tools.source_scalars import describe_decoder_scalars
from smidr.tools.source_inventory import _quote


def main() raises:
    var args = argv()
    if len(args) != 10:
        raise Error("usage: decoder_scalar_source <fixture.gguf> <ordinary-config> <query> <past> <capacity> <pairing> <mask> <provenance> <scalar_work_limit>")
    var config = read_source_config(args[2], SourceConfigPolicy(1048576, 10000, 10000000, 64))
    var layers = source_decoder_layers(config, DecoderLayerPolicy(1000, 100000, 10000000))
    var intent = source_decoder_architecture(layers, DecoderArchitecturePolicy(100000, 10000000))
    var scalars = source_decoder_scalars(intent, args[8], Int(args[9]))
    var input = _from_file(args[1])
    var source = input.take_inventory()
    var output = String("output.weight") if "output.weight" in source.bindings else String("token_embd.weight")
    var policy = DecoderGraphPolicy(parse_rotary_flags(args[7]), output, "explicit synthetic geometry only; ordinary modifiers unresolved")
    var plan = build_decoder_semantic_plan(source^, decoder_geometry(input.parameters), scalars, policy, Int(args[3]), Int(args[4]), Int(args[5]))
    var rotary = RotaryLoweringPolicy(args[6], "explicit fixture basis; source word representation only", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    var text = String("{\"scope\":\"ordinary_scalar_projection_into_synthetic_geometry\",\"ordinary_model_admitted\":false,\"device_execution_verified\":false,\"source_scalars\":") + describe_decoder_scalars(scalars)
    text += ",\"source_fields\":{"
    var first = True
    for key in intent.layers.source.fields:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + _quote(intent.layers.source.fields[key])
    text += "},\"unresolved\":["
    for i in range(len(intent.unresolved)):
        if i != 0:
            text += ","
        text += _quote(intent.unresolved[i])
    text += "],\"lowered\":" + describe_rotary_graph(graph, rotary) + "}"
    print(text)
