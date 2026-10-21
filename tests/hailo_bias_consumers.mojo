# Test-only downstream cache/matrix/storage integration; no inference math.
from std.sys import argv
from hailo_decoder_bias_api import fixture_plan
from smidr.cache_layout import CacheLayoutAssumptions, plan_cache_layout, cache_element_offset
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction, matrix_tile_count
from smidr.storage_estimate import StorageAssumptions, estimate_storage, aligned_bytes
from smidr.tools.source_inventory import _quote


def main() raises:
    var args = argv()
    if len(args) != 8:
        raise Error("expected root weight config attention_mask mlp_mask scalar_mode case")
    var plan = fixture_plan(args[1], args[2], args[3], args[4], args[5], args[6])
    if args[7] == "bypass" or args[7] == "cache_bypass" or args[7] == "storage_bypass" or args[7] == "matrix_bypass":
        for i in range(len(plan.operations)):
            if plan.operations[i].kind == "add_projection_bias":
                var raw = plan.operations[i].inputs[0]
                var biased = plan.operations[i].output
                for j in range(i + 1, len(plan.operations)):
                    for k in range(len(plan.operations[j].inputs)):
                        if plan.operations[j].inputs[k] == biased:
                            plan.operations[j].inputs[k] = raw
                break
    var key_stride = aligned_bytes(plan.kv_heads * plan.key_dim, 2, 16)
    var value_stride = aligned_bytes(plan.kv_heads * plan.value_dim, 2, 16)
    var policy = CacheLayoutAssumptions(2, 2, key_stride, value_stride, 16,
        9223372036854775807, "explicit hypothetical bias cache scenario")
    if args[7] == "storage_bypass":
        _ = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16,
            plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical bias storage"))
        raise Error("unexpected accepted storage bypass")
    if args[7] == "matrix_bypass":
        for i in range(len(plan.operations)):
            if plan.operations[i].kind == "linear":
                _ = plan_matrix_contraction(plan, i,
                    MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical bias matrix schedule"))
                raise Error("unexpected accepted matrix bypass")
    var cache = plan_cache_layout(plan, policy)
    var storage = estimate_storage(plan, StorageAssumptions(2, 2, 8, 16,
        plan.source.weight_bytes, 0, 9223372036854775807, "hypothetical bias storage"))
    var schedules = 0
    var tiles = 0
    for i in range(len(plan.operations)):
        if plan.operations[i].kind == "linear":
            var schedule = plan_matrix_contraction(plan, i,
                MatrixTilePolicy(2, 5, 3, 2, 2, 4, 16, 10000000, "hypothetical bias matrix schedule"))
            schedules += 1
            tiles += matrix_tile_count(schedule)
    var text = String("{\"scope\":\"bias_compiler_consumer_scenarios\",\"device_access\":false,\"regions\":[")
    for i in range(len(cache.regions)):
        if i != 0:
            text += ","
        var region = cache.regions[i].copy()
        var dimension = plan.key_dim if region.kind == "key" else plan.value_dim
        text += "{\"name\":" + _quote(region.name) + ",\"offset\":" + String(region.offset)
        text += ",\"stride\":" + String(region.stride) + ",\"bytes\":" + String(region.byte_count)
        text += ",\"last_element_offset\":" + String(cache_element_offset(cache, i, 7, plan.kv_heads - 1, dimension - 1)) + "}"
    print(text + "],\"cache_bytes\":" + String(cache.total_bytes) + ",\"storage_bytes\":" + String(storage.total_bytes) + ",\"matrix_schedules\":" + String(schedules) + ",\"matrix_tiles\":" + String(tiles) + "}")
