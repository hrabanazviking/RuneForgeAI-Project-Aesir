# tests/c9_h174_chunk.mojo
# H174 — chunked prefill correctness (TEST-ONLY driver, not shipped).
#
# Asserts: (1) forward_chunk() logits within 1e-3 of prefill() (token by
# token); (2) the KV cache after forward_chunk is BIT-IDENTICAL to the
# cache after prefill(); (3) prompt-cache: prefilling a prefix, then
# continuing, yields a bit-identical cache to prefilling the whole prompt
# at once (10 prefix/prompt pairs).
# Needs the TinyLlama Q4_0 model at /home/pi/models/tinyllama/... (Mimir).
# Usage: c9_h174_chunk   (run from the repo root)

from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc

from armvegr.infer import Inference
from armvegr.sp_tokenizer import SPTokenizer
from armvegr.bpe import _read_file


def _max_abs_err_f16(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
) -> Float32:
    var m = Float32(0.0)
    for i in range(n):
        var d = Float32(a.unsafe_offset(i).unsafe_load()) - Float32(
            b.unsafe_offset(i).unsafe_load()
        )
        if d < Float32(0.0):
            d = -d
        if d > m:
            m = d
    return m


def _cache_identical(a: Inference, b: Inference) -> Bool:
    # Compare the full K/V caches element-wise (bit-identity).
    var n = 22 * a.max_seq * 4 * 64
    for i in range(n):
        if a.k_cache.unsafe_offset(i).unsafe_load() != b.k_cache.unsafe_offset(i).unsafe_load():
            return False
        if a.v_cache.unsafe_offset(i).unsafe_load() != b.v_cache.unsafe_offset(i).unsafe_load():
            return False
    return True


def main() raises:
    var model_path = String("/home/pi/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_0.gguf")
    var tok = SPTokenizer()
    tok.load("data/armvegr/tinyllama_tokenizer.model")
    var data = _read_file("data/bench/e2e_prompt.txt")
    var bb = List[Int8]()
    for i in range(len(data)):
        bb.append(Int8(data[i]))
    bb.append(0)
    var text = String(unsafe_from_utf8_ptr=bb.unsafe_ptr())
    var ids = tok.encode(text)
    print("prompt tokens: " + String(len(ids)))

    # Test 1+2: chunked vs token-by-token on the first 96 tokens.
    var N = 96
    var prompt = List[Int]()
    for i in range(N):
        prompt.append(ids[i])

    var inf1 = Inference(1024)
    inf1.load(model_path)
    var lp1 = inf1.prefill(prompt)

    var inf2 = Inference(1024)
    inf2.model = inf1.model.shallow_copy()
    var lp2 = inf2.forward_chunk(prompt, 32)

    var err = _max_abs_err_f16(lp1, lp2, 32000)
    print("chunked-vs-prefill max_abs_err: " + String(err))
    if err > Float32(1e-3):
        print("T1-FAIL logits differ")
        return
    print("T1 logits within 1e-3: PASS")
    if not _cache_identical(inf1, inf2):
        print("T2-FAIL KV cache differs")
        return
    print("T2 KV cache bit-identical: PASS")
    inf2.free()

    # Test 3: prompt-cache — 10 prefix/prompt pairs, bit-identical caches.
    for trial in range(10):
        var plen = 32 + trial * 4  # prefix length 32..68
        var pre = List[Int]()
        var rest = List[Int]()
        for i in range(plen):
            pre.append(ids[i])
        for i in range(plen, N):
            rest.append(ids[i])
        var ia = Inference(1024)
        ia.model = inf1.model.shallow_copy()
        _ = ia.prefill(pre)
        for i in range(len(rest)):
            _ = ia.forward(rest[i])
        var ib = Inference(1024)
        ib.model = inf1.model.shallow_copy()
        var full = List[Int]()
        for i in range(N):
            full.append(ids[i])
        _ = ib.prefill(full)
        if not _cache_identical(ia, ib):
            print("T3-FAIL pair " + String(trial))
            return
        ia.free()
        ib.free()
    print("T3 prompt-cache bit-identical (10 pairs): PASS")

    inf1.free()
    print("H174-CHUNK-ALL-PASS")
