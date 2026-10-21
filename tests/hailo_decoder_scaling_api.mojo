# Test-only structural mutation/refusal probe, no numerical attention.
from std.sys import argv
from hailo_decoder_window_api import window_fixture
from smidr.scaling_policy import DecoderScalingPolicy
from smidr.source_scalars import ScalarWord
from smidr.primitive_recipes import lower_primitive_recipes
from smidr.session_graph import validate_plan_session_state
from smidr.semantic_plan import validate_plan_window_state
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


def scaling_fixture(root: String, label: String, config: String, scalar: String,
                   mode: String, returned: Int, past: Int, capacity: Int,
                   widths: String, variant: String = "valid") raises -> SemanticPlan:
    var seed = window_fixture(root, label, config, scalar, mode, returned, past, capacity, widths)
    var scaling = DecoderScalingPolicy("linear", ScalarWord(64, 4611686018427387904), "invocation", "scaling API test provenance", 1000000)
    if variant == "builder_kind":
        scaling.kind = "unknown"
    elif variant == "builder_factor":
        scaling.factor.bits = 0
    elif variant == "builder_width":
        scaling.factor.width = 16
    elif variant == "builder_origin":
        scaling.origin = "changed"
    elif variant == "builder_work":
        scaling.work = 1
    elif variant == "builder_provenance":
        scaling.provenance = ""
    var geometry = DecoderGeometry(seed.layers, seed.hidden, seed.feed_forward,
        seed.heads, seed.kv_heads, seed.key_dim, seed.value_dim, seed.rope_dim,
        seed.vocabulary, 9223372036854775807, seed.source_layout)
    var source = seed.source^
    seed.source = SourceTensorInventory()
    if scalar == "source64":
        var plan = build_decoder_semantic_plan(source^, geometry, seed.source_scalars,
            seed.decoder_policy, seed.bias_policy, seed.activation_policy, seed.session_policy, seed.window_policy, scaling, 2, past, capacity)
        scaling.kind = "changed"
        scaling.factor.bits = 0
        scaling.origin = "changed"
        scaling.provenance = "changed"
        scaling.work = 1
        return plan^
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
        geometry.vocabulary, geometry.source_context, seed.rope_base, seed.rms_epsilon, geometry.source_layout)
    var plan = build_decoder_semantic_plan(source^, parameters, seed.decoder_policy,
        seed.bias_policy, seed.activation_policy, seed.session_policy, seed.window_policy, scaling, 2, past, capacity)
    scaling.kind = "changed"
    scaling.factor.bits = 0
    scaling.origin = "changed"
    scaling.provenance = "changed"
    scaling.work = 1
    return plan^


