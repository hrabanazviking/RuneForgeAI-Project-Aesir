# Test-only projection ownership/refusal/remote-header metadata. No model math.
from std.sys import argv
from std.collections import Dict
from armvegr.safetensors import decode_safetensors_header
from smidr.safetensors_inventory import safetensors_inventory_from_header
from smidr.source_metadata_file import read_source_metadata_bytes
from smidr.source_storage import SourceStorageInventory, safetensors_source_storage
from smidr.source_inventory import SourceSemanticPolicy
from smidr.source_config import SourceConfigPolicy, read_source_config
from smidr.source_root import SourceRootPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, read_unindexed_source_collection
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers
from smidr.decoder_architecture import SourceDecoderArchitecture, DecoderArchitecturePolicy, source_decoder_architecture
from smidr.decoder_projections import DecoderProjectionPolicy, bind_decoder_projections, validate_decoder_projections
from smidr.tools.decoder_projections import _snapshot, describe_decoder_projections


@fieldwise_init
struct _Inputs(Movable):
    var architecture: SourceDecoderArchitecture
    var files: List[SourceStorageInventory]


def _inputs(root: String, weight: String, config: String) raises -> _Inputs:
    var collection = read_unindexed_source_collection(root, weight, config,
        SourceRootPolicy(4095, 1000, 16777216, 9223372036854775807),
        SourceConfigPolicy(1048576, 10000, 10000000, 64),
        SafetensorsFdPolicy(1048576, 10000, 64, 10000000, 64, 9223372036854775807),
        ShardCollectionPolicy(4, 10000, 16777216, 9223372036854775807, 100000000))
    var layers = source_decoder_layers(collection.config, DecoderLayerPolicy(4096, 100000, 10000000))
    var architecture = source_decoder_architecture(layers, DecoderArchitecturePolicy(100000, 10000000))
    var files = List[SourceStorageInventory]()
    files.append(_snapshot(collection.shard.storage))
    return _Inputs(architecture^, files^)


def _remote_header(path: String, total: Int, label: String) raises -> SourceStorageInventory:
    var raw = read_source_metadata_bytes(path, 1048576)
    var data = List[UInt8]()
    for i in range(8):
        data.append(UInt8((len(raw) >> (i * 8)) & 255))
    for byte in raw:
        data.append(byte)
    var header = decode_safetensors_header(data, Int64(total), 1048576, 10000, 64, 10000000, 64)
    var inventory = safetensors_inventory_from_header(header)
    return safetensors_source_storage(inventory, "REMOTE_METADATA_ONLY:" + label, 10000, 64, 10000000)


