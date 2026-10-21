# Test-only structural mutation/refusal probe, no numerical attention.
from std.sys import argv
from hailo_decoder_session_api import session_fixture
from smidr.window_policy import DecoderWindowPolicy, window_policy_charge
from smidr.tools.window_policy import parse_window_widths
from smidr.semantic_plan import SemanticPlan, DecoderGeometry, DenseDecoderParameters, build_decoder_semantic_plan
from smidr.source_inventory import SourceTensorInventory
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.cache_layout import plan_cache_layout, CacheLayoutAssumptions
from smidr.matrix_tiles import plan_matrix_contraction, MatrixTilePolicy
from smidr.storage_estimate import estimate_storage, StorageAssumptions
from smidr.bias_graph import validate_plan_bias_state
from smidr.activation_graph import validate_plan_activation_state


def window_fixture(root: String, label: String, config: String, scalar: String,
                   mode: String, returned: Int, past: Int, capacity: Int,
                   widths: String, variant: String = "valid") raises -> SemanticPlan:
    var seed = session_fixture(root, label, config, "1,1", "1,1", scalar, "gelu_erf,relu", mode, returned, past, capacity)
    var window = DecoderWindowPolicy(parse_window_widths(widths), "invocation", "window API test provenance", 1000000)
    if variant == "builder_width":
        window.windows[0] = -1
    elif variant == "builder_count":
        window.windows.append(1)
    elif variant == "builder_origin":
        window.origin = "changed"
    elif variant == "builder_work":
        window.work = 1
    elif variant == "builder_provenance":
        window.provenance = ""
    var geometry = DecoderGeometry(seed.layers, seed.hidden, seed.feed_forward,
        seed.heads, seed.kv_heads, seed.key_dim, seed.value_dim, seed.rope_dim,
        seed.vocabulary, 9223372036854775807, seed.source_layout)
    var source = seed.source^
    seed.source = SourceTensorInventory()
    if scalar == "source64":
        var plan = build_decoder_semantic_plan(source^, geometry, seed.source_scalars,
            seed.decoder_policy, seed.bias_policy, seed.activation_policy, seed.session_policy, window, 2, past, capacity)
        window.windows[0] = -1
        window.origin = "changed"
        window.provenance = "changed"
        window.work = 1
        return plan^
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
        geometry.vocabulary, geometry.source_context, seed.rope_base, seed.rms_epsilon, geometry.source_layout)
    var plan = build_decoder_semantic_plan(source^, parameters, seed.decoder_policy,
        seed.bias_policy, seed.activation_policy, seed.session_policy, window, 2, past, capacity)
    window.windows[0] = -1
    window.origin = "changed"
    window.provenance = "changed"
    window.work = 1
    return plan^


