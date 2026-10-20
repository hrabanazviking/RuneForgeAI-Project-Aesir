# Actual indexed source files -> checked owned storage, not model execution.
from std.collections import Dict
from smidr.source_root import SourceRootPolicy, SourceModelRoot, open_source_model_root
from smidr.source_metadata_file import read_source_metadata_owned_fd
from smidr.source_index import SourceIndexPolicy, SourceShardIndex, parse_source_index
from smidr.source_config import SourceConfigPolicy, SourceConfiguration, parse_source_config
from smidr.safetensors_fd import SafetensorsFdPolicy, read_safetensors_owned_fd
from smidr.source_storage import SourceStorageInventory, safetensors_source_storage


@fieldwise_init
struct ShardCollectionPolicy(Copyable, Movable):
    var shards: Int
    var tensors: Int
    var metadata_bytes: Int
    var payload_bytes: Int
    var work: Int


@fieldwise_init
struct SourceShardFile(Movable):
    var label: String
    var storage: SourceStorageInventory


@fieldwise_init
struct SourceShardCollection(Movable):
    var root_path: String
    var index: SourceShardIndex
    var config: SourceConfiguration
    var shards: List[SourceShardFile]
    var tensor_count: Int
    var metadata_bytes: Int
    var payload_bytes: Int
    var work_units: Int


def _charge(used: Int, amount: Int, bound: Int) raises -> Int:
    if used < 0 or amount < 0 or used > bound or amount > bound - used:
        raise Error("ShardCollection: aggregate byte/count/work bound exceeded")
    return used + amount


def read_indexed_shard_collection(path: String, index_label: String, config_label: String,
                                  root_policy: SourceRootPolicy, index_policy: SourceIndexPolicy,
                                  config_policy: SourceConfigPolicy, fd_policy: SafetensorsFdPolicy,
                                  policy: ShardCollectionPolicy) raises -> SourceShardCollection:
    _collection_policy(policy)
    _fd_policy(fd_policy)
    if index_policy.bytes <= 0 or index_policy.tensors <= 0 or config_policy.bytes <= 0:
        raise Error("ShardCollection: invalid supplied parser byte/tensor policy")
    var root = open_source_model_root(path, root_policy)
    try:
        var used = 0
        var work = 0
        var index_file = root.open_file(index_label)
        var index_cap = min(index_policy.bytes, min(policy.metadata_bytes, policy.work))
        var index_data = read_source_metadata_owned_fd(index_file.take_fd(), index_cap)
        used = _charge(used, len(index_data), policy.metadata_bytes)
        work = _charge(work, len(index_data), policy.work)
        var capped_index = index_policy.copy()
        capped_index.tensors = min(index_policy.tensors, policy.tensors)
        var index = parse_source_index(index_data, capped_index)
        index.source_path = index_file.source_path
        var config_cap = min(config_policy.bytes, min(policy.metadata_bytes - used, policy.work - work))
        var config = _load_config(root, config_label, config_policy, config_cap)
        used = _charge(used, config.source_bytes, policy.metadata_bytes)
        work = _charge(work, config.source_bytes, policy.work)
        var labels = Dict[String, Bool]()
        var names = Dict[String, Bool]()
        var shards = List[SourceShardFile]()
        var payload = 0
        for name in index.weight_map:
            work = _charge(work, 1, policy.work)
            var label = index.weight_map[name]
            if label in labels:
                continue
            if len(shards) >= policy.shards or len(names) >= policy.tensors:
                raise Error("ShardCollection: aggregate shard/tensor count exceeded")
            work = _charge(work, 1, policy.work)
            labels[label] = True
            var read_cap = min(policy.metadata_bytes - used, policy.work - work)
            var shard = _load_shard(root, label, fd_policy, policy.tensors - len(names), read_cap)
            used = _charge(used, shard.storage.data_offset, policy.metadata_bytes)
            work = _charge(work, shard.storage.data_offset, policy.work)
            for tensor in shard.storage.tensors:
                if tensor.original_name in names:
                    raise Error("ShardCollection: duplicate global tensor name")
                if tensor.original_name not in index.weight_map:
                    raise Error("ShardCollection: actual tensor is absent from index")
                if index.weight_map[tensor.original_name] != label:
                    raise Error("ShardCollection: actual tensor belongs to a different index label")
                if len(names) >= policy.tensors:
                    raise Error("ShardCollection: aggregate tensor count exceeded")
                names[tensor.original_name] = True
                work = _charge(work, 1, policy.work)
                work = _charge(work, len(tensor.source_shape), policy.work)
                payload = _charge(payload, tensor.byte_count, policy.payload_bytes)
            shards.append(shard^)
        if len(names) != len(index.weight_map):
            raise Error("ShardCollection: indexed tensor missing from actual shards")
        if index.declared_total_size >= 0 and payload != index.declared_total_size:
            raise Error("ShardCollection: declared total_size differs from actual payload bytes")
        root.close()
        return SourceShardCollection(path, index^, config^, shards^, len(names), used, payload, work)
    except e:
        root.close()
        raise e


