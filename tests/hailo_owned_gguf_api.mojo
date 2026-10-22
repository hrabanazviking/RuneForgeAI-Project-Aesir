# Test-only ownership/cache/lifetime mutations. No tensor evaluation.
from std.sys import argv
from std.ffi import external_call
from smidr.owned_gguf_compiler import OwnedGGUFCompiler, compile_owned_gguf, load_owned_gguf_compiler, read_owned_gguf_weight_tile, _require_compiler_source
from smidr.sealed_gguf_source import parse_sealed_packed_gguf, load_sealed_packed_gguf
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction, matrix_tile_count
from smidr.source_weight_tiles import read_source_weight_tile
from smidr.tools.source_weight_tiles import describe_source_weight_tile
from smidr.tools.semantic_plan import describe_semantic_plan
from smidr.tools.primitive_recipes import describe_primitive_recipes
from smidr.tools.expanded_graph import describe_expanded_graph
from hailo_sealed_gguf_api import _constants, _snapshot, _copy
from hailbru.syscall import os_openat, os_close_descriptor, O_CLOEXEC


def _move(var context: OwnedGGUFCompiler) -> OwnedGGUFCompiler:
    return context^


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error("usage: hailo_owned_gguf_api mode path query past capacity")
    var mode = String(args[1])
    var path = String(args[2])
    var query = Int(args[3])
    var past = Int(args[4])
    var capacity = Int(args[5])
    if mode == "recovery":
        for stage in range(3):
            var failed = load_sealed_packed_gguf(path, 16777216, 16384, 16384, 16384)
            var refused = False
            try:
                _ = compile_owned_gguf(failed^, 0 if stage == 0 else query, past, capacity, 0 if stage == 1 else 1)
            except:
                refused = True
            if not refused:
                raise Error("test: compiler failure did not refuse")
        var recovered = load_owned_gguf_compiler(path, 16777216, 16384, 16384, 16384, query, past, capacity)
        print(describe_expanded_graph(recovered.graph))
        return
    var owner = load_sealed_packed_gguf(path, 16777216, 16384, 16384, 16384)
    if mode == "truncate" or mode == "replace" or mode == "mutate":
        if mode == "replace":
            if external_call["unlink", Int32](path.unsafe_ptr()) != 0:
                raise Error("test: unlink failed")
            var fd = os_openat("aarch64", path, 2 | 64 | O_CLOEXEC(), 384)
            if fd < 0:
                raise Error("test: replacement open failed")
            _ = os_close_descriptor(fd)
        else:
            var fd = os_openat("aarch64", path, 2 | O_CLOEXEC(), 0)
            if fd < 0:
                raise Error("test: mutation open failed")
            var size = Int64(1) if mode == "truncate" else Int64(0)
            if external_call["ftruncate", Int32](Int32(fd), size) != 0:
                _ = os_close_descriptor(fd)
                raise Error("test: truncate failed")
            _ = os_close_descriptor(fd)
    if mode == "cache":
        owner.digest_hex = String("forged compiler identity")
        owner.source.fields.clear()
        owner.source.fields["forged"] = -1
        owner.source.field_types.clear()
        owner.source.field_types["forged"] = -1
        owner.source.tensors["output.weight"].offset = -1
        owner.source.tensor_shapes.clear()
        owner.source.data_offset = -1
        owner.source.source.version = 0
        owner.source.source.tensor_count = 0
        owner.source.source.kv_count = 0
    elif mode == "owner_closed":
        owner.source.source.close()
    elif mode == "owner_size":
        owner.source_bytes -= 1
    elif mode == "owner_declared":
        owner.source.source.file_size -= 1
    elif mode == "owner_capacity":
        # Restore captured cleanup capacity before consuming refusal.
        var saved = owner.source.source._mapping_extent
        owner.source.source._mapping_extent -= 1
        var refused = False
        try:
            _require_compiler_source(owner)
        except:
            refused = True
        owner.source.source._mapping_extent = saved
        if not refused:
            raise Error("test: mapping capacity admitted")
        print("refused")
        return
    var context = compile_owned_gguf(owner^, query, past, capacity, 0 if mode == "digest_zero" else 1 if mode == "digest_short" else 16384)
    if mode == "move":
        context = _move(context^)
    var policy = MatrixTilePolicy(1, 1, 130, 2, 2, 4, 8, 16777216, "synthetic copied byte scenario")
    var operation = len(context.graph.source.operations) - 1
    var name = context.graph.source.operations[operation].weight
    if mode == "constants":
        _constants(context.owner.source, name)
        return
    if mode == "snapshot":
        _snapshot(context.owner.source)
        return
    if mode == "semantic":
        print(describe_semantic_plan(context.graph.source))
        return
    if mode == "recipes":
        print(describe_primitive_recipes(context.graph.recipes, context.graph.source))
        return
    if mode == "expanded":
        print(describe_expanded_graph(context.graph))
        return
    if mode == "tiles":
        var schedule = plan_matrix_contraction(context.graph.source, operation, policy)
        for i in range(matrix_tile_count(schedule)):
            var tile = read_owned_gguf_weight_tile(context, operation, policy, i, 16777216)
            print(describe_source_weight_tile(tile))
        return
    if mode == "retained":
        var tile = read_owned_gguf_weight_tile(context, operation, policy, 0, 16777216)
        context.close()
        context.close()
        var refused = False
        try:
            _ = read_owned_gguf_weight_tile(context, operation, policy, 0, 16777216)
        except:
            refused = True
        if not refused:
            raise Error("test: closed owner read admitted")
        print(describe_source_weight_tile(tile))
        return
    if mode == "closed":
        context.close()
    elif mode == "source_size":
        context.owner.source.source.file_size -= 1
    elif mode == "source_data":
        context.owner.source.data_offset += 1
    elif mode == "source_binding":
        context.owner.source.tensors[name].offset += 2
    elif mode == "graph_size":
        context.graph.source.source.source_bytes -= 1
    elif mode == "graph_architecture":
        context.graph.source.source.architecture = String("stale")
    elif mode == "graph_binding":
        context.graph.source.source.bindings[name].file_offset += 2
    elif mode == "graph_storage":
        context.graph.source.source.storage[name].original_name = String("stale")
    elif mode == "graph_file":
        context.graph.source.source.files[path].source_bytes -= 1
    elif mode == "graph_operation":
        context.graph.source.operations[operation].weight = String("missing")
    elif mode == "graph_lifetime":
        context.graph.source.tensors[context.graph.source.operations[operation].output].producer = -1
    elif mode == "schedule_binding":
        var schedule = plan_matrix_contraction(context.graph.source, operation, policy)
        schedule.binding.file_offset += 2
        _ = read_source_weight_tile(context.owner.source, schedule, 0, 16777216)
        raise Error("test: stale schedule admitted")
    elif mode == "policy":
        policy.workspace_bound = 1
    if mode == "closed" or mode.startswith("source_") or mode.startswith("graph_") or mode == "policy" or mode == "index" or mode == "bound" or mode == "operation":
        _ = read_owned_gguf_weight_tile(context, -1 if mode == "operation" else operation,
            policy, -1 if mode == "index" else 0, 0 if mode == "bound" else 16777216)
        raise Error("test: stale context or bound admitted")
    print(context.owner.digest_hex)
    print(describe_semantic_plan(context.graph.source))
    print(describe_primitive_recipes(context.graph.recipes, context.graph.source))
    print(describe_expanded_graph(context.graph))
    _constants(context.owner.source, name)
    var tile = read_owned_gguf_weight_tile(context, operation, policy, 0, 16777216)
    print(describe_source_weight_tile(tile))
