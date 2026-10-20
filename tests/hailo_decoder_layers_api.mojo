# Owned configuration, mutable-state and real collection tests. No model math.
from std.sys import argv
from smidr.source_config import SourceConfigPolicy, read_source_config
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers, validate_decoder_layers, decoder_layer_uses_rope
from smidr.tools.decoder_layers import describe_decoder_layers
from smidr.source_root import SourceRootPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import read_unindexed_source_collection, read_indexed_shard_collection, ShardCollectionPolicy
from smidr.tools.program_integrity import _signed


def main() raises:
    var args = argv()
    if len(args) == 5 and (args[1] == "unindexed" or args[1] == "indexed"):
        var root = SourceRootPolicy(4095, 1000, 10000000, 100000000)
        var config = SourceConfigPolicy(1048576, 10000, 10000000, 64)
        var fd = SafetensorsFdPolicy(1048576, 10000, 64, 10000000, 64, 1048584)
        var collection_policy = ShardCollectionPolicy(1000, 10000, 10000000, 100000000, 20000000)
        var policy = DecoderLayerPolicy(4096, 100000, 10000000)
        if args[1] == "unindexed":
            var source = read_unindexed_source_collection(args[2], args[3], args[4], root, config, fd, collection_policy)
            var intent = source_decoder_layers(source.config, policy)
            source.config.fields["num_hidden_layers"] = "999"
            print(describe_decoder_layers(intent))
        else:
            var index = SourceIndexPolicy(1048576, 10000, 10000, 10000000, 64)
            var source = read_indexed_shard_collection(args[2], args[3], args[4], root, index, config, fd, collection_policy)
            var intent = source_decoder_layers(source.config, policy)
            source.config.fields["num_hidden_layers"] = "999"
            print(describe_decoder_layers(intent))
        return
    if len(args) != 6 and len(args) != 7:
        raise Error("usage: hailo_decoder_layers_api config mode layers entries work [query]")
    var source = read_source_config(args[1], SourceConfigPolicy(1048576, 10000, 10000000, 64))
    var policy = DecoderLayerPolicy(_signed(args[3]), _signed(args[4]), _signed(args[5]))
    var intent = source_decoder_layers(source, policy)
    var mode = String(args[2])
    if mode == "cycles":
        var original = source.fields["num_hidden_layers"]
        for _ in range(40):
            source.fields["num_hidden_layers"] = "true"
            var refused = False
            try:
                _ = source_decoder_layers(source, policy)
            except:
                refused = True
            if not refused:
                raise Error("invalid source intent accepted in repeated error cycle")
            source.fields["num_hidden_layers"] = original
            var next = source_decoder_layers(source, policy)
            validate_decoder_layers(next, policy)
        print(describe_decoder_layers(intent))
        return
    if mode == "ownership":
        var other = source_decoder_layers(source, policy)
        var saved = describe_decoder_layers(other)
        source.fields["num_hidden_layers"] = "999"
        if describe_decoder_layers(intent) != saved:
            raise Error("decoder intent borrows input config fields")
        intent.source.fields["custom"] = "null"
        intent.declared_rope_flags.clear()
        intent.rope_enabled[0] = 9
        intent.field_origins["model_type"] = "changed"
        intent.policy.work = 1
        if describe_decoder_layers(other) != saved:
            raise Error("independent decoder intents share owned storage")
        print(saved)
        return
    elif mode == "model":
        intent.model_type = "other"
    elif mode == "layers":
        intent.layer_count += 1
    elif mode == "declared":
        intent.declared_rope_flags[0] = 1 - intent.declared_rope_flags[0]
    elif mode == "tail":
        intent.declared_rope_flags[len(intent.declared_rope_flags) - 1] = 1 - intent.declared_rope_flags[len(intent.declared_rope_flags) - 1]
    elif mode == "effective":
        intent.rope_enabled[0] = 1 - intent.rope_enabled[0]
    elif mode == "effective_length":
        intent.rope_enabled.append(1)
    elif mode == "types":
        intent.layer_types[0] = "changed"
    elif mode == "interval":
        intent.no_rope_layer_interval += 1
    elif mode == "window":
        intent.use_sliding_window = not intent.use_sliding_window
    elif mode == "raw_window":
        intent.window_fields["sliding_window"] = "999"
    elif mode == "origin":
        intent.field_origins["model_type"] = "guessed"
    elif mode == "origin_missing":
        _ = intent.field_origins.pop("model_type")
    elif mode == "notes":
        intent.unresolved.append("fabricated")
    elif mode == "entries":
        intent.entry_count += 1
    elif mode == "work":
        intent.work_units += 1
    elif mode == "owned_policy":
        intent.policy.layers = 0
    elif mode == "external_policy":
        var other = intent.policy.copy()
        other.work += 1
        validate_decoder_layers(intent, other)
    elif mode == "source_layers":
        intent.source.fields["num_hidden_layers"] = "2"
    elif mode == "source_work":
        intent.source.work_units += 1
    elif mode == "source_bytes":
        intent.source.source_bytes = -1
    elif mode == "unknown_malformed":
        intent.source.fields["custom"] = "{"
    elif mode == "unknown_duplicate":
        intent.source.fields["custom"] = "{\"x\":1,\"x\":2}"
    elif mode == "unknown_surrogate":
        intent.source.fields["custom"] = "\"\\ud800\""
    elif mode == "unknown_trailing":
        intent.source.fields["custom"] = "true false"
    elif mode != "accept" and mode != "query":
        raise Error("unknown decoder layer test mutation")
    if mode == "query":
        if len(args) != 7:
            raise Error("query index required")
        _ = decoder_layer_uses_rope(intent, _signed(args[6]))
    print(describe_decoder_layers(intent))
