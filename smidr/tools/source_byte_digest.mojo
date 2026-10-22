from std.sys import argv
from smidr.source_byte_digest import SourceByteDigest, read_source_byte_digest_window


def describe_source_digest(window: SourceByteDigest) -> String:
    return String("{\"schema_version\":1,\"scope\":\"observed_source_byte_window_digest\",\"byte_digest_computed\":true,\"source_fingerprint_verified\":false,\"immutable_source_verified\":false,\"binding_identity_verified\":false,\"execution_tested\":false,\"device_access\":false,\"source_bytes\":") + String(window.source_bytes) + ",\"first\":" + String(window.first) + ",\"count\":" + String(window.count) + ",\"read_calls\":" + String(window.read_calls) + ",\"digest_hex\":\"" + window.digest_hex + "\"}"


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error("usage: source_byte_digest source first count read_byte_bound read_call_bound")
    var result = read_source_byte_digest_window(args[1], Int(args[2]), Int(args[3]), Int(args[4]), Int(args[5]))
    print(describe_source_digest(result))
