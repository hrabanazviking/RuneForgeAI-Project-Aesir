from pathlib import Path
import json,hashlib
current={n:Path(n).read_text() for n in json.loads(Path('../dynamic-graph-final/source-hashes.json').read_text())}
def undo_diagnostics(files):
 files=files.copy();n='smidr/semantic_plan.mojo';s=files[n]
 a='''def validate_plan_scaling_state(plan: SemanticPlan) raises:
    if len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work:
        raise Error("DecoderScaling: graph work bound changed")
    validate_plan_dynamic_state(plan)
''';b='''def validate_plan_scaling_state(plan: SemanticPlan) raises:
    validate_plan_dynamic_state(plan)
    if len(plan.operations) > plan.source.policy.work or len(plan.tensors) > plan.source.policy.work:
        raise Error("DecoderScaling: graph work bound changed")
''';assert a in s;files[n]=s.replace(a,b,1)
 n='smidr/expanded_graph.mojo';s=files[n];start=s.index('def validate_dynamic_expansion');head,part=s[:start],s[start:]
 part=part.replace('    validate_plan_scaling_state(graph.source)','    validate_plan_dynamic_state(graph.source)',1)
 a=part.index('    if not graph.source.explicit_dynamic:\n');b=part.index('    if len(graph.recipes.recipes) > work',a)
 files[n]=head+part[:a]+part[b:];return files

def undo_public_wrapper(files):
 files=files.copy();n='smidr/semantic_plan.mojo';s=files[n]
 start=s.index('def validate_decoder_geometry(');end=s.index('    if p.layers',start)
 s=s[:start]+'''def validate_decoder_geometry(p: DecoderGeometry, source: SourceTensorInventory,
                              query_tokens: Int, past_tokens: Int,
                              context_capacity: Int, dynamic_limit: Int = 0) raises:
'''+s[end:]
 s=s.replace('_validate_decoder_geometry(decoder_geometry(parameters), source, query_tokens, past_tokens, context_capacity, dynamic_before.policy.limit)', 'validate_decoder_geometry(decoder_geometry(parameters), source, query_tokens, past_tokens, context_capacity, dynamic_before.policy.limit)')
 s=s.replace('_validate_decoder_geometry(geometry, plan.source, plan.query_tokens, plan.past_tokens, plan.context_capacity, plan.dynamic_before.policy.limit)', 'validate_decoder_geometry(geometry, plan.source, plan.query_tokens, plan.past_tokens, plan.context_capacity, plan.dynamic_before.policy.limit)')
 files[n]=s;return files

def undo_role_diagnostics(files):
 files=files.copy()
 for name in ['session_graph','cache_layout','primitive_recipes','semantic_plan']:
  n='smidr/'+name+'.mojo';s=files[n]
  if name=='session_graph':s=s.replace('''    if plan.explicit_dynamic:
        validate_plan_position_role(plan, positions)
    elif plan.tensors[positions].producer != -1:
        raise Error("DecoderSession: positions must be external input")
''','    validate_plan_position_role(plan, positions)\n',1)
  if name=='cache_layout':s=s.replace('                if plan.explicit_dynamic:\n                    validate_plan_position_role(plan, position_id)\n','                validate_plan_position_role(plan, position_id)\n',1)
  if name=='primitive_recipes':s=s.replace('    if plan.explicit_dynamic:\n        validate_plan_position_role(plan, op.inputs[1])\n','    validate_plan_position_role(plan, op.inputs[1])\n',1)
  if name=='semantic_plan':s=s.replace('    if plan.explicit_dynamic:\n        validate_plan_position_role(plan, names["positions"])\n','    validate_plan_position_role(plan, names["positions"])\n',1)
  files[n]=s
 return files

prediag=undo_diagnostics(current);precompat=undo_public_wrapper(prediag);selected=undo_role_diagnostics(precompat)
for path,files in [(Path('../dynamic-graph-final'),current),(Path('../dynamic-graph-final-pre-diagnostics'),prediag),(Path('../dynamic-graph-final-pre-compatibility'),precompat),(Path('../dynamic-graph-selected'),selected)]:
 expected=json.loads((path/'source-hashes.json').read_text())
 mismatches=[n for n,h in expected.items() if hashlib.sha256(files[n].encode()).hexdigest()!=h]
 assert not mismatches,(str(path),mismatches)
 dest=path/'source-snapshot';dest.mkdir(exist_ok=False)
 for n in expected:
  p=dest/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(files[n])
 print(path,len(expected),'exact source contents archived after hash equality')
