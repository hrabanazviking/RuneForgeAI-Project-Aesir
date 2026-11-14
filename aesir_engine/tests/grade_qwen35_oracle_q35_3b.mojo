# Q35-3b oracle grade driver (not a suite test).
#
# Loads the REAL qwen35 GGUF on the Aesir CPU engine through the
# Q35-3r Q8_0-RESIDENT path (numerics proven identical to the default
# path at fixture grade: logits diff 0.0) and teacher-forces ONE
# prompt per process invocation over the token stream written by
# probe_qwen35_tokens_q35_3b (tokenized once from the file's own
# tokenizer; the llama.cpp comparator consumes the identical IDs).
#
# Modes:
#   grade <gguf> <tokens.txt> <pidx> <comp.csv> <out.csv>
#     Per-token forward; after each position the KVCache logit-row
#     sink row is graded with the banked A-045 arithmetic
#     (core.parity_battery parity_logit_rank/gap): rank/gap of the
#     TRUE next token and of the comparator's argmax in Aesir's row.
#     out.csv: prompt,pos,true,aesir_argmax,rank_true,gap_true,
#              rank_comp,gap_comp
#   gen <gguf> <tokens.txt> <pidx> <n>
#     Greedy generation of n tokens from the prompt; prints IDs and
#     the detokenized text (RuneStreamDecoder over the file's own
#     tokenizer).
#   batch <gguf> <tokens.txt> <pidx>
#     Batched forward over the same prompt in one chunk; prints the
#     final-row argmax and the state/conv/logit diffs vs a per-token
#     run in the same process (real-shape extension of Q35-3a (c)).

from std.sys import argv

from core.mimir_well import KVCache
from core.parity_battery import parity_logit_gap, parity_logit_rank
from aesir import AesirEngine, GenerationConfig
from loader.tokenizer import RuneStreamDecoder


def read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as source:
        text = source.read()
    return text


def parse_ints(text: String) -> List[Int]:
    var out = List[Int]()
    var bytes = text.as_bytes()
    var cur = 0
    var neg = False
    var in_num = False
    for i in range(len(bytes)):
        var b = Int(bytes[i])
        if b == 45 and not in_num:
            neg = True
            in_num = True
            cur = 0
        elif b >= 48 and b <= 57:
            if not in_num:
                in_num = True
                neg = False
                cur = 0
            cur = cur * 10 + (b - 48)
        else:
            if in_num:
                out.append(-cur if neg else cur)
                in_num = False
                neg = False
    if in_num:
        out.append(-cur if neg else cur)
    return out^


def prompt_tokens(text: String, pidx: Int) raises -> List[Int]:
    var lines = text.split("\n")
    if pidx < 0 or pidx >= len(lines):
        raise Error("prompt index out of range")
    return parse_ints(String(lines[pidx]))


def comp_argmax_for(text: String, pidx: Int) -> List[Int]:
    # comp.csv rows: prompt,pos,true,argmax,rank_true,gap_true_milli...
    var out = List[Int]()
    var lines = text.split("\n")
    for li in range(len(lines)):
        var nums = parse_ints(String(lines[li]))
        if len(nums) >= 4 and nums[0] == pidx:
            while len(out) <= nums[1]:
                out.append(-1)
            out[nums[1]] = nums[3]
    return out^


def argmax_row(row: List[Float32]) -> Int:
    var best = 0
    for i in range(len(row)):
        if row[i] > row[best]:
            best = i
    return best


def is_finite(v: Float32) -> Bool:
    return v == v and v < Float32(1e30) and v > Float32(-1e30)


