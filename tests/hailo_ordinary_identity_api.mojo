# Test-only retained source mutations; no tensor/model numerical evaluation.
from std.sys import argv
from smidr.ordinary_tensor_identity import compare_owned_indexed_tensors, compare_owned_unindexed_tensors
from smidr.owned_ordinary_binding import OwnedIndexedOrdinaryBinding, OwnedUnindexedOrdinaryBinding, load_owned_indexed_ordinary, load_owned_unindexed_ordinary
from smidr.tools.owned_ordinary_binding import _binding_policy, _root_policy, _copy_policy
from smidr.tools.ordinary_tensor_identity import describe_comparison
from hailo_owned_ordinary_binding_api import _cache_config, _cache_shard, _damage_schema, _damage_policy, _damage_shard
from hailo_sealed_collection_api import _mutate


def _move_indexed(var context: OwnedIndexedOrdinaryBinding) -> OwnedIndexedOrdinaryBinding:
    return context^


def _move_unindexed(var context: OwnedUnindexedOrdinaryBinding) -> OwnedUnindexedOrdinaryBinding:
    return context^


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) != 51 and len(args) != 46:
        raise Error("test: invalid identity API argument count")
    var indexed = args[1] == "indexed"
    var mode = args[2]
    var policy = _binding_policy(args, 3, indexed)
    var offset = 47 if indexed else 42
    var left = args[offset]
    var right = args[offset+1]
    if mode == "nul_name":
        right = "\0missing"
    var bound = Int(args[offset+2])
    var chunk = Int(args[offset+3])
    if indexed:
        var context = load_owned_indexed_ordinary(args[3], args[4], args[5], _root_policy(args, 3), _copy_policy(args, 30), policy)
        if mode == "move":
            context = _move_indexed(context^)
        elif mode == "cache":
            _cache_config(context.owner.config)
            for i in range(len(context.owner.shards)):
                _cache_shard(context.owner.shards[i])
        elif mode.startswith("schema:"):
            _damage_schema(context.schema, String(mode[byte=7:]))
        elif mode.startswith("policy:"):
            _damage_policy(context.policy, String(mode[byte=7:]))
        elif mode.startswith("external:"):
            _damage_policy(policy, String(mode[byte=9:]))
        elif mode.startswith("shard:"):
            _damage_shard(context.owner.shards[0], String(mode[byte=6:]))
        elif mode.startswith("original:"):
            _mutate(args[3] + "/config.json", String(mode[byte=9:]))
            for i in range(len(context.owner.shards)):
                _mutate(args[3] + "/" + context.owner.shards[i].label, String(mode[byte=9:]))
        elif mode == "closed":
            context.close()
        var result = compare_owned_indexed_tensors(context, left, right, bound, chunk, policy)
        # Output owns descriptions independently of both the result's sources
        # and the caller's mutable schema.
        context.schema.binding.source.storage[left].source_shape[0] += 1
        context.close()
        print(describe_comparison(result))
    else:
        var context = load_owned_unindexed_ordinary(args[3], args[4], args[5], _root_policy(args, 3), _copy_policy(args, 25), policy)
        if mode == "move":
            context = _move_unindexed(context^)
        elif mode == "cache":
            _cache_config(context.owner.config)
            _cache_shard(context.owner.shard)
        elif mode.startswith("schema:"):
            _damage_schema(context.schema, String(mode[byte=7:]))
        elif mode.startswith("policy:"):
            _damage_policy(context.policy, String(mode[byte=7:]))
        elif mode.startswith("external:"):
            _damage_policy(policy, String(mode[byte=9:]))
        elif mode.startswith("shard:"):
            _damage_shard(context.owner.shard, String(mode[byte=6:]))
        elif mode.startswith("original:"):
            _mutate(args[3] + "/config.json", String(mode[byte=9:]))
            _mutate(args[3] + "/" + context.owner.shard.label, String(mode[byte=9:]))
        elif mode == "closed":
            context.close()
        var result = compare_owned_unindexed_tensors(context, left, right, bound, chunk, policy)
        context.schema.binding.source.storage[left].source_shape[0] += 1
        context.close()
        print(describe_comparison(result))