def main() raises:
    var a = argv()
    if len(a) != 11:
        raise Error("expected root label config scalar mode returned past capacity widths case")
    var variant = a[10]
    var plan = scaling_fixture(a[1], a[2], a[3], a[4], a[5], Int(a[6]), Int(a[7]), Int(a[8]), a[9], variant)
    var mask = -1
    var linear = -1
    for i in range(len(plan.operations)):
        if plan.operations[i].kind == "rope_query" and mask == -1:
            mask = i
        if plan.operations[i].kind == "linear":
            linear = i
    if variant == "plan_flag":
        plan.explicit_scaling = False
    elif variant == "plan_kind":
        plan.scaling_policy.kind = "default"
    elif variant == "plan_factor":
        plan.scaling_policy.factor.bits = 4613937818241073152
    elif variant == "plan_width":
        plan.scaling_policy.factor.width = 32
    elif variant == "plan_origin":
        plan.scaling_policy.origin = "changed"
    elif variant == "plan_work":
        plan.scaling_policy.work = 1
    elif variant == "plan_charge":
        plan.scaling_work += 1
    elif variant == "plan_provenance":
        plan.scaling_policy.provenance = ""
    elif variant == "plan_session":
        plan.explicit_session = False
    elif variant == "plan_window":
        plan.explicit_window = False
    elif variant == "plan_source_factor":
        plan.operations[mask].scaling_factor.bits = 4613937818241073152
    elif variant == "plan_source_kind":
        plan.operations[mask].scaling_kind = "default"
    elif variant == "plan_stray":
        plan.operations[0].scaling_factor = ScalarWord(64, 4607182418800017408)
    elif variant == "plan_bypass":
        plan.operations[mask].kind = "changed"
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
        plan.tensors[plan.operations[mask].output].last_use = 0
    elif variant == "plan_alias":
        plan.tensors[plan.operations[mask].output].alias_of = 0
    elif variant == "plan_producer":
        plan.tensors[plan.operations[mask].output].producer = -1
    elif variant == "plan_rope_flags":
        plan.decoder_policy.rope_enabled[0] = 1 - plan.decoder_policy.rope_enabled[0]
    elif variant == "plan_bias_count":
        plan.bias_policy.attention.clear()
    if variant == "cache_bypass" or variant == "matrix_bypass" or variant == "storage_bypass" or variant == "bias_bypass" or variant == "activation_bypass" or variant == "session_bypass" or variant == "window_bypass":
        plan.operations[mask].scaling_factor.bits = 4613937818241073152
    if variant == "cache_bypass" or variant == "matrix_bypass" or variant == "storage_bypass" or variant == "bias_bypass" or variant == "activation_bypass" or variant == "session_bypass" or variant == "window_bypass":
        if variant == "cache_bypass":
            _ = plan_cache_layout(plan, CacheLayoutAssumptions(2, 2, 32, 32, 16, 9223372036854775807, "hypothetical window cache"))
        elif variant == "matrix_bypass":
            _ = plan_matrix_contraction(plan, linear, MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical window matrix"))
        elif variant == "bias_bypass":
            validate_plan_bias_state(plan)
        elif variant == "activation_bypass":
            validate_plan_activation_state(plan)
        elif variant == "session_bypass":
            validate_plan_session_state(plan)
        elif variant == "window_bypass":
            validate_plan_window_state(plan)
        else:
            _ = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16, plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical window storage"))
        raise Error("unexpected consumer accepted scaling bypass")
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
    if variant == "no_basis":
        _ = lower_primitive_recipes(plan)
        raise Error("unexpected implicit basis acceptance")
    var rotary = RotaryLoweringPolicy("split_half", "explicit synthetic bias basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    var r = -1
    var g = -1
    for i in range(len(graph.recipes.recipes)):
        if graph.recipes.recipes[i].kind == "rope_query" and r == -1:
            r = i
    for i in range(len(graph.operations)):
        if graph.operations[i].kind == "rotary_frequency_scale" and g == -1:
            g = i
    if variant == "snapshot_policy":
        graph.recipes.scaling_policy.factor.bits = 4613937818241073152
    elif variant == "snapshot_flag":
        graph.recipes.explicit_scaling = False
    elif variant == "snapshot_work":
        graph.recipes.scaling_work += 1
    elif variant == "recipe_factor":
        graph.recipes.recipes[r].scaling_factor.bits = 4613937818241073152
    elif variant == "recipe_factor_width":
        graph.recipes.recipes[r].scaling_factor.width = 32
    elif variant == "recipe_scaling_kind":
        graph.recipes.recipes[r].scaling_kind = "default"
    elif variant == "recipe_inputs":
        graph.recipes.recipes[r].source_inputs[1] = 0
    elif variant == "recipe_local_map":
        graph.recipes.recipes[r].input_values[1] = 0
    elif variant == "recipe_kind":
        graph.recipes.recipes[r].operations[1].kind = "changed"
    elif variant == "recipe_edge":
        graph.recipes.recipes[r].operations[1].inputs[0] = 0
    elif variant == "recipe_domain":
        graph.recipes.recipes[r].values[2].domain = "index"
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
    elif variant == "recipe_window":
        graph.recipes.recipes[r].window_tokens = 1
    elif variant == "recipe_stray":
        graph.recipes.recipes[0].scaling_kind = "linear"
    elif variant == "global_factor":
        graph.operations[g].scaling_factor.bits = 4613937818241073152
    elif variant == "global_factor_width":
        graph.operations[g].scaling_factor.width = 32
    elif variant == "global_stray":
        graph.operations[0].scaling_kind = "linear"
    elif variant == "global_scaling_kind":
        graph.operations[g].scaling_kind = "default"
    elif variant == "global_kind":
        graph.operations[g].kind = "changed"
    elif variant == "global_edge":
        graph.operations[g].inputs[0] = 0
    elif variant == "global_domain":
        graph.values[graph.operations[g].output].domain = "index"
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
        graph.source.scaling_policy.factor.bits = 4613937818241073152
    print(describe_rotary_graph(graph, rotary))
