# Synthetic source-header mathematical selection/mutation harness; no forward.
from std.sys import argv
from hailo_decoder_bias_api import fixture_plan
from smidr.activation_policy import DecoderActivationPolicy, same_activation_policy, activation_policy_charge
from smidr.tools.decoder_activation_graph import parse_activation_kinds
from smidr.semantic_plan import SemanticPlan, DecoderGeometry, DenseDecoderParameters, build_decoder_semantic_plan
from smidr.source_inventory import SourceTensorInventory
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.cache_layout import CacheLayoutAssumptions, plan_cache_layout
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction
from smidr.storage_estimate import StorageAssumptions, estimate_storage


def activation_fixture(root: String, label: String, config: String, attention: String,
                       mlp: String, scalar: String, kinds: String, mode: String = "valid") raises -> SemanticPlan:
    var seed = fixture_plan(root, label, config, attention, mlp, scalar)
    var activation = DecoderActivationPolicy(parse_activation_kinds(kinds), "activation API test provenance", 1000000)
    if mode == "builder_work":
        activation.work = 1
    elif mode == "builder_provenance":
        activation.provenance = ""
    elif mode == "builder_length":
        activation.kinds.append("silu")
    var geometry = DecoderGeometry(seed.layers, seed.hidden, seed.feed_forward,
        seed.heads, seed.kv_heads, seed.key_dim, seed.value_dim, seed.rope_dim,
        seed.vocabulary, 64, seed.source_layout)
    var source = seed.source^
    seed.source = SourceTensorInventory()
    if scalar == "source64":
        var plan = build_decoder_semantic_plan(source^, geometry, seed.source_scalars,
            seed.decoder_policy, seed.bias_policy, activation, 2, 1, 8)
        activation.kinds[0] = "changed"
        activation.provenance = "changed"
        activation.work = 1
        return plan^
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
        geometry.vocabulary, geometry.source_context, seed.rope_base, seed.rms_epsilon, geometry.source_layout)
    var plan = build_decoder_semantic_plan(source^, parameters, seed.decoder_policy, seed.bias_policy, activation, 2, 1, 8)
    activation.kinds[0] = "changed"
    activation.provenance = "changed"
    activation.work = 1
    return plan^


