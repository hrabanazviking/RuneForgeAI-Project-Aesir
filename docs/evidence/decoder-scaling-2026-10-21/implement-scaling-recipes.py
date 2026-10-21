from pathlib import Path
p=Path('smidr/semantic_plan.mojo');s=p.read_text().replace('scaling_policy.factor if explicit_scaling else ScalarWord(0, 0)','scaling_policy.factor.copy() if explicit_scaling else ScalarWord(0, 0)')
s=s.replace('    var names = Dict[String, Int]()\n    for i in range(len(plan.tensors)):', '    var names = Dict[String, Int]()\n    for i in range(len(plan.tensors)):')
needle='    var expected = 0\n    for layer in range(plan.layers):';assert needle in s
s=s.replace(needle,'    if plan.explicit_bias:\n        _ = validate_bias_policy(plan.bias_policy, plan.layers, len(plan.source.bindings), plan.source.policy.work)\n'+needle)
p.write_text(s)
p=Path('smidr/primitive_recipes.mojo');s=p.read_text();s='from smidr.scaling_policy import DecoderScalingPolicy, empty_scaling_policy\n'+s
s=s.replace('    var window_tokens: Int\n','    var scaling_kind: String\n    var scaling_factor: ScalarWord\n    var window_tokens: Int\n',1)
s=s.replace('        self.window_tokens = 0\n','        self.scaling_kind = String("")\n        self.scaling_factor = ScalarWord(0, 0)\n        self.window_tokens = 0\n',1)
s=s.replace('    var explicit_window: Bool\n','    var explicit_scaling: Bool\n    var scaling_policy: DecoderScalingPolicy\n    var scaling_work: Int\n    var explicit_window: Bool\n',1)
s=s.replace('        self.explicit_window = False\n','        self.explicit_scaling = False\n        self.scaling_policy = empty_scaling_policy()\n        self.scaling_work = 0\n        self.explicit_window = False\n',1)
s=s.replace('    r.rotary_dim = plan.rope_dim\n','    if plan.explicit_scaling:\n        r.scaling_kind = plan.scaling_policy.kind\n        r.scaling_factor = plan.scaling_policy.factor.copy()\n    r.rotary_dim = plan.rope_dim\n',1)
s=s.replace('    var angles = r.emit("rotary_angles", [positions, frequency], angle_shape.copy())','    if plan.explicit_scaling and plan.scaling_policy.kind == "linear":\n        frequency = r.emit("rotary_frequency_scale", [frequency], [pairs])\n    var angles = r.emit("rotary_angles", [positions, frequency], angle_shape.copy())',1)
s=s.replace('    var lowered = PrimitiveRecipes()\n','    if plan.explicit_scaling and not rotary:\n        raise Error("DecoderScaling: explicit mathematical rotary basis required")\n    var lowered = PrimitiveRecipes()\n    lowered.explicit_scaling = plan.explicit_scaling\n    lowered.scaling_policy = plan.scaling_policy.copy()\n    lowered.scaling_work = plan.scaling_work\n',1)
p.write_text(s)
p=Path('smidr/expanded_graph.mojo');s=p.read_text();s='from smidr.scaling_policy import same_scaling_policy\n'+s
s=s.replace('rms_scalar, rotary_scalar\n','rms_scalar, rotary_scalar, validate_plan_scaling_state\n')
s=s.replace('    var window_tokens: Int\n','    var window_tokens: Int\n    var scaling_kind: String\n    var scaling_factor: ScalarWord\n',1)
s=s.replace('rotary_provenance: String, window_tokens: Int = 0):','rotary_provenance: String, window_tokens: Int = 0,\n                 scaling_kind: String = "", scaling_factor: ScalarWord = ScalarWord(0, 0)):')
s=s.replace('        self.window_tokens = window_tokens\n','        self.window_tokens = window_tokens\n        self.scaling_kind = scaling_kind\n        self.scaling_factor = scaling_factor.copy()\n',1)
s=s.replace('             window_tokens: Int = 0) raises -> Int:','             window_tokens: Int = 0, scaling_kind: String = "",\n             scaling_factor: ScalarWord = ScalarWord(0, 0)) raises -> Int:')
s=s.replace('rotary_pairing, rotary_provenance, window_tokens))','rotary_pairing, rotary_provenance, window_tokens, scaling_kind, scaling_factor))')
s=s.replace('recipe.epsilon_scalar, recipe.rotary_base_scalar, recipe.window_tokens)','recipe.epsilon_scalar, recipe.rotary_base_scalar, recipe.window_tokens, recipe.scaling_kind, recipe.scaling_factor)')
s=s.replace('    validate_session_expansion(graph)\n','    validate_session_expansion(graph)\n    validate_scaling_expansion(graph)\n',1)
s=s.replace('        if stored.source_inputs != recipe.source_inputs','        if stored.scaling_kind != recipe.scaling_kind or not same_scalar_word(stored.scaling_factor, recipe.scaling_factor) or stored.source_inputs != recipe.source_inputs',1)
s=s.replace('            if actual.source_operation != recipe.source_operation','            if actual.scaling_kind != recipe.scaling_kind or not same_scalar_word(actual.scaling_factor, recipe.scaling_factor) or actual.source_operation != recipe.source_operation',1)
needle='            local[expected.output] = actual.output\n';idx=s.index(needle,s.index('def validate_rotary_expansion('))
s=s[:idx]+'''            if graph.source.explicit_scaling:
                var is_result = expected.output == recipe.result
                var expected_name = graph.source.tensors[recipe.source_output].name
                if not is_result:
                    expected_name += ".primitive." + String(j)
                if value.name != expected_name or value.source_tensor != (recipe.source_output if is_result else -1) or value.source_weight.byte_length() != 0:
                    raise Error("DecoderScaling: changed rotary global identity")
'''+s[idx:]
s+='''\n\ndef validate_scaling_expansion(graph: ExpandedGraph) raises:
    validate_plan_scaling_state(graph.source)
    if graph.recipes.explicit_scaling != graph.source.explicit_scaling or graph.recipes.scaling_work != graph.source.scaling_work or not same_scaling_policy(graph.recipes.scaling_policy, graph.source.scaling_policy):
        raise Error("DecoderScaling: retained scaling policy snapshot changed")
    if graph.source.explicit_scaling and graph.recipes.rotary_policy.pairing.byte_length() == 0:
        raise Error("DecoderScaling: explicit mathematical basis missing")
    for r in graph.recipes.recipes:
        if r.source_operation < 0 or r.source_operation >= len(graph.source.operations):
            raise Error("DecoderScaling: invalid retained source identity")
        var kind = graph.source.operations[r.source_operation].kind
        var rotary = kind == "rope_query" or kind == "rope_key"
        if graph.source.explicit_scaling and rotary:
            if r.scaling_kind != graph.source.scaling_policy.kind or not same_scalar_word(r.scaling_factor, graph.source.scaling_policy.factor):
                raise Error("DecoderScaling: changed retained factor")
            if r.window_tokens != 0 or r.epsilon_scalar.width != 0 or r.epsilon_scalar.bits != 0 or r.weight.file_offset != 0 or r.weight.columns != 0 or r.weight.rows != 0 or r.weight.source_kind != 0 or r.weight.byte_count != 0 or r.weight_extent.path.byte_length() != 0 or r.weight_extent.source_bytes != 0 or r.weight_extent.payload_start != 0:
                raise Error("DecoderScaling: stray retained rotary constant/extent")
            var w = r.weight_storage.copy()
            if w.format.byte_length() != 0 or w.gguf_kind != 0 or w.dtype.byte_length() != 0 or w.tensor_name.byte_length() != 0 or len(w.shape) != 0 or w.source_path.byte_length() != 0 or w.file_offset != 0 or w.byte_count != 0 or w.elements != 0:
                raise Error("DecoderScaling: stray retained rotary storage")
        elif r.scaling_kind.byte_length() != 0 or r.scaling_factor.width != 0 or r.scaling_factor.bits != 0:
            raise Error("DecoderScaling: stray retained scaling metadata")
    for op in graph.operations:
        if op.source_operation < 0 or op.source_operation >= len(graph.source.operations):
            raise Error("DecoderScaling: invalid expanded source identity")
        var kind = graph.source.operations[op.source_operation].kind
        if graph.source.explicit_scaling and (kind == "rope_query" or kind == "rope_key"):
            if op.scaling_kind != graph.source.scaling_policy.kind or not same_scalar_word(op.scaling_factor, graph.source.scaling_policy.factor) or op.window_tokens != 0 or op.epsilon_scalar.width != 0 or op.epsilon_scalar.bits != 0:
                raise Error("DecoderScaling: changed expanded factor/unused metadata")
        elif op.scaling_kind.byte_length() != 0 or op.scaling_factor.width != 0 or op.scaling_factor.bits != 0:
            raise Error("DecoderScaling: stray expanded scaling metadata")
    if not graph.source.explicit_scaling:
        return
    if len(graph.values) > graph.source.source.policy.work or len(graph.operations) > graph.source.source.policy.work:
        raise Error("DecoderScaling: expanded work bound exceeded")
    var last = List[Int]()
    for value in graph.values:
        if value.producer < -1 or value.producer >= len(graph.operations):
            raise Error("DecoderScaling: invalid expanded producer")
        last.append(value.producer)
    for i in range(len(graph.operations)):
        var op = graph.operations[i].copy()
        if op.output < 0 or op.output >= len(graph.values) or graph.values[op.output].producer != i:
            raise Error("DecoderScaling: changed expanded output producer")
        for id in op.inputs:
            if id < 0 or id >= len(graph.values) or graph.values[id].producer >= i:
                raise Error("DecoderScaling: unavailable expanded operand")
            last[id] = i
    for i in range(len(graph.values)):
        var value = graph.values[i].copy()
        if value.storage == "source_weight" or value.storage == "persistent_kv" or is_expanded_export(graph, i):
            last[i] = len(graph.operations)
        if value.last_use != last[i]:
            raise Error("DecoderScaling: changed expanded lifetime")
'''
p.write_text(s)
p=Path('smidr/expanded_storage.mojo');s=p.read_text();needle='        if op.kind == "select_negative_infinity" and len(op.inputs) != 2:'
assert needle in s;s=s.replace(needle,'''        if op.kind == "rotary_frequency_scale":
            if len(op.inputs) != 1 or output.domain != "real" or output.shape != List[Int]([graph.source.rope_dim // 2]) or op.scaling_kind != "linear":
                raise Error("ExpandedStorage: scaled frequency vector role changed")
            var id = op.inputs[0]
            if id < 0 or id >= value_count or graph.values[id].domain != "real" or graph.values[id].shape != output.shape:
                raise Error("ExpandedStorage: scaled frequency input changed")
'''+needle)
p.write_text(s)
