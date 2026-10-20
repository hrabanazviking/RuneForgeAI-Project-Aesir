# Test-only structural graph mutations. No tensor payload or numerical model.
from std.sys import argv
from smidr.source_storage import SourceStorageTensor
from smidr.semantic_plan import SemanticPlan, checked_product
from smidr.source_inventory import SourceTensorInventory, SourceTensorBinding, SourceFileExtent
from smidr.matrix_tiles import MatrixSchedule, MatrixTilePolicy, plan_matrix_contraction
from smidr.tools.matrix_tiles import describe_matrix_schedule


def _schedule(m: Int, n: Int, c: Int, tm: Int, tn: Int, tc: Int,
              mode: String) raises -> MatrixSchedule:
    var source = SourceTensorInventory()
    source.architecture = String("synthetic structural graph")
    source.data_offset = 64
    source.weight_bytes = checked_product(checked_product(n, c), 2)
    if source.weight_bytes > 9223372036854775807 - 64:
        raise Error("MatrixTiles: test source extent overflow")
    source.source_bytes = source.weight_bytes + 64
    source.bindings["weights"] = SourceTensorBinding(64, c, n, 1, source.weight_bytes)
    source.storage["weights"] = SourceStorageTensor("gguf", 1, "weights", "synthetic.gguf",
        [c, n], "gguf_fastest_axis_first", c * n, 64, source.weight_bytes)
    source.files["synthetic.gguf"] = SourceFileExtent("gguf", source.source_bytes, 64)
    source.alias_provenance = "explicit synthetic matrix identity binding"
    var plan = SemanticPlan(source^)
    var input = plan.tensor("input", [m, c])
    plan.weight("weights", c, n)
    var output = plan.emit("linear", "output", [input], [m, n], "weights")
    var policy = MatrixTilePolicy(tm, tn, tc, 2, 1, 4, 8, 1048576, "synthetic tile policy")
    var op = 0
    if mode == "split":
        if n % 2 != 0:
            raise Error("MatrixTiles: test split requires even N")
        plan.tensors[output].shape = [m, 2, n // 2]
    elif mode == "outer":
        plan.tensors[input].shape = [1, m, c]
        plan.tensors[output].shape = [1, m, n]
    elif mode == "outer_mismatch":
        plan.tensors[input].shape = [1, m, c]
        plan.tensors[output].shape = [m, 1, n]
    elif mode == "operation":
        op = -1
    elif mode == "kind":
        plan.operations[0].kind = String("add")
    elif mode == "inputs":
        plan.operations[0].inputs.append(input)
    elif mode == "input_id":
        plan.operations[0].inputs[0] = -1
    elif mode == "output_id":
        plan.operations[0].output = 2
    elif mode == "same_id":
        plan.operations[0].output = input
    elif mode == "weight_name":
        plan.operations[0].weight = String("absent")
    elif mode == "consumed":
        plan.used_weights["weights"] = False
    elif mode == "input_product":
        plan.tensors[input].elements += 1
    elif mode == "output_product":
        plan.tensors[output].elements += 1
    elif mode == "input_empty":
        plan.tensors[input].shape = List[Int]()
    elif mode == "output_shape":
        plan.tensors[output].shape = [n, m]
    elif mode == "input_future":
        plan.tensors[input].producer = 0
    elif mode == "input_dead":
        plan.tensors[input].last_use = -1
    elif mode == "output_producer":
        plan.tensors[output].producer = -1
    elif mode == "output_lifetime":
        plan.tensors[output].last_use = 2
    elif mode == "output_owner":
        plan.tensors[output].persistent = True
    elif mode == "output_alias":
        plan.tensors[output].alias_of = input
    elif mode == "binding_columns":
        plan.source.bindings["weights"].columns += 1
    elif mode == "binding_rows":
        plan.source.bindings["weights"].rows += 1
    elif mode == "binding_kind":
        plan.source.bindings["weights"].source_kind = -1
    elif mode == "binding_bytes":
        plan.source.bindings["weights"].byte_count -= 1
    elif mode == "binding_offset":
        plan.source.bindings["weights"].file_offset = 63
    elif mode == "source_extent":
        plan.source.source_bytes -= 1
    elif mode == "data_offset":
        plan.source.data_offset = -1
    elif mode == "width":
        policy.input_width = 0
    elif mode == "weight_width":
        policy.weight_width = 0
    elif mode == "accumulator_width":
        policy.accumulator_width = -1
    elif mode == "alignment":
        policy.alignment = 3
    elif mode == "workspace":
        policy.workspace_bound = 1
    elif mode == "provenance":
        policy.provenance = String("")
    elif mode == "byte_overflow":
        policy.input_width = 9223372036854775807
    elif mode != "accept" and mode != "ownership" and mode != "mutate":
        raise Error("MatrixTiles: unknown test mutation")
    var schedule = plan_matrix_contraction(plan, op, policy)
    if mode == "ownership":
        plan.tensors[input].shape[0] = 999
        plan.source.bindings["weights"].columns = 999
        policy.provenance = String("changed")
    elif mode == "mutate":
        schedule.c += 1
    return schedule^


def main() raises:
    var args = argv()
    if len(args) != 8 and len(args) != 9:
        raise Error("usage: hailo_matrix_tiles_api m n c tm tn tc mutation [selection]")
    var schedule = _schedule(Int(args[1]), Int(args[2]), Int(args[3]), Int(args[4]), Int(args[5]), Int(args[6]), args[7])
    print(describe_matrix_schedule(schedule, args[8] if len(args) == 9 else String("enumerate")))
