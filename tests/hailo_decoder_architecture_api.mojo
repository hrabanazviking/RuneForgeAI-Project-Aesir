# Test-only parameter snapshots, mutations, real collection cleanup and cycles.
from std.sys import argv
from smidr.source_config import SourceConfigPolicy, read_source_config
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers
from smidr.decoder_architecture import DecoderArchitecturePolicy, source_decoder_architecture, validate_decoder_architecture
from smidr.tools.decoder_architecture import describe_decoder_architecture
from smidr.source_root import SourceRootPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import read_unindexed_source_collection, read_indexed_shard_collection, ShardCollectionPolicy


def main() raises:
    var args = argv()
    var layer_policy = DecoderLayerPolicy(4096, 100000, 10000000)
    var policy = DecoderArchitecturePolicy(100000, 10000000)
    if len(args) == 5 and (args[1] == "unindexed" or args[1] == "indexed"):
        var root = SourceRootPolicy(4095, 1000, 10000000, 100000000)
        var config = SourceConfigPolicy(1048576, 10000, 10000000, 64)
        var fd = SafetensorsFdPolicy(1048576, 10000, 64, 10000000, 64, 1048584)
        var collection_policy = ShardCollectionPolicy(1000, 10000, 10000000, 100000000, 20000000)
        if args[1] == "unindexed":
            var source = read_unindexed_source_collection(args[2], args[3], args[4], root, config, fd, collection_policy)
            var layers = source_decoder_layers(source.config, layer_policy)
            var intent = source_decoder_architecture(layers, policy)
            source.config.fields.clear()
            layers.source.fields.clear()
            print(describe_decoder_architecture(intent))
        else:
            var index = SourceIndexPolicy(1048576, 10000, 10000, 10000000, 64)
            var source = read_indexed_shard_collection(args[2], args[3], args[4], root, index, config, fd, collection_policy)
            var layers = source_decoder_layers(source.config, layer_policy)
            var intent = source_decoder_architecture(layers, policy)
            source.config.fields.clear()
            layers.source.fields.clear()
            print(describe_decoder_architecture(intent))
        return
    if len(args) != 3:
        raise Error("expected config test_case")
    var source = read_source_config(args[1], SourceConfigPolicy(1048576, 10000, 10000000, 64))
    var layers = source_decoder_layers(source, layer_policy)
    var intent = source_decoder_architecture(layers, policy)
    var mode = String(args[2])
    if mode == "ownership":
        var other = source_decoder_architecture(layers, policy)
        var saved = describe_decoder_architecture(other)
        source.fields.clear()
        layers.source.fields.clear()
        layers.rope_enabled.clear()
        if describe_decoder_architecture(intent) != saved:
            raise Error("architecture intent borrows source/layer owner")
        intent.dimensions.clear()
        intent.flags.clear()
        intent.scalars.clear()
        intent.field_origins.clear()
        intent.unresolved.clear()
        intent.layers.source.fields.clear()
        intent.layers.rope_enabled.clear()
        if describe_decoder_architecture(other) != saved:
            raise Error("independent architecture results share mutable storage")
        print(saved)
        return
    if mode == "cycles":
        var original = source.fields["hidden_size"]
        for _ in range(40):
            source.fields["hidden_size"] = "true"
            var invalid_layers = source_decoder_layers(source, layer_policy)
            var refused = False
            try:
                _ = source_decoder_architecture(invalid_layers, policy)
            except:
                refused = True
            if not refused:
                raise Error("invalid architecture scalar accepted in cycle")
            source.fields["hidden_size"] = original
            var valid_layers = source_decoder_layers(source, layer_policy)
            var fresh = source_decoder_architecture(valid_layers, policy)
            validate_decoder_architecture(fresh, policy)
        print(describe_decoder_architecture(intent))
        return
    if mode == "dimension":
        intent.dimensions["hidden_size"] += 1
    elif mode == "dimension_extra":
        intent.dimensions["guessed"] = 1
    elif mode == "dimension_missing":
        _ = intent.dimensions.pop("hidden_size")
    elif mode == "candidate":
        intent.dimensions["head_dim_candidate"] += 1
    elif mode == "flag":
        intent.flags["attention_bias"] = not intent.flags["attention_bias"]
    elif mode == "flag_missing":
        _ = intent.flags.pop("use_cache")
    elif mode == "scalar":
        intent.scalars["rms_norm_eps"] *= 2
    elif mode == "scalar_missing":
        _ = intent.scalars.pop("rope_theta")
    elif mode == "activation":
        intent.activation = "other"
    elif mode == "origin":
        intent.field_origins["hidden_size"] = "guessed"
    elif mode == "origin_missing":
        _ = intent.field_origins.pop("hidden_size")
    elif mode == "notes":
        intent.unresolved.append("guessed")
    elif mode == "entries":
        intent.entry_count += 1
    elif mode == "work":
        intent.work_units += 1
    elif mode == "owned_policy":
        intent.policy.work = 1
    elif mode == "external_policy":
        policy.work -= 1
    elif mode == "layer_mask":
        intent.layers.rope_enabled[0] = 1 - intent.layers.rope_enabled[0]
    elif mode == "source_dimension":
        intent.layers.source.fields["hidden_size"] = "999"
    elif mode == "source_scalar":
        intent.layers.source.fields["rope_theta"] = "true"
    elif mode == "source_accounting":
        intent.layers.source.work_units += 1
    elif mode == "source_unknown_json":
        intent.layers.source.fields["custom"] = "{"
    elif mode == "layer_policy":
        intent.layers.policy.work = 1
    else:
        raise Error("unknown test mutation")
    validate_decoder_architecture(intent, policy)
    print("unexpected architecture acceptance")
