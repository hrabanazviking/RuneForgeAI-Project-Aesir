# Direct graph integration invariants, without numeric/model/device execution.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan, SemanticTensor
from smidr.expanded_graph import ExpandedGraph, expand_semantic_graph


def _returned_graph(path: String) raises -> ExpandedGraph:
    var plan = read_dense_semantic_plan(path, 2, 0, 16)
    return expand_semantic_graph(plan^)


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_expanded_api <source.gguf> <case>")
    var mode = args[2]
    if mode == "ownership":
        var graph = _returned_graph(args[1])
        var old = graph.source_values[0]
        var size = graph.values[old].shape[0]
        var weight_id = graph.weight_values["token_embd.weight"]
        var columns = graph.values[weight_id].shape[1]
        graph.source.tensors[0].shape[0] = 123
        graph.source.source.bindings["token_embd.weight"].columns = 456
        graph.recipes.recipes[0].values[0].shape[1] = 789
        if graph.values[old].shape[0] != size or graph.values[weight_id].shape[1] != columns:
            raise Error("ExpandedGraph: values alias prior compiler structures")
        print("owned-expanded-graph-pass")
        return
    var plan = read_dense_semantic_plan(args[1], 2, 0, 16)
    var cache = -1
    var view = -1
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent and cache == -1:
            cache = i
        if plan.tensors[i].alias_of >= 0 and view == -1:
            view = i
    if mode == "bad_output":
        plan.operations[0].output = -1
    elif mode == "duplicate_output":
        plan.operations[2].output = plan.operations[0].output
    elif mode == "unmapped_input":
        plan.operations[0].inputs[0] = -1
    elif mode == "short_index_lifetime":
        plan.tensors[0].last_use = -1
    elif mode == "index_shape":
        plan.tensors[0].shape[0] = 3
        plan.tensors[0].elements = 3
    elif mode == "external_domain":
        plan.tensors[0].name = "untyped_external"
    elif mode == "persistent_lifetime":
        plan.tensors[cache].last_use = 0
    elif mode == "alias_self":
        plan.tensors[view].alias_of = view
    elif mode == "alias_extent":
        plan.tensors[view].shape[0] = 17
        plan.tensors[view].elements = 17 * 2 * 2
    elif mode == "bad_weight":
        plan.operations[0].weight = "missing.weight"
    elif mode == "weight_extent":
        plan.source.bindings["token_embd.weight"].byte_count = plan.source.source_bytes
    elif mode == "orphan":
        plan.tensors.append(SemanticTensor("orphan", [1], 1, -2, -2, False, -1))
    elif mode == "lost_export":
        plan.logits = -1
    else:
        raise Error("unknown test mutation")
    var graph = expand_semantic_graph(plan^)
    print(len(graph.operations))
