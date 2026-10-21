from pathlib import Path
p=Path('smidr/semantic_plan.mojo');s=p.read_text();s='from smidr.scaling_policy import DecoderScalingPolicy, empty_scaling_policy, same_scaling_policy, validate_scaling_policy\n'+s
s=s.replace('same_decoder_scalars\n','same_decoder_scalars, same_scalar_word\n')
s=s.replace('    var window_tokens: Int\n','    var window_tokens: Int\n    var scaling_kind: String\n    var scaling_factor: ScalarWord\n',1)
s=s.replace('weight: String, window_tokens: Int = 0):','weight: String, window_tokens: Int = 0, scaling_kind: String = "",\n                 scaling_factor: ScalarWord = ScalarWord(0, 0)):')
s=s.replace('        self.window_tokens = window_tokens\n','        self.window_tokens = window_tokens\n        self.scaling_kind = scaling_kind\n        self.scaling_factor = scaling_factor.copy()\n',1)
s=s.replace('    var explicit_window: Bool\n','    var explicit_scaling: Bool\n    var scaling_policy: DecoderScalingPolicy\n    var scaling_work: Int\n    var explicit_window: Bool\n',1)
s=s.replace('        self.explicit_window = False\n','        self.explicit_scaling = False\n        self.scaling_policy = empty_scaling_policy()\n        self.scaling_work = 0\n        self.explicit_window = False\n',1)
s=s.replace('             window_tokens: Int = 0) raises -> Int:','             window_tokens: Int = 0, scaling_kind: String = "",\n             scaling_factor: ScalarWord = ScalarWord(0, 0)) raises -> Int:')
s=s.replace('output, weight, window_tokens))','output, weight, window_tokens, scaling_kind, scaling_factor))')
# Existing public overloads remain unchanged; add two typed combined forms.
start=s.index('def build_decoder_semantic_plan(var source: SourceTensorInventory,\n                              parameters: DenseDecoderParameters, policy: DecoderGraphPolicy,\n                              bias: DecoderBiasPolicy, activation: DecoderActivationPolicy,\n                              session: DecoderSessionPolicy, window: DecoderWindowPolicy,')
end=s.index('def _build_decoder_semantic_plan(',start)
over=s[start:end].replace('window: DecoderWindowPolicy,','window: DecoderWindowPolicy, scaling: DecoderScalingPolicy,').replace('session, True, window, True)','session, True, window, True, scaling, True)')
s=s[:end]+over+s[end:]
s=s.replace('                               explicit_window: Bool = False) raises -> SemanticPlan:','                               explicit_window: Bool = False,\n                               scaling_policy: DecoderScalingPolicy = empty_scaling_policy(),\n                               explicit_scaling: Bool = False) raises -> SemanticPlan:')
s=s.replace('    var plan = SemanticPlan(source^)\n','    var scaling_work = 0\n    if explicit_scaling:\n        if not explicit_session or not explicit_window:\n            raise Error("DecoderScaling: explicit session/window ownership required")\n        scaling_work = validate_scaling_policy(scaling_policy, source.policy.work)\n    var plan = SemanticPlan(source^)\n    plan.explicit_scaling = explicit_scaling\n    plan.scaling_policy = scaling_policy.copy()\n    plan.scaling_work = scaling_work\n',1)
for kind,stem,heads in [('rope_query','q','heads'),('rope_key','k','kv_heads')]:
 old=f'plan.emit("{kind}", p + "{stem}_rotary", [{stem}, positions], [query_tokens, plan.{heads}, plan.key_dim])'
 new=f'plan.emit("{kind}", p + "{stem}_rotary", [{stem}, positions], [query_tokens, plan.{heads}, plan.key_dim], "", -1, 0, scaling_policy.kind if explicit_scaling else String(""), scaling_policy.factor if explicit_scaling else ScalarWord(0, 0))'
 assert old in s;s=s.replace(old,new)
