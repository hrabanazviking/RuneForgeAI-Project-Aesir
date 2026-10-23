# Original full stored-representation observation. No model or numerical math.
from smidr.source_storage import SourceStorageTensor, source_storage_bytes
from smidr.sealed_source_collection import SealedCollectionShard, read_sealed_collection_constants
from smidr.owned_ordinary_binding import OwnedIndexedOrdinaryBinding, OwnedUnindexedOrdinaryBinding, OrdinaryBindingPolicy
from smidr.owned_ordinary_binding import _same_binding_policy, _refresh_indexed, _refresh_unindexed, _same_schema


@fieldwise_init
struct OrdinaryTensorComparison(Movable):
    var left_name: String
    var right_name: String
    var left: SourceStorageTensor
    var right: SourceStorageTensor
    var elements_per_operand: Int
    var bytes_per_operand: Int
    var raw_elements_read: Int
    var chunks: Int
    var differing_elements: Int
    var first_differing_element: Int
    var all_elements_equal: Bool


def _compatible(left: SourceStorageTensor, right: SourceStorageTensor,
                element_bound: Int, chunk_bound: Int) raises:
    if element_bound <= 0 or chunk_bound <= 0:
        raise Error("OrdinaryTensorIdentity: positive total element and chunk bounds required")
    if left.source_format != "safetensors" or right.source_format != left.source_format or left.source_kind != right.source_kind or left.axis_order != right.axis_order or len(left.source_shape) != len(right.source_shape):
        raise Error("OrdinaryTensorIdentity: different representation comparison unresolved")
    for i in range(len(left.source_shape)):
        if left.source_shape[i] != right.source_shape[i]:
            raise Error("OrdinaryTensorIdentity: different source shape comparison unresolved")
    var bytes = source_storage_bytes(left)
    if bytes != left.byte_count or source_storage_bytes(right) != right.byte_count or bytes != right.byte_count or left.elements != right.elements:
        raise Error("OrdinaryTensorIdentity: inconsistent selected source layout")
    # Charge both complete operands before allocating any component window.
    if left.elements > element_bound // 2:
        raise Error("OrdinaryTensorIdentity: total raw element bound exceeded")


def _compare(left_shard: SealedCollectionShard, right_shard: SealedCollectionShard,
             left_name: String, right_name: String,
             left: SourceStorageTensor, right: SourceStorageTensor,
             element_bound: Int, chunk_bound: Int) raises -> OrdinaryTensorComparison:
    _compatible(left, right, element_bound, chunk_bound)
    var first = 0
    var chunks = 0
    var different = 0
    var earliest = -1
    while first < left.elements:
        var count = min(chunk_bound, left.elements - first)
        var a = read_sealed_collection_constants(left_shard, left.original_name, first, count, chunk_bound)
        var b = read_sealed_collection_constants(right_shard, right.original_name, first, count, chunk_bound)
        for i in range(count):
            if a.raw_words[i] != b.raw_words[i]:
                different += 1
                if earliest < 0:
                    earliest = first + i
        first += count
        chunks += 1
    return OrdinaryTensorComparison(left_name, right_name, left.copy(), right.copy(),
        first, left.byte_count, first * 2, chunks, different, earliest, different == 0)


def compare_owned_indexed_tensors(mut context: OwnedIndexedOrdinaryBinding,
        left_name: String, right_name: String, element_bound: Int,
        chunk_bound: Int, policy: OrdinaryBindingPolicy) raises -> OrdinaryTensorComparison:
    _same_binding_policy(context.policy, policy)
    var actual = _refresh_indexed(context.owner, policy)
    _same_schema(context.schema, actual, policy)
    ref storage = actual.binding.source.storage
    if left_name not in storage or right_name not in storage:
        raise Error("OrdinaryTensorIdentity: canonical source component missing")
    ref left = storage[left_name]
    ref right = storage[right_name]
    var a = -1
    var b = -1
    for i in range(len(context.owner.shards)):
        if context.owner.shards[i].storage.source_path == left.source_path:
            a = i
        if context.owner.shards[i].storage.source_path == right.source_path:
            b = i
    if a < 0 or b < 0:
        raise Error("OrdinaryTensorIdentity: actual retained component shard missing")
    return _compare(context.owner.shards[a], context.owner.shards[b], left_name,
        right_name, left, right, element_bound, chunk_bound)


def compare_owned_unindexed_tensors(mut context: OwnedUnindexedOrdinaryBinding,
        left_name: String, right_name: String, element_bound: Int,
        chunk_bound: Int, policy: OrdinaryBindingPolicy) raises -> OrdinaryTensorComparison:
    _same_binding_policy(context.policy, policy)
    var actual = _refresh_unindexed(context.owner, policy)
    _same_schema(context.schema, actual, policy)
    ref storage = actual.binding.source.storage
    if left_name not in storage or right_name not in storage:
        raise Error("OrdinaryTensorIdentity: canonical source component missing")
    ref left = storage[left_name]
    ref right = storage[right_name]
    if context.owner.shard.storage.source_path != left.source_path or context.owner.shard.storage.source_path != right.source_path:
        raise Error("OrdinaryTensorIdentity: actual retained component shard differs")
    return _compare(context.owner.shard, context.owner.shard, left_name,
        right_name, left, right, element_bound, chunk_bound)
