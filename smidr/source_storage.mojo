# Original source storage metadata. No value conversion or model execution.
from std.collections import Dict
from loader.packed_gguf import PackedGGUF, packed_row_bytes
from smidr.safetensors_inventory import read_safetensors_inventory, SafetensorsInventory


@fieldwise_init
struct SourceStorageTensor(Copyable, Movable):
    var source_format: String
    var source_kind: Int
    var original_name: String
    var source_path: String
    var source_shape: List[Int]
    var axis_order: String
    var elements: Int
    var file_offset: Int
    var byte_count: Int


@fieldwise_init
struct SourceStorageInventory(Movable):
    var source_format: String
    var source_path: String
    var source_bytes: Int
    var data_offset: Int
    var tensors: List[SourceStorageTensor]
    var metadata: Dict[String, String]


def _product(a: Int, b: Int) raises -> Int:
    if a < 0 or b < 0 or (b != 0 and a > 9223372036854775807 // b):
        raise Error("SourceStorage: invalid or overflowing source product")
    return a * b


def _elements(shape: List[Int]) raises -> Int:
    var empty = False
    for dimension in shape:
        if dimension < 0:
            raise Error("SourceStorage: negative source axis")
        empty = empty or dimension == 0
    if empty:
        return 0
    var result = 1
    for dimension in shape:
        result = _product(result, dimension)
    return result


def source_storage_bytes(tensor: SourceStorageTensor) raises -> Int:
    """Container tag selects the dtype namespace, never a bare integer cast."""
    var count = _elements(tensor.source_shape)
    if tensor.elements != count:
        raise Error("SourceStorage: source element count mismatch")
    if tensor.source_format == "gguf":
        if tensor.axis_order != "gguf_fastest_axis_first" or len(tensor.source_shape) < 1 or len(tensor.source_shape) > 2 or count == 0:
            raise Error("SourceStorage: current GGUF source axes unresolved")
        var rows = tensor.source_shape[1] if len(tensor.source_shape) == 2 else 1
        return _product(packed_row_bytes(tensor.source_kind, tensor.source_shape[0]), rows)
    if tensor.source_format == "safetensors":
        if tensor.axis_order != "row_major_outermost_first":
            raise Error("SourceStorage: safetensors source axis order mismatch")
        if tensor.source_kind == 0 or tensor.source_kind == 1:
            return _product(count, 2)
        if tensor.source_kind == 2:
            return _product(count, 4)
        raise Error("SourceStorage: source dtype implementation unresolved")
    raise Error("SourceStorage: source container implementation unresolved")


def _span_greater(starts: List[Int], ends: List[Int], a: Int, b: Int) -> Bool:
    return starts[a] > starts[b] or (starts[a] == starts[b] and ends[a] > ends[b])


def _span_swap(mut starts: List[Int], mut ends: List[Int], a: Int, b: Int):
    var start = starts[a]
    var end = ends[a]
    starts[a] = starts[b]
    ends[a] = ends[b]
    starts[b] = start
    ends[b] = end


def _span_sift(mut starts: List[Int], mut ends: List[Int], size: Int, root: Int):
    var parent = root
    while parent < size // 2:
        var child = parent * 2 + 1
        if child + 1 < size and _span_greater(starts, ends, child + 1, child):
            child += 1
        if not _span_greater(starts, ends, child, parent):
            return
        _span_swap(starts, ends, parent, child)
        parent = child


def _sort_storage_spans(mut starts: List[Int], mut ends: List[Int]):
    # Original paired heapsort. Empty spans sort before positive spans sharing
    # their start, retaining valid scalar/empty source coverage boundaries.
    var parent = len(starts) // 2
    while parent > 0:
        parent -= 1
        _span_sift(starts, ends, len(starts), parent)
    var size = len(starts)
    while size > 1:
        size -= 1
        _span_swap(starts, ends, 0, size)
        _span_sift(starts, ends, size, 0)


def _descriptor_work(count: Int, tensor_bound: Int, work_bound: Int) raises -> Int:
    # Work units: n*(2*ceil(log2(n))+3) plus declared axes. This bounds
    # new catalog projection/validation, not the legacy parser's admission.
    if count < 0 or tensor_bound <= 0 or work_bound <= 0 or count > tensor_bound:
        raise Error("SourceStorage: positive bounds/tensor count required")
    var levels = 0
    var half = count
    while half > 1:
        half = (half - 1) // 2 + 1
        levels += 1
    var work = _product(count, 2 * levels + 3)
    if work > work_bound:
        raise Error("SourceStorage: descriptor work bound exceeded")
    return work


def _axis_work(work: Int, rank: Int, rank_bound: Int, work_bound: Int) raises -> Int:
    if rank_bound <= 0 or rank > rank_bound or rank > work_bound - work:
        raise Error("SourceStorage: source rank/work bound exceeded")
    return work + rank


def validate_source_storage(inventory: SourceStorageInventory, tensor_bound: Int,
                            rank_bound: Int, work_bound: Int) raises:
    if tensor_bound <= 0 or rank_bound <= 0 or work_bound <= 0:
        raise Error("SourceStorage: positive descriptor bounds required")
    if inventory.source_format != "gguf" and inventory.source_format != "safetensors":
        raise Error("SourceStorage: source container implementation unresolved")
    if inventory.source_path.byte_length() == 0 or "\0" in inventory.source_path:
        raise Error("SourceStorage: nonempty source path without NUL required")
    if inventory.source_bytes < 0 or inventory.data_offset < 0 or inventory.data_offset > inventory.source_bytes or len(inventory.tensors) > tensor_bound:
        raise Error("SourceStorage: source extent/tensor bound mismatch")
    if (inventory.source_format == "gguf" and inventory.data_offset < 24) or (inventory.source_format == "safetensors" and inventory.data_offset < 10):
        raise Error("SourceStorage: data extent precedes minimum source header")
    var work = _descriptor_work(len(inventory.tensors), tensor_bound, work_bound)
    var seen = Dict[String, Bool]()
    var starts = List[Int]()
    var ends = List[Int]()
    starts.reserve(len(inventory.tensors))
    ends.reserve(len(inventory.tensors))
    for tensor in inventory.tensors:
        work = _axis_work(work, len(tensor.source_shape), rank_bound, work_bound)
        if tensor.original_name in seen:
            raise Error("SourceStorage: duplicate original source name")
        seen[tensor.original_name] = True
        if tensor.source_format != inventory.source_format or tensor.source_path != inventory.source_path:
            raise Error("SourceStorage: tensor container/path provenance mismatch")
        var size = source_storage_bytes(tensor)
        if tensor.file_offset < inventory.data_offset or tensor.file_offset > inventory.source_bytes or tensor.byte_count != size or size > inventory.source_bytes - tensor.file_offset:
            raise Error("SourceStorage: source shape/byte extent mismatch")
        starts.append(tensor.file_offset)
        ends.append(tensor.file_offset + size)
    _sort_storage_spans(starts, ends)
    var cursor = inventory.data_offset
    for i in range(len(starts)):
        if starts[i] < cursor:
            raise Error("SourceStorage: overlapping source spans or interior empty span")
        if inventory.source_format == "safetensors" and starts[i] != cursor:
            raise Error("SourceStorage: uncovered safetensors source payload")
        cursor = ends[i]
    if inventory.source_format == "safetensors" and cursor != inventory.source_bytes:
        raise Error("SourceStorage: uncovered safetensors source payload")


def gguf_source_storage(source: PackedGGUF, tensor_bound: Int,
                        rank_bound: Int, work_bound: Int) raises -> SourceStorageInventory:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceStorage: live GGUF source owner required")
    if tensor_bound <= 0 or rank_bound <= 0 or work_bound <= 0 or len(source.tensors) > tensor_bound:
        raise Error("SourceStorage: positive bounds/tensor count required")
    var work = _descriptor_work(len(source.tensors), tensor_bound, work_bound)
    var tensors = List[SourceStorageTensor]()
    tensors.reserve(len(source.tensors))
    for name in source.tensors:
        var b = source.tensors[name]
        var shape = source.tensor_shape(name)
        work = _axis_work(work, len(shape), rank_bound, work_bound)
        tensors.append(SourceStorageTensor("gguf", b.kind, name, source.source.file_path,
            shape^, "gguf_fastest_axis_first", _product(b.columns, b.rows), b.offset, b.byte_count))
    var result = SourceStorageInventory("gguf", source.source.file_path,
        Int(source.source.file_size), source.data_offset, tensors^, Dict[String, String]())
    validate_source_storage(result, tensor_bound, rank_bound, work_bound)
    return result^


def read_gguf_source_storage(path: String, tensor_bound: Int,
                             rank_bound: Int, work_bound: Int) raises -> SourceStorageInventory:
    # Existing PackedGGUF parser's admission/work policy runs before catalog
    # projection. These bounds govern the new descriptor/validation boundary.
    var source = PackedGGUF(path)
    try:
        var result = gguf_source_storage(source, tensor_bound, rank_bound, work_bound)
        source.source.close()
        return result^
    except e:
        source.source.close()
        raise e


def read_safetensors_source_storage(path: String, header_bound: Int,
                                    tensor_bound: Int, rank_bound: Int,
                                    work_bound: Int, depth_bound: Int) raises -> SourceStorageInventory:
    # Existing reader returns owned metadata after closing the file. All five
    # parser policies apply before constructing the tagged value projection.
    var source = read_safetensors_inventory(path, header_bound, tensor_bound,
                                           rank_bound, work_bound, depth_bound)
    return safetensors_source_storage(source, path, tensor_bound, rank_bound, work_bound)


def safetensors_source_storage(source: SafetensorsInventory, path: String,
                               tensor_bound: Int, rank_bound: Int,
                               work_bound: Int) raises -> SourceStorageInventory:
    var work = _descriptor_work(len(source.tensors), tensor_bound, work_bound)
    var tensors = List[SourceStorageTensor]()
    tensors.reserve(len(source.tensors))
    for tensor in source.tensors:
        work = _axis_work(work, len(tensor.shape), rank_bound, work_bound)
        tensors.append(SourceStorageTensor("safetensors", Int(tensor.dtype),
            tensor.name, path, tensor.shape.copy(), "row_major_outermost_first",
            Int(tensor.elements), tensor.file_offset, tensor.byte_count))
    var result = SourceStorageInventory("safetensors", path, Int(source.source_bytes),
        Int(source.data_offset), tensors^, source.metadata.copy())
    validate_source_storage(result, tensor_bound, rank_bound, work_bound)
    return result^
