# Validate selected activation roles at every downstream compilation boundary.
from std.collections import Dict
from smidr.activation_policy import empty_activation_policy, same_activation_policy, validate_activation_policy, activation_kind_supported
from smidr.semantic_plan import SemanticPlan, checked_product, is_plan_export
from smidr.source_inventory import validate_source_weight


def validate_plan_activation_state(plan: SemanticPlan) raises:
    if not plan.explicit_activation:
        if not same_activation_policy(plan.activation_policy, empty_activation_policy()) or plan.activation_work != 0:
            raise Error("DecoderActivation: stray explicit policy state")
        for i in range(len(plan.operations)):
            if plan.operations[i].kind == "gelu_erf" or plan.operations[i].kind == "relu":
                raise Error("DecoderActivation: alternate operation lacks explicit policy")
        return
    if validate_activation_policy(plan.activation_policy, plan.layers, plan.source.policy.work) != plan.activation_work or len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work:
        raise Error("DecoderActivation: stale policy/graph work")
    if plan.explicit_bias and len(plan.bias_policy.mlp) != plan.layers:
        raise Error("DecoderActivation: incomplete bias selection")
    var names = Dict[String, Int]()
    var last = List[Int]()
    var uses = List[Int]()
    for i in range(len(plan.tensors)):
        var t = plan.tensors[i].copy()
        if t.name in names or t.producer < -1 or t.producer >= len(plan.operations):
            raise Error("DecoderActivation: duplicate name or invalid producer")
        if t.producer >= 0 and plan.operations[t.producer].output != i:
            raise Error("DecoderActivation: orphaned source producer identity")
        names[t.name] = i
        last.append(t.producer)
        uses.append(0)
    var activations = 0
    for i in range(len(plan.operations)):
        var op = plan.operations[i].copy()
        if op.output < 0 or op.output >= len(plan.tensors) or plan.tensors[op.output].producer != i:
            raise Error("DecoderActivation: changed source producer")
        if activation_kind_supported(op.kind):
            activations += 1
        for id in op.inputs:
            if id < 0 or id >= len(plan.tensors) or plan.tensors[id].producer >= i:
                raise Error("DecoderActivation: unavailable source input")
            last[id] = i
            uses[id] += 1
    if activations != plan.layers:
        raise Error("DecoderActivation: incomplete or duplicate gate activation")
    var shape = List[Int]([plan.query_tokens, plan.feed_forward])
    var elements = checked_product(plan.query_tokens, plan.feed_forward)
    for layer in range(plan.layers):
        var p = String("blk.") + String(layer) + "."
        var biased = plan.explicit_bias and plan.bias_policy.mlp[layer] == 1
        var kind = plan.activation_policy.kinds[layer]
        var gate_name = p + "gate_biased" if biased else p + "gate"
        var up_name = p + "up_biased" if biased else p + "up"
        var roles = List[String]([p + "gate", p + "up", gate_name, up_name, p + "gate_" + kind, p + "gated"])
        for name in roles:
            if name not in names:
                raise Error("DecoderActivation: missing selected source role")
            var t = plan.tensors[names[name]].copy()
            if t.shape != shape or t.elements != elements or t.persistent or t.alias_of != -1 or t.producer < 0:
                raise Error("DecoderActivation: changed gate axes/product/storage")
        var gate_id = names[gate_name]
        var up_id = names[up_name]
        var act_id = names[p + "gate_" + kind]
        var gated_id = names[p + "gated"]
        var act = plan.operations[plan.tensors[act_id].producer].copy()
        var product = plan.operations[plan.tensors[gated_id].producer].copy()
        if act.kind != kind or act.inputs != List[Int]([gate_id]) or act.weight.byte_length() != 0 or product.kind != "multiply" or product.inputs != List[Int]([act_id, up_id]) or product.weight.byte_length() != 0 or uses[act_id] != 1 or uses[gate_id] != 1 or uses[up_id] != 1 or uses[gated_id] != 1:
            raise Error("DecoderActivation: changed or bypassed activation/product edge")
        for index in range(2):
            var name = p + "gate" if index == 0 else p + "up"
            var weight = p + "ffn_gate.weight" if index == 0 else p + "ffn_up.weight"
            var id = names[name]
            var op = plan.operations[plan.tensors[id].producer].copy()
            if op.kind != "linear" or op.weight != weight or len(op.inputs) != 1 or plan.tensors[op.inputs[0]].name != p + "ffn_norm":
                raise Error("DecoderActivation: changed gate/up projection role")
            validate_source_weight(plan.source, weight, plan.hidden, plan.feed_forward, False)
            if biased:
                var target = gate_id if index == 0 else up_id
                var bias = plan.operations[plan.tensors[target].producer].copy()
                if bias.kind != "add_projection_bias" or bias.inputs != List[Int]([id]) or bias.weight != weight.replace(".weight", ".bias") or uses[id] != 1:
                    raise Error("DecoderActivation: changed bias-before-activation order")
        if p + "down" not in names:
            raise Error("DecoderActivation: missing gate product consumer")
        var down = plan.operations[plan.tensors[names[p + "down"]].producer].copy()
        if down.kind != "linear" or down.weight != p + "ffn_down.weight" or down.inputs != List[Int]([gated_id]):
            raise Error("DecoderActivation: changed gate product consumer")
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent or is_plan_export(plan, i):
            last[i] = len(plan.operations)
        if last[i] != plan.tensors[i].last_use:
            raise Error("DecoderActivation: stale source lifetime")
