"""Opt-in structural inspection of a real model's mmproj (vision) GGUF.

Usage: inspect_mmproj <model.gguf>
Discovers the mmproj beside the model, parses its full metadata and tensor
inventory, validates the vision tower spec, and prints the structure report.
Model weights are caller-owned and never enter Git (TESTING_PROTOCOL.md).
"""
from std.sys import argv
from loader.mmproj import MmprojFile, find_mmproj_beside


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: inspect_mmproj <model.gguf>")
    var mmproj_path = find_mmproj_beside(args[1])
    if mmproj_path == "":
        raise Error("no mmproj found beside " + args[1])
    var mmproj = MmprojFile(mmproj_path)
    var spec = mmproj.vision_spec()
    print(mmproj.describe(spec), end="")
    if not spec.present:
        raise Error("mmproj carries no vision tower")
    print("vision spec validation: PASS")
