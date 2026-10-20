# Host source metadata only, no value conversion or model evaluation.
from std.sys import argv
from smidr.safetensors_inventory import read_safetensors_inventory, SafetensorsInventory
from smidr.tools.program_integrity import _integer
from smidr.tools.hrpc_frame import _to_hex
from hailbru.errors import herror


def _string_hex(text: String) -> String:
    var bytes = List[UInt8]()
    for byte in text.as_bytes():
        bytes.append(byte)
    return _to_hex(bytes)


def main() raises:
    var args = argv()
    if len(args) != 7:
        raise herror("BadArgs", "expected path/header/tensors/rank/work/depth bounds")
    var inventory = read_safetensors_inventory(args[1], _integer(args[2]), _integer(args[3]),
        _integer(args[4]), _integer(args[5]), _integer(args[6]))
    print(describe_safetensors_inventory(inventory))


def describe_safetensors_inventory(inventory: SafetensorsInventory) raises -> String:
    var text = String("{\"source_bytes\":") + String(inventory.source_bytes) + ",\"data_offset\":" + String(inventory.data_offset) + ",\"tensors\":["
    for i in range(len(inventory.tensors)):
        if i > 0:
            text += ","
        ref tensor = inventory.tensors[i]
        text += "{\"name_utf8_hex\":\"" + _string_hex(tensor.name) + "\",\"dtype\":" + String(tensor.dtype) + ",\"elements\":" + String(tensor.elements) + ",\"offset\":" + String(tensor.file_offset) + ",\"bytes\":" + String(tensor.byte_count) + ",\"shape\":["
        for axis in range(len(tensor.shape)):
            if axis > 0:
                text += ","
            text += String(tensor.shape[axis])
        text += "]}"
    text += "],\"metadata\":["
    var first = True
    for key in inventory.metadata:
        if not first:
            text += ","
        first = False
        text += "[\"" + _string_hex(key) + "\",\"" + _string_hex(inventory.metadata[key]) + "\"]"
    return text + "],\"device_access\":false,\"tensor_values_loaded\":false,\"execution_tested\":false}"
