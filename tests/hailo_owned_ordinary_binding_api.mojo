# Test-only retained input mutations and representation/lifetime checks.
from std.sys import argv
from smidr.owned_ordinary_binding import *
from smidr.owned_ordinary_binding import _same_binding_policy
from smidr.ordinary_projection_schema import OrdinaryProjectionSchema
from smidr.sealed_source_collection import SealedCollectionShard
from smidr.sealed_source_metadata import SealedSourceConfig
from smidr.tools.owned_ordinary_binding import _binding_policy, _report
from smidr.tools.sealed_source_collection import _indexed, _unindexed, describe_indexed, describe_unindexed
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.tools.source_inventory import _quote
from hailo_sealed_safetensors_api import _window
from hailo_sealed_collection_api import _mutate


def _cache_config(mut owner: SealedSourceConfig):
    owner.config.fields.clear()
    owner.config.source_bytes = -1
    owner.config.work_units = -1
    owner.config.source_path = "forged cache"
    owner.digest_hex = "claimed"
    owner.source.digest_hex = "claimed"


def _cache_shard(mut shard: SealedCollectionShard):
    shard.owner.source.descs.clear()
    shard.owner.source.metadata.clear()
    shard.owner.source.header_size = -1
    shard.owner.source.header_bound = -1
    shard.owner.source.tensor_bound = -1
    shard.owner.source.rank_bound = -1
    shard.owner.source.work_bound = -1
    shard.owner.source.depth_bound = -1
    shard.storage.tensors.clear()
    shard.storage.metadata.clear()
    shard.storage.source_bytes = -1
    shard.storage.data_offset = -1
    shard.storage.source_path = "forged cache"
    shard.owner.digest_hex = "claimed"


def _damage_shard(mut shard: SealedCollectionShard, mode: String) raises:
    if mode == "closed":
        shard.owner.close()
    elif mode == "owner_extent":
        shard.owner.source_bytes -= 1
    elif mode == "file_size":
        shard.owner.source.file_size -= 1
    elif mode == "route":
        shard.owner.source._sealed_route = False
    elif mode == "label":
        shard.label = "wrong label"
    elif mode == "namespace":
        shard.owner.label = "wrong namespace"


