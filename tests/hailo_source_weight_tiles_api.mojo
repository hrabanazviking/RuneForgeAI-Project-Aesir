# Test-only live source/schedule mutations and returned-copy ownership.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction
from smidr.source_weight_tiles import SourceWeightTile, read_source_weight_tile
from smidr.tools.source_weight_tiles import describe_source_weight_tile


def _window(path: String, mode: String) raises -> SourceWeightTile:
    var plan = read_dense_semantic_plan(path, 1, 0, 16)
    var policy = MatrixTilePolicy(1, 2, 130, 2, 2, 4, 8, 1048576, "synthetic byte-copy scenario")
    var schedule = plan_matrix_contraction(plan, 2, policy)
    var source = PackedGGUF(path)
    var name = schedule.weight_name
    var bound = 1048576
    var index = 0
    if mode == "closed":
        source.source.close()
    elif mode == "live_size":
        source.source.file_size -= 1
    elif mode == "live_data":
        source.data_offset += 1
    elif mode == "live_missing":
        schedule.storage.original_name = String("missing")
    elif mode == "live_offset":
        source.tensors[name].offset += 2
    elif mode == "live_columns":
        source.tensors[name].columns += 1
    elif mode == "live_rows":
        source.tensors[name].rows += 1
    elif mode == "live_kind":
        source.tensors[name].kind = 0
    elif mode == "live_bytes":
        source.tensors[name].byte_count -= 1
    elif mode == "schedule_offset":
        schedule.binding.file_offset += 2
    elif mode == "schedule_columns":
        schedule.binding.columns += 1
    elif mode == "schedule_kind":
        schedule.binding.source_kind = -1
    elif mode == "schedule_bytes":
        schedule.binding.byte_count -= 1
    elif mode == "schedule_shape":
        schedule.input_shape[1] += 1
    elif mode == "schedule_width":
        schedule.policy.input_width = 9223372036854775807
    elif mode == "negative_bound":
        bound = -1
    elif mode == "zero_bound":
        bound = 0
    elif mode == "short_bound":
        bound = 1
    elif mode == "negative_index":
        index = -1
    elif mode == "large_index":
        index = 9223372036854775807
    elif mode != "accept" and mode != "ownership":
        raise Error("SourceWeightTiles: unknown test mutation")
    var window = read_source_weight_tile(source, schedule, index, bound)
    if mode == "ownership":
        source.source.close()
        source.tensors[name].offset = -1
        schedule.weight_name = String("changed")
        schedule.binding.file_offset = -1
    return window^


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: hailo_source_weight_tiles_api source mode")
    var window = _window(args[1], args[2])
    print(describe_source_weight_tile(window))
