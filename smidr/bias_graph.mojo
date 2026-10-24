# Original projection-wide bias source/edge checks. Mathematical IR only.
from std.collections import Dict
from smidr.bias_policy import empty_bias_policy, same_bias_policy, validate_bias_policy
from smidr.semantic_plan import validate_plan_window_state, SemanticPlan, checked_product, is_plan_export, validate_plan_source_sharing
from smidr.source_weight_sharing import validate_shared_source_coverage
from smidr.source_inventory import validate_source_weight


def projection_bias_width(plan: SemanticPlan, index: Int) raises -> Int:
    if index < 0 or index >= len(plan.operations):
        raise Error("DecoderBias: source operation index out of range")
    var op = plan.operations[index].copy()
    if op.kind != "add_projection_bias" or len(op.inputs) != 1 or op.inputs[0] < 0 or op.inputs[0] >= len(plan.tensors) or op.output < 0 or op.output >= len(plan.tensors):
        raise Error("DecoderBias: invalid projection bias source extent")
    var input = plan.tensors[op.inputs[0]].copy()
    var output = plan.tensors[op.output].copy()
    if input.producer < 0 or input.producer >= index or output.producer != index or input.persistent or output.persistent or input.alias_of != -1 or output.alias_of != -1:
        raise Error("DecoderBias: invalid projection bias activation role")
    var linear = plan.operations[input.producer].copy()
    if linear.kind != "linear" or linear.output != op.inputs[0] or linear.weight.replace(".weight", ".bias") != op.weight:
        raise Error("DecoderBias: bias is not bound to its source linear output")
    if (len(input.shape) != 2 and len(input.shape) != 3) or input.shape != output.shape or input.shape[0] != plan.query_tokens:
        raise Error("DecoderBias: projection activation axes mismatch")
    var width = 1
    for axis in range(1, len(input.shape)):
        width = checked_product(width, input.shape[axis])
    if input.elements != checked_product(plan.query_tokens, width) or output.elements != input.elements:
        raise Error("DecoderBias: projection activation product mismatch")
    validate_source_weight(plan.source, op.weight, width, 1, True)
    return width


def validate_plan_bias_state(plan: SemanticPlan) raises:
    validate_plan_source_sharing(plan)
    validate_plan_window_state(plan)
    if not plan.explicit_bias:
        if not same_bias_policy(plan.bias_policy, empty_bias_policy()) or plan.bias_work != 0:
            raise Error("DecoderBias: stray explicit policy state")
        for i in range(len(plan.operations)):
            if plan.operations[i].kind == "add_projection_bias":
                raise Error("DecoderBias: source operation lacks explicit policy")
        return
    var work = validate_bias_policy(plan.bias_policy, plan.layers,
        len(plan.source.bindings), plan.source.policy.work)
    if work != plan.bias_work or len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work:
        raise Error("DecoderBias: policy/graph work state changed")
    if len(plan.source_sharing.aliases) == 0:
        if len(plan.used_weights) != len(plan.source.bindings):
            raise Error("DecoderBias: incomplete consumed source set")
        for name in plan.source.bindings:
            if name not in plan.used_weights or not plan.used_weights[name]:
                raise Error("DecoderBias: source binding was not consumed")
    var wanted = Dict[String, List[Int]]()
    for layer in range(plan.layers):
        var p = String("blk.") + String(layer) + "."
        if plan.bias_policy.attention[layer] == 1:
            wanted[p + "attn_q.bias"] = [plan.query_tokens, plan.heads, plan.key_dim]
            wanted[p + "attn_k.bias"] = [plan.query_tokens, plan.kv_heads, plan.key_dim]
            wanted[p + "attn_v.bias"] = [plan.query_tokens, plan.kv_heads, plan.value_dim]
            wanted[p + "attn_output.bias"] = [plan.query_tokens, plan.hidden]
        if plan.bias_policy.mlp[layer] == 1:
            wanted[p + "ffn_gate.bias"] = [plan.query_tokens, plan.feed_forward]
            wanted[p + "ffn_up.bias"] = [plan.query_tokens, plan.feed_forward]
            wanted[p + "ffn_down.bias"] = [plan.query_tokens, plan.hidden]
    var seen = Dict[String, Int]()
    var linear_seen = Dict[String, Int]()
    var raw_uses = Dict[Int, Int]()
    var actual_weights = Dict[String, Bool]()
    var last = List[Int]()
    for i in range(len(plan.tensors)):
        last.append(plan.tensors[i].producer)
    for i in range(len(plan.operations)):
        var op = plan.operations[i].copy()
        if op.output < 0 or op.output >= len(plan.tensors) or plan.tensors[op.output].producer != i:
            raise Error("DecoderBias: invalid source producer")
        if op.weight.byte_length() != 0:
            if op.weight not in plan.source.bindings:
                raise Error("DecoderBias: source operation weight is missing")
            actual_weights[op.weight] = True
        if op.kind == "linear":
            var name = op.weight.replace(".weight", ".bias")
            if name in wanted:
                if name in linear_seen:
                    raise Error("DecoderBias: duplicate selected linear producer")
                linear_seen[name] = i
        if op.kind == "add_projection_bias":
            if op.weight not in wanted or op.weight in seen:
                raise Error("DecoderBias: missing policy role or duplicate bias")
            _ = projection_bias_width(plan, i)
            if plan.tensors[op.output].shape != wanted[op.weight]:
                raise Error("DecoderBias: selected role feature axes changed")
            seen[op.weight] = i
            raw_uses[op.inputs[0]] = i
        for id in op.inputs:
            if id < 0 or id >= len(plan.tensors) or plan.tensors[id].producer >= i:
                raise Error("DecoderBias: unavailable source input")
            last[id] = i
    if len(plan.source_sharing.aliases) == 0:
        if len(actual_weights) != len(plan.source.bindings):
            raise Error("DecoderBias: retained source tensor has no operation use")
    else:
        validate_shared_source_coverage(plan.source, actual_weights, plan.source_sharing)
    if len(seen) != len(wanted) or len(linear_seen) != len(wanted):
        raise Error("DecoderBias: incomplete selected bias/linear set")
    for i in range(len(plan.operations)):
        for id in plan.operations[i].inputs:
            if id in raw_uses and raw_uses[id] != i:
                raise Error("DecoderBias: selected raw linear result bypasses bias")
    for i in range(len(plan.tensors)):
        var tensor = plan.tensors[i].copy()
        if tensor.persistent or is_plan_export(plan, i):
            last[i] = len(plan.operations)
        if tensor.last_use != last[i]:
            raise Error("DecoderBias: stale source lifetime")
