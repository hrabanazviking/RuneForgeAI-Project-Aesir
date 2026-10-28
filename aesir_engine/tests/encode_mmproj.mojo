"""Opt-in full vision-encoder proof on real weights (vision Slice 3b).

Usage: encode_mmproj <model.gguf> <image.ppm> <dumpdir>
Discovers the mmproj beside the model, preprocesses the image (Slice 2),
then runs the pinned gemma4v encoder (design doc section 5): 2x-1 input
scaling, patch embedding, factorized position add, 16 blocks, pooling,
projector. Each stage is written to <dumpdir>/stage_<name>.txt (one token
per line) and its aggregates printed, for per-stage comparison against the
independent numpy oracle (step 1 of the slice 3b plan).
"""
from std.sys import argv
from loader.mmproj import MmprojFile, find_mmproj_beside
from loader.image_prep import load_ppm_file, preprocess_image
from core.vision_encoder import (
    add_position_embeddings,
    patch_embed,
    pool_tokens,
    project_tokens,
    vision_block,
)
from hailbru.syscall import os_host_architecture, write_file_str


def _dump_stage(
    dumpdir: String, name: String, values: List[Float32], rows: Int, width: Int
) raises:
    var text = String("")
    for r in range(rows):
        var base = r * width
        for i in range(width):
            text += String(values[base + i]) + " "
        text += "\n"
    write_file_str(
        os_host_architecture(), dumpdir + "/" + name + ".txt", text
    )
    var total = Float32(0.0)
    var peak = Float32(0.0)
    for i in range(len(values)):
        total += values[i]
        var magnitude = values[i]
        if magnitude < 0.0:
            magnitude = -magnitude
        if magnitude > peak:
            peak = magnitude
    print(
        name, "sum:", total, "maxabs:", peak,
        "first4:", values[0], values[1], values[2], values[3],
    )


def main() raises:
    var args = argv()
    if len(args) < 4:
        raise Error("usage: encode_mmproj <model.gguf> <image.ppm> <dumpdir>")
    var mmproj_path = find_mmproj_beside(args[1])
    if mmproj_path == "":
        raise Error("no mmproj found beside " + args[1])
    var mmproj = MmprojFile(mmproj_path)
    var spec = mmproj.vision_spec()
    var tokens = spec.patch_count()
    var grid = spec.patch_grid()
    var hidden = spec.embedding_length
    var dumpdir = String(args[3])
    var image = load_ppm_file(args[2])
    var patches = preprocess_image(image, spec)
    # Input scaling 2x-1 before the patch projection (gemma4v.cpp:9-11).
    var scaled = List[Float32]()
    scaled.reserve(len(patches))
    for i in range(len(patches)):
        scaled.append(patches[i] * Float32(2.0) - Float32(1.0))
    var patch_weights = mmproj.tensor_f32("v.patch_embd.weight")
    var x = patch_embed(
        scaled, patch_weights, tokens, spec.patch_size, hidden
    )
    _dump_stage(dumpdir, "stage_patch_embed", x, tokens, hidden)
    var pos_table = mmproj.tensor_f32("v.position_embd.weight")
    var pos_rows = mmproj.tensors["v.position_embd.weight"].d1
    x = add_position_embeddings(x, pos_table, tokens, grid, hidden, pos_rows)
    _dump_stage(dumpdir, "stage_pos_add", x, tokens, hidden)
    for b in range(spec.block_count):
        x = vision_block(mmproj, x, spec, b)
        if b == 0:
            _dump_stage(dumpdir, "stage_block0", x, tokens, hidden)
    _dump_stage(dumpdir, "stage_block15", x, tokens, hidden)
    var pooled = pool_tokens(x, grid, hidden, 3)
    var pooled_rows = len(pooled) // hidden
    _dump_stage(dumpdir, "stage_pooled", pooled, pooled_rows, hidden)
    var projected = project_tokens(mmproj, pooled, spec)
    _dump_stage(
        dumpdir, "stage_projected", projected, pooled_rows, spec.projection_dim
    )
    print("encode real-weights: PASS")
