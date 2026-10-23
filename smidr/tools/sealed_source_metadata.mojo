# Scoped observed JSON input inspection, never model evaluation or device access.
from std.sys import argv
from smidr.sealed_source_metadata import load_sealed_source_config, load_sealed_source_index
from smidr.source_config import SourceConfigPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.tools.source_config import describe_source_config
from smidr.tools.source_index import describe_source_index
from smidr.tools.source_inventory import _quote


def _description(kind: String, digest: String, label: String, size: Int64, parsed: String) -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"owned_sealed_source_metadata\",\"sealed_metadata_bytes_bound\":true,\"kind\":") + _quote(kind)
    text += ",\"digest_hex\":" + _quote(digest) + ",\"label\":" + _quote(label) + ",\"source_bytes\":" + String(size) + ",\"parsed\":" + parsed
    return text + ",\"atomic_original_snapshot_verified\":false,\"source_fingerprint_verified\":false,\"immutable_source_verified\":false,\"binding_identity_verified\":false,\"compiled_artifact_identity_verified\":false,\"semantic_adapter_verified\":false,\"device_format_verified\":false,\"device_fit_verified\":false,\"device_placement_verified\":false,\"execution_tested\":false,\"device_access\":false}"


def main() raises:
    var args = argv()
    if len(args) == 11 and args[1] == "config":
        var policy = SourceConfigPolicy(Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]))
        var owner = load_sealed_source_config(args[2], Int(args[3]), Int(args[4]), Int(args[5]), Int(args[6]), policy)
        var text = _description("config", owner.digest_hex, owner.label, owner.source.source_bytes, describe_source_config(owner.config))
        owner.close()
        print(text)
    elif len(args) == 12 and args[1] == "index":
        var policy = SourceIndexPolicy(Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]), Int(args[11]))
        var owner = load_sealed_source_index(args[2], Int(args[3]), Int(args[4]), Int(args[5]), Int(args[6]), policy)
        var text = _description("index", owner.digest_hex, owner.label, owner.source.source_bytes, describe_source_index(owner.index))
        owner.close()
        print(text)
    else:
        raise Error("usage: sealed_source_metadata config|index path source_bytes reads writes digests parser_bounds")
