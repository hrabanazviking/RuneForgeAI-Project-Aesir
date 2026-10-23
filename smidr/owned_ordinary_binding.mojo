# Original retained ordinary compiler inputs. No model numerical execution.
from std.collections import Dict
from hailbru.syscall import os_host_architecture
from hailbru.source_sealed_copy import _require_sealed_source, read_sealed_source_digest
from hailbru.source_digest import digest_borrowed_regular_window
from smidr.source_config import SourceConfigPolicy, parse_source_config, _admit
from smidr.source_index import SourceIndexPolicy, parse_source_index, _policy
from smidr.source_root import SourceRootPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, _collection_policy, _fd_policy, _charge
from smidr.sealed_source_metadata import SealedSourceConfig, SealedSourceIndex, _validated_extent, read_sealed_metadata_bytes
from smidr.sealed_source_collection import (
    SealedCollectionCopyPolicy, SealedCollectionShard,
    SealedIndexedSourceCollection, SealedUnindexedSourceCollection,
    read_sealed_indexed_source_collection, read_sealed_unindexed_source_collection,
    read_sealed_collection_constants,
)
from smidr.safetensors_inventory import _project_inventory
from smidr.source_storage import SourceStorageInventory, safetensors_source_storage
from smidr.safetensors_constants import SafetensorsConstantWindow
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers, _same_fields, _same_strings
from smidr.decoder_architecture import DecoderArchitecturePolicy, source_decoder_architecture
from smidr.decoder_projections import DecoderProjectionPolicy, _same_policy, _same_source
from smidr.ordinary_projection_schema import OrdinaryProjectionSchema, bind_ordinary_projection_schema, validate_ordinary_projection_schema


@fieldwise_init
struct OrdinaryBindingPolicy(Copyable, Movable):
    var config: SourceConfigPolicy
    var index: SourceIndexPolicy
    var fd: SafetensorsFdPolicy
    var collection: ShardCollectionPolicy
    var layers: DecoderLayerPolicy
    var architecture: DecoderArchitecturePolicy
    var projection: DecoderProjectionPolicy
    var hash_bytes: Int
    var digest_calls: Int


@fieldwise_init
struct OwnedIndexedOrdinaryBinding(Movable):
    var owner: SealedIndexedSourceCollection
    var schema: OrdinaryProjectionSchema
    var policy: OrdinaryBindingPolicy

    def close(mut self) raises:
        self.owner.close()


@fieldwise_init
struct OwnedUnindexedOrdinaryBinding(Movable):
    var owner: SealedUnindexedSourceCollection
    var schema: OrdinaryProjectionSchema
    var policy: OrdinaryBindingPolicy

    def close(mut self) raises:
        self.owner.close()


def _admit_binding(policy: OrdinaryBindingPolicy) raises:
    _collection_policy(policy.collection)
    _fd_policy(policy.fd)
    _ = _admit(policy.config, 0)
    _ = _policy(policy.index, 0)
    if policy.hash_bytes <= 0 or policy.digest_calls <= 0:
        raise Error("OwnedOrdinaryBinding: positive aggregate hash-byte/per-file call bounds required")


def _shard_extent(shard: SealedCollectionShard) raises -> Int:
    ref owner = shard.owner
    ref source = owner.source
    if not source._sealed_route or not source.opened or source.fd < 0 or owner.source_bytes < 8 or source.file_size != owner.source_bytes or source._mapping_extent != owner.source_bytes:
        raise Error("OwnedOrdinaryBinding: live exact sealed mapping required")
    _require_sealed_source(os_host_architecture(), Int64(source.fd), owner.source_bytes)
    return Int(owner.source_bytes)


