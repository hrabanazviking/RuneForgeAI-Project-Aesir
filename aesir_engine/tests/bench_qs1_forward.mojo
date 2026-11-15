"""QS-1 forward-path timing on the REAL 27B file (resident).
Builds a 435-token stream by repeating the p5 token line, then
times: (a) per-token _forward_position prefill, (b) batched
_forward_batch prefill at the engine cap, (c) 16 decode steps
via _forward_position after (b). Prints _prefill_batch_cap()."""
from std.ffi import external_call
from std.collections import InlineArray
from core.mimir_well import KVCache
from aesir import AesirEngine, GenerationConfig


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("clock_gettime failed")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as source:
        text = source.read()
    return text


def parse_ints(text: String) -> List[Int]:
    var out = List[Int]()
    var cur = 0
    var in_num = False
    for i in range(len(text.as_bytes())):
        var b = Int(text.as_bytes()[i])
        if b >= 48 and b <= 57:
            if not in_num:
                in_num = True
                cur = 0
            cur = cur * 10 + (b - 48)
        else:
            if in_num:
                out.append(cur)
                in_num = False
    if in_num:
        out.append(cur)
    return out^


def main() raises:
    from std.sys import argv
    var args = argv()
    var engine = AesirEngine(args[1], knowledge_capacity=1, qwen35_resident=True)
    var lines = read_text(args[2]).split("\n")
    var seed = parse_ints(String(lines[5]))
    var tokens = List[Int]()
    while len(tokens) < 435:
        for t in seed:
            tokens.append(t)
    print("STREAM TOKENS:", len(tokens))
    print("PREFILL_BATCH_CAP:", engine._prefill_batch_cap())
    var cfg = GenerationConfig(max_new_tokens=48, temperature=Float32(0.0), top_k=40, top_p=Float32(0.9), repetition_penalty=Float32(1.0), seed=UInt64(42))
    var ctx = len(tokens) + 64
    engine.pool.offset = engine.runtime_offset
    var kv1 = KVCache(ctx, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
    var t0 = monotonic_ns()
    for p in range(len(tokens) - 1):
        _ = engine._forward_position(tokens, kv1, p, cfg, True)
    var last1 = engine._forward_position(tokens, kv1, len(tokens) - 1, cfg, False)
    var t1 = monotonic_ns()
    print("PERT TOKEN PREFILL ms:", Float64(t1 - t0) / 1e6, "tok/s:", Float64(len(tokens)) / (Float64(t1 - t0) / 1e9), "last:", last1)
    engine.pool.offset = engine.runtime_offset
    var kv2 = KVCache(ctx, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
    var cap = engine._prefill_batch_cap()
    var t2 = monotonic_ns()
    var pos = 0
    var next_tok = -1
    if cap > 1:
        while len(tokens) - 1 - pos >= cap:
            _ = engine._forward_batch(tokens, kv2, pos, cap, cfg, True)
            pos += cap
        next_tok = engine._forward_batch(tokens, kv2, pos, len(tokens) - pos, cfg, False)
    else:
        for p in range(len(tokens) - 1):
            _ = engine._forward_position(tokens, kv2, p, cfg, True)
        next_tok = engine._forward_position(tokens, kv2, len(tokens) - 1, cfg, False)
    var t3 = monotonic_ns()
    print("BATCHED PREFILL ms:", Float64(t3 - t2) / 1e6, "tok/s:", Float64(len(tokens)) / (Float64(t3 - t2) / 1e9), "next:", next_tok)
    var stream = tokens.copy()
    stream.append(next_tok)
    var t4 = monotonic_ns()
    var nt = next_tok
    for i in range(16):
        nt = engine._forward_position(stream, kv2, len(stream) - 1, cfg, False)
        stream.append(nt)
    var t5 = monotonic_ns()
    print("DECODE 16 ms:", Float64(t5 - t4) / 1e6, "tok/s:", Float64(16) / (Float64(t5 - t4) / 1e9))
    print("QS1_FORWARD_DONE")
