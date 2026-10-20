# Test-only cache metadata mutations and returned ownership. No model math.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.cache_layout import CacheLayout, CacheLayoutAssumptions, plan_cache_layout, cache_element_offset


def _owned(path: String) raises -> CacheLayout:
    var plan = read_dense_semantic_plan(path, 3, 0, 16)
    return plan_cache_layout(plan, CacheLayoutAssumptions(2, 1, 64, 64, 64, 1048576, "synthetic API scenario"))


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_cache_layout_api <source.gguf> <case>")
    var mode = args[2]
    if mode == "ownership":
        var layout = _owned(args[1])
        var saved = layout.regions.copy()
        layout.regions[0].offset = 999
        layout.policy.provenance = "changed"
        var fresh = _owned(args[1])
        if fresh.policy.provenance != "synthetic API scenario" or len(fresh.regions) != len(saved):
            raise Error("CacheLayout: returned ownership drift")
        for i in range(len(saved)):
            if fresh.regions[i].offset != saved[i].offset or fresh.regions[i].name != saved[i].name:
                raise Error("CacheLayout: returned regions alias another owner")
        if cache_element_offset(fresh, 0, 15, 1, 1) != 966:
            raise Error("CacheLayout: owned address mismatch")
        print("owned-cache-layout-pass")
        return
    if mode.startswith("layout_"):
        var layout = _owned(args[1])
        if mode == "layout_overlap":
            layout.regions[1].offset = 0
        elif mode == "layout_stride":
            layout.regions[0].stride = 1
        elif mode == "layout_bytes":
            layout.regions[0].byte_count += 1
        elif mode == "layout_name":
            layout.regions[0].name = "other"
        elif mode == "layout_id":
            layout.regions[1].source_view = layout.regions[0].source_tensor
        elif mode == "layout_total":
            layout.total_bytes -= 1
        elif mode == "layout_pool":
            layout.policy.pool_bytes = 1
        elif mode == "layout_dimension":
            layout.key_dim = 3
        elif mode == "layout_shape":
            layout.capacity = 0
        elif mode == "layout_regions":
            layout.layers = 2
        else:
            raise Error("unknown layout case")
        print(cache_element_offset(layout, 0, 0, 0, 0))
        return
    var plan = read_dense_semantic_plan(args[1], 3, 0, 16)
    var base = -1
    var view = -1
    var writer = -1
    var key = -1
    for i in range(len(plan.tensors)):
        if plan.tensors[i].name == "blk.0.key_cache":
            base = i
        elif plan.tensors[i].name == "blk.0.keys_view":
            view = i
        elif plan.tensors[i].name == "blk.0.k_rotary":
            writer = i
        elif plan.tensors[i].name == "blk.0.k":
            key = i
    var append = plan.tensors[view].producer
    var rotary = plan.tensors[writer].producer
    var linear = plan.tensors[key].producer
    if mode == "base_shape":
        plan.tensors[base].shape[0] = 15
    elif mode == "base_elements":
        plan.tensors[base].elements += 1
    elif mode == "base_owner":
        plan.tensors[base].persistent = False
    elif mode == "base_producer":
        plan.tensors[base].producer = 0
    elif mode == "base_alias":
        plan.tensors[base].alias_of = base
    elif mode == "base_lifetime":
        plan.tensors[base].last_use -= 1
    elif mode == "view_alias":
        plan.tensors[view].alias_of = view
    elif mode == "view_shape":
        plan.tensors[view].shape[1] = 1
    elif mode == "view_lifetime":
        plan.tensors[view].last_use -= 1
    elif mode == "append_input":
        plan.operations[append].inputs[0] = writer
    elif mode == "append_writer":
        plan.operations[append].inputs[1] = key
    elif mode == "append_arity":
        plan.operations[append].inputs = [base]
    elif mode == "append_output":
        plan.operations[append].output = base
    elif mode == "append_kind":
        plan.operations[append].kind = "other"
    elif mode == "writer_kind":
        plan.operations[rotary].kind = "other"
    elif mode == "writer_output":
        plan.operations[rotary].output = key
    elif mode == "writer_input":
        plan.operations[rotary].inputs[0] = base
    elif mode == "projection_weight":
        plan.operations[linear].weight = "blk.0.attn_v.weight"
    elif mode == "projection_shape":
        plan.source.bindings["blk.0.attn_k.weight"].rows += 1
    elif mode == "projection_extent":
        plan.source.bindings["blk.0.attn_k.weight"].file_offset = -1
    elif mode == "projection_bytes":
        plan.source.bindings["blk.0.attn_k.weight"].byte_count -= 1
    elif mode == "projection_consumed":
        plan.used_weights["blk.0.attn_k.weight"] = False
    elif mode == "source_extent":
        plan.source.data_offset = -1
    elif mode == "hidden":
        plan.hidden += 1
    elif mode == "heads":
        plan.kv_heads += 1
    elif mode == "session":
        plan.past_tokens = 16
    elif mode == "layers":
        plan.layers = 2
    elif mode == "rename":
        plan.tensors[base].name = "other"
    elif mode == "duplicate":
        plan.tensors[writer].name = plan.tensors[key].name
    elif mode == "foreign_owner":
        plan.tensors[0].persistent = True
    elif mode == "foreign_alias":
        plan.tensors[0].alias_of = base
    else:
        raise Error("unknown graph case")
    var layout = plan_cache_layout(plan, CacheLayoutAssumptions(2, 1, 64, 64, 64, 1048576, "synthetic API scenario"))
    print(layout.total_bytes)
