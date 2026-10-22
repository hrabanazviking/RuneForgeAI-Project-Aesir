# Bounded observed source inspector; no model execution or device access.
from std.sys import argv
from smidr.sealed_safetensors_source import load_sealed_safetensors
from smidr.tools.source_inventory import _quote


def main() raises:
    var args = argv()
    if len(args) != 11:
        raise Error("usage: sealed_safetensors_source path bytes reads writes digests header tensors rank work depth")
    var owner = load_sealed_safetensors(args[1], Int(args[2]), Int(args[3]), Int(args[4]),
        Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]))
    var text = String("{\"schema_version\":1,\"scope\":\"owned_sealed_safetensors_source\",\"sealed_input_bytes_bound\":true,\"atomic_original_snapshot_verified\":false,\"source_fingerprint_verified\":false,\"immutable_source_verified\":false,\"binding_identity_verified\":false,\"compiled_artifact_identity_verified\":false,\"device_format_verified\":false,\"device_fit_verified\":false,\"device_placement_verified\":false,\"execution_tested\":false,\"device_access\":false,\"source_bytes\":") + String(owner.source_bytes)
    text += ",\"digest_hex\":\"" + owner.digest_hex + "\",\"label\":" + _quote(owner.label)
    text += ",\"data_offset\":" + String(owner.source.header_size + 8) + ",\"tensor_count\":" + String(owner.source.tensor_count()) + "}"
    owner.close()
    print(text)
