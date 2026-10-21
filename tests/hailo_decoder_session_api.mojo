# Source-neutral session mutation harness; no numerical forward.
from std.sys import argv
from hailo_decoder_activation_api import activation_fixture
from smidr.semantic_plan import SemanticPlan, DecoderGeometry, DenseDecoderParameters, build_decoder_semantic_plan
from smidr.source_inventory import SourceTensorInventory
from smidr.session_policy import DecoderSessionPolicy, session_policy_charge
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.cache_layout import CacheLayoutAssumptions, plan_cache_layout, validate_cache_layout, cache_element_offset
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction
from smidr.storage_estimate import StorageAssumptions, estimate_storage


def session_fixture(root: String, label: String, config: String, attention: String,
                    mlp: String, scalar: String, kinds: String, mode: String,
                    returned: Int, past: Int, capacity: Int, variant: String = "valid") raises -> SemanticPlan:
    var seed = activation_fixture(root, label, config, attention, mlp, scalar, kinds)
    var policy = DecoderSessionPolicy(mode, returned, 0, "invocation", "session API test provenance", 1000000)
    if variant == "builder_mode":
        policy.mode = "unknown"
    elif variant == "builder_return":
        policy.return_cache = 2
    elif variant == "builder_source_return":
        policy.source_return_cache = -1
    elif variant == "builder_origin":
        policy.return_origin = "unknown"
    elif variant == "builder_inherit":
        policy.return_origin = "source"
        policy.return_cache = 1
    elif variant == "builder_work":
        policy.work = 1
    elif variant == "builder_provenance":
        policy.provenance = ""
    var geometry = DecoderGeometry(seed.layers, seed.hidden, seed.feed_forward,
        seed.heads, seed.kv_heads, seed.key_dim, seed.value_dim, seed.rope_dim,
        seed.vocabulary, 9223372036854775807, seed.source_layout)
    var source = seed.source^
    seed.source = SourceTensorInventory()
    if scalar == "source64":
        var plan = build_decoder_semantic_plan(source^, geometry, seed.source_scalars,
            seed.decoder_policy, seed.bias_policy, seed.activation_policy, policy, 2, past, capacity)
        policy.mode = "changed"
        policy.return_cache = 2
        policy.source_return_cache = 2
        policy.return_origin = "changed"
        policy.provenance = "changed"
        policy.work = 1
        return plan^
    var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
        geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
        geometry.vocabulary, geometry.source_context, seed.rope_base, seed.rms_epsilon, geometry.source_layout)
    var plan = build_decoder_semantic_plan(source^, parameters, seed.decoder_policy,
        seed.bias_policy, seed.activation_policy, policy, 2, past, capacity)
    policy.mode = "changed"
    policy.return_cache = 2
    policy.source_return_cache = 2
    policy.return_origin = "changed"
    policy.provenance = "changed"
    policy.work = 1
    return plan^


