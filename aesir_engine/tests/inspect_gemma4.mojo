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
    var dimensions: List[String] = [
        "gemma4.block_count", "gemma4.embedding_length",
        "gemma4.feed_forward_length", "gemma4.attention.head_count",
        "gemma4.attention.head_count_kv", "gemma4.attention.shared_kv_layers",
    ]
    for key in dimensions:
        var kind = model.field_types[key]
        print(key, " type=", kind, end="")
        if kind == 9:
            var offset = model.fields[key]
            var element_type = Int(model.source._read_u32(offset))
            var count = Int(model.source._read_u64(offset + 4))
            print(" element_type=", element_type, " count=", count, " values=", end="")
            var cursor = offset + 12
            for _ in range(count):
                print(model._integer_value(key, element_type, cursor), end=" ")
                cursor = model.source.skip_value(UInt32(element_type), cursor)
            print()
        else:
            print(" value=", model.integer(key))
    var tokenizer = Gemma4Tokenizer(model)
    for i in range(2, len(args)):
        var ids = tokenizer.encode(args[i], True)
        print(ids)
