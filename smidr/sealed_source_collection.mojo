# Original owned ordinary collection orchestration; no model computation.
from std.collections import Dict
from hailbru.syscall import os_host_architecture
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy, _require_sealed_source
from smidr.source_metadata_file import _regular_bytes
from smidr.source_root import SourceRootPolicy, SourceModelRoot, SourceRegularFile, open_source_model_root
from smidr.source_config import SourceConfigPolicy, _admit
from smidr.source_index import SourceIndexPolicy, _policy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, _collection_policy, _fd_policy, _charge
from smidr.sealed_source_metadata import SealedSourceConfig, SealedSourceIndex, parse_sealed_source_config, parse_sealed_source_index
from smidr.sealed_safetensors_source import SealedSafetensors, parse_sealed_safetensors, read_sealed_safetensors_constants
from smidr.safetensors_inventory import _project_inventory
from smidr.source_storage import SourceStorageInventory, safetensors_source_storage
from smidr.safetensors_constants import SafetensorsConstantWindow


@fieldwise_init
struct SealedCollectionCopyPolicy(Copyable, Movable):
    var source_bytes: Int
    var reads: Int
    var writes: Int
    var digests: Int


@fieldwise_init
struct SealedCollectionShard(Movable):
    var label: String
    var owner: SealedSafetensors
    var storage: SourceStorageInventory


@fieldwise_init
struct SealedIndexedSourceCollection(Movable):
    var root_path: String
    var config: SealedSourceConfig
    var index: SealedSourceIndex
    var shards: List[SealedCollectionShard]
    var tensor_count: Int
    var metadata_bytes: Int
    var payload_bytes: Int
    var work_units: Int
    var source_bytes: Int

    def close(mut self) raises:
        var error = String("")
        try:
            self.config.close()
        except e:
            error = String(e)
        try:
            self.index.close()
        except e:
            if error == "":
                error = String(e)
        for i in range(len(self.shards)):
            self.shards[i].owner.close()
        if error != "":
            raise Error(error)


@fieldwise_init
struct SealedUnindexedSourceCollection(Movable):
    var root_path: String
    var config: SealedSourceConfig
    var shard: SealedCollectionShard
    var tensor_count: Int
    var metadata_bytes: Int
    var payload_bytes: Int
    var work_units: Int
    var source_bytes: Int

    def close(mut self) raises:
        var error = String("")
        try:
            self.config.close()
        except e:
            error = String(e)
        self.shard.owner.close()
        if error != "":
            raise Error(error)


def _copy_policy(policy: SealedCollectionCopyPolicy) raises:
    if policy.source_bytes <= 0 or policy.reads <= 0 or policy.writes <= 0 or policy.digests <= 0:
        raise Error("SealedCollection: positive aggregate source-byte and per-file call bounds required")


def _seal_file(var file: SourceRegularFile, byte_bound: Int,
        policy: SealedCollectionCopyPolicy) raises -> SealedSourceBytes:
    try:
        if file.arch != os_host_architecture():
            raise Error("SealedCollection: actual host differs from original owner")
        var bytes = seal_source_copy(file.arch, file.fd, file.source_bytes,
            byte_bound, policy.reads, policy.writes, policy.digests)
        file.close()
        return bytes^
    except e:
        # Existing close relinquishes ownership even when it reports a failure.
        # Preserve the original error while still attempting original cleanup.
        try:
            file.close()
        except:
            pass
        raise e


def _open_copy(mut root: SourceModelRoot, label: String, mut used: Int,
        policy: SealedCollectionCopyPolicy, file_byte_bound: Int = 9223372036854775807) raises -> SealedSourceBytes:
    var file = root.open_file(label)
    if file_byte_bound <= 0 or file.source_bytes > Int64(file_byte_bound):
        raise Error("SealedCollection: original metadata extent exceeds byte admission bound")
    var remaining = policy.source_bytes - used
    used = _charge(used, Int(file.source_bytes), policy.source_bytes)
    return _seal_file(file^, remaining, policy)


