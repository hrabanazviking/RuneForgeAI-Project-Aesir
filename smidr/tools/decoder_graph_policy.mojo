# Explicit typed policy inspector. Metadata only; never source-model execution.
from std.sys import argv
from smidr.semantic_plan import DecoderGraphPolicy, SemanticPlan, build_decoder_semantic_plan
from smidr.tools.typed_decoder import _from_file
from smidr.tools.semantic_plan import describe_semantic_plan, _integers
from smidr.tools.source_inventory import _quote
from smidr.cache_layout import CacheLayoutAssumptions, plan_cache_layout, cache_element_offset
from smidr.expanded_graph import expand_semantic_graph
from smidr.expanded_storage import ExpandedStorageAssumptions, estimate_expanded_storage
from smidr.storage_estimate import StorageAssumptions, estimate_storage
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction, matrix_tile_count


def parse_rotary_flags(value: String) raises -> List[Int]:
    # Diagnostic CLI is bounded separately from the typed source-derived policy.
    if value.byte_length() > 4096:
        raise Error("DecoderGraphPolicy: diagnostic flag byte bound exceeded")
    var flags = List[Int]()
    if value.byte_length() != 0:
        for item in value.split(","):
            flags.append(Int(item))
    return flags^


def describe_decoder_graph(var plan: SemanticPlan) raises -> String:
    var text = String("{\"schema_version\":1,\"architecture_adapter_verified\":false,\"execution_tested\":false,\"device_access\":false,\"policy\":{\"rope_enabled\":")
    text += _integers(plan.decoder_policy.rope_enabled) + ",\"output_weight\":" + _quote(plan.decoder_policy.output_weight) + ",\"provenance\":" + _quote(plan.decoder_policy.provenance) + "},\"graph\":" + describe_semantic_plan(plan)
    var cache = plan_cache_layout(plan, CacheLayoutAssumptions(2, 1, 1048576, 1048576, 16, 1099511627776, "explicit diagnostic cache scenario"))
    text += ",\"cache\":["
    for i in range(len(cache.regions)):
        if i != 0:
            text += ","
        var r = cache.regions[i].copy()
        var dimension = plan.key_dim if i % 2 == 0 else plan.value_dim
        text += "[" + String(r.source_tensor) + "," + String(r.source_view) + "," + String(r.offset) + "," + String(r.token_bytes) + "," + String(r.stride) + "," + String(r.byte_count) + "," + String(cache_element_offset(cache, i, cache.capacity - 1, cache.heads - 1, dimension - 1)) + "]"
    text += "],\"matrix_operations\":["
    var first = True
    for step in range(len(plan.operations)):
        if plan.operations[step].kind == "linear":
            var schedule = plan_matrix_contraction(plan, step, MatrixTilePolicy(2, 3, 2, 2, 2, 4, 8, 1073741824, "explicit diagnostic matrix scenario"))
            if not first:
                text += ","
            first = False
            text += "[" + String(step) + "," + String(schedule.input_tensor) + "," + String(schedule.output_tensor) + "," + String(matrix_tile_count(schedule)) + "]"
    var storage = estimate_storage(plan, StorageAssumptions(2, 2, 4, 16, 10000, 100, 1099511627776, "explicit diagnostic storage scenario"))
    text += "],\"source_tensor_bytes\":" + _integers(storage.tensor_bytes)
    var expanded = expand_semantic_graph(plan^)
    var expanded_storage = estimate_expanded_storage(expanded, ExpandedStorageAssumptions(2, 1, 2, 4, 16, 10000, 100, 1099511627776, "explicit diagnostic expanded scenario"))
    var source_map = List[Int]()
    for i in range(len(expanded.source.tensors)):
        source_map.append(expanded.source_values[i])
    text += ",\"source_to_global\":" + _integers(source_map) + ",\"expanded_value_bytes\":" + _integers(expanded_storage.value_bytes) + ",\"expanded_values\":["
    for i in range(len(expanded.values)):
        if i != 0:
            text += ","
        var v = expanded.values[i].copy()
        text += "{\"name\":" + _quote(v.name) + ",\"shape\":" + _integers(v.shape) + ",\"domain\":" + _quote(v.domain) + ",\"producer\":" + String(v.producer) + ",\"last_use\":" + String(v.last_use) + ",\"alias_of\":" + String(v.alias_of) + ",\"source_tensor\":" + String(v.source_tensor) + "}"
    text += "],\"expanded_operations\":["
    for i in range(len(expanded.operations)):
        if i != 0:
            text += ","
        var op = expanded.operations[i].copy()
        text += "{\"kind\":" + _quote(op.kind) + ",\"inputs\":" + _integers(op.inputs) + ",\"output\":" + String(op.output) + ",\"source_operation\":" + String(op.source_operation) + "}"
    return text + "],\"expanded_result\":" + String(expanded.result) + "}"


def main() raises:
    var args = argv()
    if len(args) != 8:
        raise Error("usage: decoder_graph_policy metadata.gguf query past capacity rotary_csv explicit_output provenance")
    var inputs = _from_file(args[1])
    var source = inputs.take_inventory()
    var policy = DecoderGraphPolicy(parse_rotary_flags(args[5]), String(args[6]), String(args[7]))
    var plan = build_decoder_semantic_plan(source^, inputs.parameters, policy, Int(args[2]), Int(args[3]), Int(args[4]))
    print(describe_decoder_graph(plan^))