def main() raises:
    var arguments = argv()
    if len(arguments) < 5:
        raise Error("usage: grade|gen|batch ... (see header)")
    var mode = arguments[1]
    var engine = AesirEngine(arguments[2], knowledge_capacity=1, qwen35_resident=True)
    if engine.parser.config.architecture != "qwen35":
        raise Error("architecture is not qwen35")
    print("LOADED resident:", engine.parser.config.architecture, "blocks:", engine.parser.config.block_count, "vocab:", engine.tokenizer.vocab_size)
    var cfg = GenerationConfig(max_new_tokens=48, temperature=Float32(0.0), top_k=40, top_p=Float32(0.9), repetition_penalty=Float32(1.0), seed=UInt64(42))
    var tokens = prompt_tokens(read_text(arguments[3]), Int(atol(arguments[4])))
    print("PROMPT TOKENS:", len(tokens))
    var ctx = len(tokens) + 64
    if mode == String("grade"):
        var comp = comp_argmax_for(read_text(arguments[5]), Int(atol(arguments[4])))
        engine.pool.offset = engine.runtime_offset
        var kv = KVCache(ctx, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
        kv.capture_logit_row = True
        var out = String("prompt,pos,true,aesir_argmax,rank_true,gap_true_milli,rank_comp,gap_comp_milli\n")
        for pos in range(len(tokens) - 1):
            _ = engine._forward_position(tokens, kv, pos, cfg, False)
            var row = kv.last_logit_row.copy()
            for i in range(len(row)):
                if not is_finite(row[i]):
                    raise Error("non-finite logit at pos " + String(pos))
            var true_next = tokens[pos + 1]
            var rt = parity_logit_rank(row, true_next)
            var gt = parity_logit_gap(row, true_next)
            var ca = comp[pos] if pos < len(comp) else -1
            var rc = parity_logit_rank(row, ca)
            var gc = parity_logit_gap(row, ca)
            out += String(arguments[4]) + "," + String(pos) + "," + String(true_next) + "," + String(argmax_row(row)) + "," + String(rt) + "," + String(Int(gt * Float32(1000.0))) + "," + String(rc) + "," + String(Int(gc * Float32(1000.0))) + "\n"
        var handle = open(arguments[6], "w")
        handle.write(out)
        handle.close()
        print("GRADE WRITTEN:", arguments[6])
    elif mode == String("gen"):
        var n = Int(atol(arguments[5]))
        engine.pool.offset = engine.runtime_offset
        var kv = KVCache(ctx + n, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
        var stream = tokens.copy()
        var nxt = -1
        for pos in range(len(stream)):
            nxt = engine._forward_position(stream, kv, pos, cfg, False)
        var gen = List[Int]()
        for _ in range(n):
            gen.append(nxt)
            if nxt == engine.tokenizer.eos_token_id:
                break
            stream.append(nxt)
            nxt = engine._forward_position(stream, kv, len(stream) - 1, cfg, False)
        var ids = String("")
        for i in range(len(gen)):
            ids += String(gen[i]) + String(" ")
        print("GEN IDS:", ids)
        var dec = RuneStreamDecoder()
        var text = String("")
        for i in range(len(gen)):
            text += dec.decode_id(gen[i], engine.tokenizer)
        text += dec.flush()
        print("GEN TEXT BEGIN")
        print(text)
        print("GEN TEXT END")
    elif mode == String("batch"):
        engine.pool.offset = engine.runtime_offset
        var kv1 = KVCache(ctx, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
        kv1.capture_logit_row = True
        var n1 = -1
        for pos in range(len(tokens)):
            n1 = engine._forward_position(tokens, kv1, pos, cfg, False)
        var row1 = kv1.last_logit_row.copy()
        ref st1 = engine.qwen35_state
        var ns = st1.ssm_layer_count * st1.head_count * st1.d_state * st1.d_state
        var s1 = List[Float32]()
        for i in range(ns):
            s1.append(Float32(st1.s_data.unsafe_load(i)))
        engine.pool.offset = engine.runtime_offset
        var kv2 = KVCache(ctx, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
        kv2.capture_logit_row = True
        var n2 = engine._forward_batch(tokens, kv2, 0, len(tokens), cfg, False)
        var row2 = kv2.last_logit_row.copy()
        ref st2 = engine.qwen35_state
        var ds = Float32(0.0)
        for i in range(ns):
            var d = s1[i] - Float32(st2.s_data.unsafe_load(i))
            if d < Float32(0.0):
                d = -d
            if d > ds:
                ds = d
        var dl = Float32(0.0)
        for i in range(len(row1)):
            var d = row1[i] - row2[i]
            if d < Float32(0.0):
                d = -d
            if d > dl:
                dl = d
        print("BATCH CHECK: per-token next", n1, " batched next", n2, " s_data max_abs_diff", ds, " final-logits max_abs_diff", dl)
    else:
        raise Error("unknown mode: " + mode)
