# Structural compiler mutation probe only; never tensor-data evaluation.
from std.sys import argv
from smidr.tools.decoder_activation_graph import read_bias_source
from smidr.tools.dynamic_decoder_graph import dynamic_plan
from smidr.semantic_plan import dynamic_plan_work, validate_plan_dynamic_state, dynamic_position_at, dynamic_context_output, dynamic_cache_history_output
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph, validate_rotary_expansion
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.cache_layout import plan_cache_layout, CacheLayoutAssumptions
from smidr.matrix_tiles import plan_matrix_contraction, MatrixTilePolicy
from smidr.storage_estimate import estimate_storage, StorageAssumptions
from smidr.session_graph import validate_plan_session_state
from smidr.bias_graph import validate_plan_bias_state
from smidr.activation_graph import validate_plan_activation_state


def main() raises:
    var a = argv()
    if len(a) != 6:
        raise Error("expected root label config case consumer")
    var schema = read_bias_source("unindexed", a[1], a[2], a[3])
    var plan = dynamic_plan(schema, 2, 0, 32, 2, "1,0", "1,1", "1,1", "source64", 1000000, "dynamic API ownership", "gelu_erf,relu", "full_prefix", 1, "3,1", "invocation", 32, 1077936128, 128, 32, "-", "-")
    if dynamic_position_at(plan, 0) != 0 or dynamic_position_at(plan, 1) != 1 or dynamic_context_output(plan).selected != 8 or len(dynamic_cache_history_output(plan).end_tokens) != 1:
        raise Error("dynamic accessor mismatch")
    var rotary = RotaryLoweringPolicy("split_half", "explicit dynamic test basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    var rot = -1
    var recipe = -1
    var gain = -1
    for i in range(len(graph.source.operations)):
        if graph.source.operations[i].kind == "rope_query":
            rot = i
    for i in range(len(graph.recipes.recipes)):
        if graph.recipes.recipes[i].source_operation == rot:
            recipe = i
    for i in range(len(graph.operations)):
        if graph.operations[i].source_operation == rot and graph.operations[i].kind == "dynamic_rotary_gain":
            gain = i
    var variant = String(a[4])
    if variant == "work":
        var bound = graph.source.dynamic_work
        var before = graph.source.dynamic_before.copy()
        var after = graph.source.dynamic_after.copy()
        before.policy.work = bound
        before.work = bound
        after.policy.work = bound
        after.work = bound
        if dynamic_plan_work(before, after, 0, 2, graph.source.decoder_policy.rope_enabled, bound) != bound:
            raise Error("exact logical work boundary mismatch")
        before.policy.work -= 1
        before.work -= 1
        after.policy.work -= 1
        after.work -= 1
        var refused = False
        try:
            _ = dynamic_plan_work(before, after, 0, 2, graph.source.decoder_policy.rope_enabled, bound - 1)
        except:
            refused = True
        if not refused:
            raise Error("short logical graph work accepted")
        variant = "valid"
    if variant == "plan_flag":
        graph.source.explicit_dynamic = False
    elif variant == "source_context":
        graph.source.dynamic_source_context += 1
    elif variant == "graph_charge":
        graph.source.dynamic_work += 1
    elif variant == "before_theta":
        graph.source.dynamic_before.policy.theta.bits += 1
    elif variant == "before_factor":
        graph.source.dynamic_before.policy.factor.bits = 0
    elif variant == "before_width":
        graph.source.dynamic_before.policy.factor.width = 0
    elif variant == "before_ref":
        graph.source.dynamic_before.policy.reference += 1
    elif variant == "before_limit":
        graph.source.dynamic_before.policy.limit = 0
    elif variant == "before_work":
        graph.source.dynamic_before.work = 0
    elif variant == "before_initial":
        graph.source.dynamic_before.initial_selected = 0
    elif variant == "before_end":
        graph.source.dynamic_before.end_tokens.append(0)
    elif variant == "before_selected":
        graph.source.dynamic_before.selected_contexts.append(0)
    elif variant == "after_end":
        graph.source.dynamic_after.end_tokens[0] += 1
    elif variant == "after_selected":
        graph.source.dynamic_after.selected_contexts[0] += 1
    elif variant == "after_factor":
        graph.source.dynamic_after.policy.factor.bits += 1
    elif variant == "after_initial":
        graph.source.dynamic_after.initial_selected += 1
    elif variant == "after_work":
        graph.source.dynamic_after.work -= 1
    elif variant == "source_position_start":
        graph.source.operations[0].position_start += 1
    elif variant == "source_position_kind":
        graph.source.operations[0].kind = "linear"
    elif variant == "source_position_input":
        graph.source.operations[0].inputs.append(0)
    elif variant == "source_position_weight":
        graph.source.operations[0].weight = "stray"
    elif variant == "source_position_shape":
        graph.source.tensors[1].shape[0] += 1
    elif variant == "source_position_product":
        graph.source.tensors[1].elements += 1
    elif variant == "source_position_producer":
        graph.source.tensors[1].producer = -1
    elif variant == "source_position_life":
        graph.source.tensors[1].last_use -= 1
    elif variant == "source_position_alias":
        graph.source.tensors[1].alias_of = 0
    elif variant == "source_position_persistent":
        graph.source.tensors[1].persistent = True
    elif variant == "source_rotary_reference":
        graph.source.operations[rot].dynamic_reference += 1
    elif variant == "source_rotary_selected":
        graph.source.operations[rot].dynamic_selected += 1
    elif variant == "source_rotary_factor":
        graph.source.operations[rot].dynamic_factor.bits += 1
    elif variant == "source_rotary_width":
        graph.source.operations[rot].dynamic_factor.width = 0
    elif variant == "source_rotary_position":
        graph.source.operations[rot].inputs[1] = 0
    elif variant == "source_rotary_kind":
        graph.source.operations[rot].kind = "linear"
    elif variant == "source_rotary_start":
        graph.source.operations[rot].position_start = 0
    elif variant == "source_rotary_shape":
        graph.source.tensors[graph.source.operations[rot].output].shape[1] += 1
    elif variant == "source_rotary_life":
        graph.source.tensors[graph.source.operations[rot].output].last_use += 1
    elif variant == "source_nonrotary_metadata":
        graph.source.operations[1].dynamic_reference = 8
    elif variant == "source_scalar":
        graph.source.source_scalars.rope_base.bits += 1
    elif variant == "source_session":
        graph.source.explicit_session = False
    elif variant == "source_window":
        graph.source.explicit_window = False
    elif variant == "source_scaling":
        graph.source.explicit_scaling = True
    elif variant == "source_export":
        graph.source.cache_exports.append(0)
    elif variant == "source_logit":
        graph.source.logits = 0
    elif variant == "source_projection_weight":
        graph.source.operations[graph.source.tensors[graph.source.operations[rot].inputs[0]].producer].weight = "changed"
    elif variant == "snapshot_flag":
        graph.recipes.explicit_dynamic = False
    elif variant == "snapshot_context":
        graph.recipes.dynamic_source_context += 1
    elif variant == "snapshot_charge":
        graph.recipes.dynamic_work += 1
    elif variant == "snapshot_before":
        graph.recipes.dynamic_before.initial_selected += 1
    elif variant == "snapshot_after":
        graph.recipes.dynamic_after.selected_contexts[0] += 1
    elif variant == "snapshot_word":
        graph.recipes.dynamic_after.policy.factor.bits += 1
    elif variant == "recipe_reference":
        graph.recipes.recipes[recipe].dynamic_reference += 1
    elif variant == "recipe_selected":
        graph.recipes.recipes[recipe].dynamic_selected += 1
    elif variant == "recipe_word":
        graph.recipes.recipes[recipe].dynamic_factor.bits += 1
    elif variant == "recipe_kind":
        graph.recipes.recipes[recipe].operations[1].kind = "changed"
    elif variant == "recipe_gain_shape":
        graph.recipes.recipes[recipe].values[3].shape[0] += 1
    elif variant == "recipe_gain_domain":
        graph.recipes.recipes[recipe].values[3].domain = "index"
    elif variant == "recipe_gain_life":
        graph.recipes.recipes[recipe].values[3].last_use += 1
    elif variant == "recipe_frequency_edge":
        graph.recipes.recipes[recipe].operations[2].inputs[0] = 1
    elif variant == "global_reference":
        graph.operations[gain].dynamic_reference += 1
    elif variant == "global_selected":
        graph.operations[gain].dynamic_selected += 1
    elif variant == "global_word":
        graph.operations[gain].dynamic_factor.bits += 1
    elif variant == "global_gain_shape":
        graph.values[graph.operations[gain].output].shape[0] += 1
    elif variant == "global_gain_domain":
        graph.values[graph.operations[gain].output].domain = "index"
    elif variant == "global_gain_life":
        graph.values[graph.operations[gain].output].last_use += 1
    elif variant == "global_gain_kind":
        graph.operations[gain].kind = "changed"
    elif variant == "global_gain_edge":
        graph.operations[gain].inputs.append(0)
    elif variant == "global_frequency_edge":
        graph.operations[gain + 1].inputs[0] = 0
    elif variant == "global_range_start":
        graph.operations[0].position_start += 1
    elif variant == "global_range_kind":
        graph.operations[0].kind = "prefix_key_indices"
    elif variant == "global_range_source":
        graph.operations[0].source_operation = 1
    elif variant == "global_range_step":
        graph.operations[0].recipe_step = 0
    elif variant == "global_range_metadata":
        graph.operations[0].dynamic_selected = 8
    elif variant == "global_range_domain":
        graph.values[graph.operations[0].output].domain = "real"
    elif variant == "global_range_storage":
        graph.values[graph.operations[0].output].storage = "index"
    elif variant == "global_range_map":
        graph.source_values[1] = 0
    elif variant == "global_range_name":
        graph.values[graph.operations[0].output].name = "changed"
    elif variant == "global_range_shape":
        graph.values[graph.operations[0].output].shape[0] += 1
    elif variant == "global_range_product":
        graph.values[graph.operations[0].output].elements += 1
    elif variant == "global_range_life":
        graph.values[graph.operations[0].output].last_use += 1
    elif variant == "global_range_alias":
        graph.values[graph.operations[0].output].alias_of = 0
    elif variant == "global_range_word":
        graph.operations[0].rotary_base_scalar.bits = 1
    elif variant == "global_start_stray":
        graph.operations[1].position_start = 0
    elif variant == "global_nonrotary_word":
        graph.operations[1].dynamic_factor.bits = 1
    elif variant == "global_nonrotary_kind":
        graph.operations[1].kind = "dynamic_rotary_gain"
    elif variant != "valid":
        raise Error("unknown mutation")
    if a[5] == "session":
        validate_plan_session_state(graph.source)
    elif a[5] == "bias":
        validate_plan_bias_state(graph.source)
    elif a[5] == "activation":
        validate_plan_activation_state(graph.source)
    elif a[5] == "semantic_storage":
        _ = estimate_storage(graph.source, StorageAssumptions(2, 2, 8, 16, graph.source.source.weight_bytes, 0, 9223372036854775807, "test"))
    elif a[5] == "cache":
        _ = plan_cache_layout(graph.source, CacheLayoutAssumptions(2, 2, 16, 16, 16, 1000000, "test"))
    elif a[5] == "matrix":
        for i in range(len(graph.source.operations)):
            if graph.source.operations[i].kind == "linear":
                _ = plan_matrix_contraction(graph.source, i, MatrixTilePolicy(1, 4, 4, 2, 2, 4, 16, 1000000, "test"))
                break
    elif a[5] != "expanded":
        raise Error("unknown consumer")
    validate_rotary_expansion(graph)
    print(describe_rotary_graph(graph, rotary))