def main() raises:
    var args = argv()
    if len(args) != 9:
        raise Error("expected root weight config attention mlp scalar kinds case")
    var mode = args[8]
    if mode == "charge_overflow":
        _ = activation_policy_charge(9223372036854775807, "bounded", 0, 9223372036854775807, 9223372036854775807)
    elif mode == "charge_negative":
        _ = activation_policy_charge(1, "bounded", -1, 1000, 1000)
    elif mode == "charge_source_limit":
        _ = activation_policy_charge(1, "bounded", 4, 1001, 1000)
    var plan = activation_fixture(args[1], args[2], args[3], args[4], args[5], args[6], args[7], mode)
    if mode == "legacy_stray":
        plan.explicit_activation = False
    elif mode == "policy_kind":
        plan.activation_policy.kinds[0] = "unknown"
    elif mode == "policy_choice":
        plan.activation_policy.kinds[0] = "silu" if plan.activation_policy.kinds[0] != "silu" else String("relu")
    elif mode == "policy_length":
        plan.activation_policy.kinds.append("silu")
    elif mode == "policy_work":
        plan.activation_policy.work = 1
    elif mode == "policy_provenance":
        plan.activation_policy.provenance = ""
    elif mode == "policy_charge":
        plan.activation_work += 1
    var first = -1
    for i in range(len(plan.operations)):
        if plan.operations[i].kind == "silu" or plan.operations[i].kind == "gelu_erf" or plan.operations[i].kind == "relu":
            first = i
            break
    if first < 0:
        raise Error("missing activation in fixture")
    var output = plan.operations[first].output
    var input = plan.operations[first].inputs[0]
    if mode == "plan_kind":
        plan.operations[first].kind = "multiply"
    elif mode == "plan_weight":
        plan.operations[first].weight = "output_norm.weight"
    elif mode == "plan_input":
        plan.operations[first].inputs[0] = input - 1
    elif mode == "plan_product":
        plan.operations[first + 1].inputs[0] = input
    elif mode == "plan_shape":
        plan.tensors[output].shape[1] += 1
    elif mode == "plan_elements":
        plan.tensors[output].elements += 1
    elif mode == "plan_name":
        plan.tensors[output].name = "changed"
    elif mode == "plan_lifetime":
        plan.tensors[output].last_use += 1
    elif mode == "plan_producer":
        plan.tensors[output].producer += 1
    elif mode == "plan_persistent":
        plan.tensors[output].persistent = True
    elif mode == "plan_alias":
        plan.tensors[output].alias_of = 0
    elif mode == "plan_orphan":
        plan.tensors[input].producer = first
    elif mode == "plan_duplicate":
        plan.operations.append(plan.operations[first].copy())
    elif mode == "plan_omitted":
        plan.operations[first].kind = "identity"
    if mode == "cache_bypass" or mode == "matrix_bypass" or mode == "storage_bypass":
        plan.operations[first + 1].inputs[0] = input
        if mode == "cache_bypass":
            _ = plan_cache_layout(plan, CacheLayoutAssumptions(2, 2, 16, 16, 16, 9223372036854775807, "hypothetical activation cache"))
        elif mode == "matrix_bypass":
            _ = plan_matrix_contraction(plan, 2, MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical activation matrix"))
        else:
            _ = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16, plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical activation storage"))
        raise Error("unexpected consumer accepted bypass")
    var rotary = RotaryLoweringPolicy("split_half", "explicit synthetic bias basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    var r = -1
    for i in range(len(graph.recipes.recipes)):
        if graph.recipes.recipes[i].source_operation == first:
            r = i
    var global_index = -1
    for i in range(len(graph.operations)):
        if graph.operations[i].source_operation == first:
            global_index = i
            break
    if mode == "recipe_policy":
        graph.recipes.activation_policy.kinds[0] = "changed"
    elif mode == "recipe_work":
        graph.recipes.activation_work += 1
    elif mode == "recipe_explicit":
        graph.recipes.explicit_activation = False
    elif mode == "recipe_identity":
        graph.recipes.recipes[r].source_operation += 1
    elif mode == "recipe_input":
        graph.recipes.recipes[r].source_inputs[0] += 1
    elif mode == "recipe_result":
        graph.recipes.recipes[r].result = 0
    elif mode == "recipe_kind":
        graph.recipes.recipes[r].kind = "changed"
    elif mode == "recipe_precondition":
        graph.recipes.recipes[r].runtime_preconditions.append("changed")
    elif mode == "recipe_divisor":
        graph.recipes.recipes[r].divisor = 2
    elif mode == "recipe_weight":
        graph.recipes.recipes[r].weight.columns = 1
    elif mode == "recipe_shape":
        graph.recipes.recipes[r].values[0].shape[1] += 1
    elif mode == "recipe_domain":
        graph.recipes.recipes[r].values[0].domain = "predicate"
    elif mode == "recipe_lifetime":
        graph.recipes.recipes[r].values[0].last_use += 1
    elif mode == "recipe_operation":
        graph.recipes.recipes[r].operations[0].kind = "changed"
    elif mode == "recipe_edge":
        graph.recipes.recipes[r].operations[0].inputs[0] = 1
    elif mode == "recipe_remaining":
        graph.recipes.remaining_source_operations.append(first)
    elif mode == "global_operation":
        graph.operations[global_index].kind = "changed"
    elif mode == "global_edge":
        graph.operations[global_index].inputs[0] += 1
    elif mode == "global_step":
        graph.operations[global_index].recipe_step += 1
    elif mode == "global_metadata":
        graph.operations[global_index].width = 1
    elif mode == "global_precondition":
        graph.operations[global_index].runtime_preconditions.append("changed")
    elif mode == "global_shape":
        graph.values[graph.operations[global_index].output].shape[1] += 1
    elif mode == "global_domain":
        graph.values[graph.operations[global_index].output].domain = "predicate"
    elif mode == "global_lifetime":
        graph.values[graph.operations[global_index].output].last_use += 1
    elif mode == "global_name":
        graph.values[graph.operations[global_index].output].name = "changed"
    elif mode == "global_alias":
        graph.values[graph.operations[global_index].output].alias_of = 0
    elif mode == "global_mapping":
        graph.source_values[output] += 1
    elif mode == "global_omitted":
        graph.operations[global_index].source_operation = 0
    print(describe_rotary_graph(graph, rotary))