def main() raises:
    var args = argv()
    var policy = DecoderProjectionPolicy(SourceSemanticPolicy(4, 10000, 64, 10000000), 10000000, "projection API test provenance")
    if len(args) == 7 and args[1] == "remote":
        var config = read_source_config(args[2], SourceConfigPolicy(1048576, 10000, 10000000, 64))
        var layers = source_decoder_layers(config, DecoderLayerPolicy(4096, 100000, 10000000))
        var architecture = source_decoder_architecture(layers, DecoderArchitecturePolicy(100000, 10000000))
        var files = List[SourceStorageInventory]()
        files.append(_remote_header(args[3], Int(args[4]), "header0"))
        files.append(_remote_header(args[5], Int(args[6]), "header1"))
        var intent = bind_decoder_projections(architecture, files, policy)
        print("{\"remote_metadata_only\":true,\"local_model_admitted\":false,\"binding\":" + describe_decoder_projections(intent) + "}")
        return
    if len(args) != 5:
        raise Error("expected root weight_label config_label test_case")
    var input = _inputs(args[1], args[2], args[3])
    var mode = String(args[4])
    if mode == "input_duplicate":
        var duplicate = _snapshot(input.files[0])
        duplicate.source_path = "SYNTHETIC_DUPLICATE_METADATA_ONLY"
        for i in range(len(duplicate.tensors)):
            duplicate.tensors[i].source_path = duplicate.source_path
        input.files.append(duplicate^)
    elif mode == "input_layer_count":
        input.architecture.layers.layer_count = 9223372036854775807
    elif mode == "input_format":
        input.files[0].source_format = "gguf"
    elif mode == "input_kind":
        input.files[0].tensors[0].source_kind = 99
    elif mode == "input_policy_work":
        policy.work = 1
    elif mode == "input_metadata":
        input.files[0].metadata["unbounded"] = ""  # Entry must still be charged.
        var initial = bind_decoder_projections(input.architecture, input.files, policy)
        policy.work = initial.work_units - 1
    var intent = bind_decoder_projections(input.architecture, input.files, policy)
    if mode == "ownership":
        var other = bind_decoder_projections(input.architecture, input.files, policy)
        var saved = describe_decoder_projections(other)
        input.architecture.layers.source.fields.clear()
        input.files[0].metadata.clear()
        input.files[0].tensors[0].source_shape[0] += 1
        input.files.clear()
        policy.provenance = "changed"
        if describe_decoder_projections(intent) != saved:
            raise Error("projection result aliases mutable inputs")
        intent.files[0].metadata.clear()
        intent.files[0].tensors[0].source_shape[0] += 1
        intent.architecture.layers.source.fields.clear()
        intent.source.storage["token_embd.weight"].source_shape[0] += 1
        intent.source.bindings.clear()
        intent.unresolved.clear()
        if describe_decoder_projections(other) != saved:
            raise Error("independent projection results share storage")
        print(saved)
        return
    if mode == "cycles":
        var original = input.files[0].tensors[0].original_name
        for _ in range(40):
            input.files[0].tensors[0].original_name = "unknown_source_role"
            var refused = False
            try:
                _ = bind_decoder_projections(input.architecture, input.files, policy)
            except:
                refused = True
            if not refused:
                raise Error("unknown role accepted in error cycle")
            input.files[0].tensors[0].original_name = original
            var fresh = bind_decoder_projections(input.architecture, input.files, policy)
            validate_decoder_projections(fresh, policy)
        print(describe_decoder_projections(intent))
        return
    if mode == "key_dim":
        intent.key_dim += 1
    elif mode == "value_dim":
        intent.value_dim += 1
    elif mode == "output":
        intent.output_weight = "guessed"
    elif mode == "notes":
        intent.unresolved.append("guessed")
    elif mode == "work":
        intent.work_units += 1
    elif mode == "owned_policy":
        intent.policy.work -= 1
    elif mode == "external_policy":
        policy.work -= 1
    elif mode == "source_architecture":
        intent.source.architecture = "other"
    elif mode == "source_provenance":
        intent.source.alias_provenance = "guessed"
    elif mode == "source_extent":
        intent.source.source_bytes += 1
    elif mode == "source_offset":
        intent.source.data_offset += 1
    elif mode == "source_weight_bytes":
        intent.source.weight_bytes += 1
    elif mode == "source_alias":
        _ = intent.source.bindings.pop("output_norm.weight")
    elif mode == "source_binding":
        intent.source.bindings["token_embd.weight"].rows += 1
    elif mode == "source_kind":
        intent.source.bindings["token_embd.weight"].source_kind = 2
    elif mode == "source_tag":
        intent.source.storage["token_embd.weight"].source_format = "gguf"
    elif mode == "source_shape":
        intent.source.storage["token_embd.weight"].source_shape[0] += 1
    elif mode == "source_name":
        intent.source.storage["token_embd.weight"].original_name = "other"
    elif mode == "source_path":
        intent.source.storage["token_embd.weight"].source_path = "other"
    elif mode == "source_policy":
        intent.source.policy.tensors += 1
    elif mode == "original_name":
        intent.files[0].tensors[0].original_name = "other"
    elif mode == "original_shape":
        intent.files[0].tensors[0].source_shape[0] += 1
    elif mode == "original_offset":
        intent.files[0].tensors[0].file_offset += 1
    elif mode == "original_extent":
        intent.files[0].source_bytes += 1
    elif mode == "original_metadata":
        intent.files[0].metadata["extra"] = "retained"
    elif mode == "original_metadata_count":
        intent.files[0].metadata["extra"] = ""
    elif mode == "architecture":
        intent.architecture.dimensions["hidden_size"] += 1
    elif mode == "layer_mask":
        intent.architecture.layers.rope_enabled[0] = 1 - intent.architecture.layers.rope_enabled[0]
    else:
        raise Error("unknown mutation case")
    validate_decoder_projections(intent, policy)
    print("unexpected projection mutation acceptance")
