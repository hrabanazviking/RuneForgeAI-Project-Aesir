# Tagged semantic metadata inspection. No architecture adaptation or execution.
from std.collections import Dict
from std.sys import argv
from smidr.source_inventory import SourceTensorInventory, append_source_storage, validate_source_inventory
from smidr.source_storage import read_gguf_source_storage, read_safetensors_source_storage, SourceStorageInventory
from smidr.tools.source_inventory import _quote
from smidr.tools.semantic_plan import _integers


def describe_semantic_storage(source: SourceTensorInventory) raises -> String:
    validate_source_inventory(source)
    var text = String("{\"schema_version\":1,\"scope\":\"tagged_semantic_storage\",\"execution_tested\":false,\"device_access\":false,\"architecture_adapter_verified\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false")
    text += ",\"source_bytes\":" + String(source.source_bytes) + ",\"data_offset\":" + String(source.data_offset) + ",\"weight_bytes\":" + String(source.weight_bytes)
    text += ",\"alias_provenance\":" + _quote(source.alias_provenance) + ",\"files\":{"
    var first = True
    for path in source.files:
        if not first:
            text += ","
        first = False
        var file = source.files[path].copy()
        text += _quote(path) + ":{\"source_format\":" + _quote(file.source_format) + ",\"source_bytes\":" + String(file.source_bytes) + ",\"data_offset\":" + String(file.data_offset) + "}"
    text += "},\"bindings\":{"
    first = True
    for name in source.bindings:
        if not first:
            text += ","
        first = False
        var b = source.bindings[name]
        var t = source.storage[name].copy()
        text += _quote(name) + ":{\"source_format\":" + _quote(t.source_format) + ",\"source_kind\":" + String(t.source_kind)
        text += ",\"original_name\":" + _quote(t.original_name) + ",\"source_path\":" + _quote(t.source_path) + ",\"source_shape\":" + _integers(t.source_shape)
        text += ",\"axis_order\":" + _quote(t.axis_order) + ",\"elements\":" + String(t.elements) + ",\"file_offset\":" + String(t.file_offset) + ",\"byte_count\":" + String(t.byte_count)
        text += ",\"columns\":" + String(b.columns) + ",\"rows\":" + String(b.rows) + "}"
    return text + "}}"


def append_explicit_prefix(mut destination: SourceTensorInventory,
                           storage: SourceStorageInventory, prefix: String) raises:
    var aliases = Dict[String, String]()
    for tensor in storage.tensors:
        aliases[prefix + tensor.original_name] = tensor.original_name
    append_source_storage(destination, storage, aliases, "explicit diagnostic alias prefix: " + prefix)


def append_path(mut destination: SourceTensorInventory, format: String,
                path: String, prefix: String) raises:
    var p = destination.policy.copy()
    if format == "gguf":
        var storage = read_gguf_source_storage(path, p.tensors, p.rank, p.work)
        append_explicit_prefix(destination, storage, prefix)
    elif format == "safetensors":
        var storage = read_safetensors_source_storage(path, 16777216, p.tensors, p.rank, p.work, 64)
        append_explicit_prefix(destination, storage, prefix)
    else:
        raise Error("SemanticStorage: source format implementation unresolved")


def main() raises:
    var args = argv()
    if len(args) < 4 or (len(args) - 1) % 3 != 0:
        raise Error("usage: semantic_storage [format path explicit_alias_prefix]...")
    var source = SourceTensorInventory()
    for i in range(1, len(args), 3):
        append_path(source, args[i], args[i + 1], args[i + 2])
    print(describe_semantic_storage(source))
