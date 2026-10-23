# Scoped retained compiler-input inspector. No model/device computation.
from std.sys import argv
from smidr.owned_ordinary_binding import OrdinaryBindingPolicy, load_owned_indexed_ordinary, load_owned_unindexed_ordinary
from smidr.source_root import SourceRootPolicy
from smidr.sealed_source_collection import SealedCollectionCopyPolicy
from smidr.source_config import SourceConfigPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy
from smidr.decoder_layers import DecoderLayerPolicy
from smidr.decoder_architecture import DecoderArchitecturePolicy
from smidr.decoder_projections import DecoderProjectionPolicy
from smidr.source_inventory import SourceSemanticPolicy
from smidr.tools.sealed_source_collection import _indexed, _unindexed, describe_indexed, describe_unindexed
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema


def _binding_policy(args: List[String], base: Int, indexed: Bool) raises -> OrdinaryBindingPolicy:
    var c = base + (12 if indexed else 7)
    var f = base + (16 if indexed else 11)
    var p = base + (22 if indexed else 17)
    var b = base + (31 if indexed else 26)
    var index = SourceIndexPolicy(1048576, 10000, 100000, 10000000, 64)
    if indexed:
        index = SourceIndexPolicy(Int(args[base+7]), Int(args[base+8]), Int(args[base+9]), Int(args[base+10]), Int(args[base+11]))
    return OrdinaryBindingPolicy(
        SourceConfigPolicy(Int(args[c]), Int(args[c+1]), Int(args[c+2]), Int(args[c+3])), index^,
        SafetensorsFdPolicy(Int(args[f]), Int(args[f+1]), Int(args[f+2]), Int(args[f+3]), Int(args[f+4]), Int(args[f+5])),
        ShardCollectionPolicy(Int(args[p]), Int(args[p+1]), Int(args[p+2]), Int(args[p+3]), Int(args[p+4])),
        DecoderLayerPolicy(Int(args[b]), Int(args[b+1]), Int(args[b+2])),
        DecoderArchitecturePolicy(Int(args[b+3]), Int(args[b+4])),
        DecoderProjectionPolicy(SourceSemanticPolicy(Int(args[b+5]), Int(args[b+6]), Int(args[b+7]), Int(args[b+8])), Int(args[b+9]), args[b+10]),
        Int(args[b+11]), Int(args[b+12]))


def _report(collection: String, schema: String) -> String:
    return String("{\"schema_version\":1,\"scope\":\"owned_observed_ordinary_projection_binding\",\"collection\":") + collection + ",\"schema\":" + schema + ",\"atomic_original_snapshot_verified\":false,\"immutable_source_verified\":false,\"compiled_artifact_identity_verified\":false,\"complete_architecture_verified\":false,\"device_format_verified\":false,\"device_fit_verified\":false,\"device_placement_verified\":false,\"execution_tested\":false,\"device_access\":false}"


def _root_policy(args: List[String], base: Int) raises -> SourceRootPolicy:
    return SourceRootPolicy(Int(args[base+3]), Int(args[base+4]), Int(args[base+5]), Int(args[base+6]))


def _copy_policy(args: List[String], base: Int) raises -> SealedCollectionCopyPolicy:
    return SealedCollectionCopyPolicy(Int(args[base]), Int(args[base+1]), Int(args[base+2]), Int(args[base+3]))


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) == 46 and args[1] == "indexed":
        var policy = _binding_policy(args, 2, True)
        var context = load_owned_indexed_ordinary(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 29), policy)
        var text = _report(describe_indexed(context.owner), describe_ordinary_projection_schema(context.schema))
        context.close()
        print(text)
    elif len(args) == 41 and args[1] == "unindexed":
        var policy = _binding_policy(args, 2, False)
        var context = load_owned_unindexed_ordinary(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 24), policy)
        var text = _report(describe_unindexed(context.owner), describe_ordinary_projection_schema(context.schema))
        context.close()
        print(text)
    else:
        raise Error("usage: owned_ordinary_binding indexed|unindexed collection arguments then layer/architecture/projection policies aggregate-hash-bytes per-file-digest-calls")
