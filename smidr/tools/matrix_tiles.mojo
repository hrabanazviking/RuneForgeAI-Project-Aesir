# Native host schedule inspector, never a device program or numerical runner.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.matrix_tiles import MatrixSchedule, MatrixTilePolicy, matrix_workspace_bytes, matrix_tile_count, matrix_tile, plan_matrix_contraction
from smidr.tools.source_inventory import _quote


def _shape(shape: List[Int]) -> String:
    var text = String("[")
    for i in range(len(shape)):
        if i != 0:
            text += ","
        text += String(shape[i])
    return text + "]"


def describe_matrix_schedule(schedule: MatrixSchedule, selection: String) raises -> String:
    var count = matrix_tile_count(schedule)
    var b = schedule.binding
    var text = String("{\"schema_version\":1,\"device_access\":false,\"execution_tested\":false,\"physical_layout_verified\":false,\"source_fingerprint_verified\":false")
    text += ",\"operation\":" + String(schedule.operation) + ",\"input_tensor\":" + String(schedule.input_tensor) + ",\"output_tensor\":" + String(schedule.output_tensor)
    text += ",\"weight\":" + _quote(schedule.weight_name) + ",\"binding\":[" + String(b.file_offset) + "," + String(b.columns) + "," + String(b.rows) + "," + String(b.source_kind) + "," + String(b.byte_count) + "]"
    text += ",\"input_shape\":" + _shape(schedule.input_shape) + ",\"output_shape\":" + _shape(schedule.output_shape)
    text += ",\"m\":" + String(schedule.m) + ",\"n\":" + String(schedule.n) + ",\"c\":" + String(schedule.c)
    text += ",\"tile_count\":" + String(count) + ",\"workspace_bytes\":" + String(matrix_workspace_bytes(schedule)) + ",\"provenance\":" + _quote(schedule.policy.provenance)
    var start = 0
    var stop = 0
    if selection == "enumerate":
        if count > 4096:
            raise Error("MatrixTiles: diagnostic enumeration bound exceeded")
        stop = count
    elif selection != "summary":
        start = Int(selection)
        _ = matrix_tile(schedule, start)
        stop = start + 1
    text += ",\"tiles\":["
    for index in range(start, stop):
        var tile = matrix_tile(schedule, index)
        if index != start:
            text += ","
        text += "[" + String(tile.row) + "," + String(tile.output) + "," + String(tile.contraction)
        text += "," + String(tile.rows) + "," + String(tile.outputs) + "," + String(tile.contractions)
        text += "," + String(tile.input_element) + "," + String(tile.input_row_stride)
        text += "," + String(tile.weight_element) + "," + String(tile.weight_row_stride)
        text += "," + String(tile.output_element) + "," + String(tile.output_row_stride)
        text += "," + String(Int(tile.initialize_accumulator)) + "," + String(Int(tile.finalize_output)) + "]"
    return text + "]}"


def main() raises:
    var args = argv()
    if len(args) != 15 and len(args) != 16:
        raise Error("usage: matrix_tiles source query past capacity operation tile_m tile_n tile_c input_width weight_width accumulator_width alignment workspace provenance [enumerate|summary|tile_index]")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    var policy = MatrixTilePolicy(Int(args[6]), Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]), Int(args[11]), Int(args[12]), Int(args[13]), args[14])
    var schedule = plan_matrix_contraction(plan, Int(args[5]), policy)
    print(describe_matrix_schedule(schedule, args[15] if len(args) == 16 else String("summary")))
