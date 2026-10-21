# Native compiler graph inspector. No arithmetic execution or device upload.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.expanded_graph import ExpandedGraph, expand_semantic_graph
from smidr.tools.source_inventory import _quote
from smidr.tools.semantic_plan import _integers
from smidr.tools.source_scalars import describe_scalar_word, describe_decoder_scalars


def describe_expanded_graph(graph: ExpandedGraph) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"expanded_mathematical_graph\",\"executable_program\":false,\"device_execution_verified\":false,\"source_fingerprint_verified\":false,\"expanded_storage_recomputed\":false")
    if graph.source.explicit_scalars:
        text = text.replace("\"schema_version\":1", "\"schema_version\":2")
        text += ",\"source_scalars\":" + describe_decoder_scalars(graph.source.source_scalars)
    text += ",\"architecture\":" + _quote(graph.source.source.architecture) + ",\"source_operation_count\":" + String(len(graph.source.operations)) + ",\"source_tensor_count\":" + String(len(graph.source.tensors))
    text += ",\"runtime_preconditions\":[\"token_ids_in_vocabulary\",\"positions_equal_past_plus_query_index\",\"kv_prefix_initialized_through_past\"]"
    text += ",\"unresolved_gates\":[\"source_identity_layout_and_rope\",\"device_precision_and_numerical_acceptance\",\"weight_conversion_and_placement\",\"expanded_storage_accounting\",\"CCW_encoding_upload_and_hardware_result\"]"
    text += ",\"source_to_global\":["
    for i in range(len(graph.source.tensors)):
        if i != 0:
            text += ","
        text += String(graph.source_values[i])
    text += "],\"weights\":{"
    var first = True
    for name in graph.weight_values:
        if not first:
            text += ","
        first = False
        var binding = graph.source.source.bindings[name]
        text += _quote(name) + ":{\"value\":" + String(graph.weight_values[name]) + ",\"file_offset\":" + String(binding.file_offset) + ",\"columns\":" + String(binding.columns) + ",\"rows\":" + String(binding.rows)
        text += ",\"source_kind\":" + String(binding.source_kind) + ",\"byte_count\":" + String(binding.byte_count) + "}"
    text += "},\"values\":["
    for i in range(len(graph.values)):
        if i != 0:
            text += ","
        var value = graph.values[i].copy()
        text += "{\"id\":" + String(i) + ",\"name\":" + _quote(value.name) + ",\"shape\":" + _integers(value.shape) + ",\"elements\":" + String(value.elements)
        text += ",\"domain\":" + _quote(value.domain) + ",\"storage\":" + _quote(value.storage) + ",\"producer\":" + String(value.producer) + ",\"last_use\":" + String(value.last_use)
        text += ",\"alias_of\":" + String(value.alias_of) + ",\"source_tensor\":" + String(value.source_tensor) + ",\"source_weight\":" + _quote(value.source_weight) + "}"
    text += "],\"operations\":["
    for i in range(len(graph.operations)):
        if i != 0:
            text += ","
        var op = graph.operations[i].copy()
        text += "{\"id\":" + String(i) + ",\"kind\":" + _quote(op.kind) + ",\"inputs\":" + _integers(op.inputs) + ",\"output\":" + String(op.output)
        text += ",\"source_operation\":" + String(op.source_operation) + ",\"recipe_step\":" + String(op.recipe_step) + ",\"width\":" + String(op.width) + ",\"epsilon_bits\":" + (String("null") if op.epsilon_scalar.width == 64 else String(op.epsilon_bits))
        if graph.source.explicit_scalars:
            text += ",\"epsilon_scalar\":" + describe_scalar_word(op.epsilon_scalar) + ",\"rotary_base_scalar\":" + describe_scalar_word(op.rotary_base_scalar)
        text += ",\"source_weight\":" + _quote(op.source_weight) + ",\"runtime_preconditions\":["
        for j in range(len(op.runtime_preconditions)):
            if j != 0:
                text += ","
            text += _quote(op.runtime_preconditions[j])
        text += "]}"
    text += "],\"unexpanded_source_operations\":["
    for i in range(len(graph.recipes.remaining_source_operations)):
        if i != 0:
            text += ","
        var index = graph.recipes.remaining_source_operations[i]
        text += "{\"id\":" + String(index) + ",\"kind\":" + _quote(graph.source.operations[index].kind) + "}"
    return text + "],\"result\":" + String(graph.result) + "}"


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("usage: expanded_graph <source.gguf> <query> <past> <context_capacity>")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    var graph = expand_semantic_graph(plan^)
    print(describe_expanded_graph(graph))