def _damage_schema(mut intent: OrdinaryProjectionSchema, mode: String) raises:
    if mode == "head_dim":
        intent.head_dim += 1
    elif mode == "head_origin":
        intent.head_dim_origin = "guessed"
    elif mode == "schema_provenance":
        intent.schema_provenance = "guessed"
    elif mode == "schema_work":
        intent.work_units += 1
    elif mode == "key_dim":
        intent.binding.key_dim += 1
    elif mode == "value_dim":
        intent.binding.value_dim += 1
    elif mode == "output":
        intent.binding.output_weight = "guessed"
    elif mode == "notes":
        intent.binding.unresolved.append("guessed")
    elif mode == "work":
        intent.binding.work_units += 1
    elif mode == "owned_policy":
        intent.binding.policy.work -= 1
    elif mode == "source_architecture":
        intent.binding.source.architecture = "other"
    elif mode == "source_provenance":
        intent.binding.source.alias_provenance = "other"
    elif mode == "source_extent":
        intent.binding.source.source_bytes += 1
    elif mode == "source_offset":
        intent.binding.source.data_offset += 1
    elif mode == "source_weight_bytes":
        intent.binding.source.weight_bytes += 1
    elif mode == "source_alias":
        _ = intent.binding.source.bindings.pop("output_norm.weight")
    elif mode == "source_binding":
        intent.binding.source.bindings["token_embd.weight"].rows += 1
    elif mode == "source_kind":
        intent.binding.source.bindings["token_embd.weight"].source_kind = 99
    elif mode == "source_tag":
        intent.binding.source.storage["token_embd.weight"].source_format = "gguf"
    elif mode == "source_shape":
        intent.binding.source.storage["token_embd.weight"].source_shape[0] += 1
    elif mode == "source_name":
        intent.binding.source.storage["token_embd.weight"].original_name = "other"
    elif mode == "source_path":
        intent.binding.source.storage["token_embd.weight"].source_path = "other"
    elif mode == "source_policy":
        intent.binding.source.policy.tensors += 1
    elif mode == "original_name":
        intent.binding.files[0].tensors[0].original_name = "other"
    elif mode == "original_shape":
        intent.binding.files[0].tensors[0].source_shape[0] += 1
    elif mode == "original_offset":
        intent.binding.files[0].tensors[0].file_offset += 1
    elif mode == "original_extent":
        intent.binding.files[0].source_bytes += 1
    elif mode == "original_metadata":
        intent.binding.files[0].metadata["extra"] = "retained"
    elif mode == "original_metadata_count":
        intent.binding.files[0].metadata["extra"] = ""
    elif mode == "architecture":
        intent.binding.architecture.dimensions["hidden_size"] += 1
    elif mode == "layer_mask":
        intent.binding.architecture.layers.rope_enabled[0] = 1 - intent.binding.architecture.layers.rope_enabled[0]
    elif mode == "bias_binding":
        intent.binding.source.bindings["blk.0.attn_q.bias"].columns += 1
    elif mode == "bias_shape":
        intent.binding.source.storage["blk.0.attn_q.bias"].source_shape[0] += 1
    elif mode == "bias_flag":
        intent.binding.architecture.flags["attention_bias"] = False
    elif mode == "source_columns":
        intent.binding.source.bindings["token_embd.weight"].columns += 1
    elif mode == "binding_offset":
        intent.binding.source.bindings["token_embd.weight"].file_offset += 1
    elif mode == "binding_bytes":
        intent.binding.source.bindings["token_embd.weight"].byte_count += 1
    elif mode == "storage_kind":
        intent.binding.source.storage["token_embd.weight"].source_kind = 99
    elif mode == "storage_axes":
        intent.binding.source.storage["token_embd.weight"].axis_order = "other"
    elif mode == "storage_elements":
        intent.binding.source.storage["token_embd.weight"].elements += 1
    elif mode == "storage_offset":
        intent.binding.source.storage["token_embd.weight"].file_offset += 1
    elif mode == "storage_bytes":
        intent.binding.source.storage["token_embd.weight"].byte_count += 1
    elif mode == "file_format":
        intent.binding.source.files[intent.binding.files[0].source_path].source_format = "gguf"
    elif mode == "file_bytes":
        intent.binding.source.files[intent.binding.files[0].source_path].source_bytes += 1
    elif mode == "file_offset":
        intent.binding.source.files[intent.binding.files[0].source_path].data_offset += 1
    elif mode == "config_fields":
        intent.binding.architecture.layers.source.fields["unknown"] = "true"
    elif mode == "config_bytes":
        intent.binding.architecture.layers.source.source_bytes += 1
    elif mode == "config_work":
        intent.binding.architecture.layers.source.work_units += 1
    elif mode == "config_path":
        intent.binding.architecture.layers.source.source_path = "other"
    elif mode == "layer_policy":
        intent.binding.architecture.layers.policy.work += 1
    elif mode == "arch_policy":
        intent.binding.architecture.policy.work += 1
    elif mode == "arch_scalar":
        intent.binding.architecture.scalars["rms_norm_eps"] = 0.5
    elif mode == "arch_origin":
        intent.binding.architecture.field_origins["hidden_size"] = "guessed"
    elif mode == "arch_notes":
        intent.binding.architecture.unresolved.append("guessed")
    elif mode == "arch_work":
        intent.binding.architecture.work_units += 1
    elif mode == "arch_activation":
        intent.binding.architecture.activation = "other"
    elif mode == "layer_origin":
        intent.binding.architecture.layers.field_origins["layer_types"] = "guessed"
    elif mode == "layer_raw":
        intent.binding.architecture.layers.window_fields["other"] = "true"
    elif mode == "layer_type":
        intent.binding.architecture.layers.layer_types.append("other")
    elif mode == "layer_notes":
        intent.binding.architecture.layers.unresolved.append("guessed")
    elif mode == "layer_work":
        intent.binding.architecture.layers.work_units += 1
    elif mode == "original_kind":
        intent.binding.files[0].tensors[0].source_kind = 99
    elif mode == "original_path":
        intent.binding.files[0].tensors[0].source_path = "other"
    elif mode == "original_axes":
        intent.binding.files[0].tensors[0].axis_order = "other"
    elif mode == "original_elements":
        intent.binding.files[0].tensors[0].elements += 1
    elif mode == "original_bytes":
        intent.binding.files[0].tensors[0].byte_count += 1
    elif mode == "original_format":
        intent.binding.files[0].tensors[0].source_format = "gguf"
    else:
        raise Error("test: unknown schema mutation")