def _collection_policy(policy: ShardCollectionPolicy) raises:
    if policy.shards <= 0 or policy.tensors <= 0 or policy.metadata_bytes <= 0 or policy.payload_bytes <= 0 or policy.work <= 0:
        raise Error("ShardCollection: positive aggregate policies required")


def _fd_policy(policy: SafetensorsFdPolicy) raises:
    if policy.tensors <= 0 or policy.read_bytes <= 0 or policy.header_bytes <= 0 or policy.rank <= 0 or policy.work <= 0 or policy.depth <= 0 or policy.depth > 64:
        raise Error("ShardCollection: invalid supplied fd policy")


def _load_config(mut root: SourceModelRoot, label: String,
                  policy: SourceConfigPolicy, byte_cap: Int) raises -> SourceConfiguration:
    var file = root.open_file(label)
    var data = read_source_metadata_owned_fd(file.take_fd(), byte_cap)
    var result = parse_source_config(data, policy)
    result.source_path = file.source_path
    return result^


def _load_shard(mut root: SourceModelRoot, label: String,
                 policy: SafetensorsFdPolicy, tensor_cap: Int,
                 read_cap: Int) raises -> SourceShardFile:
    var file = root.open_file(label)
    var capped = policy.copy()
    capped.tensors = min(policy.tensors, tensor_cap)
    capped.read_bytes = min(policy.read_bytes, read_cap)
    var inventory = read_safetensors_owned_fd(file.take_fd(), capped)
    var storage = safetensors_source_storage(inventory, file.source_path,
        capped.tensors, policy.rank, policy.work)
    return SourceShardFile(label, storage^)


@fieldwise_init
struct SourceUnindexedCollection(Movable):
    var root_path: String
    var config: SourceConfiguration
    var shard: SourceShardFile
    var tensor_count: Int
    var metadata_bytes: Int
    var payload_bytes: Int
    var work_units: Int


def read_unindexed_source_collection(path: String, weight_label: String, config_label: String,
                                     root_policy: SourceRootPolicy, config_policy: SourceConfigPolicy,
                                     fd_policy: SafetensorsFdPolicy,
                                     policy: ShardCollectionPolicy) raises -> SourceUnindexedCollection:
    _collection_policy(policy)
    _fd_policy(fd_policy)
    if config_policy.bytes <= 0:
        raise Error("ShardCollection: invalid supplied config byte policy")
    var root = open_source_model_root(path, root_policy)
    try:
        var cap = min(config_policy.bytes, min(policy.metadata_bytes, policy.work))
        var config = _load_config(root, config_label, config_policy, cap)
        var used = _charge(0, config.source_bytes, policy.metadata_bytes)
        var work = _charge(0, config.source_bytes, policy.work)
        work = _charge(work, 1, policy.work)
        var read_cap = min(policy.metadata_bytes - used, policy.work - work)
        var shard = _load_shard(root, weight_label, fd_policy, policy.tensors, read_cap)
        used = _charge(used, shard.storage.data_offset, policy.metadata_bytes)
        work = _charge(work, shard.storage.data_offset, policy.work)
        var count = len(shard.storage.tensors)
        var payload = 0
        for tensor in shard.storage.tensors:
            work = _charge(work, 1, policy.work)
            work = _charge(work, len(tensor.source_shape), policy.work)
            payload = _charge(payload, tensor.byte_count, policy.payload_bytes)
        root.close()
        return SourceUnindexedCollection(path, config^, shard^, count, used, payload, work)
    except e:
        root.close()
        raise e
