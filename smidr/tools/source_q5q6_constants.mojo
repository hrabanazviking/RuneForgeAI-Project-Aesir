# Bounded static source representation inspector; no device or model math.
from std.sys import argv
from smidr.source_q5q6_constants import Q5KConstantWindow, Q6KConstantWindow, read_q5k_constant_window, read_q6k_constant_window
from smidr.source_inventory import SourceTensorBinding


def _prefix(binding: SourceTensorBinding, first: Int, kind: Int) -> String:
    var b = binding
    return String("{\"schema_version\":1,\"execution_tested\":false,\"device_access\":false,\"source_fingerprint_verified\":false,\"device_weight_format_verified\":false,\"source_kind\":") + String(kind) + ",\"first\":" + String(first) + ",\"binding\":[" + String(b.file_offset) + "," + String(b.columns) + "," + String(b.rows) + "," + String(b.source_kind) + "," + String(b.byte_count) + "],\"components\":["


def describe_q5k(window: Q5KConstantWindow) -> String:
    var text = _prefix(window.binding, window.first, 13)
    for i in range(len(window.components)):
        var c = window.components[i]
        if i != 0:
            text += ","
        text += "[" + String(Int(c.d_bits)) + "," + String(Int(c.dmin_bits)) + "," + String(Int(c.d_binary32_bits)) + "," + String(Int(c.dmin_binary32_bits)) + "," + String(Int(c.q)) + "," + String(Int(c.scale_factor)) + "," + String(Int(c.min_factor)) + "]"
    return text + "]}"


def describe_q6k(window: Q6KConstantWindow) -> String:
    var text = _prefix(window.binding, window.first, 14)
    for i in range(len(window.components)):
        var c = window.components[i]
        if i != 0:
            text += ","
        text += "[" + String(Int(c.d_bits)) + "," + String(Int(c.d_binary32_bits)) + "," + String(Int(c.q)) + "," + String(Int(c.scale_factor)) + "]"
    return text + "]}"


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error("usage: source_q5q6_constants source weight first count source_kind")
    var kind = Int(args[5])
    if kind == 13:
        var window = read_q5k_constant_window(args[1], args[2], Int(args[3]), Int(args[4]), 4096)
        print(describe_q5k(window))
    elif kind == 14:
        var window = read_q6k_constant_window(args[1], args[2], Int(args[3]), Int(args[4]), 4096)
        print(describe_q6k(window))
    else:
        raise Error("SourceKConstants: source kind decoder not implemented by this inspector")
