# Original checked semantic source references. Metadata, never execution.
from std.collections import Dict
from loader.packed_gguf import PackedGGUF
from smidr.source_storage import (
    SourceStorageTensor, SourceStorageInventory, source_storage_bytes,
    validate_source_storage, gguf_source_storage, _sort_storage_spans,
)


@fieldwise_init
struct SourceTensorBinding(ImplicitlyCopyable, Movable):
    # Compatibility logical projection, never an admissible reference alone.
    var file_offset: Int
    var columns: Int
    var rows: Int
    var source_kind: Int
    var byte_count: Int


@fieldwise_init
struct SourceFileExtent(Copyable, Movable):
    var source_format: String
    var source_bytes: Int
    var data_offset: Int


@fieldwise_init
struct SourceSemanticPolicy(Copyable, Movable):
    var files: Int
    var tensors: Int
    var rank: Int
    var work: Int


struct SourceTensorInventory(Movable):
    var architecture: String
    # Single-file compatible summaries; multi-file data_offset=-1, size=sum.
    # These summaries are never a multi-file address space.
    var source_bytes: Int
    var data_offset: Int
    var weight_bytes: Int
    var bindings: Dict[String, SourceTensorBinding]
    var storage: Dict[String, SourceStorageTensor]
    var files: Dict[String, SourceFileExtent]
    var alias_provenance: String
    var policy: SourceSemanticPolicy

    def __init__(out self):
        self.architecture = String("")
        self.source_bytes = 0
        self.data_offset = 0
        self.weight_bytes = 0
        self.bindings = Dict[String, SourceTensorBinding]()
        self.storage = Dict[String, SourceStorageTensor]()
        self.files = Dict[String, SourceFileExtent]()
        self.alias_provenance = String("")
        self.policy = SourceSemanticPolicy(4096, 1048576, 64, 134217728)


def _sum(a: Int, b: Int) raises -> Int:
    if a < 0 or b < 0 or a > 9223372036854775807 - b:
        raise Error("SourceInventory: invalid or overflowing aggregate")
    return a + b


def _logical_axes(tensor: SourceStorageTensor) raises -> Tuple[Int, Int]:
    # Source rank is preserved, never inferred from rows==1.
    if len(tensor.source_shape) == 1:
        return tensor.source_shape[0], 1
    if len(tensor.source_shape) == 2:
        if tensor.source_format == "gguf":
            return tensor.source_shape[0], tensor.source_shape[1]
        if tensor.source_format == "safetensors":
            return tensor.source_shape[1], tensor.source_shape[0]
    raise Error("SourceInventory: operation view for source rank remains unresolved")


def validate_source_binding(binding: SourceTensorBinding,
                            tensor: SourceStorageTensor,
                            extent: SourceFileExtent) raises:
    if len(tensor.source_shape) < 1 or len(tensor.source_shape) > 2:
        raise Error("SourceInventory: operation view for source rank remains unresolved")
    var size = source_storage_bytes(tensor)
    var columns, rows = _logical_axes(tensor)
    if columns <= 0 or rows <= 0 or binding.columns != columns or binding.rows != rows:
        raise Error("SourceInventory: logical axes differ from tagged source")
    if tensor.source_path.byte_length() == 0 or "\0" in tensor.source_path:
        raise Error("SourceInventory: original backing path required")
    if tensor.source_format != extent.source_format or extent.source_bytes <= 0 or extent.data_offset < 0 or extent.data_offset > extent.source_bytes:
        raise Error("SourceInventory: backing-file format/extent mismatch")
    if (extent.source_format == "gguf" and extent.data_offset < 24) or (extent.source_format == "safetensors" and extent.data_offset < 10):
        raise Error("SourceInventory: backing extent precedes source header")
    if binding.file_offset != tensor.file_offset or binding.source_kind != tensor.source_kind or binding.byte_count != tensor.byte_count or binding.byte_count != size or size <= 0:
        raise Error("SourceInventory: logical projection differs from tagged source")
    if tensor.file_offset < extent.data_offset or tensor.file_offset > extent.source_bytes or size > extent.source_bytes - tensor.file_offset:
        raise Error("SourceInventory: tagged source exceeds its backing file")


