# Read-only source compiler inspection. Does not load or execute a model backend.
from std.sys import argv
from smidr.source_inventory import read_source_inventory


def _quote(value: String) -> String:
    var result = value.replace("\\", "\\\\").replace("\"", "\\\"")
    var digits = String("0123456789abcdef")
    for code in range(32):
        var hi = code // 16
        var lo = code % 16
        var escaped = String("\\u00") + String(digits[byte=hi:hi + 1]) + String(digits[byte=lo:lo + 1])
        result = result.replace(String(chr(code)), escaped)
    return String("\"") + result + String("\"")


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: source_inventory <source.gguf>")
    var inventory = read_source_inventory(args[1])
    var text = String("{\"schema_version\":1,\"scope\":\"source_tensor_inventory\",\"architecture\":") + _quote(inventory.architecture)
    text += ",\"source_bytes\":" + String(inventory.source_bytes) + ",\"data_offset\":" + String(inventory.data_offset)
    text += ",\"weight_bytes\":" + String(inventory.weight_bytes) + ",\"tensor_count\":" + String(len(inventory.bindings))
    text += ",\"execution_tested\":false,\"executable_program\":false,\"source_fingerprint_verified\":false,\"bindings\":{"
    var first = True
    for name in inventory.bindings:
        if not first:
            text += ","
        first = False
        var tensor = inventory.bindings[name]
        text += _quote(name) + ":{\"file_offset\":" + String(tensor.file_offset) + ",\"columns\":" + String(tensor.columns) + ",\"rows\":" + String(tensor.rows) + ",\"source_kind\":" + String(tensor.source_kind) + ",\"byte_count\":" + String(tensor.byte_count) + "}"
    print(text + "}}")
