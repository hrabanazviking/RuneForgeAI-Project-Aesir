"""Opt-in slice 5 end-to-end image chat proof on the real pair.

Usage: image_chat_mmproj <model.gguf> <red.ppm> <blue.ppm>

Section A (forward control, bit-exact): a full prefill whose span
override carries the span's own token_embd rows must reproduce the
no-override sampled token exactly — the override contributes the
embedding rows and nothing else.

Section B (behaviour): AesirEngine.generate_image_chat answers the
same question ("What is the dominant color of this image?", greedy)
for a solid red and a solid blue image, plus a text-only control
with no image at all. The two image answers must track the images.

NOTE: this program reaches the K-quant GEMM family, whose LLVM
codegen crashes on some host CPUs (pre-existing, base-identical;
see VISION_DEV_STATE.md). On such hosts it does not compile; the
assembly-level seam proof is tests/inject_mmproj.mojo.
"""
from std.sys import argv
from aesir import AesirEngine, GenerationConfig
from core.inference import _embed_tokens, forward_pass_batched
from core.mimir_well import KVCache
from core.vision_encoder import encode_image_rows
from loader.mmproj import find_mmproj_beside


def _sample_after_prefill(
    mut engine: AesirEngine,
    tokens: List[Int],
    span_start: Int,
    span_rows: List[Float32],
) raises -> Int:
    """Batched prefill identical in shape to AesirEngine's own loop
    (32-token chunks, pure prefill except the final chunk), greedy."""
    if len(tokens) < 2:
        raise Error("inject: prompt too short")
    engine.pool.offset = engine.runtime_offset
    var cfg = engine.parser.config.copy()
    var kv = KVCache(1024, cfg.kv_dim(), engine.pool, cfg.block_count)
    var cap = 32
    var pos = 0
    var next_token = -1
    while len(tokens) - 1 - pos >= cap:
        _ = forward_pass_batched(
            tokens, engine.parser, engine.pool, kv, pos, cap,
            cfg.block_count, cfg.head_dim(), cfg.head_count,
            engine.topology, engine.blocks,
            False, engine.target_backend, False, engine.target_gpu_realm,
            Float32(0.0), 40, Float32(0.9), Float32(1.0),
            True, span_start, span_rows,
        )
        pos += cap
    next_token = forward_pass_batched(
        tokens, engine.parser, engine.pool, kv, pos, len(tokens) - pos,
        cfg.block_count, cfg.head_dim(), cfg.head_count,
        engine.topology, engine.blocks,
        False, engine.target_backend, False, engine.target_gpu_realm,
        Float32(0.0), 40, Float32(0.9), Float32(1.0),
        False, span_start, span_rows,
    )
    engine.pool.offset = engine.runtime_offset
    return next_token


def main() raises:
    var args = argv()
    if len(args) < 4:
        raise Error("usage: image_chat_mmproj <model.gguf> <red.ppm> <blue.ppm>")
    var engine = AesirEngine(args[1])
    var mmproj_path = find_mmproj_beside(args[1])
    if mmproj_path == "":
        raise Error("image_chat: no mmproj beside the model")
    var question = String("What is the dominant color of this image?")
    var prompt_img = String("<|turn>user\n<|image|>" + question + "<turn|>\n<|turn>model\n")
    var prompt_txt = String("<|turn>user\n" + question + "<turn|>\n<|turn>model\n")
    var marker_id = engine.tokenizer.special_token_id("<|image|>")
    # Section A: forward control on the red image's expansion.
    var rows = encode_image_rows(mmproj_path, args[2])
    var width = engine.parser.config.embedding_length
    var n_soft = len(rows) // width
    var toks0 = engine.tokenizer.encode(prompt_img, True)
    var span_start = -1
    var markers = 0
    for i in range(len(toks0)):
        if toks0[i] == marker_id:
            markers += 1
            span_start = i
    if markers != 1:
        raise Error("image_chat: prompt must carry exactly one image marker")
    var tokens = List[Int]()
    for i in range(len(toks0)):
        if i == span_start:
            for _ in range(n_soft):
                tokens.append(marker_id)
        else:
            tokens.append(toks0[i])
    engine.pool.offset = engine.runtime_offset
    var x_plain = _embed_tokens(engine.parser, engine.pool, tokens, 0, len(tokens))
    var embd_rows = List[Float32]()
    for k in range(n_soft * width):
        embd_rows.append(
            x_plain.data.unsafe_load(span_start * width + k).cast[DType.float32]()
        )
    var tok_ctl = _sample_after_prefill(engine, tokens, span_start, embd_rows)
    var tok_plain = _sample_after_prefill(engine, tokens, -1, List[Float32]())
    print("control tokens: embd", tok_ctl, "plain", tok_plain)
    if tok_ctl != tok_plain:
        raise Error("image_chat: embedding-row control does not reproduce the plain run")
    print("image chat forward control: PASS")
    # Section B: behaviour through the engine's image chat surface.
    var config = GenerationConfig(
        max_new_tokens=48, temperature=0.0, repetition_penalty=1.0
    )
    var red = engine.generate_image_chat(prompt_img, args[2], config)
    print("RED IMAGE ANSWER:", red.text)
    var blue = engine.generate_image_chat(prompt_img, args[3], config)
    print("BLUE IMAGE ANSWER:", blue.text)
    var text_only = engine.generate_tokens_config(prompt_txt, config)
    print("TEXT-ONLY ANSWER:", text_only.text)
    print("image_chat_mmproj: DONE")
