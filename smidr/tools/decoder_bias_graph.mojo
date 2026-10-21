# Actual ordinary source metadata plus an explicitly selected mathematical recipe.
# No complete ordinary adapter, payload evaluation or hardware access.
from std.sys import argv
from smidr.source_config import SourceConfigPolicy
from smidr.source_root import SourceRootPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, read_unindexed_source_collection, read_indexed_shard_collection
from smidr.source_storage import SourceStorageInventory
from smidr.source_inventory import SourceSemanticPolicy, SourceTensorInventory
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers
from smidr.decoder_architecture import DecoderArchitecturePolicy, source_decoder_architecture
from smidr.decoder_projections import DecoderProjectionPolicy
from smidr.ordinary_projection_schema import OrdinaryProjectionSchema, bind_ordinary_projection_schema
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.tools.decoder_projections import _snapshot
from smidr.decoder_scalar_source import source_decoder_scalars
from smidr.bias_policy import DecoderBiasPolicy
from smidr.semantic_plan import SemanticPlan, DecoderGeometry, DenseDecoderParameters, DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.tools.source_inventory import _quote


def read_bias_source(mode: String, root: String, label: String, config: String) raises -> OrdinaryProjectionSchema:
    var root_policy = SourceRootPolicy(4095, 1000, 16777216, 9223372036854775807)
    var config_policy = SourceConfigPolicy(1048576, 10000, 10000000, 64)
    var fd_policy = SafetensorsFdPolicy(1048576, 10000, 64, 10000000, 64, 9223372036854775807)
    var collection_policy = ShardCollectionPolicy(8, 10000, 16777216, 9223372036854775807, 100000000)
    var projection_policy = DecoderProjectionPolicy(SourceSemanticPolicy(8, 10000, 64, 10000000), 10000000, "actual source headers; mathematical bias recipe only")
    if mode == "unindexed":
        var collection = read_unindexed_source_collection(root, label, config, root_policy, config_policy, fd_policy, collection_policy)
        var layers = source_decoder_layers(collection.config, DecoderLayerPolicy(4096, 100000, 10000000))
        var architecture = source_decoder_architecture(layers, DecoderArchitecturePolicy(100000, 10000000))
        var files = List[SourceStorageInventory]()
        files.append(_snapshot(collection.shard.storage))
        return bind_ordinary_projection_schema(architecture, files, projection_policy)
    if mode != "indexed":
        raise Error("DecoderBiasInspector: indexed or unindexed mode required")
    var collection = read_indexed_shard_collection(root, label, config, root_policy,
        SourceIndexPolicy(1048576, 10000, 100000, 10000000, 64), config_policy, fd_policy, collection_policy)
    var layers = source_decoder_layers(collection.config, DecoderLayerPolicy(4096, 100000, 10000000))
    var architecture = source_decoder_architecture(layers, DecoderArchitecturePolicy(100000, 10000000))
    var files = List[SourceStorageInventory]()
    for i in range(len(collection.shards)):
        files.append(_snapshot(collection.shards[i].storage))
    return bind_ordinary_projection_schema(architecture, files, projection_policy)


def bias_plan(mut schema: OrdinaryProjectionSchema, query: Int, past: Int, capacity: Int,
              rope_dim: Int, mask: String, attention: String, mlp: String,
              scalar_mode: String, work: Int, provenance: String) raises -> SemanticPlan:
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
        "explicit mathematical recipe; source cache/training/activation/scaling/window modifiers unresolved")
    var bias = DecoderBiasPolicy(parse_rotary_flags(attention), parse_rotary_flags(mlp), provenance, work)
    var source = schema.binding.source^
    schema.binding.source = SourceTensorInventory()
    if scalar_mode == "source64":
        return build_decoder_semantic_plan(source^, geometry, scalars, graph_policy, bias, query, past, capacity)
    if scalar_mode != "requested32":
        raise Error("DecoderBiasInspector: explicit source64 or requested32 scalar mode required")
    var epsilon32 = Float32(schema.binding.architecture.scalars["rms_norm_eps"])
    var base32 = Float32(schema.binding.architecture.scalars["rope_theta"])
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
        geometry.vocabulary, geometry.source_context, base32, epsilon32, geometry.source_layout)
    return build_decoder_semantic_plan(source^, parameters, graph_policy, bias, query, past, capacity)


def main() raises:
    var args = argv()
    if len(args) != 16:
        raise Error("expected mode root index/weight config query past capacity rope_dim rope_mask attention_mask mlp_mask scalar_mode pairing bias_work provenance")
    var schema = read_bias_source(args[1], args[2], args[3], args[4])
    var original = describe_ordinary_projection_schema(schema)
    var plan = bias_plan(schema, Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8]),
        args[9], args[10], args[11], args[12], Int(args[14]), args[15])
    var rotary = RotaryLoweringPolicy(args[13], "explicit mathematical bias inspector basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    print(String("{\"scope\":\"selected_projection_bias_mathematical_recipe\",\"ordinary_model_admitted\":false,\"device_execution_verified\":false,\"scalar_mode\":") + _quote(args[12]) + ",\"original_source\":" + original + ",\"lowered\":" + describe_rotary_graph(graph, rotary) + "}")
