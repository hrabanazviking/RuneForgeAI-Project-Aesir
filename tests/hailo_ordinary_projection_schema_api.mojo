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


from smidr.ordinary_projection_schema import bind_ordinary_projection_schema, validate_ordinary_projection_schema
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema


def main() raises:
    var args = argv()
    var policy = DecoderProjectionPolicy(SourceSemanticPolicy(4, 10000, 64, 10000000), 10000000, "qualified projection API test")
    if len(args) == 7 and args[1] == "remote":
        var config = read_source_config(args[2], SourceConfigPolicy(1048576, 10000, 10000000, 64))
        var layers = source_decoder_layers(config, DecoderLayerPolicy(4096, 100000, 10000000))
        var architecture = source_decoder_architecture(layers, DecoderArchitecturePolicy(100000, 10000000))
        var files = List[SourceStorageInventory]()
        files.append(_remote_header(args[3], Int(args[4]), "header0"))
        files.append(_remote_header(args[5], Int(args[6]), "header1"))
        var intent = bind_ordinary_projection_schema(architecture, files, policy)
        print("{\"remote_metadata_only\":true,\"local_model_admitted\":false,\"schema\":" + describe_ordinary_projection_schema(intent) + "}")
        return
    if len(args) != 5:
        raise Error("expected root weight_label config_label test_case")
    var input = _inputs(args[1], args[2], args[3])
    var mode = String(args[4])
    if mode == "input_layer_count":
        input.architecture.layers.layer_count = 9223372036854775807
    elif mode == "input_work":
        policy.work = 1
    elif mode == "input_format":
        input.files[0].source_format = "gguf"
    var intent = bind_ordinary_projection_schema(input.architecture, input.files, policy)
    if mode == "valid":
        print(describe_ordinary_projection_schema(intent))
        return
    if mode == "ownership":
        var other = bind_ordinary_projection_schema(input.architecture, input.files, policy)
        var saved = describe_ordinary_projection_schema(other)
        input.architecture.layers.source.fields.clear()
        input.files[0].metadata.clear()
        input.files[0].tensors[0].source_shape[0] += 1
        input.files.clear()
        policy.provenance = "changed"
        if describe_ordinary_projection_schema(intent) != saved:
            raise Error("schema aliases mutable inputs")
        intent.binding.files[0].metadata.clear()
        intent.binding.files[0].tensors[0].source_shape[0] += 1
        intent.binding.architecture.layers.source.fields.clear()
        intent.binding.source.bindings.clear()
        intent.binding.unresolved.clear()
        intent.head_dim_origin = "changed"
        if describe_ordinary_projection_schema(other) != saved:
            raise Error("independent schemas share mutable owners")
        print(saved)
        return
    if mode == "cycles":
        var original = input.files[0].tensors[0].original_name
        for _ in range(40):
            input.files[0].tensors[0].original_name = "unknown_source_role"
            var refused = False
            try:
                _ = bind_ordinary_projection_schema(input.architecture, input.files, policy)
            except:
                refused = True
            if not refused:
                raise Error("unknown role accepted")
            input.files[0].tensors[0].original_name = original
            var fresh = bind_ordinary_projection_schema(input.architecture, input.files, policy)
            validate_ordinary_projection_schema(fresh, policy)
        print(describe_ordinary_projection_schema(intent))
        return
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
    elif mode == "external_policy":
        policy.work -= 1
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
    elif mode == "old_validator":
        validate_decoder_projections(intent.binding, policy)
    else:
        raise Error("unknown mutation case")
    validate_ordinary_projection_schema(intent, policy)
    print("unexpected schema mutation acceptance")
