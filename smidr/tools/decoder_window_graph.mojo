# Actual source metadata and an explicit mathematical window/session choice.
from std.sys import argv
from smidr.tools.decoder_activation_graph import read_bias_source, parse_activation_kinds
from smidr.ordinary_projection_schema import OrdinaryProjectionSchema
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.decoder_scalar_source import source_decoder_scalars
from smidr.decoder_activation_source import source_decoder_activations
from smidr.decoder_session_source import source_decoder_session
from smidr.decoder_window_source import source_decoder_windows
from smidr.window_policy import DecoderWindowPolicy
from smidr.tools.window_policy import parse_window_widths
from smidr.source_inventory import SourceTensorInventory
from smidr.bias_policy import DecoderBiasPolicy
from smidr.activation_policy import DecoderActivationPolicy
from smidr.semantic_plan import SemanticPlan, DecoderGeometry, DenseDecoderParameters, DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.tools.source_inventory import _quote


def window_plan(mut schema: OrdinaryProjectionSchema, query: Int, past: Int, capacity: Int,
              rope_dim: Int, mask: String, attention: String, mlp: String,
              scalar_mode: String, work: Int, provenance: String, selectors: String, session_mode: String, return_override: Int, windows: String) raises -> SemanticPlan:
    var geometry = DecoderGeometry(schema.binding.architecture.layers.layer_count,
        schema.binding.architecture.dimensions["hidden_size"],
        schema.binding.architecture.dimensions["intermediate_size"],
        schema.binding.architecture.dimensions["num_attention_heads"],
        schema.binding.architecture.dimensions["num_key_value_heads"],
        schema.binding.key_dim, schema.binding.value_dim, rope_dim,
        schema.binding.architecture.dimensions["vocab_size"],
        schema.binding.architecture.dimensions["max_position_embeddings"], "row_major_outermost_first")
    var scalars = source_decoder_scalars(schema.binding.architecture, "exact ordinary scalar source for selected mathematical recipe", 1000000)
    var graph_policy = DecoderGraphPolicy(parse_rotary_flags(mask), schema.binding.output_weight,
        "explicit mathematical recipe; source cache/training/scaling/window/full graph modifiers unresolved")
    var bias = DecoderBiasPolicy(parse_rotary_flags(attention), parse_rotary_flags(mlp), provenance, work)
    var activation = source_decoder_activations(schema.binding.architecture, provenance, work) if selectors == "source" else DecoderActivationPolicy(parse_activation_kinds(selectors), provenance, work)
    var session = source_decoder_session(schema.binding.architecture, session_mode, return_override, provenance, work)
    var window = source_decoder_windows(schema.binding.architecture, provenance, work) if windows == "source" else DecoderWindowPolicy(parse_window_widths(windows), "invocation", provenance, work)
    var source = schema.binding.source^
    schema.binding.source = SourceTensorInventory()
    if scalar_mode == "source64":
        return build_decoder_semantic_plan(source^, geometry, scalars, graph_policy, bias, activation, session, window, query, past, capacity)
    if scalar_mode != "requested32":
        raise Error("DecoderBiasInspector: explicit source64 or requested32 scalar mode required")
    var epsilon32 = Float32(schema.binding.architecture.scalars["rms_norm_eps"])
    var base32 = Float32(schema.binding.architecture.scalars["rope_theta"])
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
        geometry.vocabulary, geometry.source_context, base32, epsilon32, geometry.source_layout)
    return build_decoder_semantic_plan(source^, parameters, graph_policy, bias, activation, session, window, query, past, capacity)


def main() raises:
    var args = argv()
    if len(args) != 20:
        raise Error("expected mode root label config query past capacity rope_dim rope_mask attention_mask mlp_mask scalar_mode pairing work provenance selectors/source session_mode return_override windows/source")
    var schema = read_bias_source(args[1], args[2], args[3], args[4])
    var original = describe_ordinary_projection_schema(schema)
    var plan = window_plan(schema, Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8]),
        args[9], args[10], args[11], args[12], Int(args[14]), args[15], args[16], args[17], Int(args[18]), args[19])
    var rotary = RotaryLoweringPolicy(args[13], "explicit mathematical activation inspector basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    print(String("{\"scope\":\"selected_window_mathematical_recipe\",\"ordinary_model_admitted\":false,\"device_execution_verified\":false,\"scalar_mode\":") + _quote(args[12]) + ",\"original_source\":" + original + ",\"lowered\":" + describe_rotary_graph(graph, rotary) + "}")
