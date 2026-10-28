"""Opt-in slice 4 integration proof on the real model pair (design
doc section 4, proof plan (b)).

Usage: inject_mmproj <model.gguf> <image.ppm> <oracle_projected.bin>

<oracle_projected.bin> is the independent numpy oracle's projected
stage as raw little-endian Float32 (16 x 1536 for the gemma4 tower).

Proves, on the real weights:
  1. Assembly: _embed_tokens + apply_embedding_span puts exactly the
     proven projected encoder rows at the image span (compared both
     against the in-process encoder output, f16-exact after the seam
     cast, and against the external oracle within the established
     tolerance), and leaves every other position bit-identical to
     the plain embedding stream.
  The forward-level controls (embedding-row control through a full
  prefill, and the behavioural image chat) live in
  tests/image_chat_mmproj.mojo, which needs the full forward graph.
"""
from std.sys import argv
from std.memory.alloc import alloc, Layout
from core.inference import _embed_tokens, apply_embedding_span
from core.mimir_well import MimirWell, RuneTensor, f16
from core.vision_encoder import encode_image_rows
from loader.gguf import GGUFSeer
from loader.mmproj import find_mmproj_beside
from loader.tokenizer import RuneWeaver
from hailbru.syscall import os_host_architecture, read_file_bytes


def _load_f32_bin(path: String, count: Int) raises -> List[Float32]:
    var bytes = read_file_bytes(os_host_architecture(), path, Int64(16 * 1024 * 1024))
    if len(bytes) != count * 4:
        raise Error("inject: oracle bin size mismatch")
    var buf = alloc(Layout[Float32](count=count))^.unsafe_leak()
    var byte_ptr = buf.unsafe_bitcast[UInt8]()
    for i in range(count * 4):
        byte_ptr.unsafe_store(i, bytes[i])
    var out = List[Float32]()
    out.reserve(count)
    for i in range(count):
        out.append(buf.unsafe_load(i))
    buf.unsafe_free()
    return out^


def main() raises:
    var args = argv()
    if len(args) < 4:
        raise Error("usage: inject_mmproj <model.gguf> <image.ppm> <oracle_projected.bin>")
    # Loader-level staging (metadata + tensor map, no generic
    # tensor-set validation): the generic engine's admission
    # contract is llama-family-shaped, while this LM's execution
    # route is the PackedGGUF/CUDA session. The assembly seam
    # needs only the tokenizer, the config, and token_embd.
    var pool = MimirWell(1 << 30)
    var seer = GGUFSeer(args[1])
    var weaver = RuneWeaver()
    seer._open_and_map()
    seer._parse_header()
    var table_offset = seer._parse_metadata(weaver)
    seer._parse_tensors(table_offset, pool)
    var mmproj_path = find_mmproj_beside(args[1])
    if mmproj_path == "":
        raise Error("inject: no mmproj beside the model")
    var rows = encode_image_rows(mmproj_path, args[2])
    var width = seer.config.embedding_length
    if width <= 0 or len(rows) % width != 0:
        raise Error("inject: encoder width mismatch")
    var n_soft = len(rows) // width
    var oracle = _load_f32_bin(args[3], len(rows))
    var marker_id = weaver.special_token_id("<|image|>")
    var prompt = String("<|turn>user\n<|image|>What is the dominant color of this image?<turn|>\n<|turn>model\n")
    var toks0 = weaver.encode(prompt, True)
    var span_start = -1
    var markers = 0
    for i in range(len(toks0)):
        if toks0[i] == marker_id:
            markers += 1
            span_start = i
    if markers != 1:
        raise Error("inject: prompt must carry exactly one image marker")
    var tokens = List[Int]()
    for i in range(len(toks0)):
        if i == span_start:
            for _ in range(n_soft):
                tokens.append(marker_id)
        else:
            tokens.append(toks0[i])
    print("tokens:", len(tokens), "span_start:", span_start, "n_soft:", n_soft)
    var x = _embed_tokens(seer, pool, tokens, 0, len(tokens))
    var x_plain = _embed_tokens(seer, pool, tokens, 0, len(tokens))
    apply_embedding_span(x, rows, span_start, 0)
    var max_oracle = Float32(0.0)
    var max_engine = Float32(0.0)
    var neighbour_bad = 0
    var span_diff = 0
    for r in range(len(tokens)):
        for j in range(width):
            var v = x.data.unsafe_load(r * width + j).cast[DType.float32]()
            var vp = x_plain.data.unsafe_load(r * width + j).cast[DType.float32]()
            if span_start <= r and r < span_start + n_soft:
                var src = rows[(r - span_start) * width + j]
                var d1 = v - oracle[(r - span_start) * width + j]
                if d1 < 0.0:
                    d1 = -d1
                if d1 > max_oracle:
                    max_oracle = d1
                var d2 = v - src
                if d2 < 0.0:
                    d2 = -d2
                if d2 > max_engine:
                    max_engine = d2
                if v != vp:
                    span_diff += 1
            else:
                if v != vp:
                    neighbour_bad += 1
    print("assembly max|span-oracle|:", max_oracle, "max|span-engine|:", max_engine)
    print("neighbour mismatches:", neighbour_bad, "span elements changed:", span_diff)
    if max_oracle > Float32(0.02) or max_engine > Float32(0.005):
        raise Error("inject: span rows do not match the proven encoder output")
    if neighbour_bad != 0 or span_diff == 0:
        raise Error("inject: embedding stream seam is not exact")
    print("inject assembly: PASS")
    print("inject_mmproj: PASS")