s=s.replace('def validate_plan_window_state(plan: SemanticPlan) raises:\n','def validate_plan_window_state(plan: SemanticPlan) raises:\n    validate_plan_scaling_state(plan)\n')
s+='''\n\ndef validate_plan_scaling_state(plan: SemanticPlan) raises:
    if len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work:
        raise Error("DecoderScaling: graph work bound changed")
    if not plan.explicit_scaling:
        if not same_scaling_policy(plan.scaling_policy, empty_scaling_policy()) or plan.scaling_work != 0:
            raise Error("DecoderScaling: stray explicit policy state")
        for op in plan.operations:
            if op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
                raise Error("DecoderScaling: source metadata lacks explicit policy")
        return
    if not plan.explicit_session or not plan.explicit_window or validate_scaling_policy(plan.scaling_policy, plan.source.policy.work) != plan.scaling_work:
        raise Error("DecoderScaling: policy ownership/accounting changed")
    validate_decoder_graph_policy(plan.decoder_policy, plan.source, plan.layers, plan.hidden, plan.vocabulary)
    if plan.query_tokens <= 0 or plan.key_dim <= 0 or plan.rope_dim <= 0 or plan.rope_dim > plan.key_dim or plan.rope_dim % 2 != 0:
        raise Error("DecoderScaling: rotary dimensions changed")
    var names = Dict[String, Int]()
    for i in range(len(plan.tensors)):
        if plan.tensors[i].name in names:
            raise Error("DecoderScaling: duplicate source role")
        names[plan.tensors[i].name] = i
    if "positions" not in names:
        raise Error("DecoderScaling: source positions missing")
    var pos_id = names["positions"]
    var pos = plan.tensors[pos_id].copy()
    if pos.shape != List[Int]([plan.query_tokens]) or pos.elements != plan.query_tokens or pos.producer != -1 or pos.persistent or pos.alias_of != -1:
        raise Error("DecoderScaling: changed source positions")
    var count = 0
    for op in plan.operations:
        if op.kind == "rope_query" or op.kind == "rope_key":
            count += 1
            if op.scaling_kind != plan.scaling_policy.kind or not same_scalar_word(op.scaling_factor, plan.scaling_policy.factor):
                raise Error("DecoderScaling: selected source operation factor changed")
        elif op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
            raise Error("DecoderScaling: stray source operation factor")
    var expected = 0
    for layer in range(plan.layers):
        var prefix = String("blk.") + String(layer) + "."
        for side in List[String](["q", "k"]):
            var name = prefix + side + "_rotary"
            if plan.decoder_policy.rope_enabled[layer] == 0:
                if name in names:
                    raise Error("DecoderScaling: rotary output bypasses NoPE selection")
                continue
            expected += 1
            if name not in names:
                raise Error("DecoderScaling: selected rotary source output missing")
            var t = plan.tensors[names[name]].copy()
            if t.producer < 0 or t.producer >= len(plan.operations):
                raise Error("DecoderScaling: invalid rotary producer")
            var op = plan.operations[t.producer].copy()
            var input_name = prefix + side + (String("_biased") if plan.explicit_bias and plan.bias_policy.attention[layer] == 1 else String(""))
            if input_name not in names:
                raise Error("DecoderScaling: source rotary activation missing")
            var input_id = names[input_name]
            var input = plan.tensors[input_id].copy()
            var heads = plan.heads if side == "q" else plan.kv_heads
            var shape = List[Int]([plan.query_tokens, heads, plan.key_dim])
            var elements = checked_product(checked_product(plan.query_tokens, heads), plan.key_dim)
            if op.kind != (String("rope_query") if side == "q" else String("rope_key")) or op.inputs != List[Int]([input_id, pos_id]) or op.output != names[name] or op.weight.byte_length() != 0 or op.window_tokens != 0:
                raise Error("DecoderScaling: changed source rotary kind/edges/weight")
            if t.shape != shape or input.shape != shape or t.elements != elements or input.elements != elements or t.persistent or t.alias_of != -1 or input.persistent or input.alias_of != -1 or input.producer < 0 or input.producer >= t.producer or input.last_use < t.producer or input.last_use > len(plan.operations) or t.last_use < t.producer or t.last_use > len(plan.operations):
                raise Error("DecoderScaling: changed rotary axes/products/storage/lifetimes")
    if count != expected:
        raise Error("DecoderScaling: missing/duplicate rotary source operations")
'''
p.write_text(s)
