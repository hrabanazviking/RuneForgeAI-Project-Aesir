"""Opt-in physical Gemma 4 CUDA execution; no synthetic model substitution."""
from std.sys import argv
from core.gemma4_cuda import Gemma4CUDASession
from loader.tokenizer import RuneStreamDecoder
from std.ffi import external_call

def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_gemma4_cuda <model.gguf>")
    var session = Gemma4CUDASession(args[1])
    var tokens: List[Int] = [2]
    session.tokenizer.append_message(tokens, "user", "What is two plus two? Answer in one short sentence.")
    session.tokenizer.append_generation_prompt(tokens)
    print("Prompt IDs:", tokens)
    var next_token = -1
    for i in range(len(tokens)):
        next_token = session.forward(tokens[i], i == len(tokens) - 1)
    var decoder = RuneStreamDecoder()
    for _ in range(64):
        if next_token == 106 or next_token == 1:
            print("\nEOS", next_token)
            break
        var spelling = session.tokenizer.vocabulary.vocab[next_token].replace("▁", " ")
        print(decoder.decode_token(spelling), end="")
        _ = external_call["fflush", Int32](Int(0))
        next_token = session.forward(next_token)
