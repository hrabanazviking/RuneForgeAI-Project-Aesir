"""Opt-in external metadata admission checks; no GPU allocation or weight edits."""
from std.sys import argv
from loader.packed_gguf import PackedGGUF, PackedTensor
from core.llama3_cuda import validate_llama3

def require_rejection(model: PackedGGUF, capacity: Int) raises:
    var rejected = False
    try:
        validate_llama3(model, capacity)
    except:
        rejected = True
    if not rejected:
        raise Error("Unsupported Llama profile was admitted")

def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_llama3_profile <model.gguf>")
    var model = PackedGGUF(args[1])
    validate_llama3(model, 8192)
    require_rejection(model, 0)
    require_rejection(model, 1)
    require_rejection(model, 8193)
    var q = model.tensors["blk.0.attn_q.weight"]
    model.tensors["blk.0.attn_q.weight"] = PackedTensor(q.offset, q.columns + 256, q.rows, q.kind, q.byte_count)
    require_rejection(model, 8192)
    model.tensors["blk.0.attn_q.weight"] = q
    var norm = model.tensors["output_norm.weight"]
    model.tensors["output_norm.weight"] = PackedTensor(norm.offset, norm.columns, norm.rows, 1, norm.byte_count)
    require_rejection(model, 8192)
    model.tensors["output_norm.weight"] = norm
    model.tensors["unsupported.bias"] = norm
    require_rejection(model, 8192)
    _ = model.tensors.pop("unsupported.bias")
    var head_offset = model.fields["llama.attention.head_count"]
    model.fields["llama.attention.head_count"] = model.fields["llama.embedding_length"]
    require_rejection(model, 8192)
    model.fields["llama.attention.head_count"] = head_offset
    # Reuse existing immutable string bytes for a non-'none' scaling value.
    model.fields["llama.rope.scaling.type"] = model.fields["general.architecture"]
    model.field_types["llama.rope.scaling.type"] = model.field_types["general.architecture"]
    require_rejection(model, 8192)
    _ = model.fields.pop("llama.rope.scaling.type")
    _ = model.field_types.pop("llama.rope.scaling.type")
    validate_llama3(model, 8192)
    print("PASS: admitted real profile and eight unsupported context/shape/norm/tensor/head/RoPE cases")
