# tests/c3_h058_smoke.mojo
# H058 — CPU smoke test binary (TEST-ONLY, not shipped).
#
# Loads a GGUF file, tokenizes a prompt with BPE, runs 20 sampler steps
# (random logits), decodes. Prints a perf JSON line. Used by
# prof/armvegr/test_cpu_smoke.py for crash detection.
# Usage: c3_h058_smoke <gguf_path>

from std.sys import argv
from std.ffi import external_call

from armvegr.gguf_loader import GGUFLoader
from armvegr.bpe import BPEModel
from armvegr.sampler import Sampler


def main() raises:
    var args = argv()
    if len(args) < 2:
        print("usage: c3_h058_smoke <gguf_path>")
        return
    var gguf_path = String(args[1])

    # Load GGUF.
    var loader = GGUFLoader()
    loader.open(gguf_path)
    var n_tensors = loader.tensor_count()
    print("SMOKE tensors:", n_tensors)

    # Tokenize.
    var bpe = BPEModel()
    bpe.load("data/armvegr/gpt2_bpe.bin", "data/armvegr/unicode_classes.bin")
    var prompt = String("Hello world")
    var ids = bpe.encode(prompt)
    print("SMOKE prompt tokens:", len(ids))

    # 20 sampler steps with random logits (greedy for speed; crash detection).
    var sampler = Sampler(0x5EED)
    var vocab = 50257
    var gen = ids.copy()
    var state = UInt64(12345)
    for step in range(20):
        var logits = List[Float32]()
        for i in range(vocab):
            state = state * 6364136223846793005 + 1442695040888963407
            var r = Float32((state >> 33) & 0xFFFF) / Float32(65535.0) - Float32(0.5)
            logits.append(r * Float32(10.0))
        var tok = sampler.greedy(logits)
        gen.append(tok)
    var text = bpe.decode(gen)
    print("SMOKE generated chars:", len(text.as_bytes()))
    print('SMOKE_JSON {"tensors": ' + String(n_tensors) + ', "prompt_tokens": '
          + String(len(ids)) + ', "generated_tokens": 20, "status": "ok"}')
