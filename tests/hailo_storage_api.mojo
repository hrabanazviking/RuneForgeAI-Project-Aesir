# Test-only mutations of typed host compiler structures; no model execution.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.storage_estimate import StorageAssumptions, aligned_bytes, checked_sum, estimate_storage


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_storage_api <source.gguf> <case>")
    var mode = args[2]
    if mode == "round_overflow":
        print(aligned_bytes(9223372036854775807, 1, 2))
        return
    if mode == "product_overflow":
        print(aligned_bytes(9223372036854775807, 2, 1))
        return
    if mode == "sum_overflow":
        print(checked_sum(9223372036854775807, 1))
        return
    var plan = read_dense_semantic_plan(args[1], 3, 0, 16)
    var cache = -1
    var view = -1
    for i in range(len(plan.tensors)):
        if plan.tensors[i].persistent and cache == -1:
            cache = i
        if plan.tensors[i].alias_of >= 0 and view == -1:
            view = i
    if mode == "short_lifetime":
        plan.tensors[2].last_use = 0
    elif mode == "forward_input":
        plan.operations[0].inputs[0] = plan.logits
    elif mode == "negative_input":
        plan.operations[0].inputs[0] = -1
    elif mode == "bad_output":
        plan.operations[0].output = -1
    elif mode == "producer_mismatch":
        plan.tensors[2].producer = 1
    elif mode == "short_persistent":
        plan.tensors[cache].last_use = 0
    elif mode == "alias_cycle":
        plan.tensors[view].alias_of = view
    elif mode == "alias_extent":
        plan.tensors[view].shape[0] = 17
        plan.tensors[view].elements = 17 * 2 * 2
    elif mode == "wrong_elements":
        plan.tensors[2].elements += 1
    elif mode == "empty_shape":
        plan.tensors[2].shape = List[Int]()
    elif mode == "lost_result":
        plan.tensors[plan.logits].last_use -= 1
    else:
        raise Error("unknown test mutation")
    var policy = StorageAssumptions(2, 2, 4, 64, 65536, 0, 1048576, "test structural refusal")
    var estimate = estimate_storage(plan, policy)
    print(estimate.total_bytes)
