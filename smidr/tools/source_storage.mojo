# Native ordinary-source storage inspection, never tensor/model execution.
from std.sys import argv
from smidr.source_storage import SourceStorageInventory, read_gguf_source_storage, read_safetensors_source_storage
from smidr.tools.source_inventory import _quote
from smidr.tools.semantic_plan import _integers
from smidr.tools.program_integrity import _integer


def describe_source_storage(inventory: SourceStorageInventory) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"tagged_source_storage\",\"source_format\":") + _quote(inventory.source_format)
    text += ",\"source_path\":" + _quote(inventory.source_path) + ",\"source_bytes\":" + String(inventory.source_bytes) + ",\"data_offset\":" + String(inventory.data_offset)
    text += ",\"execution_tested\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false,\"tensor_values_loaded\":false,\"tensors\":["
    for i in range(len(inventory.tensors)):
        if i != 0:
            text += ","
        ref tensor = inventory.tensors[i]
        text += "{\"source_format\":" + _quote(tensor.source_format) + ",\"source_kind\":" + String(tensor.source_kind)
        text += ",\"original_name\":" + _quote(tensor.original_name) + ",\"source_path\":" + _quote(tensor.source_path) + ",\"source_shape\":" + _integers(tensor.source_shape)
        text += ",\"axis_order\":" + _quote(tensor.axis_order) + ",\"elements\":" + String(tensor.elements) + ",\"file_offset\":" + String(tensor.file_offset) + ",\"byte_count\":" + String(tensor.byte_count) + "}"
    text += "],\"metadata\":{"
    var first = True
    for key in inventory.metadata:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + _quote(inventory.metadata[key])
    return text + "}}"


def main() raises:
    var args = argv()
    if len(args) == 6 and args[1] == "gguf":
        var inventory = read_gguf_source_storage(args[2], _integer(args[3]), _integer(args[4]), _integer(args[5]))
        print(describe_source_storage(inventory))
    elif len(args) == 8 and args[1] == "safetensors":
        var inventory = read_safetensors_source_storage(args[2], _integer(args[3]),
            _integer(args[4]), _integer(args[5]), _integer(args[6]), _integer(args[7]))
        print(describe_source_storage(inventory))
    else:
        raise Error("usage: source_storage gguf path tensors/rank/work OR safetensors path header/tensors/rank/work/depth")