def validate_source_inventory_header(source: SourceTensorInventory) raises:
    var p = source.policy.copy()
    if p.files <= 0 or p.tensors <= 0 or p.rank <= 0 or p.work <= 0 or len(source.files) == 0 or len(source.files) > p.files or len(source.bindings) == 0 or len(source.bindings) > p.tensors or len(source.storage) != len(source.bindings) or source.alias_provenance.byte_length() == 0:
        raise Error("SourceInventory: complete bounded tagged source required")
    if len(source.files) > p.work or len(source.bindings) > p.work - len(source.files):
        raise Error("SourceInventory: descriptor work bound exceeded")
    var total = 0
    var offset = -1
    for path in source.files:
        var file = source.files[path].copy()
        if path.byte_length() == 0 or "\0" in path or file.source_bytes <= 0 or file.data_offset < 0 or file.data_offset > file.source_bytes or (file.source_format != "gguf" and file.source_format != "safetensors"):
            raise Error("SourceInventory: invalid backing-file declaration")
        total = _sum(total, file.source_bytes)
        if len(source.files) == 1:
            offset = file.data_offset
    if source.source_bytes != total or source.data_offset != offset:
        raise Error("SourceInventory: diagnostic source summary mismatch")


def validate_source_weight(source: SourceTensorInventory, name: String,
                           columns: Int, rows: Int, vector: Bool) raises:
    validate_source_inventory_header(source)
    if name not in source.bindings or name not in source.storage:
        raise Error("SourceInventory: missing paired canonical source binding")
    ref tensor = source.storage[name]
    if tensor.source_path not in source.files or len(tensor.source_shape) > source.policy.rank:
        raise Error("SourceInventory: missing backing file or rank bound exceeded")
    var binding = source.bindings[name]
    validate_source_binding(binding, tensor, source.files[tensor.source_path])
    if columns <= 0 or rows <= 0 or binding.columns != columns or binding.rows != rows or (vector and rows != 1):
        raise Error("SourceInventory: operation source shape mismatch")
    if tensor.source_format == "safetensors":
        if (vector and len(tensor.source_shape) != 1) or (not vector and len(tensor.source_shape) != 2):
            raise Error("SourceInventory: vector and matrix source roles differ")


def validate_source_inventory(source: SourceTensorInventory) raises:
    validate_source_inventory_header(source)
    var n = len(source.bindings)
    var levels = 0
    var half = n
    while half > 1:
        half = (half - 1) // 2 + 1
        levels += 1
    # Bound file-by-tensor grouping and per-file span heapsorts before work.
    var factor = _sum(len(source.files), 2 * levels + 5)
    if n > (source.policy.work - len(source.files)) // factor:
        raise Error("SourceInventory: descriptor work bound exceeded")
    var work = n * factor + len(source.files)
    var total = 0
    for name in source.bindings:
        if name not in source.storage:
            raise Error("SourceInventory: missing tagged source descriptor")
        ref tensor = source.storage[name]
        if len(tensor.source_shape) > source.policy.rank or len(tensor.source_shape) > source.policy.work - work:
            raise Error("SourceInventory: source rank/work bound exceeded")
        work += len(tensor.source_shape)
        if tensor.source_path not in source.files:
            raise Error("SourceInventory: missing original backing file")
        validate_source_binding(source.bindings[name], tensor, source.files[tensor.source_path])
        total = _sum(total, tensor.byte_count)
    if total != source.weight_bytes:
        raise Error("SourceInventory: aggregate weight byte count mismatch")
    for path in source.files:
        var names = Dict[String, Bool]()
        var starts = List[Int]()
        var ends = List[Int]()
        for name in source.bindings:
            ref tensor = source.storage[name]
            if tensor.source_path != path:
                continue
            if tensor.original_name in names:
                raise Error("SourceInventory: duplicate original name in backing file")
            names[tensor.original_name] = True
            starts.append(tensor.file_offset)
            ends.append(tensor.file_offset + tensor.byte_count)
        _sort_storage_spans(starts, ends)
        var cursor = source.files[path].data_offset
        for i in range(len(starts)):
            if starts[i] < cursor:
                raise Error("SourceInventory: overlapping per-file source spans")
            if source.files[path].source_format == "safetensors" and starts[i] != cursor:
                raise Error("SourceInventory: uncovered per-file safetensors payload")
            cursor = ends[i]
        if source.files[path].source_format == "safetensors" and cursor != source.files[path].source_bytes:
            raise Error("SourceInventory: uncovered per-file safetensors payload")


