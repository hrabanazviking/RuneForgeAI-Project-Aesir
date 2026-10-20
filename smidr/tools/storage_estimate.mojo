# Explicit hypothetical resource scenario; never hardware admission.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.storage_estimate import StorageAssumptions, estimate_storage
from smidr.tools.semantic_plan import _integers
from smidr.tools.source_inventory import _quote


def main() raises:
    var args = argv()
    if len(args) != 13:
        raise Error("usage: storage_estimate <source.gguf> <query> <past> <capacity> <activation_width> <kv_width> <index_width> <alignment> <assumed_device_weight_bytes> <assumed_workspace_bytes> <budget_bytes> <provenance>")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    var policy = StorageAssumptions(Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]), Int(args[11]), args[12])
    var result = estimate_storage(plan, policy)
    var text = String("{\"schema_version\":1,\"scope\":\"hypothetical_storage_estimate\",\"hardware_fit_verified\":false,\"device_allocation_performed\":false,\"complete_lowering_resource_plan\":false")
    text += ",\"unresolved_costs\":[\"actual_device_precision_and_layout\",\"weight_conversion_and_duplication\",\"device_alignment_and_workspace\",\"program_runtime_and_allocator_overhead\",\"measured_available_hardware_budget\"]"
    text += ",\"assumptions\":{\"activation_width\":" + String(policy.activation_width) + ",\"kv_width\":" + String(policy.kv_width) + ",\"index_width\":" + String(policy.index_width)
    text += ",\"alignment\":" + String(policy.alignment) + ",\"device_weight_bytes\":" + String(policy.device_weight_bytes) + ",\"workspace_bytes\":" + String(policy.workspace_bytes)
    text += ",\"budget_bytes\":" + String(policy.budget_bytes) + ",\"provenance\":" + _quote(policy.provenance) + "}"
    text += ",\"source_packed_weight_bytes\":" + String(plan.source.weight_bytes) + ",\"persistent_kv_bytes\":" + String(result.persistent_kv_bytes)
    text += ",\"input_bytes\":" + String(result.input_bytes) + ",\"peak_activation_bytes\":" + String(result.peak_activation_bytes) + ",\"peak_step\":" + String(result.peak_step)
    text += ",\"total_bytes\":" + String(result.total_bytes) + ",\"within_supplied_budget\":" + String("true" if result.within_supplied_budget else "false")
    text += ",\"tensor_bytes\":" + _integers(result.tensor_bytes) + ",\"activation_live_bytes\":" + _integers(result.activation_live_bytes) + "}"
    print(text)
