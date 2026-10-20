# Typed mathematical graph inspector; synthetic descriptors, never model math.
from std.sys import argv
from std.memory import bitcast
from smidr.tools.hrpc_device import _uint32
from loader.packed_gguf import PackedGGUF
from smidr.source_inventory import SourceTensorInventory, SourceTensorBinding, inventory_from_source
from smidr.semantic_plan import (
    DenseDecoderParameters, SemanticPlan, gguf_dense_decoder_parameters,
    build_dense_semantic_plan, checked_product,
)
from smidr.tools.semantic_plan import describe_semantic_plan
from smidr.tools.program_integrity import _signed


@fieldwise_init
struct _Inputs(Movable):
    var inventory: SourceTensorInventory
    var parameters: DenseDecoderParameters

    def take_inventory(mut self) -> SourceTensorInventory:
        var result = self.inventory^
        self.inventory = SourceTensorInventory()
        return result^


def _from_file(path: String) raises -> _Inputs:
    var source = PackedGGUF(path)
    try:
        var parameters = gguf_dense_decoder_parameters(source)
        var inventory = inventory_from_source(source)
        source.source.close()
        return _Inputs(inventory^, parameters^)
    except e:
        source.source.close()
        raise e


def _parameter(mut p: DenseDecoderParameters, field: String, value: String) raises:
    if field == "rope_base":
        p.rope_base = Float32(atof(value))
    elif field == "rms_epsilon":
        p.rms_epsilon = Float32(atof(value))
    elif field == "rope_base_bits":
        p.rope_base = bitcast[DType.float32](_uint32(value))
    elif field == "rms_epsilon_bits":
        p.rms_epsilon = bitcast[DType.float32](_uint32(value))
    elif field == "source_layout":
        p.source_layout = value
    elif field == "layers":
        p.layers = _signed(value)
    elif field == "hidden":
        p.hidden = _signed(value)
    elif field == "feed_forward":
        p.feed_forward = _signed(value)
    elif field == "heads":
        p.heads = _signed(value)
    elif field == "kv_heads":
        p.kv_heads = _signed(value)
    elif field == "key_dim":
        p.key_dim = _signed(value)
    elif field == "value_dim":
        p.value_dim = _signed(value)
    elif field == "rope_dim":
        p.rope_dim = _signed(value)
    elif field == "vocabulary":
        p.vocabulary = _signed(value)
    elif field == "source_context":
        p.source_context = _signed(value)
    else:
        raise Error("TypedDecoder: unknown parameter field")


def _inventory(mut inventory: SourceTensorInventory, mode: String) raises:
    var binding = inventory.bindings["token_embd.weight"]
    if mode == "architecture":
        inventory.architecture = "other"
    elif mode == "empty":
        inventory.bindings.clear()
    elif mode == "source_bytes":
        inventory.source_bytes = -1
    elif mode == "data_offset":
        inventory.data_offset = -1
    elif mode == "data_after_source":
        inventory.data_offset = inventory.source_bytes + 1
    elif mode == "aggregate":
        inventory.weight_bytes += 1
    elif mode == "offset_before":
        binding.file_offset = inventory.data_offset - 1
    elif mode == "offset_after":
        binding.file_offset = inventory.source_bytes + 1
    elif mode == "offset_overflow":
        binding.file_offset = 9223372036854775807
    elif mode == "columns":
        binding.columns = 0
    elif mode == "rows":
        binding.rows = 0
    elif mode == "rows_overflow":
        binding.rows = 9223372036854775807
    elif mode == "kind":
        binding.source_kind = 99
    elif mode == "byte_count":
        binding.byte_count += 1
    elif mode == "overlap":
        binding.file_offset = inventory.bindings["blk.0.attn_q.weight"].file_offset
    elif mode == "extra":
        inventory.bindings["extra.weight"] = binding
    elif mode == "missing":
        _ = inventory.bindings.pop("output_norm.weight")
        inventory.weight_bytes -= inventory.bindings["blk.0.attn_norm.weight"].byte_count
    else:
        raise Error("TypedDecoder: unknown inventory mutation")
    if "token_embd.weight" in inventory.bindings:
        inventory.bindings["token_embd.weight"] = binding


def _add(mut s: SourceTensorInventory, name: String, columns: Int, rows: Int) raises:
    var size = checked_product(checked_product(columns, rows), 4)
    s.bindings[name] = SourceTensorBinding(s.source_bytes, columns, rows, 0, size)
    s.source_bytes += size
    s.weight_bytes += size


def _synthetic() raises -> _Inputs:
    var inventory = SourceTensorInventory()
    inventory.architecture = "llama"
    inventory.data_offset = 64
    inventory.source_bytes = 64
    _add(inventory, "token_embd.weight", 8, 10)
    _add(inventory, "output_norm.weight", 8, 1)
    _add(inventory, "output.weight", 8, 10)
    _add(inventory, "blk.0.attn_norm.weight", 8, 1)
    _add(inventory, "blk.0.ffn_norm.weight", 8, 1)
    _add(inventory, "blk.0.attn_q.weight", 8, 8)
    _add(inventory, "blk.0.attn_k.weight", 8, 4)
    _add(inventory, "blk.0.attn_v.weight", 8, 4)
    _add(inventory, "blk.0.attn_output.weight", 8, 8)
    _add(inventory, "blk.0.ffn_gate.weight", 8, 12)
    _add(inventory, "blk.0.ffn_up.weight", 8, 12)
    _add(inventory, "blk.0.ffn_down.weight", 12, 8)
    return _Inputs(inventory^, DenseDecoderParameters(1, 8, 12, 4, 2, 2, 2, 2,
        10, 64, 10000, 0.00001, "reference"))


def main() raises:
    var args = argv()
    if len(args) == 2 and args[1] == "synthetic":
        var input = _synthetic()
        var inventory = input.take_inventory()
        var graph = build_dense_semantic_plan(inventory^, input.parameters, 3, 0, 16)
        print(describe_semantic_plan(graph))
        return
    if len(args) < 6:
        raise Error("TypedDecoder: expected mode/path/query/past/capacity [mutation]")
    var input = _from_file(args[2])
    if args[1] == "parameter" and len(args) == 8:
        _parameter(input.parameters, args[6], args[7])
    elif args[1] == "inventory" and len(args) == 7:
        _inventory(input.inventory, args[6])
    elif args[1] != "typed" or len(args) != 6:
        raise Error("TypedDecoder: invalid mode")
    var inventory = input.take_inventory()
    var graph = build_dense_semantic_plan(inventory^, input.parameters,
        _signed(args[3]), _signed(args[4]), _signed(args[5]))
    print(describe_semantic_plan(graph))
