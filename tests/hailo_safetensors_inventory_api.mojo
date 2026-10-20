# Host metadata ownership/cleanup checks. No value load/conversion/inference.
from std.sys import argv
from armvegr.safetensors import SafetensorsLoader, STTensorDesc
from smidr.safetensors_inventory import read_safetensors_inventory


def _closed(source: SafetensorsLoader) raises:
    if source.opened or source.fd != -1 or source.file_size != 0 or source.header_size != 0 or len(source.descs) != 0 or len(source.metadata) != 0:
        raise Error("SafetensorsApi: failed/closed source retains live state")
    var refused = False
    try:
        source._req(0, 0)
    except:
        refused = True
    if not refused:
        raise Error("SafetensorsApi: closed mapped access accepted")


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("SafetensorsApi: expected valid and invalid fixture paths")
    var source = SafetensorsLoader()
    _closed(source)
    for _ in range(20):
        var refused = False
        try:
            source.open(args[2], 65536, 32, 16, 4096, 16)
        except:
            refused = True
        if not refused:
            source.close()
            raise Error("SafetensorsApi: invalid source accepted")
        _closed(source)
        source.open(args[1], 65536, 32, 16, 4096, 16)
        var count = source.tensor_count()
        refused = False
        try:
            source.open(args[1])
        except:
            refused = True
        if not refused or source.tensor_count() != count or not source.opened:
            raise Error("SafetensorsApi: already-open refusal changed owner")
        source.close()
        source.close()
        _closed(source)
    var first = read_safetensors_inventory(args[1], 65536, 32, 16, 4096, 16)
    var second = read_safetensors_inventory(args[1], 65536, 32, 16, 4096, 16)
    if len(first.tensors) == 0 or len(first.tensors[0].shape) == 0:
        raise Error("SafetensorsApi: fixture needs a non-scalar tensor")
    var saved = second.tensors[0].shape[0]
    first.tensors[0].shape[0] = 999
    first.tensors[0].name = "changed"
    first.metadata["added"] = "changed"
    if second.tensors[0].shape[0] != saved or second.tensors[0].name == "changed" or "added" in second.metadata:
        raise Error("SafetensorsApi: returned inventories alias")
    var desc = STTensorDesc()
    if desc.element_count() != 1:
        raise Error("SafetensorsApi: scalar count differs")
    desc.shape.append(9223372036854775807)
    desc.shape.append(0)
    desc.shape.append(9223372036854775807)
    if desc.element_count() != 0:
        raise Error("SafetensorsApi: empty shape overflows")
    desc.shape.clear()
    desc.shape.append(4294967296)
    desc.shape.append(4294967296)
    var refused = False
    try:
        _ = desc.element_count()
    except:
        refused = True
    if not refused:
        raise Error("SafetensorsApi: overflowing shape accepted")
    print("{\"ownership_checked\":true,\"cleanup_cycles\":20,\"device_access\":false,\"tensor_values_loaded\":false,\"execution_tested\":false}")
