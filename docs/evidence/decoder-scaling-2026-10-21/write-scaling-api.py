from pathlib import Path
old=Path('tests/hailo_decoder_window_api.mojo').read_text()
imports=old[:old.index('def window_fixture')].replace('from hailo_decoder_session_api import session_fixture','from hailo_decoder_window_api import window_fixture').replace('from smidr.window_policy import DecoderWindowPolicy, window_policy_charge','from smidr.scaling_policy import DecoderScalingPolicy\nfrom smidr.source_scalars import ScalarWord\nfrom smidr.primitive_recipes import lower_primitive_recipes\nfrom smidr.session_graph import validate_plan_session_state\nfrom smidr.semantic_plan import validate_plan_window_state')
fixture=old[old.index('def window_fixture'):old.index('def main()')]
fixture=fixture.replace('def window_fixture(', 'def scaling_fixture(').replace('    var seed = session_fixture(root, label, config, "1,1", "1,1", scalar, "gelu_erf,relu", mode, returned, past, capacity)','    var seed = window_fixture(root, label, config, scalar, mode, returned, past, capacity, widths)')
a=fixture.index('    var window =');b=fixture.index('    var geometry =',a)
fixture=fixture[:a]+'''    var scaling = DecoderScalingPolicy("linear", ScalarWord(64, 4611686018427387904), "invocation", "scaling API test provenance", 1000000)
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
'''+fixture[b:]
fixture=fixture.replace('seed.session_policy, window,','seed.session_policy, seed.window_policy, scaling,')
a='''        window.windows[0] = -1
        window.origin = "changed"
        window.provenance = "changed"
        window.work = 1'''
b='''        scaling.kind = "changed"
        scaling.factor.bits = 0
        scaling.origin = "changed"
        scaling.provenance = "changed"
        scaling.work = 1'''
