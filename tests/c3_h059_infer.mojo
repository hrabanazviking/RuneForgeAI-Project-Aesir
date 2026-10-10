# tests/c3_h059_infer.mojo
# H059 — TinyLlama inference driver (TEST-ONLY, not shipped).
#
# Loads the TinyLlama Q4_0 GGUF, tokenizes a prompt with the SentencePiece
# tokenizer, runs the decode loop, and prints generated text + JSON.
# Usage: c3_h059_infer <gguf_path> <max_tokens>

from std.sys import argv

from armvegr.infer import Inference
from armvegr.sp_tokenizer import SPTokenizer
from armvegr.sampler import Sampler


def main() raises:
    var args = argv()
    if len(args) < 3:
        print("usage: c3_h059_infer <gguf_path> <max_tokens>")
        return
    var gguf_path = String(args[1])
    var max_tokens = Int(args[2])

    print("H059 loading model...")
    var inf = Inference(256)
    inf.load(gguf_path)
    print("H059 model loaded")

    var tok = SPTokenizer()
    tok.load("data/armvegr/tinyllama_tokenizer.model")

    # Chat prompt.
    var prompt = String("<|system|>\nYou are a helpful assistant.\n<|user|>\nWhat is the meaning of hospitality?\n<|assistant|>\n")
    var ids = tok.encode(prompt)
    print("H059 prompt tokens:", len(ids))

    # Prefill.
    var logits_p = inf.forward(ids[0])
    for i in range(1, len(ids)):
        logits_p = inf.forward(ids[i])

    # Decode.
    var sampler = Sampler(12345)
    var gen_ids = List[Int]()
    for i in range(len(ids)):
        gen_ids.append(ids[i])
    for step in range(max_tokens):
        var logits = List[Float32]()
        for i in range(32000):
            logits.append(Float32(logits_p.unsafe_offset(i).unsafe_load()))
        var next_tok = sampler.sample(
            logits, Float32(0.7), 40, Float32(0.95), gen_ids, Float32(1.1)
        )
        gen_ids.append(next_tok)
        if next_tok == 2:  # EOS
            break
        if (step + 1) % 10 == 0:
            print("H059 step", step + 1)
        logits_p = inf.forward(next_tok)

    var text = tok.decode(gen_ids)
    print("H059-GENERATED-START")
    print(text)
    print("H059-GENERATED-END")
    print("H059 tokens generated:", len(gen_ids) - len(ids))
