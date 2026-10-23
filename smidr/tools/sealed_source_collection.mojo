# Scoped ordinary source ownership inspection, never device/model execution.
from std.sys import argv
from smidr.sealed_source_collection import SealedCollectionCopyPolicy, SealedIndexedSourceCollection, SealedUnindexedSourceCollection, read_sealed_indexed_source_collection, read_sealed_unindexed_source_collection
from smidr.source_root import SourceRootPolicy
from smidr.source_config import SourceConfigPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy
from smidr.tools.source_config import describe_source_config
from smidr.tools.source_index import describe_source_index
from smidr.tools.source_storage import describe_source_storage
from smidr.tools.source_inventory import _quote


def _indexed(args: List[String], base: Int) raises -> SealedIndexedSourceCollection:
    var r = SourceRootPolicy(Int(args[base+3]), Int(args[base+4]), Int(args[base+5]), Int(args[base+6]))
    var i = SourceIndexPolicy(Int(args[base+7]), Int(args[base+8]), Int(args[base+9]), Int(args[base+10]), Int(args[base+11]))
    var c = SourceConfigPolicy(Int(args[base+12]), Int(args[base+13]), Int(args[base+14]), Int(args[base+15]))
    var f = SafetensorsFdPolicy(Int(args[base+16]), Int(args[base+17]), Int(args[base+18]), Int(args[base+19]), Int(args[base+20]), Int(args[base+21]))
    var p = ShardCollectionPolicy(Int(args[base+22]), Int(args[base+23]), Int(args[base+24]), Int(args[base+25]), Int(args[base+26]))
    var copy = SealedCollectionCopyPolicy(Int(args[base+27]), Int(args[base+28]), Int(args[base+29]), Int(args[base+30]))
    return read_sealed_indexed_source_collection(args[base], args[base+1], args[base+2], r, i, c, f, p, copy)


def _unindexed(args: List[String], base: Int) raises -> SealedUnindexedSourceCollection:
    var r = SourceRootPolicy(Int(args[base+3]), Int(args[base+4]), Int(args[base+5]), Int(args[base+6]))
    var c = SourceConfigPolicy(Int(args[base+7]), Int(args[base+8]), Int(args[base+9]), Int(args[base+10]))
    var f = SafetensorsFdPolicy(Int(args[base+11]), Int(args[base+12]), Int(args[base+13]), Int(args[base+14]), Int(args[base+15]), Int(args[base+16]))
    var p = ShardCollectionPolicy(Int(args[base+17]), Int(args[base+18]), Int(args[base+19]), Int(args[base+20]), Int(args[base+21]))
    var copy = SealedCollectionCopyPolicy(Int(args[base+22]), Int(args[base+23]), Int(args[base+24]), Int(args[base+25]))
    return read_sealed_unindexed_source_collection(args[base], args[base+1], args[base+2], r, c, f, p, copy)


def _flags() -> String:
    return String(",\"atomic_original_snapshot_verified\":false,\"source_fingerprint_verified\":false,\"immutable_source_verified\":false,\"binding_identity_verified\":false,\"compiled_artifact_identity_verified\":false,\"semantic_adapter_verified\":false,\"device_format_verified\":false,\"device_fit_verified\":false,\"device_placement_verified\":false,\"execution_tested\":false,\"device_access\":false}")


def describe_indexed(owner: SealedIndexedSourceCollection) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"owned_sealed_indexed_source_collection\",\"owned_observed_collection\":true,\"root_path\":") + _quote(owner.root_path)
    text += ",\"index\":" + describe_source_index(owner.index.index) + ",\"config\":" + describe_source_config(owner.config.config) + ",\"shards\":["
    for i in range(len(owner.shards)):
        if i != 0:
            text += ","
        ref shard = owner.shards[i]
        text += "{\"label\":" + _quote(shard.label) + ",\"storage\":" + describe_source_storage(shard.storage) + ",\"digest_hex\":" + _quote(shard.owner.digest_hex) + "}"
    text += "],\"index_digest_hex\":" + _quote(owner.index.digest_hex) + ",\"config_digest_hex\":" + _quote(owner.config.digest_hex)
    text += ",\"tensor_count\":" + String(owner.tensor_count) + ",\"metadata_bytes\":" + String(owner.metadata_bytes) + ",\"payload_bytes\":" + String(owner.payload_bytes) + ",\"work_units\":" + String(owner.work_units) + ",\"source_bytes\":" + String(owner.source_bytes)
    return text + _flags()


def describe_unindexed(owner: SealedUnindexedSourceCollection) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"owned_sealed_unindexed_source_collection\",\"owned_observed_collection\":true,\"root_path\":") + _quote(owner.root_path)
    text += ",\"config\":" + describe_source_config(owner.config.config) + ",\"source\":{\"label\":" + _quote(owner.shard.label) + ",\"storage\":" + describe_source_storage(owner.shard.storage) + ",\"digest_hex\":" + _quote(owner.shard.owner.digest_hex) + "}"
    text += ",\"config_digest_hex\":" + _quote(owner.config.digest_hex)
    text += ",\"tensor_count\":" + String(owner.tensor_count) + ",\"metadata_bytes\":" + String(owner.metadata_bytes) + ",\"payload_bytes\":" + String(owner.payload_bytes) + ",\"work_units\":" + String(owner.work_units) + ",\"source_bytes\":" + String(owner.source_bytes)
    return text + _flags()


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) == 33 and args[1] == "indexed":
        var owner = _indexed(args, 2)
        var text = describe_indexed(owner)
        owner.close()
        print(text)
    elif len(args) == 28 and args[1] == "unindexed":
        var owner = _unindexed(args, 2)
        var text = describe_unindexed(owner)
        owner.close()
        print(text)
    else:
        raise Error("usage: sealed_source_collection indexed|unindexed root labels parser/collection policies source-byte/read/write/digest bounds")
