# Direct compiler mutations/ownership only; no primitive executor or device API.
from std.sys import argv
from std.memory import bitcast
from smidr.tools.rotary_recipes import rotary_plan
from smidr.rotary_policy import RotaryLoweringPolicy, validate_rotary_policy
from smidr.primitive_recipes import lower_primitive_recipes
from smidr.expanded_graph import expand_semantic_graph
from smidr.expanded_storage import validate_expanded_storage_graph


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("expected fixture and mutation")
    var plan = rotary_plan(args[1], 2, 1, 16, "1")
    var policy = RotaryLoweringPolicy("split_half", "isolated API fixture policy", 100, 100000)
    var mode = String(args[2])
    var ri = -1
    for i in range(len(plan.operations)):
        if plan.operations[i].kind == "rope_query":
            ri = i
            break
    var x = plan.operations[ri].inputs[0]
    var pos = plan.operations[ri].inputs[1]
    var y = plan.operations[ri].output
    if mode == "ownership":
        var recipes = lower_primitive_recipes(plan, policy)
        var index = -1
        for i in range(len(recipes.recipes)):
            if recipes.recipes[i].source_operation == ri:
                index = i
        policy.pairing = "adjacent"
        policy.provenance = "changed"
        plan.operations[ri].inputs.clear()
        plan.tensors[x].shape[2] = 999
        plan.tensors[pos].shape[0] = 888
        plan.rope_base = 2
        if recipes.rotary_policy.pairing != "split_half" or recipes.recipes[index].rotary_provenance != "isolated API fixture policy" or recipes.recipes[index].values[0].shape[2] == 999 or recipes.recipes[index].values[1].shape[0] == 888 or len(recipes.recipes[index].source_inputs) != 2 or recipes.recipes[index].rotary_base_bits == bitcast[DType.uint32](plan.rope_base):
            raise Error("rotary recipe aliases source/policy")
        print("owned-rotary-recipe-pass")
        return
    if mode == "bad_pairing":
        policy.pairing = "inferred"
    elif mode == "empty_provenance":
        policy.provenance = ""
    elif mode == "zero_recipe_bound":
        policy.max_recipes = 0
    elif mode == "short_recipe_bound":
        policy.max_recipes = 1
    elif mode == "zero_work":
        policy.work = 0
    elif mode == "work_short" or mode == "work_exact":
        policy.work = validate_rotary_policy(plan, policy)
        if mode == "work_short":
            policy.work -= 1
    elif mode == "arity":
        _ = plan.operations[ri].inputs.pop()
    elif mode == "negative_input":
        plan.operations[ri].inputs[0] = -1
    elif mode == "negative_output":
        plan.operations[ri].output = -1
    elif mode == "weight":
        plan.operations[ri].weight = "output.weight"
    elif mode == "input_forward":
        plan.tensors[x].producer = ri
    elif mode == "input_negative_producer":
        plan.tensors[x].producer = -2
    elif mode == "input_excess_lifetime":
        plan.tensors[x].last_use = len(plan.operations) + 1
    elif mode == "output_expired":
        plan.tensors[y].last_use = ri - 1
    elif mode == "output_excess_lifetime":
        plan.tensors[y].last_use = len(plan.operations) + 1
    elif mode == "input_expired":
        plan.tensors[x].last_use = ri - 1
    elif mode == "input_rank":
        _ = plan.tensors[x].shape.pop()
    elif mode == "input_shape":
        plan.tensors[x].shape[1] += 1
    elif mode == "input_product":
        plan.tensors[x].elements += 1
    elif mode == "input_alias":
        plan.tensors[x].alias_of = pos
    elif mode == "input_persistent":
        plan.tensors[x].persistent = True
    elif mode == "output_rank":
        _ = plan.tensors[y].shape.pop()
    elif mode == "output_shape":
        plan.tensors[y].shape[2] += 1
    elif mode == "output_product":
        plan.tensors[y].elements += 1
    elif mode == "output_producer":
        plan.tensors[y].producer += 1
    elif mode == "output_alias":
        plan.tensors[y].alias_of = x
    elif mode == "output_persistent":
        plan.tensors[y].persistent = True
    elif mode == "position_producer":
        plan.tensors[pos].producer = 0
    elif mode == "position_name":
        plan.tensors[pos].name = "tokens"
    elif mode == "position_shape":
        plan.tensors[pos].shape[0] += 1
    elif mode == "position_product":
        plan.tensors[pos].elements += 1
    elif mode == "position_alias":
        plan.tensors[pos].alias_of = x
    elif mode == "position_persistent":
        plan.tensors[pos].persistent = True
    elif mode == "dimension_zero":
        plan.rope_dim = 0
    elif mode == "dimension_odd":
        plan.rope_dim = 1
    elif mode == "dimension_excess":
        plan.rope_dim = plan.key_dim + 2
    elif mode == "base_zero":
        plan.rope_base = 0
    elif mode == "base_nan":
        plan.rope_base = bitcast[DType.float32](UInt32(0x7fc00000))
    elif mode == "head_role":
        plan.operations[ri].kind = "rope_key"
    elif mode == "product_overflow":
        plan.query_tokens = 9223372036854775807
        plan.tensors[x].shape[0] = plan.query_tokens
        plan.tensors[y].shape[0] = plan.query_tokens
    elif mode == "source_policy":
        plan.source.policy.tensors = 1
    elif mode.startswith("graph_"):
        var graph = expand_semantic_graph(plan^, policy)
        var step = -1
        for i in range(len(graph.operations)):
            if graph.operations[i].rotary_dim != 0:
                step = i
                break
        var value = graph.operations[step].output
        if mode == "graph_ownership":
            policy.pairing = "changed"
            policy.provenance = "changed"
            if graph.recipes.rotary_policy.pairing != "split_half" or graph.operations[step].rotary_provenance != "isolated API fixture policy":
                raise Error("rotary graph aliases caller policy")
        elif mode == "graph_pairing":
            graph.operations[step].rotary_pairing = "adjacent"
        elif mode == "graph_provenance":
            graph.operations[step].rotary_provenance = "changed"
        elif mode == "graph_dim":
            graph.operations[step].rotary_dim += 2
        elif mode == "graph_base":
            graph.operations[step].rotary_base_bits = 0
        elif mode == "graph_kind":
            graph.operations[step].kind = "rope_query"
        elif mode == "graph_edge":
            graph.operations[step + 1].inputs[0] = value
        elif mode == "graph_arity":
            _ = graph.operations[step + 1].inputs.pop()
        elif mode == "graph_source":
            graph.operations[step].source_operation += 1
        elif mode == "graph_step":
            graph.operations[step].recipe_step = 1
        elif mode == "graph_shape":
            graph.values[value].shape[0] += 1
        elif mode == "graph_product":
            graph.values[value].elements += 1
        elif mode == "graph_domain":
            graph.values[value].domain = "index"
        elif mode == "graph_storage":
            graph.values[value].storage = "source_weight"
        elif mode == "graph_producer":
            graph.values[value].producer += 1
        elif mode == "graph_lifetime":
            graph.values[value].last_use += 1
        elif mode == "graph_position_domain":
            graph.values[graph.source_values[pos]].domain = "real"
        elif mode == "graph_export":
            graph.source_values[y] = value
        elif mode == "graph_stray_metadata":
            graph.operations[0].rotary_dim = 2
        elif mode == "graph_stray_kind":
            graph.operations[0].kind = "rotary_angles"
        elif mode == "graph_policy":
            graph.recipes.rotary_policy.pairing = "adjacent"
        elif mode == "graph_work":
            graph.recipes.rotary_work -= 1
        elif mode == "graph_disabled":
            graph.recipes.rotary_policy = RotaryLoweringPolicy("", "", 0, 0)
            graph.recipes.rotary_work = 0
        elif mode == "graph_source_base":
            graph.source.rope_base = 2
        elif mode == "graph_width":
            graph.operations[step].width = 2
        elif mode.startswith("graph_recipe_"):
            var recipe = -1
            for i in range(len(graph.recipes.recipes)):
                if graph.recipes.recipes[i].source_operation == ri:
                    recipe = i
            if mode == "graph_recipe_inputs":
                graph.recipes.recipes[recipe].source_inputs[1] = x
            elif mode == "graph_recipe_local":
                graph.recipes.recipes[recipe].input_values[1] = 0
            elif mode == "graph_recipe_shape":
                graph.recipes.recipes[recipe].values[2].shape[0] += 1
            elif mode == "graph_recipe_lifetime":
                graph.recipes.recipes[recipe].values[0].last_use = 0
            elif mode == "graph_recipe_kind":
                graph.recipes.recipes[recipe].operations[0].kind = "cos"
            elif mode == "graph_recipe_edge":
                graph.recipes.recipes[recipe].operations[1].inputs[0] = 0
            elif mode == "graph_recipe_identity":
                graph.recipes.recipes[recipe].source_operation = -1
            elif mode == "graph_recipe_result":
                graph.recipes.recipes[recipe].result = 0
            elif mode == "graph_recipe_metadata":
                graph.recipes.recipes[recipe].rotary_base_bits = 0
            else:
                raise Error("unknown owned recipe case")
        elif mode == "graph_preconditions":
            graph.operations[step].runtime_preconditions.clear()
        else:
            raise Error("unknown graph case")
        validate_expanded_storage_graph(graph)
        print("validated-rotary-graph-pass")
        return
    elif mode != "work_exact":
        raise Error("unknown source case")
    var recipes = lower_primitive_recipes(plan, policy)
    print("validated-rotary-recipes-pass")
