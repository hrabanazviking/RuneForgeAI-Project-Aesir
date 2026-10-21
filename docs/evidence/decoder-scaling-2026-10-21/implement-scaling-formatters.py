from pathlib import Path
for file,ref,flag,after,op in [
 ('smidr/tools/semantic_plan.mojo','plan','plan.explicit_scaling','    text += ",\\\"source_bytes\\\":','operation'),
 ('smidr/tools/primitive_recipes.mojo','lowered','lowered.explicit_scaling','    text += ",\\\"unresolved_gates\\\":','recipe'),
 ('smidr/tools/expanded_graph.mojo','graph.source','graph.source.explicit_scaling','    text += ",\\\"architecture\\\":','op')]:
 p=Path(file);s=p.read_text();s='from smidr.tools.scaling_policy import describe_scaling_policy\n'+s
 if file.endswith('/semantic_plan.mojo'):s=s.replace('from smidr.tools.source_scalars import describe_decoder_scalars','from smidr.tools.source_scalars import describe_decoder_scalars, describe_scalar_word')
 pos=s.index(after)
 s=s[:pos]+f'''    if {flag}:
        text = text.replace("\\\"schema_version\\\":6", "\\\"schema_version\\\":7")
        text += ",\\\"scaling_policy\\\":" + describe_scaling_policy({ref}.scaling_policy, {ref}.scaling_work)
'''+s[pos:]
 needle=f'            text += ",\\\"window_tokens\\\":" + String({op}.window_tokens)\n';assert needle in s,file
 s=s.replace(needle,needle+f'''        if {flag}:
            text += ",\\\"scaling_kind\\\":" + _quote({op}.scaling_kind) + ",\\\"scaling_factor\\\":" + describe_scalar_word({op}.scaling_factor)
''',1)
 p.write_text(s)
# Retain the complete source inspector; add only an explicit scaling selection.
p=Path('smidr/tools/decoder_scaling_graph.mojo');s=Path('smidr/tools/decoder_window_graph.mojo').read_text()
s=s.replace('from smidr.decoder_window_source import source_decoder_windows','from smidr.decoder_window_source import source_decoder_windows\nfrom smidr.decoder_scaling_source import source_decoder_scaling\nfrom smidr.scaling_policy import DecoderScalingPolicy\nfrom smidr.source_scalars import ScalarWord\nfrom smidr.tools.hrpc_program import _uint64')
s=s.replace('def window_plan(', 'def scaling_plan(').replace('windows: String) raises -> SemanticPlan:', 'windows: String, scaling_kind: String, factor_width: Int, factor_bits: UInt64) raises -> SemanticPlan:')
s=s.replace('    var source = schema.binding.source^','    var scaling = source_decoder_scaling(schema.binding.architecture, provenance, work) if scaling_kind == "source" else DecoderScalingPolicy(scaling_kind, ScalarWord(factor_width, factor_bits), "invocation", provenance, work)\n    var source = schema.binding.source^')
s=s.replace('session, window, query, past, capacity)', 'session, window, scaling, query, past, capacity)')
s=s.replace('len(args) != 20','len(args) != 23').replace('windows/source")','windows/source scaling_kind/source factor_width factor_bits")')
s=s.replace('var plan = window_plan(', 'var plan = scaling_plan(').replace('Int(args[18]), args[19])','Int(args[18]), args[19], args[20], Int(args[21]), _uint64(args[22]))')
s=s.replace('selected_window_mathematical_recipe','selected_scaling_mathematical_recipe');p.write_text(s)
