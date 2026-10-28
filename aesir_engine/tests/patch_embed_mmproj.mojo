"""Opt-in patch-embedding proof on real weights (vision Slice 3a).

Usage: patch_embed_mmproj <model.gguf> <image.ppm>
Runs preprocessing (Slice 2), loads v.patch_embd.weight from the real
mmproj, projects all patches to vision embeddings, and prints summary
statistics for comparison with an independent oracle.
"""
from std.sys import argv
from loader.mmproj import MmprojFile, find_mmproj_beside
from loader.image_prep import load_ppm_file, preprocess_image
from core.vision_encoder import patch_embed


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: patch_embed_mmproj <model.gguf> <image.ppm>")
    var mmproj_path = find_mmproj_beside(args[1])
    if mmproj_path == "":
        raise Error("no mmproj found beside " + args[1])
    var mmproj = MmprojFile(mmproj_path)
    var spec = mmproj.vision_spec()
    var image = load_ppm_file(args[2])
    var patches = preprocess_image(image, spec)
    var weights = mmproj.tensor_f32("v.patch_embd.weight")
    var embeddings = patch_embed(
        patches, weights, spec.patch_count(), spec.patch_size,
        spec.embedding_length,
    )
    if len(embeddings) != spec.patch_count() * spec.embedding_length:
        raise Error("embedding count mismatch")
    var total = Float32(0.0)
    var peak = Float32(0.0)
    for i in range(len(embeddings)):
        total += embeddings[i]
        var magnitude = embeddings[i]
        if magnitude < 0.0:
            magnitude = -magnitude
        if magnitude > peak:
            peak = magnitude
    print("embeddings:", spec.patch_count(), "x", spec.embedding_length)
    print("sum:", total)
    print("max abs:", peak)
    print(
        "first embedding first values:",
        embeddings[0], embeddings[1], embeddings[2], embeddings[3],
    )
    print("patch embed real-weights: PASS")