def main() raises:
    var args = argv()
    if len(args) != 13:
        raise Error("expected root weight config attention mlp scalar kinds session_mode returned past capacity case")
    var variant = args[12]
    if variant == "charge_overflow":
        _ = session_policy_charge("cached_append", 0, 0, "source", "bounded", 9223372036854775807, 9223372036854775807, 9223372036854775807)
    var plan = session_fixture(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], Int(args[9]), Int(args[10]), Int(args[11]), variant)
    var key = -1
    var score = -1
    for i in range(len(plan.operations)):
        if plan.tensors[plan.operations[i].output].name == "blk.0.k":
            key = i
        if plan.tensors[plan.operations[i].output].name == "blk.0.scores":
            score = i
    if variant == "plan_legacy":
        plan.explicit_session = False
    elif variant == "plan_mode":
        plan.session_policy.mode = "full_prefix" if args[8] == "cached_append" else String("cached_append")
    elif variant == "plan_return":
        plan.session_policy.return_cache = 1 - plan.session_policy.return_cache
    elif variant == "plan_origin":
        plan.session_policy.return_origin = "unknown"
    elif variant == "plan_source":
        plan.session_policy.source_return_cache = 2
    elif variant == "plan_work":
        plan.session_policy.work = 1
    elif variant == "plan_charge":
        plan.session_work += 1
    elif variant == "plan_exports":
        plan.cache_exports.append(0)
    elif variant == "plan_export_order":
        if len(plan.cache_exports) == 0:
            plan.cache_exports.append(0)
        else:
            plan.cache_exports[0] = plan.cache_exports[1]
    elif variant == "plan_key_weight":
        plan.operations[key].weight = "blk.0.attn_v.weight"
    elif variant == "plan_key_input":
        plan.operations[key].inputs[0] = 0
    elif variant == "plan_key_shape":
        plan.tensors[plan.operations[key].output].shape[2] += 1
    elif variant == "plan_key_product":
        plan.tensors[plan.operations[key].output].elements += 1
    elif variant == "plan_key_persistent":
        plan.tensors[plan.operations[key].output].persistent = True
    elif variant == "plan_key_alias":
        plan.tensors[plan.operations[key].output].alias_of = 0
    elif variant == "plan_key_name":
        plan.tensors[plan.operations[key].output].name = "changed"
    elif variant == "plan_score_input" or variant == "cache_bypass" or variant == "matrix_bypass" or variant == "storage_bypass":
        plan.operations[score].inputs[1] = plan.operations[key].output
    elif variant == "plan_norm_input":
        plan.operations[1].inputs[0] = 0
    elif variant == "plan_position_producer":
        plan.tensors[1].producer = 0
    elif variant == "plan_position_shape":
        plan.tensors[1].shape[0] += 1
    elif variant == "plan_score_kind":
        plan.operations[score].kind = "changed"
    elif variant == "plan_lifetime":
        plan.tensors[plan.operations[key].output].last_use += 1
    elif variant == "plan_past":
        plan.past_tokens = 1 if args[8] == "full_prefix" else 2
    if variant == "cache_bypass" or variant == "matrix_bypass" or variant == "storage_bypass":
        if variant == "cache_bypass":
            _ = plan_cache_layout(plan, CacheLayoutAssumptions(2, 2, 32, 32, 16, 9223372036854775807, "hypothetical session cache"))
        elif variant == "matrix_bypass":
            _ = plan_matrix_contraction(plan, key, MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical session matrix"))
        else:
            _ = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16, plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical session storage"))
        raise Error("unexpected consumer accepted session bypass")
    if variant == "layout" or variant == "layout_mode" or variant == "layout_total" or variant == "layout_lookup" or variant == "layout_geometry" or variant == "layout_region" or variant == "layout_unallocated":
        var layout = plan_cache_layout(plan, CacheLayoutAssumptions(2, 2, 32, 32, 16, 9223372036854775807, "hypothetical session cache"))
        if variant == "layout_unallocated":
            layout.policy.key_width = 9223372036854775807
            layout.policy.value_width = 9223372036854775807
            layout.policy.pool_bytes = 1
        if variant == "layout_mode":
            layout.mode = "cached_append" if args[8] == "full_prefix" else String("full_prefix")
        elif variant == "layout_geometry":
            layout.capacity = 0
        elif variant == "layout_region":
            layout.source_tensor_count = 0
        elif variant == "layout_total":
            layout.total_bytes += 1
        elif variant == "layout_lookup":
            _ = cache_element_offset(layout, len(layout.regions), 0, 0, 0)
        validate_cache_layout(layout)
        var storage = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16, plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical session storage"))
        var schedules = 0
        for i in range(len(plan.operations)):
            if plan.operations[i].kind == "linear":
                _ = plan_matrix_contraction(plan, i, MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical session matrix"))
                schedules += 1
        print(String("{\"cache_bytes\":") + String(layout.total_bytes) + ",\"regions\":" + String(len(layout.regions)) + ",\"persistent_storage_bytes\":" + String(storage.persistent_kv_bytes) + ",\"matrix_schedules\":" + String(schedules) + "}")
        return
    var rotary = RotaryLoweringPolicy("split_half", "explicit synthetic bias basis", 10000, 10000000)
    var graph = expand_semantic_graph(plan^, rotary)
    if variant == "recipe_policy":
        graph.recipes.session_policy.mode = "changed"
    elif variant == "recipe_flag":
        graph.recipes.explicit_session = False
    elif variant == "recipe_work":
        graph.recipes.session_work += 1
    elif variant == "recipe_exports":
        graph.recipes.cache_exports.append(0)
    elif variant == "global_mapping":
        if len(graph.source.cache_exports) == 0:
            graph.source_values[graph.source.logits] += 1
        else:
            graph.source_values[graph.source.cache_exports[0]] += 1
    elif variant == "global_lifetime":
        var id = graph.source.logits if len(graph.source.cache_exports) == 0 else graph.source.cache_exports[0]
        graph.values[graph.source_values[id]].last_use -= 1
    elif variant == "global_source_exports":
        graph.source.cache_exports.append(0)
    print(describe_rotary_graph(graph, rotary))
