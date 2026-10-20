# Original compiler input snapshot. Metadata/tensor descriptors, never execution.
from std.collections import Dict
from loader.packed_gguf import PackedGGUF


@fieldwise_init
struct SourceTensorBinding(ImplicitlyCopyable, Movable):
    var file_offset: Int
    var columns: Int
    var rows: Int
    var source_kind: Int
    var byte_count: Int


struct SourceTensorInventory(Movable):
    var architecture: String
    var source_bytes: Int
    var data_offset: Int
    var weight_bytes: Int
    var bindings: Dict[String, SourceTensorBinding]

    def __init__(out self):
        self.architecture = String("")
        self.source_bytes = 0
        self.data_offset = 0
        self.weight_bytes = 0
        self.bindings = Dict[String, SourceTensorBinding]()


def read_source_inventory(path: String) raises -> SourceTensorInventory:
    # Reuse loader file/range ownership only; no registry, forward or allocation
    # of model activations, KV caches, accelerator tensors or dequantized weights.
    var source = PackedGGUF(path)
    return inventory_from_source(source)


def inventory_from_source(source: PackedGGUF) raises -> SourceTensorInventory:
    # Borrow a live read-only parser so a compiler pass observes one mapping.
    var inventory = SourceTensorInventory()
    inventory.architecture = source.text("general.architecture")
    if inventory.architecture.byte_length() == 0 or len(source.tensors) == 0:
        raise Error("SourceInventory: architecture and at least one tensor are required")
    inventory.source_bytes = Int(source.source.file_size)
    inventory.data_offset = source.data_offset
    for name in source.tensors:
        var tensor = source.tensors[name]
        # Recheck descriptor invariants at the compiler boundary, with overflow-
        # safe accumulation. The loader already checked layout/range/overlap.
        if tensor.offset < inventory.data_offset or tensor.offset > inventory.source_bytes or tensor.byte_count <= 0 or tensor.byte_count > inventory.source_bytes - tensor.offset:
            raise Error("SourceInventory: tensor extent is outside its source")
        if inventory.weight_bytes > 9223372036854775807 - tensor.byte_count:
            raise Error("SourceInventory: total tensor bytes overflow")
        inventory.weight_bytes += tensor.byte_count
        inventory.bindings[name] = SourceTensorBinding(tensor.offset, tensor.columns, tensor.rows, tensor.kind, tensor.byte_count)
    # Only value descriptors escape; the loader closes its read-only mapping.
    # These offsets are not executable pointers or a verified weight identity.
    return inventory^
