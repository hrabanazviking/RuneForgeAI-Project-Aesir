# Diagnostic for copied source weight bytes. No execution or device admission.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction
from smidr.source_weight_tiles import SourceWeightTile, read_source_weight_tile
from smidr.tools.source_inventory import _quote


def describe_source_weight_tile(window: SourceWeightTile) -> String:
    var b = window.binding
    var text = String("{\"schema_version\":1,\"device_access\":false,\"execution_tested\":false,\"source_fingerprint_verified\":false,\"device_weight_packing_verified\":false")
    text += ",\"weight\":" + _quote(window.weight_name) + ",\"binding\":[" + String(b.file_offset) + "," + String(b.columns) + "," + String(b.rows) + "," + String(b.source_kind) + "," + String(b.byte_count) + "]"
    text += ",\"rectangle\":[" + String(window.first_row) + "," + String(window.row_count) + "," + String(window.first_column) + "," + String(window.column_count) + "]"
    text += ",\"spans\":["
    for i in range(len(window.spans)):
        var s = window.spans[i].copy()
        if i != 0:
            text += ","
        text += "[" + String(s.row) + "," + String(s.file_offset) + "," + String(s.byte_count) + "," + String(s.covered_column) + "," + String(s.covered_elements) + "," + String(s.prefix_elements) + "," + String(s.suffix_elements) + "," + String(s.payload_offset) + "]"
    text += "],\"payload\":["
    for i in range(len(window.payload)):
        if i != 0:
            text += ","
        text += String(Int(window.payload[i]))
    return text + "]}"


def main() raises:
    var args = argv()
    if len(args) != 12:
        raise Error("usage: source_weight_tiles source query past capacity operation tile_m tile_n tile_c tile_index workspace_bound host_byte_bound")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    # The inspector's scenario is explicit diagnostic policy. API consumers
    # supply their own precision/workspace policy; no device format is implied.
    var policy = MatrixTilePolicy(Int(args[6]), Int(args[7]), Int(args[8]), 2, 2, 4, 8, Int(args[10]), "source byte inspector scenario")
    var schedule = plan_matrix_contraction(plan, Int(args[5]), policy)
    var source = PackedGGUF(args[1])
    var window = read_source_weight_tile(source, schedule, Int(args[9]), Int(args[11]))
    print(describe_source_weight_tile(window))
