"""Opt-in real-geometry preprocessing proof against a real mmproj spec.

Usage: preprocess_mmproj <model.gguf> <image.ppm>
Discovers the model's mmproj, validates the vision spec, preprocesses the
PPM through loader/image_prep, and prints patch count, a checksum-style
sum, and spot values for comparison with an independent oracle.
"""
from std.sys import argv
from loader.mmproj import MmprojFile, find_mmproj_beside
from loader.image_prep import load_ppm_file, preprocess_image


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: preprocess_mmproj <model.gguf> <image.ppm>")
    var mmproj_path = find_mmproj_beside(args[1])
    if mmproj_path == "":
        raise Error("no mmproj found beside " + args[1])
    var mmproj = MmprojFile(mmproj_path)
    var spec = mmproj.vision_spec()
    var image = load_ppm_file(args[2])
    var patches = preprocess_image(image, spec)
    var expected = spec.patch_count() * spec.patch_size * spec.patch_size * 3
    if len(patches) != expected:
        raise Error("patch vector count mismatch")
    var total = Float32(0.0)
    for i in range(len(patches)):
        total += patches[i]
    print("patch vectors:", spec.patch_count(), "values:", len(patches))
    print("sum:", total)
    print("first patch first values:", patches[0], patches[1], patches[2], patches[3])
    print("last value:", patches[len(patches) - 1])
    print("preprocess real-geometry: PASS")