def _fresh_config(mut owner: SealedSourceConfig, policy: SourceConfigPolicy,
                  calls: Int) raises:
    var size = _validated_extent(owner.source)
    _ = _admit(policy, size)
    var digest = read_sealed_source_digest(owner.source, 0, size, max(1, size), calls)
    var bytes = read_sealed_metadata_bytes(owner.source, policy.bytes)
    var config = parse_source_config(bytes, policy)
    config.source_path = owner.label
    owner.config = config^
    owner.digest_hex = digest.digest_hex
    owner.source.digest_hex = digest.digest_hex


def _fresh_index(mut owner: SealedSourceIndex, policy: SourceIndexPolicy,
                 calls: Int) raises:
    var size = _validated_extent(owner.source)
    _ = _policy(policy, size)
    var digest = read_sealed_source_digest(owner.source, 0, size, max(1, size), calls)
    var bytes = read_sealed_metadata_bytes(owner.source, policy.bytes)
    var index = parse_source_index(bytes, policy)
    index.source_path = owner.label
    owner.index = index^
    owner.digest_hex = digest.digest_hex
    owner.source.digest_hex = digest.digest_hex


def _fresh_shard(mut shard: SealedCollectionShard, policy: SafetensorsFdPolicy,
                 tensors: Int, read_bytes: Int, calls: Int) raises:
    var size = _shard_extent(shard)
    var header = min(policy.header_bytes, min(policy.read_bytes, read_bytes) - 8)
    var count = min(policy.tensors, tensors)
    if header <= 0 or count <= 0:
        raise Error("OwnedOrdinaryBinding: remaining header/tensor policy exhausted")
    var digest = digest_borrowed_regular_window(os_host_architecture(),
        Int64(shard.owner.source.fd), Int64(size), 0, size, size, calls)
    # Reuse the retained mapping and its one existing decoder. Cached limits,
    # descriptions, metadata and claimed hashes do not establish identity.
    ref source = shard.owner.source
    source.header_bound = header
    source.tensor_bound = count
    source.rank_bound = policy.rank
    source.work_bound = policy.work
    source.depth_bound = policy.depth
    source._parse_header()
    var inventory = _project_inventory(source.file_size, source.header_size,
        source.descs, source.metadata)
    shard.storage = safetensors_source_storage(inventory, shard.owner.label,
        count, policy.rank, policy.work)
    shard.owner.digest_hex = digest.digest_hex


def _schema(config: SealedSourceConfig, files: List[SourceStorageInventory],
            policy: OrdinaryBindingPolicy) raises -> OrdinaryProjectionSchema:
    var layers = source_decoder_layers(config.config, policy.layers)
    var architecture = source_decoder_architecture(layers, policy.architecture)
    return bind_ordinary_projection_schema(architecture, files, policy.projection)


def _snapshot(storage: SourceStorageInventory) -> SourceStorageInventory:
    return SourceStorageInventory(storage.source_format, storage.source_path,
        storage.source_bytes, storage.data_offset, storage.tensors.copy(), storage.metadata.copy())


