# Test-only typed graph mutations. No model arithmetic or device access.
from std.sys import argv
from std.collections import Dict
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.expanded_graph import expand_semantic_graph
from smidr.expanded_storage import ExpandedStorageAssumptions, ExpandedStorageEstimate, estimate_expanded_storage


def _owned(path: String) raises -> ExpandedStorageEstimate:
    var plan = read_dense_semantic_plan(path, 3, 0, 16)
    var graph = expand_semantic_graph(plan^)
    var policy = ExpandedStorageAssumptions(2, 1, 2, 4, 1, 65536, 256, 1048576, "native API test assumptions")
    return estimate_expanded_storage(graph, policy)


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_expanded_storage_api <source.gguf> <case>")
    var mode = args[2]
    if mode == "ownership":
        var estimate = _owned(args[1])
        var saved = estimate.value_bytes.copy()
        estimate.value_bytes[0] = 0
        estimate.activation_live_bytes[0] = 0
        var fresh = _owned(args[1])
        if len(fresh.value_bytes) != 70 or len(fresh.activation_live_bytes) != 55 or fresh.total_bytes <= 0:
            raise Error("ExpandedStorage: invalid returned owner")
        for i in range(len(saved)):
            if saved[i] != fresh.value_bytes[i]:
                raise Error("ExpandedStorage: returned arrays alias another owner")
        print("owned-expanded-storage-pass")
        return
    var plan = read_dense_semantic_plan(args[1], 3, 0, 16)
    var graph = expand_semantic_graph(plan^)
    var act = -1
    var pred = -1
    var cache = -1
    var view = -1
    var select = -1
    var compare = -1
    var append = -1
    var constant = graph.weight_values["token_embd.weight"]
    for i in range(len(graph.values)):
        if graph.values[i].storage == "activation" and graph.values[i].domain == "real" and act == -1:
            act = i
        if graph.values[i].domain == "predicate":
            pred = i
        if graph.values[i].storage == "persistent_kv" and cache == -1:
            cache = i
        if graph.values[i].storage == "kv_view" and view == -1:
            view = i
    for i in range(len(graph.operations)):
        if graph.operations[i].kind == "select":
            select = i
        if graph.operations[i].kind == "compare_nonnegative":
            compare = i
        if graph.operations[i].kind == "kv_append_keys":
            append = i
    if mode == "unknown_domain":
        graph.values[act].domain = "mystery"
    elif mode == "unknown_storage":
        graph.values[act].storage = "mystery"
    elif mode == "hidden_predicate":
        graph.values[pred].domain = "real"
    elif mode == "false_predicate":
        graph.values[act].domain = "predicate"
    elif mode == "select_domain":
        graph.operations[select].inputs[0] = act
    elif mode == "compare_arity":
        graph.operations[compare].inputs = List[Int]()
    elif mode == "alias_cycle":
        graph.values[view].alias_of = view
    elif mode == "alias_extent":
        graph.values[view].shape[0] = 17
        graph.values[view].elements = 68
    elif mode == "alias_role":
        graph.values[view].storage = "activation"
    elif mode == "alias_input":
        graph.operations[append].inputs[0] = act
    elif mode == "constant_identity":
        graph.values[constant].source_weight = "missing.weight"
    elif mode == "constant_map":
        graph.weight_values["token_embd.weight"] = act
    elif mode == "constant_activation":
        graph.values[constant].storage = "activation"
    elif mode == "constant_shape":
        graph.values[constant].shape[0] += 1
        graph.values[constant].elements = graph.values[constant].shape[0] * graph.values[constant].shape[1]
    elif mode == "constant_extent":
        graph.source.source.bindings["token_embd.weight"].byte_count = graph.source.source.source_bytes
    elif mode == "constant_packed_size":
        graph.source.source.bindings["token_embd.weight"].byte_count -= 1
    elif mode == "constant_total":
        graph.source.source.weight_bytes -= 1
    elif mode == "constant_kind":
        graph.source.source.bindings["token_embd.weight"].source_kind = 99
    elif mode == "constant_domain":
        graph.values[constant].domain = "predicate"
    elif mode == "source_extent":
        graph.source.source.data_offset = -1
    elif mode == "source_map":
        graph.source_values[0] = -1
    elif mode == "missing_map":
        graph.source_values = Dict[Int, Int]()
    elif mode == "hidden_source_identity":
        graph.values[0].source_tensor = -1
    elif mode == "index_domain":
        graph.values[0].domain = "real"
    elif mode == "persistent_lifetime":
        graph.values[cache].last_use = 0
    elif mode == "short_lifetime":
        graph.values[act].last_use = graph.values[act].producer
    elif mode == "long_lifetime":
        graph.values[pred].last_use = len(graph.operations)
    elif mode == "bad_producer":
        graph.values[act].producer += 1
    elif mode == "bad_input":
        graph.operations[0].inputs[0] = -1
    elif mode == "future_input":
        graph.operations[0].inputs[0] = graph.result
    elif mode == "bad_output":
        graph.operations[0].output = -1
    elif mode == "duplicate_output":
        graph.operations[1].output = graph.operations[0].output
    elif mode == "orphan":
        graph.values.append(graph.values[act].copy())
    elif mode == "lost_export":
        graph.result = -1
    elif mode == "export_lifetime":
        graph.values[graph.result].last_use -= 1
    elif mode == "operation_weight":
        graph.operations[0].source_weight = "missing.weight"
    elif mode == "shape_product":
        graph.values[act].elements += 1
    else:
        raise Error("unknown mutation")
    var policy = ExpandedStorageAssumptions(2, 1, 2, 4, 1, 65536, 256, 1048576, "native malformed graph test")
    var estimate = estimate_expanded_storage(graph, policy)
    print(estimate.total_bytes)
