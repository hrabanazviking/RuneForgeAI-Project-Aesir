# Bounded original source representation inspector. No tensor product or device.
from std.sys import argv
from smidr.source_iq4_constants import IQ4ConstantWindow, read_iq4_constant_window


def describe_iq4(window: IQ4ConstantWindow) -> String:
    var b = window.binding
    var text = String("{\"schema_version\":1,\"execution_tested\":false,\"device_access\":false,\"source_fingerprint_verified\":false,\"device_weight_format_verified\":false,\"source_kind\":") + String(b.source_kind) + ",\"first\":" + String(window.first)
    text += ",\"binding\":[" + String(b.file_offset) + "," + String(b.columns) + "," + String(b.rows) + "," + String(b.source_kind) + "," + String(b.byte_count) + "],\"components\":["
    for i in range(len(window.components)):
        if i != 0:
            text += ","
        var c = window.components[i]
        text += "[" + String(Int(c.d_bits)) + "," + String(Int(c.d_binary32_bits)) + "," + (String("true") if c.group_scale_present else String("false")) + "," + String(Int(c.scale)) + "," + String(Int(c.code)) + "," + String(Int(c.q)) + "]"
    return text + "]}"


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error("usage: source_iq4_constants source name first count host_element_bound")
    var window = read_iq4_constant_window(args[1], args[2], Int(args[3]), Int(args[4]), Int(args[5]))
    print(describe_iq4(window))
