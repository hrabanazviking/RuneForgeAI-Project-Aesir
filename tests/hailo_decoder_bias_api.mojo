# Test-only synthetic source-header recipe and mutation harness; no forward.
from std.sys import argv
from std.collections import Dict
from smidr.source_config import SourceConfigPolicy
from smidr.source_root import SourceRootPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, read_unindexed_source_collection
from smidr.source_inventory import SourceTensorInventory, SourceSemanticPolicy, append_source_storage
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers
from smidr.decoder_architecture import DecoderArchitecturePolicy, source_decoder_architecture
from smidr.decoder_projections import _roles
from smidr.decoder_scalar_source import source_decoder_scalars
from smidr.bias_policy import DecoderBiasPolicy
from smidr.semantic_plan import SemanticPlan, DecoderGeometry, DenseDecoderParameters, DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import ExpandedGraph, expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph


def fixture_plan(root: String, label: String, config: String, attention: String,
                 mlp: String, scalar_mode: String, legacy: Bool = False) raises -> SemanticPlan:
    var collection = read_unindexed_source_collection(root, label, config,
        SourceRootPolicy(4095, 1000, 16777216, 9223372036854775807),
        SourceConfigPolicy(1048576, 10000, 10000000, 64),
        SafetensorsFdPolicy(1048576, 10000, 64, 10000000, 64, 9223372036854775807),
        ShardCollectionPolicy(8, 10000, 16777216, 9223372036854775807, 100000000))
    var layers = source_decoder_layers(collection.config, DecoderLayerPolicy(4096, 100000, 10000000))
    var architecture = source_decoder_architecture(layers, DecoderArchitecturePolicy(100000, 10000000))
    # Explicit synthetic mathematical alias construction, not ordinary-model admission.
    var roles = _roles(layers.layer_count, True)
    var aliases = Dict[String, String]()
    for i in range(len(collection.shard.storage.tensors)):
        var name = collection.shard.storage.tensors[i].original_name
        if name not in roles:
            raise Error("test fixture contains unknown source role")
        aliases[roles[name]] = name
    var source = SourceTensorInventory()
    source.architecture = "synthetic_bias_math"
    source.policy = SourceSemanticPolicy(8, 10000, 64, 10000000)
    append_source_storage(source, collection.shard.storage, aliases,
        "test-only source-neutral alias recipe; ordinary modifiers unresolved")
    var heads = architecture.dimensions["num_attention_heads"]
    var kv = architecture.dimensions["num_key_value_heads"]
    var query_rows = source.bindings["blk.0.attn_q.weight"].rows
    var value_rows = source.bindings["blk.0.attn_v.weight"].rows
    if query_rows % heads != 0 or value_rows % kv != 0:
        raise Error("test fixture has nonintegral head extents")
    var geometry = DecoderGeometry(layers.layer_count, architecture.dimensions["hidden_size"],
        architecture.dimensions["intermediate_size"], heads, kv, query_rows // heads,
        value_rows // kv, 2, architecture.dimensions["vocab_size"],
        architecture.dimensions["max_position_embeddings"], "row_major_outermost_first")
    var output = String("output.weight") if "output.weight" in source.bindings else String("token_embd.weight")
    var mask = List[Int]()
    for i in range(layers.layer_count):
        mask.append(i % 2)
    var decoder = DecoderGraphPolicy(mask^, output, "synthetic mixed NoPE/rotary recipe only")
    var bias = DecoderBiasPolicy(parse_rotary_flags(attention), parse_rotary_flags(mlp),
        "bias API test provenance", 10000000)
    if scalar_mode == "source64":
        var scalars = source_decoder_scalars(architecture, "exact fixture source constants", 1000000)
        if legacy:
            return build_decoder_semantic_plan(source^, geometry, scalars, decoder, 2, 1, 8)
        return build_decoder_semantic_plan(source^, geometry, scalars, decoder, bias, 2, 1, 8)
    if scalar_mode != "requested32":
        raise Error("unknown scalar mode")
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
        geometry.vocabulary, geometry.source_context, Float32(architecture.scalars["rope_theta"]),
        Float32(architecture.scalars["rms_norm_eps"]), geometry.source_layout)
    if legacy:
        return build_decoder_semantic_plan(source^, parameters, decoder, 2, 1, 8)
    return build_decoder_semantic_plan(source^, parameters, decoder, bias, 2, 1, 8)


