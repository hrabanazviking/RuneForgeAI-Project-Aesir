# Expanded schedule storage scenario; no device allocation or admission.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.expanded_graph import expand_semantic_graph
from smidr.expanded_storage import ExpandedStorageAssumptions, estimate_expanded_storage
from smidr.tools.semantic_plan import _integers
from smidr.tools.source_inventory import _quote


def main() raises:
    var args = argv()
    if len(args) != 14:
        raise Error("usage: expanded_storage <source.gguf> <query> <past> <capacity> <activation_width> <predicate_width> <kv_width> <index_width> <alignment> <assumed_device_weight_bytes> <assumed_workspace_bytes> <budget_bytes> <provenance>")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    var graph = expand_semantic_graph(plan^)
    var policy = ExpandedStorageAssumptions(Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]), Int(args[11]), Int(args[12]), args[13])
    var result = estimate_expanded_storage(graph, policy)
    var text = String("{\"schema_version\":1,\"scope\":\"hypothetical_expanded_storage\",\"expanded_schedule_accounted\":true,\"hardware_fit_verified\":false,\"device_allocation_performed\":false,\"complete_lowering_resource_plan\":false")
    text += ",\"unresolved_costs\":[\"actual_device_precision_and_layout\",\"weight_conversion_and_duplication\",\"device_alignment_and_workspace\",\"program_runtime_and_allocator_overhead\",\"measured_available_hardware_budget\"]"
    text += ",\"assumptions\":{\"activation_width\":" + String(policy.activation_width) + ",\"predicate_width\":" + String(policy.predicate_width) + ",\"kv_width\":" + String(policy.kv_width) + ",\"index_width\":" + String(policy.index_width)
    text += ",\"alignment\":" + String(policy.alignment) + ",\"device_weight_bytes\":" + String(policy.device_weight_bytes) + ",\"workspace_bytes\":" + String(policy.workspace_bytes)
    text += ",\"budget_bytes\":" + String(policy.budget_bytes) + ",\"provenance\":" + _quote(policy.provenance) + "}"
    text += ",\"source_packed_weight_bytes\":" + String(graph.source.source.weight_bytes) + ",\"operation_count\":" + String(len(graph.operations)) + ",\"value_count\":" + String(len(graph.values))
    text += ",\"persistent_kv_bytes\":" + String(result.persistent_kv_bytes) + ",\"input_bytes\":" + String(result.input_bytes)
    text += ",\"peak_activation_bytes\":" + String(result.peak_activation_bytes) + ",\"peak_step\":" + String(result.peak_step) + ",\"total_bytes\":" + String(result.total_bytes)
    text += ",\"within_supplied_budget\":" + String("true" if result.within_supplied_budget else "false")
    text += ",\"value_bytes\":" + _integers(result.value_bytes) + ",\"real_live_bytes\":" + _integers(result.real_live_bytes)
    text += ",\"predicate_live_bytes\":" + _integers(result.predicate_live_bytes) + ",\"activation_live_bytes\":" + _integers(result.activation_live_bytes) + "}"
    print(text)