def _refresh_indexed(mut owner: SealedIndexedSourceCollection,
                     policy: OrdinaryBindingPolicy) raises -> OrdinaryProjectionSchema:
    _admit_binding(policy)
    if len(owner.shards) > policy.collection.shards:
        raise Error("OwnedOrdinaryBinding: shard count bound exceeded")
    # Validate and charge ALL actual owners before hashing or parsing any file.
    var total = _charge(0, _validated_extent(owner.index.source), policy.hash_bytes)
    total = _charge(total, _validated_extent(owner.config.source), policy.hash_bytes)
    for i in range(len(owner.shards)):
        total = _charge(total, _shard_extent(owner.shards[i]), policy.hash_bytes)
    var index_policy = policy.index.copy()
    index_policy.bytes = min(index_policy.bytes, min(policy.collection.metadata_bytes, policy.collection.work))
    index_policy.tensors = min(index_policy.tensors, policy.collection.tensors)
    _fresh_index(owner.index, index_policy, policy.digest_calls)
    var used = _charge(0, owner.index.index.source_bytes, policy.collection.metadata_bytes)
    var work = _charge(0, owner.index.index.source_bytes, policy.collection.work)
    var config_policy = policy.config.copy()
    config_policy.bytes = min(config_policy.bytes, min(policy.collection.metadata_bytes - used, policy.collection.work - work))
    _fresh_config(owner.config, config_policy, policy.digest_calls)
    used = _charge(used, owner.config.config.source_bytes, policy.collection.metadata_bytes)
    work = _charge(work, owner.config.config.source_bytes, policy.collection.work)
    var labels = Dict[String, Int]()
    for i in range(len(owner.shards)):
        var label = owner.shards[i].label
        if label in labels:
            raise Error("OwnedOrdinaryBinding: duplicate retained shard label")
        labels[label] = i
    var seen_labels = Dict[String, Bool]()
    var names = Dict[String, Bool]()
    var files = List[SourceStorageInventory]()
    var payload = 0
    for name in owner.index.index.weight_map:
        work = _charge(work, 1, policy.collection.work)
        var label = owner.index.index.weight_map[name]
        if label in seen_labels:
            continue
        if label not in labels or len(names) >= policy.collection.tensors:
            raise Error("OwnedOrdinaryBinding: indexed retained shard missing or tensor bound exceeded")
        seen_labels[label] = True
        work = _charge(work, 1, policy.collection.work)
        ref shard = owner.shards[labels[label]]
        _fresh_shard(shard, policy.fd, policy.collection.tensors - len(names),
            min(policy.collection.metadata_bytes - used, policy.collection.work - work), policy.digest_calls)
        used = _charge(used, shard.storage.data_offset, policy.collection.metadata_bytes)
        work = _charge(work, shard.storage.data_offset, policy.collection.work)
        for tensor in shard.storage.tensors:
            if tensor.original_name in names or tensor.original_name not in owner.index.index.weight_map:
                raise Error("OwnedOrdinaryBinding: duplicate or unindexed actual tensor")
            if owner.index.index.weight_map[tensor.original_name] != label:
                raise Error("OwnedOrdinaryBinding: actual tensor/index label differs")
            if len(names) >= policy.collection.tensors:
                raise Error("OwnedOrdinaryBinding: tensor count bound exceeded")
            names[tensor.original_name] = True
            work = _charge(work, 1, policy.collection.work)
            work = _charge(work, len(tensor.source_shape), policy.collection.work)
            payload = _charge(payload, tensor.byte_count, policy.collection.payload_bytes)
        files.append(_snapshot(shard.storage))
    if len(seen_labels) != len(labels) or len(names) != len(owner.index.index.weight_map):
        raise Error("OwnedOrdinaryBinding: retained collection membership differs")
    if owner.index.index.declared_total_size >= 0 and payload != owner.index.index.declared_total_size:
        raise Error("OwnedOrdinaryBinding: indexed total_size differs from actual payload")
    owner.tensor_count = len(names)
    owner.metadata_bytes = used
    owner.payload_bytes = payload
    owner.work_units = work
    owner.source_bytes = total
    return _schema(owner.config, files, policy)


def _refresh_unindexed(mut owner: SealedUnindexedSourceCollection,
                       policy: OrdinaryBindingPolicy) raises -> OrdinaryProjectionSchema:
    _admit_binding(policy)
    var total = _charge(0, _validated_extent(owner.config.source), policy.hash_bytes)
    total = _charge(total, _shard_extent(owner.shard), policy.hash_bytes)
    var config_policy = policy.config.copy()
    config_policy.bytes = min(config_policy.bytes, min(policy.collection.metadata_bytes, policy.collection.work))
    _fresh_config(owner.config, config_policy, policy.digest_calls)
    var used = _charge(0, owner.config.config.source_bytes, policy.collection.metadata_bytes)
    var work = _charge(0, owner.config.config.source_bytes, policy.collection.work)
    work = _charge(work, 1, policy.collection.work)
    _fresh_shard(owner.shard, policy.fd, policy.collection.tensors,
        min(policy.collection.metadata_bytes - used, policy.collection.work - work), policy.digest_calls)
    used = _charge(used, owner.shard.storage.data_offset, policy.collection.metadata_bytes)
    work = _charge(work, owner.shard.storage.data_offset, policy.collection.work)
    var payload = 0
    for tensor in owner.shard.storage.tensors:
        work = _charge(work, 1, policy.collection.work)
        work = _charge(work, len(tensor.source_shape), policy.collection.work)
        payload = _charge(payload, tensor.byte_count, policy.collection.payload_bytes)
    owner.tensor_count = len(owner.shard.storage.tensors)
    owner.metadata_bytes = used
    owner.payload_bytes = payload
    owner.work_units = work
    owner.source_bytes = total
    var files = List[SourceStorageInventory]()
    files.append(_snapshot(owner.shard.storage))
    return _schema(owner.config, files, policy)


