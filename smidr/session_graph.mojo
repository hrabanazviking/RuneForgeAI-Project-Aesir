# Original source session invariants; no numerical attention or device code.
from std.collections import Dict
from smidr.session_policy import empty_session_policy, same_session_policy, validate_session_policy
from smidr.bias_policy import validate_bias_policy
from smidr.semantic_plan import SemanticPlan, checked_product, is_plan_export, validate_decoder_graph_policy
from smidr.source_inventory import validate_source_weight


def _session_tensor(plan: SemanticPlan, names: Dict[String, Int], name: String,
                    shape: List[Int], persistent: Bool = False, alias: Int = -1) raises -> Int:
    if name not in names:
        raise Error("DecoderSession: missing named source role: " + name)
    var id = names[name]
    var t = plan.tensors[id].copy()
    var elements = 1
    for dim in shape:
        elements = checked_product(elements, dim)
    if t.shape != shape or t.elements != elements or t.persistent != persistent or t.alias_of != alias:
        raise Error("DecoderSession: changed role shape/product/storage")
    return id


def _session_operation(plan: SemanticPlan, output: Int, kind: String,
                       inputs: List[Int], weight: String = "") raises:
    var producer = plan.tensors[output].producer
    if producer < 0 or producer >= len(plan.operations):
        raise Error("DecoderSession: missing selected role producer")
    var op = plan.operations[producer].copy()
    if op.output != output or op.kind != kind or op.inputs != inputs or op.weight != weight:
        raise Error("DecoderSession: changed role operation/dependency/source")


