# Direct descriptor arithmetic, mutation, sorting and ownership only.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from smidr.source_storage import (
    SourceStorageTensor, SourceStorageInventory, source_storage_bytes,
    read_gguf_source_storage, read_safetensors_source_storage,
    validate_source_storage, gguf_source_storage, _elements, _sort_storage_spans,
)
from smidr.tools.source_storage import describe_source_storage
from smidr.tools.semantic_plan import _integers
from smidr.tools.program_integrity import _signed


def main() raises:
    var args = argv()
    if len(args) >= 4 and args[1] == "arithmetic":
        var shape = List[Int]()
        for i in range(4, len(args)):
            shape.append(_signed(args[i]))
        var count = _elements(shape)
        var format = String(args[2])
        var tensor = SourceStorageTensor(format, _signed(args[3]), "value", "fixture",
            shape^, String("gguf_fastest_axis_first") if format == "gguf" else String("row_major_outermost_first"), count, 0, 0)
        print("{\"elements\":" + String(count) + ",\"bytes\":" + String(source_storage_bytes(tensor)) + "}")
        return
    if len(args) >= 2 and args[1] == "sort":
        if (len(args) - 2) % 2 != 0:
            raise Error("StorageApi: expected start/end pairs")
        var starts = List[Int]()
        var ends = List[Int]()
        for i in range(2, len(args), 2):
            starts.append(_signed(args[i]))
            ends.append(_signed(args[i + 1]))
        _sort_storage_spans(starts, ends)
        print("{\"starts\":" + _integers(starts) + ",\"ends\":" + _integers(ends) + "}")
        return
    if len(args) != 4:
        raise Error("StorageApi: expected format/path/mode")
    if args[1] == "gguf" and args[3] == "closed":
        var source = PackedGGUF(args[2])
        source.source.close()
        _ = gguf_source_storage(source, 1000, 64, 10000000)
        raise Error("StorageApi: closed source was accepted")
    var inventory = read_gguf_source_storage(args[2], 1000, 64, 10000000) if args[1] == "gguf" else read_safetensors_source_storage(args[2], 1048576, 1000, 64, 10000000, 64)
    var mode = String(args[3])
    if len(inventory.tensors) == 0:
        raise Error("StorageApi: mutation requires a tensor")
    if mode == "ownership":
        var tensor = inventory.tensors[0].copy()
        var snapshot = tensor.source_shape.copy()
        var name = tensor.original_name
        if len(inventory.tensors[0].source_shape) == 0:
            inventory.tensors[0].source_shape.append(999)
        else:
            inventory.tensors[0].source_shape[0] = 999
        inventory.tensors[0].original_name = "changed"
        inventory.source_path = "changed"
        if tensor.source_shape != snapshot or tensor.original_name != name or tensor.source_path == "changed":
            raise Error("StorageApi: borrowed storage escaped")
        print("{\"ownership_checked\":true,\"execution_tested\":false}")
        return
    var tensor_bound = 1000
    var rank_bound = 64
    var work_bound = 10000000
    if mode == "container":
        inventory.source_format = "other"
    elif mode == "path":
        inventory.source_path = ""
    elif mode == "nul_path":
        inventory.source_path += "\0tail"
    elif mode == "file_extent":
        inventory.source_bytes = -1
    elif mode == "data_before_header":
        inventory.data_offset = 0
    elif mode == "data_extent":
        inventory.data_offset = inventory.source_bytes + 1
    elif mode == "tensor_bound":
        tensor_bound = 0
    elif mode == "rank_bound":
        rank_bound = 0
    elif mode == "work_bound":
        work_bound = 1
    elif mode == "entry_container":
        inventory.tensors[0].source_format = "other"
    elif mode == "entry_path":
        inventory.tensors[0].source_path = "other"
    elif mode == "dtype":
        inventory.tensors[0].source_kind = 999
    elif mode == "negative_dtype":
        inventory.tensors[0].source_kind = -1
    elif mode == "axis_order":
        inventory.tensors[0].axis_order = "other"
    elif mode == "elements":
        inventory.tensors[0].elements += 1
    elif mode == "negative_axis":
        inventory.tensors[0].source_shape[0] = -1
    elif mode == "bytes":
        inventory.tensors[0].byte_count += 1
    elif mode == "offset_before":
        inventory.tensors[0].file_offset = inventory.data_offset - 1
    elif mode == "offset_overflow":
        inventory.tensors[0].file_offset = 9223372036854775807
    elif mode == "elements_overflow":
        var huge: List[Int] = [9223372036854775807, 2]
        inventory.tensors[0].source_shape = huge^
    elif mode == "bytes_negative":
        inventory.tensors[0].byte_count = -1
    elif mode == "offset_after":
        inventory.tensors[0].file_offset = inventory.source_bytes + 1
    elif mode == "duplicate":
        inventory.tensors.append(inventory.tensors[0].copy())
    elif mode == "overlap":
        if len(inventory.tensors) < 2:
            raise Error("StorageApi: overlap requires two tensors")
        inventory.tensors[1].file_offset = inventory.tensors[0].file_offset
    elif mode == "interior_empty":
        if len(inventory.tensors) < 2:
            raise Error("StorageApi: interior empty requires two tensors")
        var empty: List[Int] = [0]
        inventory.tensors[1].source_shape = empty^
        inventory.tensors[1].elements = 0
        inventory.tensors[1].byte_count = 0
        inventory.tensors[1].file_offset = inventory.tensors[0].file_offset + 1
    elif mode == "gap":
        if len(inventory.tensors) < 2:
            raise Error("StorageApi: gap requires two tensors")
        inventory.tensors[1].file_offset += 32
        inventory.source_bytes += 32
    elif mode == "coverage":
        inventory.source_bytes += 1
    elif mode == "cast":
        inventory.source_format = "safetensors" if inventory.source_format == "gguf" else "gguf"
        for i in range(len(inventory.tensors)):
            inventory.tensors[i].source_format = inventory.source_format
            inventory.tensors[i].axis_order = "gguf_fastest_axis_first" if inventory.source_format == "gguf" else "row_major_outermost_first"
    else:
        raise Error("StorageApi: unknown mutation")
    validate_source_storage(inventory, tensor_bound, rank_bound, work_bound)
    print(describe_source_storage(inventory))
