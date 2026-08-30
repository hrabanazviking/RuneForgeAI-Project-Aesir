"""Opt-in native metadata/tokenizer inspection of a caller-owned real GGUF."""
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from loader.gemma4_tokenizer import Gemma4Tokenizer

def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: inspect_gemma4 <model.gguf> [text]")
    var model = PackedGGUF(args[1])
    print("architecture=", model.text("general.architecture"), "tensors=", len(model.tensors))
    var tokenizer = Gemma4Tokenizer(model)
    for i in range(2, len(args)):
        var ids = tokenizer.encode(args[i], True)
        print(ids)