def _damage_policy(mut policy: OrdinaryBindingPolicy, mode: String):
    if mode == "config.bytes":
        policy.config.bytes += 1
    elif mode == "config.fields":
        policy.config.fields += 1
    elif mode == "config.work":
        policy.config.work += 1
    elif mode == "config.depth":
        policy.config.depth += 1
    elif mode == "index.bytes":
        policy.index.bytes += 1
    elif mode == "index.tensors":
        policy.index.tensors += 1
    elif mode == "index.fields":
        policy.index.fields += 1
    elif mode == "index.work":
        policy.index.work += 1
    elif mode == "index.depth":
        policy.index.depth += 1
    elif mode == "fd.header_bytes":
        policy.fd.header_bytes += 1
    elif mode == "fd.tensors":
        policy.fd.tensors += 1
    elif mode == "fd.rank":
        policy.fd.rank += 1
    elif mode == "fd.work":
        policy.fd.work += 1
    elif mode == "fd.depth":
        policy.fd.depth += 1
    elif mode == "fd.read_bytes":
        policy.fd.read_bytes += 1
    elif mode == "collection.shards":
        policy.collection.shards += 1
    elif mode == "collection.tensors":
        policy.collection.tensors += 1
    elif mode == "collection.metadata_bytes":
        policy.collection.metadata_bytes += 1
    elif mode == "collection.payload_bytes":
        policy.collection.payload_bytes += 1
    elif mode == "collection.work":
        policy.collection.work += 1
    elif mode == "layers.layers":
        policy.layers.layers += 1
    elif mode == "layers.entries":
        policy.layers.entries += 1
    elif mode == "layers.work":
        policy.layers.work += 1
    elif mode == "architecture.entries":
        policy.architecture.entries += 1
    elif mode == "architecture.work":
        policy.architecture.work += 1
    elif mode == "projection.work":
        policy.projection.work += 1
    elif mode == "projection.source.files":
        policy.projection.source.files += 1
    elif mode == "projection.source.tensors":
        policy.projection.source.tensors += 1
    elif mode == "projection.source.rank":
        policy.projection.source.rank += 1
    elif mode == "projection.source.work":
        policy.projection.source.work += 1
    elif mode == "hash_bytes":
        policy.hash_bytes += 1
    elif mode == "digest_calls":
        policy.digest_calls += 1
    elif mode == "projection.provenance":
        policy.projection.provenance = "changed"


def _move_indexed(var owner: OwnedIndexedOrdinaryBinding) -> OwnedIndexedOrdinaryBinding:
    return owner^


