# tests/grade_qwen35_hip_q35_6b.mojo
# Q35-6b oracle grade driver for the HIP qwen35 executor on the
# REAL file (not a suite test). Mirror of the Q35-3b CPU grade
# driver with the engines swapped: teacher-forces ONE banked
# token stream (q35-3b-tokens.txt, tokenized once from the
# file's own tokenizer) through Qwen35HipExecutor and grades
# each position's device logit row with the banked A-045
# arithmetic (core.parity_battery): rank/gap of the TRUE next
# token and of the CPU path's argmax (from the banked Q35-3b v2
# CSV for the same prompt) in the HIP row, plus argmax
# agreement HIP vs CPU. Near-tie band: rank <= 2, sub-logit gap.
#
# Modes:
#   grade <gguf> <tokens.txt> <pidx> <cpu_csv> <out.csv>
#     out.csv: prompt,pos,true,hip_argmax,cpu_argmax,
#              rank_cpu,gap_cpu_milli,rank_true,gap_true_milli
#   gen <gguf> <tokens.txt> <pidx> <n>
#     Device greedy generation of n tokens from the prompt;
#     prints IDs and detokenized text (file's own tokenizer via
#     a resident AesirEngine used for decode only).

from std.sys import argv

from loader.packed_gguf import PackedGGUF
from core.parity_battery import parity_logit_rank, parity_logit_gap
from core.qwen35_hip import Qwen35HipExecutor
from core.hip_gemv import HipGemv
from aesir import AesirEngine


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


def cpu_argmax_for(csv_text: String, pidx: Int) raises -> List[Int]:
    var out = List[Int]()
    var lines = csv_text.split("\n")
    for li in range(1, len(lines)):
        var fields = String(lines[li]).split(",")
        if len(fields) < 4:
            continue
        if Int(atol(String(fields[0]))) != pidx:
            continue
        out.append(Int(atol(String(fields[3]))))
    return out^


def argmax_row(row: List[Float32]) -> Int:
    var best = 0
    for i in range(len(row)):
        if row[i] > row[best]:
            best = i
    return best


def main() raises:
    var arguments = argv()
    if len(arguments) < 6:
        raise Error("usage: grade|gen ... (see header)")
    if not HipGemv.gate_ok():
        raise Error("Q35-6b: HIP gate absent; grade not run (honest-absent)")
    var mode = arguments[1]
    var tokens = prompt_tokens(read_text(arguments[3]), Int(atol(arguments[4])))
    print("PROMPT TOKENS:", len(tokens))
    var ctx = len(tokens) + 128
    var ex = Qwen35HipExecutor(arguments[2], ctx)
    print("EXECUTOR LOADED: layers=", ex.profile.layer_count, " vocab=", ex.profile.vocabulary_size)
    if mode == String("grade"):
        var cpu = cpu_argmax_for(read_text(arguments[5]), Int(atol(arguments[4])))
        var out = String("prompt,pos,true,hip_argmax,cpu_argmax,rank_cpu,gap_cpu_milli,rank_true,gap_true_milli\n")
        var agree = 0
        var in_band = 0
        var rank1 = 0
        var worst_gap = Float32(0.0)
        for pos in range(len(tokens) - 1):
            var row = ex.forward_chunk(List[Int]([tokens[pos]]), pos, True, 1)
            for i in range(len(row)):
                if row[i] != row[i] or row[i] > Float32(1e30) or row[i] < Float32(-1e30):
                    raise Error("non-finite logit at pos " + String(pos))
            var true_next = tokens[pos + 1]
            var ha = argmax_row(row)
            var ca = cpu[pos] if pos < len(cpu) else -1
            var rc = parity_logit_rank(row, ca)
            var gc = parity_logit_gap(row, ca)
            var rt = parity_logit_rank(row, true_next)
            var gt = parity_logit_gap(row, true_next)
            if ha == ca:
                agree += 1
            if rc == 1:
                rank1 += 1
            if rc >= 1 and rc <= 2 and gc < Float32(1.0):
                in_band += 1
            if gc > worst_gap:
                worst_gap = gc
            out += String(arguments[4]) + "," + String(pos) + "," + String(true_next) + "," + String(ha) + "," + String(ca) + "," + String(rc) + "," + String(Int(gc * Float32(1000.0))) + "," + String(rt) + "," + String(Int(gt * Float32(1000.0))) + "\n"
        var handle = open(arguments[6], "w")
        handle.write(out)
        handle.close()
        print("GRADE WRITTEN:", arguments[6])
        print("GRADE SUMMARY: positions=", len(tokens) - 1, " cpu_argmax_rank1_in_hip=", rank1, " in_near_tie_band=", in_band, " argmax_agreement=", agree, " worst_gap_cpu=", worst_gap)
    elif mode == String("gen"):
        var n = Int(atol(arguments[5]))
        var engine = AesirEngine(arguments[2], knowledge_capacity=1, qwen35_resident=True)
        var stream = tokens.copy()
        var logits = ex.forward_chunk(tokens.copy(), 0, True, 32)
        var generated = List[Int]()
        var pos = len(tokens)
        for _ in range(n):
            var nxt = argmax_row(logits)
            generated.append(nxt)
            stream.append(nxt)
            logits = ex.forward_chunk(List[Int]([nxt]), pos, True, 1)
            pos += 1
        var ids = String("")
        for t in generated:
            ids += String(t) + " "
        print("GEN IDS:", ids)
        var text = String("")
        for t in generated:
            text += engine.tokenizer.decode(t)
        print("GEN TEXT:", text)
    else:
        raise Error("unknown mode " + mode)
