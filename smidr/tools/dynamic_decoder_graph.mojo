# Ordinary source headers plus explicit compiler intent. No model execution.
from std.sys import argv
from std.memory import bitcast
from smidr.tools.decoder_activation_graph import read_bias_source, parse_activation_kinds
from smidr.ordinary_projection_schema import OrdinaryProjectionSchema
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.decoder_scalar_source import source_decoder_scalars
from smidr.source_dynamic_decoder import source_dynamic_decoder_policy
from smidr.dynamic_decoder_policy import DynamicDecoderPolicy, DynamicDecoderHistory
from smidr.tools.dynamic_decoder_policy import parse_dynamic_history_words
from smidr.source_scalars import ScalarWord
from smidr.tools.hrpc_program import _uint64
from smidr.window_policy import DecoderWindowPolicy
from smidr.tools.window_policy import parse_window_widths
from smidr.source_inventory import SourceTensorInventory
from smidr.bias_policy import DecoderBiasPolicy
from smidr.activation_policy import DecoderActivationPolicy
from smidr.session_policy import DecoderSessionPolicy
from smidr.semantic_plan import SemanticPlan, DecoderGeometry, DenseDecoderParameters, DecoderGraphPolicy, build_dynamic_decoder_semantic_plan
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.tools.source_inventory import _quote


def dynamic_plan(mut schema: OrdinaryProjectionSchema, query: Int, past: Int, capacity: Int,
                 rope_dim: Int, mask: String, attention: String, mlp: String,
                 scalar_mode: String, work: Int, provenance: String, selectors: String,
                 session_mode: String, return_cache: Int, windows: String,
                 origin: String, factor_width: Int, factor_bits: UInt64, limit: Int,
                 initial: Int, ends: String, contexts: String) raises -> SemanticPlan:
    var geometry = DecoderGeometry(schema.binding.architecture.layers.layer_count,
        schema.binding.architecture.dimensions["hidden_size"], schema.binding.architecture.dimensions["intermediate_size"],
        schema.binding.architecture.dimensions["num_attention_heads"], schema.binding.architecture.dimensions["num_key_value_heads"],
        schema.binding.key_dim, schema.binding.value_dim, rope_dim, schema.binding.architecture.dimensions["vocab_size"],
        schema.binding.architecture.dimensions["max_position_embeddings"], "row_major_outermost_first")
    var scalars = source_decoder_scalars(schema.binding.architecture, "exact dynamic selected source scalars", 1000000)
    var policy = DynamicDecoderPolicy(ScalarWord(factor_width, factor_bits), scalars.rope_base.copy(), geometry.source_context, limit, "invocation", "invocation", provenance, work)
    if origin == "source":
        policy = source_dynamic_decoder_policy(schema.binding.architecture, limit, provenance, work)
    elif origin != "invocation":
        raise Error("DynamicDecoder: explicit source or invocation origin required")
    if scalar_mode == "requested32" and origin == "invocation":
        policy.theta = ScalarWord(32, UInt64(bitcast[DType.uint32](Float32(schema.binding.architecture.scalars["rope_theta"]))))
    var before = DynamicDecoderHistory(policy.copy(), initial, parse_dynamic_history_words(ends, work), parse_dynamic_history_words(contexts, work), work)
    var decoder = DecoderGraphPolicy(parse_rotary_flags(mask), schema.binding.output_weight, provenance)
    var bias = DecoderBiasPolicy(parse_rotary_flags(attention), parse_rotary_flags(mlp), provenance, work)
    var activation = DecoderActivationPolicy(parse_activation_kinds(selectors), provenance, work)
    var session = DecoderSessionPolicy(session_mode, return_cache, Int(schema.binding.architecture.flags["use_cache"]), "invocation", provenance, work)
    var window = DecoderWindowPolicy(parse_window_widths(windows), "invocation", provenance, work)
    var source = schema.binding.source^
    schema.binding.source = SourceTensorInventory()
    if scalar_mode == "source64":
        return build_dynamic_decoder_semantic_plan(source^, geometry, scalars, decoder, bias, activation, session, window, before, query, past, capacity)
    if scalar_mode != "requested32":
        raise Error("DynamicDecoder: explicit scalar mode required")
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward, geometry.heads,
        geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim, geometry.vocabulary,
        geometry.source_context, Float32(schema.binding.architecture.scalars["rope_theta"]),
        Float32(schema.binding.architecture.scalars["rms_norm_eps"]), geometry.source_layout)
    return build_dynamic_decoder_semantic_plan(source^, parameters, decoder, bias, activation, session, window, before, query, past, capacity)


def main() raises:
    var a = argv()
    if len(a) != 27:
        raise Error("expected mode root label config query past capacity rope_dim mask attention mlp scalar_mode pairing work provenance activations session return_cache windows origin factor_width factor_bits limit initial ends contexts")
    var schema = read_bias_source(a[1], a[2], a[3], a[4])
    var original = describe_ordinary_projection_schema(schema)
    var plan = dynamic_plan(schema, Int(a[5]), Int(a[6]), Int(a[7]), Int(a[8]), a[9], a[10], a[11], a[12], Int(a[14]), a[15], a[16], a[17], Int(a[18]), a[19], a[20], Int(a[21]), _uint64(a[22]), Int(a[23]), Int(a[24]), a[25], a[26])
    var rotary = RotaryLoweringPolicy(a[13], "explicit dynamic mathematical basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    print(String("{\"scope\":\"dynamic_source_mathematical_graph\",\"ordinary_model_admitted\":false,\"device_execution_verified\":false,\"original_source\":") + original + ",\"lowered\":" + describe_rotary_graph(graph, rotary) + "}")
