from pathlib import Path
p=Path('smidr/semantic_plan.mojo');s=p.read_text();s=s.replace('@fieldwise_init\nstruct SemanticOperation','struct SemanticOperation',1)
needle='    var weight: String\n\n\nstruct SemanticPlan';assert needle in s;s=s.replace(needle,'''    var weight: String
    var window_tokens: Int

    def __init__(out self, kind: String, var inputs: List[Int], output: Int,
                 weight: String, window_tokens: Int = 0):
        self.kind = kind
        self.inputs = inputs^
        self.output = output
        self.weight = weight
        self.window_tokens = window_tokens


struct SemanticPlan''',1)
s=s.replace('var shape: List[Int], weight: String = "", alias_of: Int = -1) raises -> Int:','var shape: List[Int], weight: String = "", alias_of: Int = -1,\n             window_tokens: Int = 0) raises -> Int:',1).replace('SemanticOperation(kind, inputs^, output, weight))','SemanticOperation(kind, inputs^, output, weight, window_tokens))',1)
s=s.replace('p + "masked_scores", [scores, positions], [plan.heads, query_tokens, total])','p + "masked_scores", [scores, positions], [plan.heads, query_tokens, total], "", -1, window_policy.windows[layer] if explicit_window else 0)',1)
s=s.replace('            if op.kind == "causal_window_mask":','            if op.kind == "causal_window_mask" or op.window_tokens != 0:',1)
s=s.replace('    for op in plan.operations:\n        masks +=','    for op in plan.operations:\n        if op.kind != "causal_window_mask" and op.window_tokens != 0:\n            raise Error("DecoderWindow: stray source width metadata")\n        masks +=',1)
s=s.replace('if op.kind != kind or op.output != id or op.inputs','if op.kind != kind or op.window_tokens != plan.window_policy.windows[layer] or op.output != id or op.inputs',1);p.write_text(s)
p=Path('smidr/tools/semantic_plan.mojo');s=p.read_text();# Attach only to each operation object, not tensor or policy descriptors.
needle='        text += ",\\\"output\\\":"';idx=s.find(needle)
if idx<0:
 # Locate operation-loop output construction to append field before its closing brace.
 print('Manual semantic serializer follow-up needed')
else:
 s=s[:idx]+'        if plan.explicit_window:\n            text += ",\\\"window_tokens\\\":" + String(operation.window_tokens)\n'+s[idx:]
 p.write_text(s)
p=Path('smidr/expanded_graph.mojo');s=p.read_text();needle='        for j in range(len(expected.values)):\n';idx=s.index(needle,s.index('def validate_window_expansion'))
s=s[:idx]+'''        if retained.weight.file_offset != 0 or retained.weight.columns != 0 or retained.weight.rows != 0 or retained.weight.source_kind != 0 or retained.weight.byte_count != 0 or retained.weight_extent.source_format.byte_length() != 0 or retained.weight_extent.source_bytes != 0 or retained.weight_extent.data_offset != 0 or retained.weight_storage.source_format.byte_length() != 0 or retained.weight_storage.source_kind != 0 or retained.weight_storage.original_name.byte_length() != 0 or retained.weight_storage.source_path.byte_length() != 0 or len(retained.weight_storage.source_shape) != 0 or retained.weight_storage.axis_order.byte_length() != 0 or retained.weight_storage.elements != 0 or retained.weight_storage.file_offset != 0 or retained.weight_storage.byte_count != 0:
            raise Error("WindowExpansion: window recipe has stray source weight state")
'''+s[idx:];p.write_text(s)
p=Path('tests/hailo_decoder_window_api.mojo');s=p.read_text();s=s.replace('    elif variant == "plan_negative":','    elif variant == "plan_positive_width":\n        plan.window_policy.windows[0] += 1\n    elif variant == "plan_source_width":\n        plan.operations[mask].window_tokens += 1\n    elif variant == "plan_stray_width":\n        plan.operations[0].window_tokens = 1\n    elif variant == "plan_negative":',1)
s=s.replace('    elif variant == "recipe_scalar":','    elif variant == "recipe_weight":\n        graph.recipes.recipes[r].weight.rows = 1\n    elif variant == "recipe_extent":\n        graph.recipes.recipes[r].weight_extent.source_bytes = 1\n    elif variant == "recipe_storage":\n        graph.recipes.recipes[r].weight_storage.source_shape.append(1)\n    elif variant == "recipe_scalar":',1);p.write_text(s)
p=Path('tests/test_hailo_decoder_window.py');s=p.read_text();s=s.replace('    for r in obj["recipes"]["recipes"]:r.pop("window_tokens")','    for o in obj["source_graph"]["operations"]:o.pop("window_tokens")\n    for r in obj["recipes"]["recipes"]:r.pop("window_tokens")',1)
s=s.replace('            self.assertEqual(op["kind"],"causal_window_mask" if width else "causal_mask")','            self.assertEqual(op["window_tokens"],width)\n            self.assertEqual(op["kind"],"causal_window_mask" if width else "causal_mask")',1)
s=s.replace('        actual=[r for r in rs["recipes"] if r["kind"]=="causal_window_mask"]','        for op in ops:\n            if op["kind"]!="causal_window_mask":self.assertEqual(op["window_tokens"],0)\n        actual=[r for r in rs["recipes"] if r["kind"]=="causal_window_mask"]',1);p.write_text(s)