def validate_plan_session_state(plan: SemanticPlan) raises:
    if not plan.explicit_session:
        if not same_session_policy(plan.session_policy, empty_session_policy()) or plan.session_work != 0 or len(plan.cache_exports) != 0:
            raise Error("DecoderSession: stray explicit session state")
        return
    if validate_session_policy(plan.session_policy, plan.layers, plan.source.policy.work) != plan.session_work:
        raise Error("DecoderSession: changed session work accounting")
    if plan.layers > (len(plan.source.bindings) - 2) // 9 or len(plan.operations) == 0 or len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work or len(plan.cache_exports) > plan.layers * 2 or not plan.explicit_bias or not plan.explicit_activation:
        raise Error("DecoderSession: incomplete source/policy evidence or graph bounds")
    _ = validate_bias_policy(plan.bias_policy, plan.layers, len(plan.source.bindings), plan.source.policy.work)
    validate_decoder_graph_policy(plan.decoder_policy, plan.source, plan.layers, plan.hidden, plan.vocabulary)
    var full = plan.session_policy.mode == "full_prefix"
    if plan.query_tokens <= 0 or plan.context_capacity <= 0 or plan.past_tokens < 0 or plan.past_tokens > plan.context_capacity or plan.query_tokens > plan.context_capacity - plan.past_tokens or (full and plan.past_tokens != 0) or plan.heads <= 0 or plan.kv_heads <= 0 or plan.heads % plan.kv_heads != 0:
        raise Error("DecoderSession: incompatible mode/query/past/context")
    var total = plan.query_tokens + plan.past_tokens
    var names = Dict[String, Int]()
    var last = List[Int]()
    var persistent_count = 0
    var alias_count = 0
    var append_count = 0
    for i in range(len(plan.tensors)):
        var t = plan.tensors[i].copy()
        if t.name in names or t.producer < -1 or t.producer >= len(plan.operations) or (t.producer >= 0 and plan.operations[t.producer].output != i):
            raise Error("DecoderSession: duplicate/orphaned source identity")
        names[t.name] = i
        last.append(t.producer)
        persistent_count += Int(t.persistent)
        alias_count += Int(t.alias_of != -1)
    for i in range(len(plan.operations)):
        var op = plan.operations[i].copy()
        if op.output < 0 or op.output >= len(plan.tensors) or plan.tensors[op.output].producer != i:
            raise Error("DecoderSession: invalid source operation output")
        if op.kind == "kv_append_keys" or op.kind == "kv_append_values":
            append_count += 1
        for id in op.inputs:
            if id < 0 or id >= len(plan.tensors) or plan.tensors[id].producer >= i:
                raise Error("DecoderSession: unavailable source input")
            last[id] = i
    var count = 0 if full else plan.layers * 2
    if persistent_count != count or alias_count != count or append_count != count:
        raise Error("DecoderSession: mode/base/append/alias set mismatch")
    var positions = _session_tensor(plan, names, "positions", [plan.query_tokens])
    if plan.tensors[positions].producer != -1:
        raise Error("DecoderSession: positions must be external input")
    var exports = List[Int]()
    for layer in range(plan.layers):
        var p = String("blk.") + String(layer) + "."
        var norm = _session_tensor(plan, names, p + "attn_norm", [plan.query_tokens, plan.hidden])
        var norm_producer = plan.tensors[norm].producer
        if norm_producer < 0 or len(plan.operations[norm_producer].inputs) != 1:
            raise Error("DecoderSession: invalid attention norm role")
        var norm_input_name = String("embedding") if layer == 0 else String("blk.") + String(layer - 1) + ".ffn_residual"
        var norm_input = _session_tensor(plan, names, norm_input_name, [plan.query_tokens, plan.hidden])
        _session_operation(plan, norm, "rms_norm", [norm_input], p + "attn_norm.weight")
        validate_source_weight(plan.source, p + "attn_norm.weight", plan.hidden, 1, True)
        var selected = List[Int]()
        for side in range(3):
            var letter = String("q") if side == 0 else (String("k") if side == 1 else String("v"))
            var heads = plan.heads if side == 0 else plan.kv_heads
            var dim = plan.value_dim if side == 2 else plan.key_dim
            var shape = List[Int]([plan.query_tokens, heads, dim])
            var weight = p + "attn_" + letter + ".weight"
            var raw = _session_tensor(plan, names, p + letter, shape)
            _session_operation(plan, raw, "linear", [norm], weight)
            validate_source_weight(plan.source, weight, plan.hidden, checked_product(heads, dim), False)
            var projected = raw
            if plan.bias_policy.attention[layer] == 1:
                projected = _session_tensor(plan, names, p + letter + "_biased", shape)
                var bias = weight.replace(".weight", ".bias")
                _session_operation(plan, projected, "add_projection_bias", [raw], bias)
                validate_source_weight(plan.source, bias, checked_product(heads, dim), 1, True)
            if side < 2 and plan.decoder_policy.rope_enabled[layer] == 1:
                var rotated = _session_tensor(plan, names, p + letter + "_rotary", shape)
                _session_operation(plan, rotated, "rope_query" if side == 0 else String("rope_key"), [projected, positions])
                projected = rotated
            elif side < 2 and p + letter + "_rotary" in names:
                raise Error("DecoderSession: NoPE selection has rotary role")
            selected.append(projected)
        var keys = selected[1]
        var values = selected[2]
        for side in range(2):
            var kind = String("key") if side == 0 else String("value")
            var view_name = p + (String("keys_view") if side == 0 else String("values_view"))
            var base_name = p + kind + "_cache"
            var dim = plan.key_dim if side == 0 else plan.value_dim
            if full:
                if base_name in names or view_name in names:
                    raise Error("DecoderSession: full prefix contains cache/view identity")
            else:
                var base = _session_tensor(plan, names, base_name, [plan.context_capacity, plan.kv_heads, dim], True)
                if plan.tensors[base].producer != -1:
                    raise Error("DecoderSession: cached base must be external")
                var view = _session_tensor(plan, names, view_name, [total, plan.kv_heads, dim], False, base)
                _session_operation(plan, view, "kv_append_keys" if side == 0 else String("kv_append_values"), [base, selected[side + 1]])
                if side == 0:
                    keys = view
                else:
                    values = view
        var scores = _session_tensor(plan, names, p + "scores", [plan.heads, plan.query_tokens, total])
        _session_operation(plan, scores, "gqa_scaled_dot", [selected[0], keys])
        var masked = _session_tensor(plan, names, p + "masked_scores", [plan.heads, plan.query_tokens, total])
        _session_operation(plan, masked, "causal_mask", [scores, positions])
        var probabilities = _session_tensor(plan, names, p + "probabilities", [plan.heads, plan.query_tokens, total])
        _session_operation(plan, probabilities, "softmax", [masked])
        var attention = _session_tensor(plan, names, p + "attention", [plan.query_tokens, checked_product(plan.heads, plan.value_dim)])
        _session_operation(plan, attention, "gqa_weighted_values", [probabilities, values])
        if plan.session_policy.return_cache == 1:
            exports.append(keys)
            exports.append(values)
    if plan.cache_exports != exports:
        raise Error("DecoderSession: changed cache export set/order")
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent or is_plan_export(plan, i):
            last[i] = len(plan.operations)
        if plan.tensors[i].last_use != last[i]:
            raise Error("DecoderSession: stale source lifetime/export")