def append_source_storage(mut destination: SourceTensorInventory,
                          source: SourceStorageInventory,
                          aliases: Dict[String, String], provenance: String) raises:
    # Append is a builder operation: discard destination after any failure.
    var p = destination.policy.copy()
    if p.files <= 0 or p.tensors <= 0 or p.rank <= 0 or p.work <= 0 or provenance.byte_length() == 0 or source.source_path in destination.files or len(destination.files) >= p.files or len(destination.bindings) > p.tensors or len(source.tensors) > p.tensors - len(destination.bindings) or len(aliases) != len(source.tensors):
        raise Error("SourceInventory: explicit bounded one-to-one aliases required")
    validate_source_storage(source, p.tensors, p.rank, p.work)
    var originals = Dict[String, Int]()
    for i in range(len(source.tensors)):
        originals[source.tensors[i].original_name] = i
    var seen = Dict[String, Bool]()
    var extent = SourceFileExtent(source.source_format, source.source_bytes, source.data_offset)
    for name in aliases:
        var original = aliases[name]
        if name in destination.bindings or name in destination.storage or original not in originals or original in seen:
            raise Error("SourceInventory: duplicate or absent explicit alias")
        seen[original] = True
        var tensor = source.tensors[originals[original]].copy()
        var columns, rows = _logical_axes(tensor)
        var binding = SourceTensorBinding(tensor.file_offset, columns, rows, tensor.source_kind, tensor.byte_count)
        validate_source_binding(binding, tensor, extent)
        destination.bindings[name] = binding
        destination.storage[name] = tensor^
        destination.weight_bytes = _sum(destination.weight_bytes, binding.byte_count)
    destination.files[source.source_path] = extent^
    destination.source_bytes = _sum(destination.source_bytes, source.source_bytes)
    destination.data_offset = source.data_offset if len(destination.files) == 1 else -1
    if destination.alias_provenance.byte_length() != 0:
        destination.alias_provenance += "; "
    destination.alias_provenance += provenance
    validate_source_inventory(destination)


def read_source_inventory(path: String) raises -> SourceTensorInventory:
    var source = PackedGGUF(path)
    try:
        var inventory = inventory_from_source(source)
        source.source.close()
        return inventory^
    except e:
        source.source.close()
        raise e


def inventory_from_source(source: PackedGGUF) raises -> SourceTensorInventory:
    var inventory = SourceTensorInventory()
    inventory.architecture = source.text("general.architecture")
    if inventory.architecture.byte_length() == 0 or len(source.tensors) == 0:
        raise Error("SourceInventory: architecture and at least one tensor are required")
    var p = inventory.policy.copy()
    var storage = gguf_source_storage(source, p.tensors, p.rank, p.work)
    var aliases = Dict[String, String]()
    for tensor in storage.tensors:
        aliases[tensor.original_name] = tensor.original_name
    append_source_storage(inventory, storage, aliases, "GGUF explicit original-name identity adapter")
    return inventory^
