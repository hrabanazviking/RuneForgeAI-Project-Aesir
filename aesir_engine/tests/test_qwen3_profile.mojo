"""Opt-in real Qwen 3 profile, tokenizer, and rejection checks.

Fixture: unsloth/Qwen3-0.6B-GGUF at revision
50968a4468ef4233ed78cd7c3de230dd1d61a56b, file
Qwen3-0.6B-Q4_K_M.gguf, 396705472 bytes, SHA-256
ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a.
"""
from std.sys import argv
from loader.packed_gguf import PackedGGUF, PackedTensor
from loader.llama3_tokenizer import Llama3Tokenizer
from core.dense_gqa_profile import dense_gqa_profile_for, validate_dense_gqa


def require_rejection(model: PackedGGUF, context: Int) raises:
    var rejected = False
    try:
        validate_dense_gqa(model, dense_gqa_profile_for(model), context)
    except:
        rejected = True
    if not rejected:
        raise Error("Unsupported Qwen 3 profile was admitted")


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_qwen3_profile <Qwen3-0.6B-Q4_K_M.gguf>")
    var model = PackedGGUF(args[1])
    var profile = dense_gqa_profile_for(model)
    validate_dense_gqa(model, profile, 8192)
    if profile.name != "0.6B" or profile.query_width() != 2048:
        raise Error("Qwen 3 profile selection drifted")

    var tokenizer = Llama3Tokenizer(model)
    var actual = List[Int]()
    tokenizer.append_message(actual, "system", "You are concise.")
    tokenizer.append_message(actual, "user", "Reply with QWEN OK.")
    tokenizer.append_header(actual, "assistant")
    var expected: List[Int] = [
        151644, 8948, 198, 2610, 525, 63594, 13, 151645, 198,
        151644, 872, 198, 20841, 448, 1207, 54, 953, 10402, 13,
        151645, 198, 151644, 77091, 198,
    ]
    if len(actual) != len(expected):
        raise Error("Qwen 3 canonical chat token count mismatch")
    for i in range(len(expected)):
        if actual[i] != expected[i]:
            raise Error("Qwen 3 canonical chat token mismatch")

    require_rejection(model, 32769)
    var norm = model.tensors["blk.0.attn_q_norm.weight"]
    model.tensors["blk.0.attn_q_norm.weight"] = PackedTensor(
        norm.offset, norm.columns, norm.rows, 1, norm.byte_count
    )
    require_rejection(model, 8192)
    model.tensors["blk.0.attn_q_norm.weight"] = norm
    model.tensors["blk.0.attn_q.bias"] = norm
    require_rejection(model, 8192)
    _ = model.tensors.pop("blk.0.attn_q.bias")
    validate_dense_gqa(model, profile, 8192)
    print("PASS: Qwen 3 0.6B profile, canonical tokenizer, and strict rejections")
