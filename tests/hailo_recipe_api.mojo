# Direct compiler API refusal and ownership checks, never numerical inference.
from std.sys import argv
from std.memory import bitcast
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.primitive_recipes import lower_primitive_recipes


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_recipe_api <source.gguf> <case>")
    var plan = read_dense_semantic_plan(args[1], 2, 0, 16)
    var norm = -1
    var silu = -1
    var softmax = -1
    for i in range(len(plan.operations)):
        if plan.operations[i].kind == "rms_norm" and norm == -1:
            norm = i
        if plan.operations[i].kind == "silu":
            silu = i
        if plan.operations[i].kind == "softmax":
            softmax = i
    var mode = args[2]
    var input_id = plan.operations[norm].inputs[0]
    var output_id = plan.operations[norm].output
    var name = plan.operations[norm].weight
    if mode == "ownership":
        var recipes = lower_primitive_recipes(plan)
        var width = recipes.recipes[0].values[0].shape[1]
        var columns = recipes.recipes[0].weight.columns
        plan.tensors[input_id].shape[1] = 123
        plan.source.bindings[name].columns = 456
        plan.rms_epsilon = 5
        if recipes.recipes[0].values[0].shape[1] != width or recipes.recipes[0].weight.columns != columns or recipes.recipes[0].epsilon_bits == bitcast[DType.uint32](plan.rms_epsilon):
            raise Error("PrimitiveRecipe: returned values alias source graph")
        print("owned-recipe-values-pass")
        return
    if mode == "input_count":
        plan.operations[norm].inputs = List[Int]()
    elif mode == "negative_input":
        plan.operations[norm].inputs[0] = -1
    elif mode == "bad_output":
        plan.operations[norm].output = -1
    elif mode == "forward_input":
        plan.tensors[input_id].producer = norm
    elif mode == "producer_mismatch":
        plan.tensors[output_id].producer = norm + 1
    elif mode == "short_lifetime":
        plan.tensors[input_id].last_use = norm - 1
    elif mode == "shape_mismatch":
        plan.tensors[output_id].shape[1] += 1
    elif mode == "wrong_product":
        plan.tensors[input_id].elements += 1
    elif mode == "missing_weight":
        plan.operations[norm].weight = "missing.weight"
    elif mode == "weight_shape":
        plan.source.bindings[name].columns += 1
    elif mode == "weight_extent":
        plan.source.bindings[name].byte_count = plan.source.source_bytes
    elif mode == "zero_epsilon":
        plan.rms_epsilon = 0
    elif mode == "nan_epsilon":
        plan.rms_epsilon = bitcast[DType.float32](UInt32(0x7fc00000))
    elif mode == "silu_weight":
        plan.operations[silu].weight = name
    elif mode == "softmax_weight":
        plan.operations[softmax].weight = name
    elif mode == "softmax_shape":
        plan.tensors[plan.operations[softmax].output].shape[2] += 1
    elif mode == "softmax_lifetime":
        plan.tensors[plan.operations[softmax].inputs[0]].last_use = softmax - 1
    else:
        raise Error("unknown test case")
    var recipes = lower_primitive_recipes(plan)
    print(len(recipes.recipes))
