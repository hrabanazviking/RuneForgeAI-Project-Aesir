# Bounded sealed-source parser inspection. No model execution or device access.
from std.sys import argv
from smidr.sealed_gguf_source import load_sealed_packed_gguf


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error("usage: sealed_gguf_source path byte_bound read_calls write_calls digest_calls")
    var owned = load_sealed_packed_gguf(args[1], Int(args[2]), Int(args[3]), Int(args[4]), Int(args[5]))
    var text = String("{\"schema_version\":1,\"scope\":\"owned_sealed_gguf_source\",\"sealed_input_bytes_bound\":true,\"atomic_original_snapshot_verified\":false,\"source_fingerprint_verified\":false,\"immutable_source_verified\":false,\"binding_identity_verified\":false,\"execution_tested\":false,\"device_access\":false,\"source_bytes\":") + String(owned.source_bytes)
    text += ",\"digest_hex\":\"" + owned.digest_hex + "\",\"data_offset\":" + String(owned.source.data_offset)
    text += ",\"metadata_count\":" + String(len(owned.source.fields)) + ",\"tensor_count\":" + String(len(owned.source.tensors)) + "}"
    owned.source.source.close()
    print(text)