def _config(mut root: SourceModelRoot, label: String, policy: SourceConfigPolicy,
        byte_cap: Int, mut source_bytes: Int,
        copy: SealedCollectionCopyPolicy) raises -> SealedSourceConfig:
    var capped = policy.copy()
    capped.bytes = min(capped.bytes, byte_cap)
    _ = _admit(capped, 0)
    var bytes = _open_copy(root, label, source_bytes, copy, capped.bytes)
    return parse_sealed_source_config(bytes^, root.source_path + "/" + label, capped, copy.digests)


def _shard(mut root: SourceModelRoot, label: String, policy: SafetensorsFdPolicy,
        tensor_cap: Int, read_cap: Int, mut source_bytes: Int,
        copy: SealedCollectionCopyPolicy) raises -> SealedCollectionShard:
    var tensors = min(policy.tensors, tensor_cap)
    var header = min(policy.header_bytes, min(policy.read_bytes, read_cap) - 8)
    if tensors <= 0 or header <= 0:
        raise Error("SealedCollection: remaining tensor/header read policy exhausted")
    var bytes = _open_copy(root, label, source_bytes, copy)
    var owner = parse_sealed_safetensors(bytes^, root.source_path + "/" + label,
        header, tensors, policy.rank, policy.work, policy.depth, copy.digests)
    var inventory = _project_inventory(owner.source.file_size, owner.source.header_size,
        owner.source.descs, owner.source.metadata)
    var storage = safetensors_source_storage(inventory, owner.label,
        tensors, policy.rank, policy.work)
    return SealedCollectionShard(label, owner^, storage^)


def read_sealed_indexed_source_collection(path: String, index_label: String,
        config_label: String, root_policy: SourceRootPolicy,
        index_policy: SourceIndexPolicy, config_policy: SourceConfigPolicy,
        fd_policy: SafetensorsFdPolicy, policy: ShardCollectionPolicy,
        copy: SealedCollectionCopyPolicy) raises -> SealedIndexedSourceCollection:
    _collection_policy(policy)
    _fd_policy(fd_policy)
    _copy_policy(copy)
    _ = _admit(config_policy, 0)
    _ = _policy(index_policy, 0)
    var root = open_source_model_root(path, root_policy)
    var source_bytes = 0
    var index_cap = index_policy.copy()
    index_cap.bytes = min(index_cap.bytes, min(policy.metadata_bytes, policy.work))
    index_cap.tensors = min(index_cap.tensors, policy.tensors)
    var index_bytes = _open_copy(root, index_label, source_bytes, copy, index_cap.bytes)
    var index = parse_sealed_source_index(index_bytes^, root.source_path + "/" + index_label,
        index_cap, copy.digests)
    var used = _charge(0, index.index.source_bytes, policy.metadata_bytes)
    var work = _charge(0, index.index.source_bytes, policy.work)
    var config = _config(root, config_label, config_policy,
        min(policy.metadata_bytes - used, policy.work - work), source_bytes, copy)
    used = _charge(used, config.config.source_bytes, policy.metadata_bytes)
    work = _charge(work, config.config.source_bytes, policy.work)
    var labels = Dict[String, Bool]()
    var names = Dict[String, Bool]()
    var shards = List[SealedCollectionShard]()
    var payload = 0
    for name in index.index.weight_map:
        work = _charge(work, 1, policy.work)
        var label = index.index.weight_map[name]
        if label in labels:
            continue
        if len(shards) >= policy.shards or len(names) >= policy.tensors:
            raise Error("SealedCollection: aggregate shard/tensor count exceeded")
        labels[label] = True
        work = _charge(work, 1, policy.work)
        var shard = _shard(root, label, fd_policy, policy.tensors - len(names),
            min(policy.metadata_bytes - used, policy.work - work), source_bytes, copy)
        used = _charge(used, shard.storage.data_offset, policy.metadata_bytes)
        work = _charge(work, shard.storage.data_offset, policy.work)
        for tensor in shard.storage.tensors:
            if tensor.original_name in names:
                raise Error("SealedCollection: duplicate global tensor name")
            if tensor.original_name not in index.index.weight_map:
                raise Error("SealedCollection: actual tensor absent from index")
            if index.index.weight_map[tensor.original_name] != label:
                raise Error("SealedCollection: actual tensor belongs to different index label")
            if len(names) >= policy.tensors:
                raise Error("SealedCollection: aggregate tensor count exceeded")
            names[tensor.original_name] = True
            work = _charge(work, 1, policy.work)
            work = _charge(work, len(tensor.source_shape), policy.work)
            payload = _charge(payload, tensor.byte_count, policy.payload_bytes)
        shards.append(shard^)
    if len(names) != len(index.index.weight_map):
        raise Error("SealedCollection: indexed tensor missing from actual shards")
    if index.index.declared_total_size >= 0 and payload != index.index.declared_total_size:
        raise Error("SealedCollection: declared total_size differs from actual payload bytes")
    root.close()
    return SealedIndexedSourceCollection(path, config^, index^, shards^,
        len(names), used, payload, work, source_bytes)