def compile_owned_indexed_ordinary(var owner: SealedIndexedSourceCollection,
                                  policy: OrdinaryBindingPolicy) raises -> OwnedIndexedOrdinaryBinding:
    var schema = _refresh_indexed(owner, policy)
    return OwnedIndexedOrdinaryBinding(owner^, schema^, policy.copy())


def compile_owned_unindexed_ordinary(var owner: SealedUnindexedSourceCollection,
                                    policy: OrdinaryBindingPolicy) raises -> OwnedUnindexedOrdinaryBinding:
    var schema = _refresh_unindexed(owner, policy)
    return OwnedUnindexedOrdinaryBinding(owner^, schema^, policy.copy())


def load_owned_indexed_ordinary(path: String, index_label: String, config_label: String,
        root: SourceRootPolicy, copy: SealedCollectionCopyPolicy,
        policy: OrdinaryBindingPolicy) raises -> OwnedIndexedOrdinaryBinding:
    var owner = read_sealed_indexed_source_collection(path, index_label, config_label,
        root, policy.index, policy.config, policy.fd, policy.collection, copy)
    return compile_owned_indexed_ordinary(owner^, policy)


def load_owned_unindexed_ordinary(path: String, weight_label: String, config_label: String,
        root: SourceRootPolicy, copy: SealedCollectionCopyPolicy,
        policy: OrdinaryBindingPolicy) raises -> OwnedUnindexedOrdinaryBinding:
    var owner = read_sealed_unindexed_source_collection(path, weight_label, config_label,
        root, policy.config, policy.fd, policy.collection, copy)
    return compile_owned_unindexed_ordinary(owner^, policy)


def _same_binding_policy(a: OrdinaryBindingPolicy, b: OrdinaryBindingPolicy) raises:
    _same_policy(a.projection, b.projection)
    if a.config.bytes != b.config.bytes or a.config.fields != b.config.fields or a.config.work != b.config.work or a.config.depth != b.config.depth or a.index.bytes != b.index.bytes or a.index.tensors != b.index.tensors or a.index.fields != b.index.fields or a.index.work != b.index.work or a.index.depth != b.index.depth:
        raise Error("OwnedOrdinaryBinding: metadata policy intent changed")
    if a.fd.header_bytes != b.fd.header_bytes or a.fd.tensors != b.fd.tensors or a.fd.rank != b.fd.rank or a.fd.work != b.fd.work or a.fd.depth != b.fd.depth or a.fd.read_bytes != b.fd.read_bytes or a.collection.shards != b.collection.shards or a.collection.tensors != b.collection.tensors or a.collection.metadata_bytes != b.collection.metadata_bytes or a.collection.payload_bytes != b.collection.payload_bytes or a.collection.work != b.collection.work:
        raise Error("OwnedOrdinaryBinding: source collection policy intent changed")
    if a.layers.layers != b.layers.layers or a.layers.entries != b.layers.entries or a.layers.work != b.layers.work or a.architecture.entries != b.architecture.entries or a.architecture.work != b.architecture.work or a.hash_bytes != b.hash_bytes or a.digest_calls != b.digest_calls:
        raise Error("OwnedOrdinaryBinding: compiler policy intent changed")


