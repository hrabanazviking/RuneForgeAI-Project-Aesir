# Static constant inspector; no device or numerical execution.
from std.sys import argv
from smidr.source_q4k_constants import read_q4k_constant_window


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("usage: source_q4k_constants <source.gguf> <tensor_name> <first> <count>")
    var window = read_q4k_constant_window(args[1], args[2], Int(args[3]), Int(args[4]), 4096)
    var binding = window.binding
    var text = String("{\"schema_version\":1,\"scope\":\"source_q4k_constant_window\",\"representation\":\"source_affine_components\",\"device_weight_format\":false,\"source_fingerprint_verified\":false,\"execution_tested\":false")
    text += ",\"binding\":{\"file_offset\":" + String(binding.file_offset) + ",\"columns\":" + String(binding.columns) + ",\"rows\":" + String(binding.rows)
    text += ",\"source_kind\":" + String(binding.source_kind) + ",\"byte_count\":" + String(binding.byte_count) + "}"
    text += ",\"first\":" + String(window.first) + ",\"host_window_limit\":4096,\"components\":["
    for i in range(len(window.components)):
        if i != 0:
            text += ","
        var c = window.components[i]
        text += "{\"d_bits\":" + String(c.d_bits) + ",\"dmin_bits\":" + String(c.dmin_bits)
        text += ",\"d_binary32_bits\":" + String(c.d_binary32_bits) + ",\"dmin_binary32_bits\":" + String(c.dmin_binary32_bits)
        text += ",\"q\":" + String(c.q) + ",\"scale_factor\":" + String(c.scale_factor) + ",\"min_factor\":" + String(c.min_factor) + "}"
    print(text + "]}")
