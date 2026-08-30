"""Opt-in native Llama 3 tokenizer inspection against an external real GGUF."""
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from loader.llama3_tokenizer import Llama3Tokenizer
from loader.tokenizer import RuneStreamDecoder

def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: inspect_llama3 <model.gguf> [text...]")
    var model = PackedGGUF(args[1])
    var tokenizer = Llama3Tokenizer(model)
    for i in range(2, len(args)):
        var encoded = tokenizer.encode(args[i], True)
        print(encoded)
        var decoder = RuneStreamDecoder()
        var decoded = String("")
        for j in range(1, len(encoded)):
            decoded += tokenizer.decode(encoded[j], decoder)
        decoded += decoder.flush()
        if decoded != args[i]:
            raise Error("Llama 3 UTF-8 round trip failed")
    var chat: List[Int] = [128000]
    tokenizer.append_message(chat, "system", "You are a captain.")
    tokenizer.append_message(chat, "user", "Hello.")
    tokenizer.append_header(chat, "assistant")
    print(chat)