def main() raises:
    var a = argv()
    if len(a) != 11:
        raise Error("expected root label config scalar mode returned past capacity widths case")
    var variant = a[10]
    if variant == "charge_overflow":
        _ = window_policy_charge(9223372036854775807, "source", "bounded", 9223372036854775807, 9223372036854775807)
    var plan = window_fixture(a[1], a[2], a[3], a[4], a[5], Int(a[6]), Int(a[7]), Int(a[8]), a[9], variant)
    var mask = -1
    var linear = -1
    for i in range(len(plan.operations)):
        if plan.tensors[plan.operations[i].output].name == "blk.0.masked_scores":
            mask = i
        if plan.operations[i].kind == "linear":
            linear = i
    if variant == "plan_flag":
        plan.explicit_window = False
    elif variant == "plan_width":
        plan.window_policy.windows[0] = 0
    elif variant == "plan_positive_width":
        plan.window_policy.windows[0] += 1
    elif variant == "plan_source_width":
        plan.operations[mask].window_tokens += 1
    elif variant == "plan_stray_width":
        plan.operations[0].window_tokens = 1
    elif variant == "plan_negative":
        plan.window_policy.windows[0] = -1
    elif variant == "plan_count":
        plan.window_policy.windows.append(1)
    elif variant == "plan_origin":
        plan.window_policy.origin = "changed"
    elif variant == "plan_work":
        plan.window_policy.work = 1
    elif variant == "plan_charge":
        plan.window_work += 1
    elif variant == "plan_provenance":
        plan.window_policy.provenance = ""
    elif variant == "plan_session":
        plan.explicit_session = False
    elif variant == "plan_kind" or variant == "cache_bypass" or variant == "matrix_bypass" or variant == "storage_bypass" or variant == "bias_bypass" or variant == "activation_bypass":
        plan.operations[mask].kind = "causal_mask"
    elif variant == "plan_edge":
        plan.operations[mask].inputs[0] = 0
    elif variant == "plan_position":
        plan.operations[mask].inputs[1] = 0
    elif variant == "plan_weight":
        plan.operations[mask].weight = "changed"
    elif variant == "plan_shape":
        plan.tensors[plan.operations[mask].output].shape[0] += 1
    elif variant == "plan_product":
        plan.tensors[plan.operations[mask].output].elements += 1
    elif variant == "plan_lifetime":
        plan.tensors[plan.operations[mask].output].last_use += 1
    elif variant == "plan_alias":
        plan.tensors[plan.operations[mask].output].alias_of = 0
    if variant == "cache_bypass" or variant == "matrix_bypass" or variant == "storage_bypass" or variant == "bias_bypass" or variant == "activation_bypass":
        if variant == "cache_bypass":
            _ = plan_cache_layout(plan, CacheLayoutAssumptions(2, 2, 32, 32, 16, 9223372036854775807, "hypothetical window cache"))
        elif variant == "matrix_bypass":
            _ = plan_matrix_contraction(plan, linear, MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical window matrix"))
        elif variant == "bias_bypass":
            validate_plan_bias_state(plan)
        elif variant == "activation_bypass":
            validate_plan_activation_state(plan)
        else:
            _ = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16, plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical window storage"))
        raise Error("unexpected consumer accepted window bypass")
    if variant == "layout":
        var layout = plan_cache_layout(plan, CacheLayoutAssumptions(2, 2, 32, 32, 16, 9223372036854775807, "hypothetical window cache"))
        var storage = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16, plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical window storage"))
        var count = 0
        for i in range(len(plan.operations)):
            if plan.operations[i].kind == "linear":
                _ = plan_matrix_contraction(plan, i, MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical window matrix"))
                count += 1
        print(String("{\"cache_bytes\":") + String(layout.total_bytes) + ",\"persistent_bytes\":" + String(storage.persistent_kv_bytes) + ",\"matrix_schedules\":" + String(count) + "}")
        return
    var rotary = RotaryLoweringPolicy("split_half", "explicit synthetic bias basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    var r = -1
    var g = -1
    for i in range(len(graph.recipes.recipes)):
        if graph.recipes.recipes[i].kind == "causal_window_mask" and r == -1:
            r = i
    for i in range(len(graph.operations)):
        if graph.operations[i].kind == "prefix_key_indices" and g == -1:
            g = i
    if variant == "snapshot_policy":
        graph.recipes.window_policy.windows[0] += 1
    elif variant == "snapshot_flag":
        graph.recipes.explicit_window = False
    elif variant == "snapshot_work":
        graph.recipes.window_work += 1
    elif variant == "recipe_width":
        graph.recipes.recipes[r].window_tokens += 1
    elif variant == "recipe_inputs":
        graph.recipes.recipes[r].source_inputs[1] = 0
    elif variant == "recipe_local_map":
        graph.recipes.recipes[r].input_values[1] = 0
    elif variant == "recipe_kind":
        graph.recipes.recipes[r].operations[1].kind = "changed"
    elif variant == "recipe_edge":
        graph.recipes.recipes[r].operations[1].inputs[0] = 0
    elif variant == "recipe_domain":
        graph.recipes.recipes[r].values[2].domain = "real"
    elif variant == "recipe_lifetime":
        graph.recipes.recipes[r].values[2].last_use += 1
    elif variant == "recipe_weight":
        graph.recipes.recipes[r].weight.rows = 1
    elif variant == "recipe_extent":
        graph.recipes.recipes[r].weight_extent.source_bytes = 1
    elif variant == "recipe_storage":
        graph.recipes.recipes[r].weight_storage.source_shape.append(1)
    elif variant == "recipe_scalar":
        graph.recipes.recipes[r].epsilon_scalar.width = 32
    elif variant == "global_width":
        graph.operations[g].window_tokens += 1
    elif variant == "global_stray":
        graph.operations[0].window_tokens = 1
    elif variant == "global_kind":
        graph.operations[g].kind = "changed"
    elif variant == "global_edge":
        graph.operations[g + 1].inputs[0] = 0
    elif variant == "global_domain":
        graph.values[graph.operations[g].output].domain = "real"
    elif variant == "global_shape":
        graph.values[graph.operations[g].output].shape[0] += 1
    elif variant == "global_name":
        graph.values[graph.operations[g].output].name = "changed"
    elif variant == "global_lifetime":
        graph.values[graph.operations[g].output].last_use += 1
    elif variant == "global_source":
        graph.values[graph.operations[g].output].source_tensor = 0
    elif variant == "global_mapping":
        graph.source_values[graph.recipes.recipes[r].source_output] += 1
    elif variant == "remaining":
        graph.recipes.remaining_source_operations.append(graph.recipes.recipes[r].source_operation)
    elif variant == "source_policy":
        graph.source.window_policy.windows[0] += 1
    print(describe_rotary_graph(graph, rotary))