def main() raises:
    var args = argv()
    if len(args) != 8:
        raise Error("expected root weight config attention_mask mlp_mask scalar_mode case")
    var mode = String(args[7])
    var plan = fixture_plan(args[1], args[2], args[3], args[4], args[5], args[6], mode == "legacy")
    var first = -1
    for i in range(len(plan.operations)):
        if plan.operations[i].kind == "add_projection_bias":
            first = i
            break
    if mode == "plan_policy_flag":
        plan.bias_policy.attention[0] = 1 - plan.bias_policy.attention[0]
    elif mode == "plan_policy_mlp":
        plan.bias_policy.mlp[0] = 1 - plan.bias_policy.mlp[0]
    elif mode == "plan_policy_length":
        plan.bias_policy.attention.append(1)
    elif mode == "plan_policy_provenance":
        plan.bias_policy.provenance = ""
    elif mode == "plan_policy_work":
        plan.bias_policy.work = 1
    elif mode == "plan_charged":
        plan.bias_work += 1
    elif mode == "plan_explicit":
        plan.explicit_bias = False
    elif mode.startswith("plan_"):
        if first < 0:
            raise Error("bias mutation needs a selected source operation")
        var input = plan.operations[first].inputs[0]
        var output = plan.operations[first].output
        var weight = plan.operations[first].weight
        if mode == "plan_kind":
            plan.operations[first].kind = "add"
        elif mode == "plan_name":
            plan.operations[first].weight = "guessed.bias"
        elif mode == "plan_input":
            plan.operations[first].inputs[0] = output
        elif mode == "plan_output":
            plan.operations[first].output = input
        elif mode == "plan_shape":
            plan.tensors[output].shape[1] += 1
        elif mode == "plan_product":
            plan.tensors[output].elements += 1
        elif mode == "plan_lifetime":
            plan.tensors[input].last_use += 1
        elif mode == "plan_producer":
            plan.tensors[output].producer += 1
        elif mode == "plan_persistent":
            plan.tensors[input].persistent = True
        elif mode == "plan_alias":
            plan.tensors[output].alias_of = input
        elif mode == "plan_linear":
            plan.operations[plan.tensors[input].producer].kind = "multiply"
        elif mode == "plan_bypass":
            for i in range(first + 1, len(plan.operations)):
                for j in range(len(plan.operations[i].inputs)):
                    if plan.operations[i].inputs[j] == output:
                        plan.operations[i].inputs[j] = input
        elif mode == "plan_source_width":
            plan.source.bindings[weight].columns += 1
        elif mode == "plan_source_shape":
            plan.source.storage[weight].source_shape[0] += 1
        elif mode == "plan_used":
            plan.used_weights[weight] = False
        else:
            raise Error("unknown plan mutation")
    var rotary = RotaryLoweringPolicy("split_half", "explicit synthetic bias basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    if mode == "valid" or mode == "legacy":
        print(describe_rotary_graph(graph, rotary))
        return
    var recipe_id = -1
    var operation_id = -1
    for i in range(len(graph.recipes.recipes)):
        if graph.recipes.recipes[i].kind == "add_projection_bias":
            recipe_id = i
            break
    for i in range(len(graph.operations)):
        if graph.operations[i].kind == "add_source_projection_vector":
            operation_id = i
            break
    if recipe_id < 0 or operation_id < 0:
        raise Error("bias mutation needs a selected expanded operation")
    if mode == "snapshot_flag":
        graph.recipes.bias_policy.attention[0] = 1 - graph.recipes.bias_policy.attention[0]
    elif mode == "snapshot_mlp":
        graph.recipes.bias_policy.mlp[0] = 1 - graph.recipes.bias_policy.mlp[0]
    elif mode == "snapshot_provenance":
        graph.recipes.bias_policy.provenance = "changed"
    elif mode == "snapshot_work":
        graph.recipes.bias_policy.work -= 1
    elif mode == "snapshot_charged":
        graph.recipes.bias_work += 1
    elif mode == "snapshot_explicit":
        graph.recipes.explicit_bias = False
    elif mode == "recipe_kind":
        graph.recipes.recipes[recipe_id].kind = "guessed"
    elif mode == "recipe_mapping":
        graph.recipes.recipes[recipe_id].source_inputs[0] += 1
    elif mode == "recipe_local_mapping":
        graph.recipes.recipes[recipe_id].input_values[0] += 1
    elif mode == "recipe_output":
        graph.recipes.recipes[recipe_id].source_output += 1
    elif mode == "recipe_weight":
        graph.recipes.recipes[recipe_id].weight_name = "guessed"
    elif mode == "recipe_binding":
        graph.recipes.recipes[recipe_id].weight.file_offset += 1
    elif mode == "recipe_kind_tag":
        graph.recipes.recipes[recipe_id].weight_storage.source_kind = 99
    elif mode == "recipe_shape":
        graph.recipes.recipes[recipe_id].weight_storage.source_shape[0] += 1
    elif mode == "recipe_name":
        graph.recipes.recipes[recipe_id].weight_storage.original_name = "changed"
    elif mode == "recipe_path":
        graph.recipes.recipes[recipe_id].weight_storage.source_path = "changed"
    elif mode == "recipe_extent":
        graph.recipes.recipes[recipe_id].weight_extent.source_bytes += 1
    elif mode == "recipe_divisor":
        graph.recipes.recipes[recipe_id].divisor = 1
    elif mode == "recipe_precondition":
        graph.recipes.recipes[recipe_id].runtime_preconditions.clear()
    elif mode == "recipe_result":
        graph.recipes.recipes[recipe_id].result = 0
    elif mode == "recipe_value_shape":
        graph.recipes.recipes[recipe_id].values[2].shape[1] += 1
    elif mode == "recipe_value_domain":
        graph.recipes.recipes[recipe_id].values[1].domain = "index"
    elif mode == "recipe_value_lifetime":
        graph.recipes.recipes[recipe_id].values[0].last_use += 1
    elif mode == "recipe_operation":
        graph.recipes.recipes[recipe_id].operations[0].kind = "add"
    elif mode == "recipe_edge":
        graph.recipes.recipes[recipe_id].operations[0].inputs[1] = 0
    elif mode == "recipe_step_output":
        graph.recipes.recipes[recipe_id].operations[0].output = 0
    elif mode == "expanded_kind":
        graph.operations[operation_id].kind = "add"
    elif mode == "expanded_source":
        graph.operations[operation_id].source_operation += 1
    elif mode == "expanded_step":
        graph.operations[operation_id].recipe_step = -1
    elif mode == "expanded_weight":
        graph.operations[operation_id].source_weight = "changed"
    elif mode == "expanded_input":
        graph.operations[operation_id].inputs[1] = graph.operations[operation_id].inputs[0]
    elif mode == "expanded_output":
        graph.operations[operation_id].output += 1
    elif mode == "expanded_width":
        graph.operations[operation_id].width = 1
    elif mode == "expanded_precondition":
        graph.operations[operation_id].runtime_preconditions.clear()
    elif mode == "expanded_shape":
        graph.values[graph.operations[operation_id].output].shape[1] += 1
    elif mode == "expanded_domain":
        graph.values[graph.operations[operation_id].output].domain = "predicate"
    elif mode == "expanded_lifetime":
        graph.values[graph.operations[operation_id].inputs[0]].last_use += 1
    elif mode == "expanded_alias":
        graph.values[graph.operations[operation_id].output].alias_of = 0
    elif mode == "expanded_constant":
        graph.values[graph.operations[operation_id].inputs[1]].shape[0] += 1
    elif mode == "remaining":
        graph.recipes.remaining_source_operations.append(first)
    else:
        raise Error("unknown expanded mutation")
    print(describe_rotary_graph(graph, rotary))