def _same_schema(a: OrdinaryProjectionSchema, b: OrdinaryProjectionSchema,
                 policy: OrdinaryBindingPolicy) raises:
    # The existing validator checks every derived layer/architecture/schema and
    # source field. Anchor its raw inputs and explicit policies to fresh bytes.
    ref x = a.binding.architecture.layers
    ref y = b.binding.architecture.layers
    if x.policy.layers != policy.layers.layers or x.policy.entries != policy.layers.entries or x.policy.work != policy.layers.work or a.binding.architecture.policy.entries != policy.architecture.entries or a.binding.architecture.policy.work != policy.architecture.work:
        raise Error("OwnedOrdinaryBinding: interpretation policy intent changed")
    if x.source.source_path != y.source.source_path or x.source.source_bytes != y.source.source_bytes or x.source.work_units != y.source.work_units:
        raise Error("OwnedOrdinaryBinding: config namespace/extent/accounting changed")
    _same_fields(x.source.fields, y.source.fields)
    if len(a.binding.files) != len(b.binding.files):
        raise Error("OwnedOrdinaryBinding: compiler backing count changed")
    for i in range(len(b.binding.files)):
        ref left = a.binding.files[i]
        ref right = b.binding.files[i]
        if left.source_format != right.source_format or left.source_path != right.source_path or left.source_bytes != right.source_bytes or left.data_offset != right.data_offset:
            raise Error("OwnedOrdinaryBinding: compiler backing namespace/extent changed")
        _same_fields(left.metadata, right.metadata)
    _same_source(a.binding.source, b.binding.source)
    validate_ordinary_projection_schema(a, policy.projection)
    if a.head_dim != b.head_dim or a.head_dim_origin != b.head_dim_origin or a.schema_provenance != b.schema_provenance or a.work_units != b.work_units or a.binding.key_dim != b.binding.key_dim or a.binding.value_dim != b.binding.value_dim or a.binding.output_weight != b.binding.output_weight or a.binding.work_units != b.binding.work_units:
        raise Error("OwnedOrdinaryBinding: actual/compiler projection intent differs")
    _same_strings(a.binding.unresolved, b.binding.unresolved)


def read_owned_indexed_component(mut context: OwnedIndexedOrdinaryBinding,
        name: String, first: Int, count: Int, element_bound: Int,
        policy: OrdinaryBindingPolicy) raises -> SafetensorsConstantWindow:
    _same_binding_policy(context.policy, policy)
    var actual = _refresh_indexed(context.owner, policy)
    _same_schema(context.schema, actual, policy)
    if name not in actual.binding.source.storage:
        raise Error("OwnedOrdinaryBinding: canonical source component missing")
    ref tensor = actual.binding.source.storage[name]
    for i in range(len(context.owner.shards)):
        if context.owner.shards[i].storage.source_path == tensor.source_path:
            return read_sealed_collection_constants(context.owner.shards[i], tensor.original_name,
                first, count, element_bound)
    raise Error("OwnedOrdinaryBinding: actual retained component shard missing")


def read_owned_unindexed_component(mut context: OwnedUnindexedOrdinaryBinding,
        name: String, first: Int, count: Int, element_bound: Int,
        policy: OrdinaryBindingPolicy) raises -> SafetensorsConstantWindow:
    _same_binding_policy(context.policy, policy)
    var actual = _refresh_unindexed(context.owner, policy)
    _same_schema(context.schema, actual, policy)
    if name not in actual.binding.source.storage:
        raise Error("OwnedOrdinaryBinding: canonical source component missing")
    ref tensor = actual.binding.source.storage[name]
    if context.owner.shard.storage.source_path != tensor.source_path:
        raise Error("OwnedOrdinaryBinding: actual retained component shard differs")
    return read_sealed_collection_constants(context.owner.shard, tensor.original_name,
        first, count, element_bound)
