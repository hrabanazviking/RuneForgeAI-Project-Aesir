# Test-only tagged source mutation, role and ownership checks. No model math.
from std.sys import argv
from smidr.source_root import SourceRootPolicy
from smidr.source_config import SourceConfigPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import read_unindexed_source_collection, read_indexed_shard_collection, ShardCollectionPolicy
from std.collections import Dict
from smidr.source_inventory import (
    SourceTensorInventory, SourceTensorBinding, SourceFileExtent, SourceSemanticPolicy,
    validate_source_inventory, validate_source_weight, append_source_storage,
)
from smidr.source_storage import SourceStorageTensor, SourceStorageInventory
from smidr.tools.semantic_storage import describe_semantic_storage, append_path, append_explicit_prefix
from smidr.semantic_plan import SemanticPlan
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction
from smidr.tools.matrix_tiles import describe_matrix_schedule
from smidr.primitive_recipes import lower_primitive_recipes
from smidr.expanded_graph import expand_semantic_graph
from smidr.expanded_storage import validate_expanded_storage_graph
from smidr.source_weight_tiles import read_source_weight_tile
from loader.packed_gguf import PackedGGUF


def _source() raises -> SourceTensorInventory:
    var source = SourceTensorInventory()
    source.architecture = "explicit synthetic operation graph"
    var aliases = Dict[String, String]()
    aliases["canonical"] = "original\0π"
    var tensors = List[SourceStorageTensor]()
    tensors.append(SourceStorageTensor("safetensors", 0, "original\0π", "one.safe",
        [3, 4], "row_major_outermost_first", 12, 64, 24))
    var file = SourceStorageInventory("safetensors", "one.safe", 88, 64, tensors^, Dict[String, String]())
    append_source_storage(source, file, aliases, "test declaration; no architecture assertion")
    # Mutating input-owned descriptor/map values must not change the result.
    file.tensors[0].source_shape[0] = 999
    aliases["canonical"] = "changed"
    return source^


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("test mode required")
    var mode = String(args[1])
    if mode == "unindexed" or mode == "indexed":
        if len(args) != 5:
            raise Error("expected mode root source-or-index config")
        var root = SourceRootPolicy(4095, 1000, 10000000, 100000000)
        var config = SourceConfigPolicy(1048576, 1000, 10000000, 64)
        var fd = SafetensorsFdPolicy(1048576, 10000, 64, 10000000, 64, 1048584)
        var policy = ShardCollectionPolicy(1000, 10000, 10000000, 100000000, 20000000)
        var output = SourceTensorInventory()
        if mode == "unindexed":
            var collection = read_unindexed_source_collection(args[2], args[3], args[4], root, config, fd, policy)
            append_explicit_prefix(output, collection.shard.storage, "declared/")
        else:
            var index = SourceIndexPolicy(1048576, 10000, 1000, 10000000, 64)
            var collection = read_indexed_shard_collection(args[2], args[3], args[4], root, index, config, fd, policy)
            for i in range(len(collection.shards)):
                append_explicit_prefix(output, collection.shards[i].storage, "declared/")
        print(describe_semantic_storage(output))
        return
    if mode == "view" and (len(args) != 8 or (args[7] != "vector" and args[7] != "matrix")):
        raise Error("explicit complete test source role required")
    var source = _source()
    var name = String("canonical")
    if mode == "view" and len(args) == 8:
        source = SourceTensorInventory()
        append_path(source, args[2], args[3], "")
        validate_source_weight(source, args[4], Int(args[5]), Int(args[6]), args[7] == "vector")
    elif mode == "norm":
        source.storage[name].source_shape = [12]
        source.bindings[name].columns = 12
        source.bindings[name].rows = 1
        var plan = SemanticPlan(source^)
        plan.rms_epsilon = 0.00001
        var input = plan.tensor("input", [2, 12])
        plan.weight(name, 12, 1, True)
        _ = plan.emit("rms_norm", "output", [input], [2, 12], name)
        var recipes = lower_primitive_recipes(plan)
        plan.source.storage[name].source_shape[0] = 99
        plan.source.storage[name].original_name = "changed"
        if recipes.recipes[0].weight_storage.source_format != "safetensors" or recipes.recipes[0].weight_storage.source_shape[0] != 12 or recipes.recipes[0].weight_extent.source_bytes != 88:
            raise Error("recipe failed tagged provenance ownership")
        print("{\"owned_tagged_recipe\":true,\"execution_tested\":false}")
        return
    elif mode == "expanded":
        var plan = SemanticPlan(source^)
        plan.query_tokens = 2
        var tokens = plan.tensor("tokens", [2])
        plan.weight(name, 4, 3)
        var input = plan.emit("embedding_gather", "embedding", [tokens], [2, 4], name)
        plan.logits = plan.emit("linear", "logits", [input], [2, 3], name)
        plan.tensors[plan.logits].last_use = len(plan.operations)
        var graph = expand_semantic_graph(plan^)
        validate_expanded_storage_graph(graph)
        var weight = graph.values[graph.weight_values[name]].copy()
        if len(weight.shape) != 2 or weight.shape[0] != 3 or weight.shape[1] != 4:
            raise Error("expanded graph lost source matrix axes")
        print(describe_semantic_storage(graph.source.source))
        return
    elif mode == "matrix" or mode == "ownership" or mode == "gguf_reader":
        var plan = SemanticPlan(source^)
        var input = plan.tensor("input", [2, 4])
        plan.weight(name, 4, 3)
        _ = plan.emit("linear", "output", [input], [2, 3], name)
        var policy = MatrixTilePolicy(1, 2, 3, 2, 2, 4, 8, 1024, "test explicit storage scenario")
        var schedule = plan_matrix_contraction(plan, 0, policy)
        if mode == "ownership":
            plan.source.storage[name].source_shape[0] = 999
            plan.source.storage[name].original_name = "changed"
            plan.source.files["one.safe"].source_bytes = 999
        if mode == "gguf_reader":
            if len(args) != 3:
                raise Error("actual GGUF test path required")
            var live = PackedGGUF(args[2])
            _ = read_source_weight_tile(live, schedule, 0, 1024)
            raise Error("safetensors schedule unexpectedly entered GGUF source reader")
        var report = describe_matrix_schedule(schedule, "enumerate")
        if schedule.storage.source_format != "safetensors" or schedule.storage.source_kind != 0 or schedule.storage.source_shape[0] != 3 or schedule.storage.original_name != "original\0π" or schedule.source_bytes != 88:
            raise Error("tagged schedule lost namespace/shape/original/file ownership")
        print(report)
        return
    elif mode == "work_exact":
        source.policy.work = 9
    elif mode == "work_short":
        source.policy.work = 8
    elif mode == "alias_missing" or mode == "alias_absent" or mode == "alias_duplicate" or mode == "alias_canonical" or mode == "alias_provenance":
        var tensors = List[SourceStorageTensor]()
        tensors.append(SourceStorageTensor("safetensors", 0, "w", "two.safe", [2, 3], "row_major_outermost_first", 6, 64, 12))
        if mode == "alias_duplicate":
            tensors.append(SourceStorageTensor("safetensors", 0, "other", "two.safe", [2, 3], "row_major_outermost_first", 6, 76, 12))
        var file = SourceStorageInventory("safetensors", "two.safe", 88 if mode == "alias_duplicate" else 76, 64, tensors^, Dict[String, String]())
        var aliases = Dict[String, String]()
        if mode != "alias_missing":
            aliases["canonical" if mode == "alias_canonical" else "second"] = "absent" if mode == "alias_absent" else "w"
        if mode == "alias_duplicate":
            aliases["third"] = "w"
        append_source_storage(source, file, aliases, "" if mode == "alias_provenance" else "explicit test aliases")
    elif mode == "format":
        source.storage[name].source_format = "gguf"
    elif mode == "dtype":
        source.storage[name].source_kind = 2
    elif mode == "projection_kind":
        source.bindings[name].source_kind = 2
    elif mode == "axis_order":
        source.storage[name].axis_order = "gguf_fastest_axis_first"
    elif mode == "axes":
        source.storage[name].source_shape = [4, 3]
    elif mode == "elements":
        source.storage[name].elements += 1
    elif mode == "columns":
        source.bindings[name].columns += 1
    elif mode == "rows":
        source.bindings[name].rows += 1
    elif mode == "offset":
        source.storage[name].file_offset -= 1
    elif mode == "bytes":
        source.storage[name].byte_count -= 1
    elif mode == "file_size":
        source.files["one.safe"].source_bytes -= 1
    elif mode == "data_offset":
        source.files["one.safe"].data_offset = 65
    elif mode == "path":
        source.storage[name].source_path = "absent"
    elif mode == "missing_storage":
        source.storage.clear()
    elif mode == "missing_file":
        source.files.clear()
    elif mode == "summary_size":
        source.source_bytes += 1
    elif mode == "summary_offset":
        source.data_offset = -1
    elif mode == "total":
        source.weight_bytes += 1
    elif mode == "provenance":
        source.alias_provenance = ""
    elif mode == "rank_bound":
        source.policy.rank = 1
    elif mode == "work_bound":
        source.policy.work = 1
    elif mode == "file_bound":
        source.policy.files = 0
    elif mode == "tensor_bound":
        source.policy.tensors = 0
    elif mode == "overflow":
        source.storage[name].source_shape = [9223372036854775807, 3]
    elif mode == "untagged":
        source.storage.clear()
        source.files.clear()
        source.alias_provenance = ""
    elif mode == "duplicate_original" or mode == "overlap":
        source.bindings["second"] = source.bindings[name]
        source.storage["second"] = source.storage[name].copy()
        if mode == "overlap":
            source.storage["second"].original_name = "distinct"
        source.weight_bytes += 24
    elif mode != "accept" and mode != "view":
        raise Error("unknown test mode")
    print(describe_semantic_storage(source))
