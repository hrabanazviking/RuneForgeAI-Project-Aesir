# Real ordinary source metadata -> checked projection intent; no model math.
from std.collections import Dict
from std.sys import argv
from smidr.source_config import SourceConfigPolicy
from smidr.source_root import SourceRootPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, read_unindexed_source_collection, read_indexed_shard_collection
from smidr.source_storage import SourceStorageInventory
from smidr.source_inventory import SourceSemanticPolicy
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers
from smidr.decoder_architecture import DecoderArchitecturePolicy, source_decoder_architecture
from smidr.decoder_projections import DecoderProjectionPolicy, SourceProjectionIntent, bind_decoder_projections, validate_decoder_projections
from smidr.tools.decoder_architecture import describe_decoder_architecture
from smidr.tools.semantic_storage import describe_semantic_storage
from smidr.tools.source_inventory import _quote


def _snapshot(file: SourceStorageInventory) -> SourceStorageInventory:
    # Diagnostic callers use already bounded, root-admitted collections.
    return SourceStorageInventory(file.source_format, file.source_path, file.source_bytes,
        file.data_offset, file.tensors.copy(), file.metadata.copy())


def describe_decoder_projections(intent: SourceProjectionIntent) raises -> String:
    validate_decoder_projections(intent, intent.policy)
    var text = String("{\"schema_version\":1,\"scope\":\"ordinary_projection_binding_intent\",\"complete_architecture_verified\":false,\"source_fingerprint_verified\":false,\"execution_tested\":false,\"device_access\":false,\"key_dim\":") + String(intent.key_dim)
    text += ",\"value_dim\":" + String(intent.value_dim) + ",\"output_weight\":" + _quote(intent.output_weight) + ",\"work_units\":" + String(intent.work_units)
    text += ",\"source\":" + describe_semantic_storage(intent.source) + ",\"architecture\":" + describe_decoder_architecture(intent.architecture) + ",\"file_metadata\":{"
    for i in range(len(intent.files)):
        if i != 0:
            text += ","
        text += _quote(intent.files[i].source_path) + ":{"
        var first = True
        for key in intent.files[i].metadata:
            if not first:
                text += ","
            first = False
            text += _quote(key) + ":" + _quote(intent.files[i].metadata[key])
        text += "}"
    text += "},\"unresolved\":["
    for i in range(len(intent.unresolved)):
        if i != 0:
            text += ","
        text += _quote(intent.unresolved[i])
    return text + "]}"


def main() raises:
    var args = argv()
    if len(args) != 11 or (args[1] != "unindexed" and args[1] != "indexed"):
        raise Error("expected mode root index/weight_label config_label source[files tensors rank work] projection[work provenance]")
    var policy = DecoderProjectionPolicy(SourceSemanticPolicy(Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8])), Int(args[9]), String(args[10]))
    var root_policy = SourceRootPolicy(4095, 1000, 16777216, 9223372036854775807)
    var config_policy = SourceConfigPolicy(1048576, 10000, 10000000, 64)
    var fd_policy = SafetensorsFdPolicy(1048576, policy.source.tensors, policy.source.rank, policy.source.work, 64, 9223372036854775807)
    var collection_policy = ShardCollectionPolicy(policy.source.files, policy.source.tensors, 16777216, 9223372036854775807, 100000000)
    var layer_policy = DecoderLayerPolicy(4096, 100000, 10000000)
    var architecture_policy = DecoderArchitecturePolicy(100000, 10000000)
    if args[1] == "unindexed":
        var collection = read_unindexed_source_collection(args[2], args[3], args[4], root_policy, config_policy, fd_policy, collection_policy)
        var layers = source_decoder_layers(collection.config, layer_policy)
        var architecture = source_decoder_architecture(layers, architecture_policy)
        var files = List[SourceStorageInventory]()
        files.append(_snapshot(collection.shard.storage))
        var intent = bind_decoder_projections(architecture, files, policy)
        print(describe_decoder_projections(intent))
    else:
        var index_policy = SourceIndexPolicy(1048576, policy.source.tensors, 100000, policy.source.work, 64)
        var collection = read_indexed_shard_collection(args[2], args[3], args[4], root_policy, index_policy, config_policy, fd_policy, collection_policy)
        var layers = source_decoder_layers(collection.config, layer_policy)
        var architecture = source_decoder_architecture(layers, architecture_policy)
        var files = List[SourceStorageInventory]()
        for i in range(len(collection.shards)):
            files.append(_snapshot(collection.shards[i].storage))
        var intent = bind_decoder_projections(architecture, files, policy)
        print(describe_decoder_projections(intent))
