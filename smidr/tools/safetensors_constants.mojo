# Synthetic source-window inspector; no device or model evaluation.
from std.sys import argv
from smidr.safetensors_constants import read_safetensors_constant_window
from smidr.tools.program_integrity import _integer, _signed, _hex
from smidr.tools.safetensors_inventory import _string_hex
from hailbru.errors import herror


def main() raises:
    var args = argv()
    if len(args) != 11:
        raise herror("BadArgs", "expected path/name-hex/first/count/element/header/tensor/rank/work/depth")
    var count = _signed(args[4])
    if count > 131072:
        raise herror("BadArgs", "diagnostic reporting exceeds 131072 words")
    var name = String(from_utf8=_hex(args[2]))
    var window = read_safetensors_constant_window(args[1], name, _signed(args[3]), count,
        _signed(args[5]), _integer(args[6]), _integer(args[7]), _integer(args[8]),
        _integer(args[9]), _integer(args[10]))
    var text = String("{\"name_utf8_hex\":\"") + _string_hex(window.binding.name) + "\",\"dtype\":" + String(window.binding.dtype)
    text += ",\"source_bytes\":" + String(window.source_bytes) + ",\"data_offset\":" + String(window.data_offset)
    text += ",\"elements\":" + String(window.binding.elements) + ",\"file_offset\":" + String(window.binding.file_offset) + ",\"byte_count\":" + String(window.binding.byte_count)
    text += ",\"first\":" + String(window.first) + ",\"count\":" + String(window.count) + ",\"shape\":["
    for i in range(len(window.binding.shape)):
        if i > 0:
            text += ","
        text += String(window.binding.shape[i])
    text += "],\"raw_words\":["
    for i in range(len(window.raw_words)):
        if i > 0:
            text += ","
        text += String(window.raw_words[i])
    text += "],\"binary32_words\":["
    for i in range(len(window.binary32_words)):
        if i > 0:
            text += ","
        text += String(window.binary32_words[i])
    print(text + "],\"device_access\":false,\"model_evaluated\":false,\"execution_tested\":false}")