def _run_indexed(args: List[String], mode: String) raises:
    var policy = _binding_policy(args, 3, True)
    var owner = _indexed(args, 3)
    if mode == "pre_cache":
        _cache_config(owner.config)
        owner.source_bytes = -1
        owner.tensor_count = -1
        owner.metadata_bytes = -1
        owner.payload_bytes = -1
        owner.work_units = -1
        owner.index.index.weight_map.clear()
        owner.index.index.metadata.clear()
        owner.index.index.unknown_fields.clear()
        owner.index.index.declared_total_size = -99
        owner.index.index.source_bytes = -1
        owner.index.index.work_units = -1
        owner.index.digest_hex = "claimed"
        for i in range(len(owner.shards)):
            _cache_shard(owner.shards[i])
    if mode.startswith("pre_shard:"):
        _damage_shard(owner.shards[0], String(mode[byte=10:]))
    if mode == "closed_config":
        owner.config.close()
    if mode == "host":
        owner.config.source.arch = "forged"
    if mode == "missing_shard":
        owner.shards.clear()
    if mode == "closed_index":
        owner.index.close()
    if mode == "duplicate_label":
        owner.shards[1].label = owner.shards[0].label
    if mode.startswith("before:"):
        _mutate(owner.config.label, String(mode[byte=7:]))
        _mutate(owner.index.label, String(mode[byte=7:]))
        for i in range(len(owner.shards)):
            _mutate(owner.shards[i].owner.label, String(mode[byte=7:]))
    var context = compile_owned_indexed_ordinary(owner^, policy)
    if mode == "move":
        context = _move_indexed(context^)
    if mode == "post_cache":
        _cache_config(context.owner.config)
        context.owner.index.index.weight_map.clear()
        for i in range(len(context.owner.shards)):
            _cache_shard(context.owner.shards[i])
    if mode.startswith("after:"):
        _mutate(context.owner.config.label, String(mode[byte=6:]))
        _mutate(context.owner.index.label, String(mode[byte=6:]))
        for i in range(len(context.owner.shards)):
            _mutate(context.owner.shards[i].owner.label, String(mode[byte=6:]))
    if mode.startswith("schema:"):
        _damage_schema(context.schema, String(mode[byte=7:]))
    if mode.startswith("policy:"):
        _damage_policy(context.policy, String(mode[byte=7:]))
    if mode.startswith("external:"):
        _damage_policy(policy, String(mode[byte=9:]))
    if mode.startswith("post_shard:"):
        _damage_shard(context.owner.shards[0], String(mode[byte=11:]))
    if mode == "closed":
        context.close()
    if mode == "recover":
        context.schema.head_dim += 1
        var refused = False
        try:
            _ = read_owned_indexed_component(context, "token_embd.weight", 0, 1, 1, policy)
        except:
            refused = True
        context.schema.head_dim -= 1
        if not refused:
            raise Error("test: altered intent accepted")
    var first = -1 if mode == "window_first" else 0
    var count = 9223372036854775807 if mode == "window_count" else 1
    var cap = 0 if mode == "window_bound" else 1
    if mode == "window_empty":
        first = context.schema.binding.source.storage["token_embd.weight"].elements
        count = 0
    elif mode == "window_last":
        first = context.schema.binding.source.storage["token_embd.weight"].elements - 1
    elif mode == "window_zero":
        count = 0
    var name = "missing" if mode == "missing_name" else "token_embd.weight"
    var one = read_owned_indexed_component(context, name, first, count, cap, policy)
    var two = read_owned_indexed_component(context, "token_embd.weight", 0, 1, 1, policy)
    var saved = _window(two)
    var windows = String("[")
    var n = 0
    var names = List[String]()
    for key in context.schema.binding.source.storage:
        names.append(key)
    for key in names:
        var elements = context.schema.binding.source.storage[key].elements
        var window = read_owned_indexed_component(context, key, 0, elements, 131072, policy)
        if n != 0:
            windows += ","
        windows += "{\"canonical\":" + _quote(key) + ",\"window\":" + _window(window) + "}"
        n += 1
    var text = _report(describe_indexed(context.owner), describe_ordinary_projection_schema(context.schema))
    var selected = "{\"canonical\":" + _quote(name) + ",\"window\":" + _window(one) + "}"
    context.close()
    context.close()
    if len(one.raw_words) > 0:
        one.raw_words[0] ^= 1
        one.binary32_words[0] ^= 1
    one.binding.shape[0] += 1
    if _window(two) != saved:
        raise Error("test: copied windows alias or depend on owner")
    print(text)
    print(windows + "]")
    print(selected)


def _move_unindexed(var owner: OwnedUnindexedOrdinaryBinding) -> OwnedUnindexedOrdinaryBinding:
    return owner^


