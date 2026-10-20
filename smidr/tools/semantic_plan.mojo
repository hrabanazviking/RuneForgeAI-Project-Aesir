# Host-only source graph inspection. Does not submit executable device bytes.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.tools.source_inventory import _quote


def _integers(values: List[Int]) -> String:
    var result = String("[")
    for i in range(len(values)):
        if i != 0:
            result += ","
        result += String(values[i])
    return result + "]"


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("usage: semantic_plan <source.gguf> <query_tokens> <past_tokens> <context_capacity>")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    var text = String("{\"schema_version\":1,\"scope\":\"source_semantic_graph\",\"architecture\":") + _quote(plan.source.architecture)
    text += ",\"execution_tested\":false,\"executable_program\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false"
    text += ",\"unresolved_gates\":[\"source_layout_and_rope_pairing\",\"quantization_and_numerical_recipes\",\"activation_precision_and_layout\",\"device_resource_budgets\",\"operation_lowering_and_program_encoding\",\"program_upload_and_hardware_validation\"]"
    text += ",\"runtime_preconditions\":[\"token_ids_in_vocabulary\",\"positions_equal_past_plus_query_index\",\"kv_prefix_initialized_through_past\"]"
    text += ",\"parameters\":{\"layers\":" + String(plan.layers) + ",\"hidden\":" + String(plan.hidden) + ",\"feed_forward\":" + String(plan.feed_forward)
    text += ",\"heads\":" + String(plan.heads) + ",\"kv_heads\":" + String(plan.kv_heads) + ",\"key_dim\":" + String(plan.key_dim) + ",\"value_dim\":" + String(plan.value_dim)
    text += ",\"rope_dim\":" + String(plan.rope_dim) + ",\"vocabulary\":" + String(plan.vocabulary) + ",\"context_capacity\":" + String(plan.context_capacity)
    text += ",\"query_tokens\":" + String(plan.query_tokens) + ",\"past_tokens\":" + String(plan.past_tokens) + ",\"rope_base\":" + String(plan.rope_base)
    text += ",\"rms_epsilon\":" + String(plan.rms_epsilon) + ",\"source_layout\":" + _quote(plan.source_layout) + "}"
    text += ",\"source_bytes\":" + String(plan.source.source_bytes) + ",\"weight_bytes\":" + String(plan.source.weight_bytes) + ",\"weights\":{"
    var first = True
    for name in plan.used_weights:
        if not first:
            text += ","
        first = False
        var binding = plan.source.bindings[name]
        text += _quote(name) + ":{\"file_offset\":" + String(binding.file_offset) + ",\"columns\":" + String(binding.columns) + ",\"rows\":" + String(binding.rows)
        text += ",\"source_kind\":" + String(binding.source_kind) + ",\"byte_count\":" + String(binding.byte_count) + "}"
    text += "},\"tensors\":["
    for i in range(len(plan.tensors)):
        if i != 0:
            text += ","
        var tensor = plan.tensors[i].copy()
        text += "{\"id\":" + String(i) + ",\"name\":" + _quote(tensor.name) + ",\"shape\":" + _integers(tensor.shape)
        text += ",\"elements\":" + String(tensor.elements) + ",\"producer\":" + String(tensor.producer) + ",\"last_use\":" + String(tensor.last_use)
        text += ",\"persistent\":" + String("true" if tensor.persistent else "false") + ",\"alias_of\":" + String(tensor.alias_of) + "}"
    text += "],\"operations\":["
    for i in range(len(plan.operations)):
        if i != 0:
            text += ","
        var operation = plan.operations[i].copy()
        text += "{\"id\":" + String(i) + ",\"kind\":" + _quote(operation.kind) + ",\"inputs\":" + _integers(operation.inputs)
        text += ",\"output\":" + String(operation.output) + ",\"weight\":" + _quote(operation.weight) + "}"
    text += "],\"logits\":" + String(plan.logits) + "}"
    print(text)