def read_sealed_unindexed_source_collection(path: String, weight_label: String,
        config_label: String, root_policy: SourceRootPolicy,
        config_policy: SourceConfigPolicy, fd_policy: SafetensorsFdPolicy,
        policy: ShardCollectionPolicy,
        copy: SealedCollectionCopyPolicy) raises -> SealedUnindexedSourceCollection:
    _collection_policy(policy)
    _fd_policy(fd_policy)
    _copy_policy(copy)
    _ = _admit(config_policy, 0)
    var root = open_source_model_root(path, root_policy)
    var source_bytes = 0
    var config = _config(root, config_label, config_policy,
        min(policy.metadata_bytes, policy.work), source_bytes, copy)
    var used = _charge(0, config.config.source_bytes, policy.metadata_bytes)
    var work = _charge(0, config.config.source_bytes, policy.work)
    work = _charge(work, 1, policy.work)
    var shard = _shard(root, weight_label, fd_policy, policy.tensors,
        min(policy.metadata_bytes - used, policy.work - work), source_bytes, copy)
    used = _charge(used, shard.storage.data_offset, policy.metadata_bytes)
    work = _charge(work, shard.storage.data_offset, policy.work)
    var payload = 0
    for tensor in shard.storage.tensors:
        work = _charge(work, 1, policy.work)
        work = _charge(work, len(tensor.source_shape), policy.work)
        payload = _charge(payload, tensor.byte_count, policy.payload_bytes)
    var count = len(shard.storage.tensors)
    root.close()
    return SealedUnindexedSourceCollection(path, config^, shard^,
        count, used, payload, work, source_bytes)


def read_sealed_collection_constants(shard: SealedCollectionShard, name: String,
        first: Int, count: Int, element_bound: Int) raises -> SafetensorsConstantWindow:
    # The actual retained mapped owner, never a path or descriptor cache.
    return read_sealed_safetensors_constants(shard.owner, name, first, count, element_bound)


def read_sealed_collection_shard_bytes(shard: SealedCollectionShard,
        byte_bound: Int) raises -> List[UInt8]:
    ref owner = shard.owner
    ref source = owner.source
    if byte_bound <= 0 or owner.source_bytes < 8 or owner.source_bytes > Int64(byte_bound):
        raise Error("SealedCollection: explicit positive shard byte bound exceeded")
    if not source._sealed_route or not source.opened or source.fd < 0 or source.file_size != owner.source_bytes or source._mapping_extent != owner.source_bytes:
        raise Error("SealedCollection: live exact sealed shard mapping required")
    var arch = os_host_architecture()
    _require_sealed_source(arch, Int64(source.fd), owner.source_bytes)
    var data = _regular_bytes(arch, Int64(source.fd), Int(owner.source_bytes), True)
    _require_sealed_source(arch, Int64(source.fd), owner.source_bytes)
    return data^