def _run_unindexed(args: List[String], mode: String) raises:
    var policy = _binding_policy(args, 3, False)
    var owner = _unindexed(args, 3)
    if mode == "pre_cache":
        _cache_config(owner.config)
        owner.source_bytes = -1
        owner.tensor_count = -1
        owner.metadata_bytes = -1
        owner.payload_bytes = -1
        owner.work_units = -1
        _cache_shard(owner.shard)
    if mode.startswith("pre_shard:"):
        _damage_shard(owner.shard, String(mode[byte=10:]))
    if mode == "closed_config":
        owner.config.close()
    if mode == "host":
        owner.config.source.arch = "forged"
    if mode.startswith("before:"):
        _mutate(owner.config.label, String(mode[byte=7:]))
        _mutate(owner.shard.owner.label, String(mode[byte=7:]))
    var context = compile_owned_unindexed_ordinary(owner^, policy)
    if mode == "move":
        context = _move_unindexed(context^)
    if mode == "post_cache":
        _cache_config(context.owner.config)
        _cache_shard(context.owner.shard)
    if mode.startswith("after:"):
        _mutate(context.owner.config.label, String(mode[byte=6:]))
        _mutate(context.owner.shard.owner.label, String(mode[byte=6:]))
    if mode.startswith("schema:"):
        _damage_schema(context.schema, String(mode[byte=7:]))
    if mode.startswith("policy:"):
        _damage_policy(context.policy, String(mode[byte=7:]))
    if mode.startswith("external:"):
        _damage_policy(policy, String(mode[byte=9:]))
    if mode.startswith("post_shard:"):
        _damage_shard(context.owner.shard, String(mode[byte=11:]))
    if mode == "closed":
        context.close()
    if mode == "recover":
        context.schema.head_dim += 1
        var refused = False
        try:
            _ = read_owned_unindexed_component(context, "token_embd.weight", 0, 1, 1, policy)
        except:
            refused = True
        context.schema.head_dim -= 1
        if not refused:
            raise Error("test: altered intent accepted")
    var first = -1 if mode == "window_first" else 0
    var count = 9223372036854775807 if mode == "window_count" else 1
    var cap = 0 if mode == "window_bound" else 1
    if mode == "window_empty":
        first = context.schema.binding.source.storage["token_embd.weight"].elements
        count = 0
    elif mode == "window_last":
        first = context.schema.binding.source.storage["token_embd.weight"].elements - 1
    elif mode == "window_zero":
        count = 0
    var name = "missing" if mode == "missing_name" else "token_embd.weight"
    var one = read_owned_unindexed_component(context, name, first, count, cap, policy)
    var two = read_owned_unindexed_component(context, "token_embd.weight", 0, 1, 1, policy)
    var saved = _window(two)
    var windows = String("[")
    var n = 0
    var names = List[String]()
    for key in context.schema.binding.source.storage:
        names.append(key)
    for key in names:
        var elements = context.schema.binding.source.storage[key].elements
        var window = read_owned_unindexed_component(context, key, 0, elements, 131072, policy)
        if n != 0:
            windows += ","
        windows += "{\"canonical\":" + _quote(key) + ",\"window\":" + _window(window) + "}"
        n += 1
    var text = _report(describe_unindexed(context.owner), describe_ordinary_projection_schema(context.schema))
    var selected = "{\"canonical\":" + _quote(name) + ",\"window\":" + _window(one) + "}"
    context.close()
    context.close()
    if len(one.raw_words) > 0:
        one.raw_words[0] ^= 1
        one.binary32_words[0] ^= 1
    one.binding.shape[0] += 1
    if _window(two) != saved:
        raise Error("test: copied windows alias or depend on owner")
    print(text)
    print(windows + "]")
    print(selected)


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) == 47 and args[1] == "indexed":
        _run_indexed(args, args[2])
    elif len(args) == 42 and args[1] == "unindexed":
        _run_unindexed(args, args[2])
    else:
        raise Error("test: expected mode case and explicit collection/compiler arguments")