assert a in fixture;fixture=fixture.replace(a,b).replace(a[4:],b[4:])
# Dedent replacements for the requested32 branch independently.
fixture=fixture.replace('    window.windows[0] = -1\n    window.origin = "changed"\n    window.provenance = "changed"\n    window.work = 1','    scaling.kind = "changed"\n    scaling.factor.bits = 0\n    scaling.origin = "changed"\n    scaling.provenance = "changed"\n    scaling.work = 1')
head='''def main() raises:
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
'''
mutations={
 'plan_flag':'plan.explicit_scaling = False',
 'plan_kind':'plan.scaling_policy.kind = "default"',
 'plan_factor':'plan.scaling_policy.factor.bits = 4613937818241073152',
 'plan_width':'plan.scaling_policy.factor.width = 32',
 'plan_origin':'plan.scaling_policy.origin = "changed"',
 'plan_work':'plan.scaling_policy.work = 1',
 'plan_charge':'plan.scaling_work += 1',
 'plan_provenance':'plan.scaling_policy.provenance = ""',
 'plan_session':'plan.explicit_session = False',
 'plan_window':'plan.explicit_window = False',
 'plan_source_factor':'plan.operations[mask].scaling_factor.bits = 4613937818241073152',
 'plan_source_kind':'plan.operations[mask].scaling_kind = "default"',
 'plan_stray':'plan.operations[0].scaling_factor = ScalarWord(64, 4607182418800017408)',
 'plan_bypass':'plan.operations[mask].kind = "changed"',
 'plan_edge':'plan.operations[mask].inputs[0] = 0',
 'plan_position':'plan.operations[mask].inputs[1] = 0',
 'plan_weight':'plan.operations[mask].weight = "changed"',
 'plan_shape':'plan.tensors[plan.operations[mask].output].shape[0] += 1',
 'plan_product':'plan.tensors[plan.operations[mask].output].elements += 1',
 'plan_lifetime':'plan.tensors[plan.operations[mask].output].last_use = 0',
 'plan_alias':'plan.tensors[plan.operations[mask].output].alias_of = 0',
 'plan_producer':'plan.tensors[plan.operations[mask].output].producer = -1',
 'plan_rope_flags':'plan.decoder_policy.rope_enabled[0] = 0',
 'plan_bias_count':'plan.bias_policy.attention.clear()',
}
for i,(case,code) in enumerate(mutations.items()):head+=f'    {"if" if i==0 else "elif"} variant == "{case}":\n        {code}\n'
bypass=('cache','matrix','storage','bias','activation','session','window')
head+='    if '+ ' or '.join(f'variant == "{x}_bypass"' for x in bypass)+':\n        plan.operations[mask].scaling_factor.bits = 4613937818241073152\n'
# Reuse complete existing consumer/layout inspection with the selected source altered.
a=old.index('    if variant == "cache_bypass" or variant == "matrix_bypass"',old.index('    elif variant == "plan_alias"'))
b=old.index('    var rotary =',a)
block=old[a:b].replace(' or variant == "activation_bypass":',' or variant == "activation_bypass" or variant == "session_bypass" or variant == "window_bypass":').replace('        else:\n            _ = estimate_storage','        elif variant == "session_bypass":\n            validate_plan_session_state(plan)\n        elif variant == "window_bypass":\n            validate_plan_window_state(plan)\n        else:\n            _ = estimate_storage').replace('window bypass','scaling bypass')
head+=block
head+='''    if variant == "no_basis":
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
'''
mutations2={
 'snapshot_policy':'graph.recipes.scaling_policy.factor.bits = 4613937818241073152',
 'snapshot_flag':'graph.recipes.explicit_scaling = False',
 'snapshot_work':'graph.recipes.scaling_work += 1',
 'recipe_factor':'graph.recipes.recipes[r].scaling_factor.bits = 4613937818241073152',
 'recipe_factor_width':'graph.recipes.recipes[r].scaling_factor.width = 32',
 'recipe_scaling_kind':'graph.recipes.recipes[r].scaling_kind = "default"',
 'recipe_inputs':'graph.recipes.recipes[r].source_inputs[1] = 0',
 'recipe_local_map':'graph.recipes.recipes[r].input_values[1] = 0',
 'recipe_kind':'graph.recipes.recipes[r].operations[1].kind = "changed"',
 'recipe_edge':'graph.recipes.recipes[r].operations[1].inputs[0] = 0',
 'recipe_domain':'graph.recipes.recipes[r].values[2].domain = "index"',
 'recipe_lifetime':'graph.recipes.recipes[r].values[2].last_use += 1',
 'recipe_weight':'graph.recipes.recipes[r].weight.rows = 1',
 'recipe_extent':'graph.recipes.recipes[r].weight_extent.source_bytes = 1',
 'recipe_storage':'graph.recipes.recipes[r].weight_storage.source_shape.append(1)',
 'recipe_scalar':'graph.recipes.recipes[r].epsilon_scalar.width = 32',
 'recipe_window':'graph.recipes.recipes[r].window_tokens = 1',
 'recipe_stray':'graph.recipes.recipes[0].scaling_kind = "linear"',
 'global_factor':'graph.operations[g].scaling_factor.bits = 4613937818241073152',
 'global_factor_width':'graph.operations[g].scaling_factor.width = 32',
 'global_stray':'graph.operations[0].scaling_kind = "linear"',
 'global_scaling_kind':'graph.operations[g].scaling_kind = "default"',
 'global_kind':'graph.operations[g].kind = "changed"',
 'global_edge':'graph.operations[g].inputs[0] = 0',
 'global_domain':'graph.values[graph.operations[g].output].domain = "index"',
 'global_shape':'graph.values[graph.operations[g].output].shape[0] += 1',
 'global_name':'graph.values[graph.operations[g].output].name = "changed"',
 'global_lifetime':'graph.values[graph.operations[g].output].last_use += 1',
 'global_source':'graph.values[graph.operations[g].output].source_tensor = 0',
 'global_mapping':'graph.source_values[graph.recipes.recipes[r].source_output] += 1',
 'remaining':'graph.recipes.remaining_source_operations.append(graph.recipes.recipes[r].source_operation)',
 'source_policy':'graph.source.scaling_policy.factor.bits = 4613937818241073152',
}
for i,(case,code) in enumerate(mutations2.items()):head+=f'    {"if" if i==0 else "elif"} variant == "{case}":\n        {code}\n'
head+='    print(describe_rotary_graph(graph, rotary))\n'
Path('tests/hailo_decoder_scaling_api.mojo').write_text(imports+fixture+head)
Path('../decoder-scaling-api-cases.json').write_text(__import__('json').dumps(list(mutations)+list(mutations2)+[x+'_bypass' for x in bypass]+['no_basis']+['builder_'+x for x in ('kind','factor','width','origin','work','provenance')],indent=2)+'\n')
