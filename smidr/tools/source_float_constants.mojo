# Native compiler constant inspector; never a numerical model/device backend.
from std.sys import argv
from smidr.source_float_constants import read_floating_constant_window


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("usage: source_float_constants <source.gguf> <tensor_name> <first> <count>")
    # Diagnostic host allocation cap only; it is not a hardware support limit.
    var window = read_floating_constant_window(args[1], args[2], Int(args[3]), Int(args[4]), 4096)
    var binding = window.binding
    var text = String("{\"schema_version\":1,\"scope\":\"source_floating_constant_window\",\"representation\":\"ieee_binary32_bits\",\"device_weight_format\":false,\"source_fingerprint_verified\":false,\"execution_tested\":false")
    text += ",\"binding\":{\"file_offset\":" + String(binding.file_offset) + ",\"columns\":" + String(binding.columns) + ",\"rows\":" + String(binding.rows)
    text += ",\"source_kind\":" + String(binding.source_kind) + ",\"byte_count\":" + String(binding.byte_count) + "}"
    text += ",\"first\":" + String(window.first) + ",\"host_window_limit\":4096,\"bits\":["
    for i in range(len(window.bits)):
        if i != 0:
            text += ","
        text += String(window.bits[i])
    print(text + "]}")
