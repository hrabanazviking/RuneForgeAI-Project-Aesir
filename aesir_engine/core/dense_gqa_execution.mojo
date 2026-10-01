"""Prepared descriptors for an already admitted dense GQA model.

Called after validate_dense_gqa, before device allocation. Per-token execution
borrows descriptors instead of allocating names and looking up tensor tables.
The mapped GGUF and device weights remain owned by the session.
"""
from loader.packed_gguf import PackedGGUF, PackedTensor
from core.dense_gqa_profile import DenseGQAProfile


@fieldwise_init
struct DenseGQALayer(ImplicitlyCopyable, Movable):
    var attention_norm: Int
    var query: PackedTensor
    var key: PackedTensor
    var value: PackedTensor
    var attention_output: PackedTensor
    var feed_forward_norm: Int
    var gate: PackedTensor
    var up: PackedTensor
    var down: PackedTensor
    var query_norm: Int
    var key_norm: Int


def prepare_dense_gqa_layers(model: PackedGGUF, profile: DenseGQAProfile) raises -> List[DenseGQALayer]:
    var result = List[DenseGQALayer]()
    for layer in range(profile.layer_count):
        var prefix = "blk." + String(layer) + "."
        var query_norm = -1
        var key_norm = -1
        if profile.qk_norm:
            query_norm = model.tensors[prefix + "attn_q_norm.weight"].offset
            key_norm = model.tensors[prefix + "attn_k_norm.weight"].offset
        result.append(DenseGQALayer(
            model.tensors[prefix + "attn_norm.weight"].offset,
            model.tensors[prefix + "attn_q.weight"],
            model.tensors[prefix + "attn_k.weight"],
            model.tensors[prefix + "attn_v.weight"],
            model.tensors[prefix + "attn_output.weight"],
            model.tensors[prefix + "ffn_norm.weight"].offset,
            model.tensors[prefix + "ffn_gate.weight"],
            model.tensors[prefix + "ffn_up.weight"],
            model.tensors[prefix + "ffn_down.weight"], query_norm, key_norm,
        ))
    return result^
