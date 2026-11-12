# tests/bench_parity_battery_a045.mojo
# A-045: CPU parity battery -- REUSABLE driver for every later backend.
#
# Usage: bench_parity_battery_a045 <oracle.gguf> <candidate.gguf> <label>
#
# Method (raw-oracle discipline): the token sequence is the RAW prompt
# "One day, Timmy went to" (tokenizer, add_bos=True -- the A-004/A-030
# standard run, NO chat template) followed by the 32 pinned oracle
# greedy IDs (A-004 llama.cpp oracle, re-verified by A-030/A-036 on
# this engine's F16 run). Both engines (oracle F16 and candidate quant)
# teacher-force that exact sequence on CPU; at every position the
# captured logit row (A-045 sink) grades the NEXT oracle token:
# rank (core/parity_battery) + logit gap (top1 - target).
# Primary rows = the 32 continuation positions; the 7 prompt-internal
# positions are reported separately (prompt-boundary class).
# The driver also free-runs 32 greedy tokens from the candidate for
# the IQ coherence note (never token-exactness for IQ).
# Prints A045_POS lines for every divergent continuation position and
# one A045_SUMMARY line per candidate. Exit code stays 0 for judged
# divergences (they are data, filed in the ledger); it raises only on
# harness failure (load failure, missing logit row, tokenizer drift).

from std.sys import argv

from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_top_token,
    parity_verdict_code,
)
from aesir import AesirEngine


def _oracle_ids() -> List[Int]:
    var e = List[Int]()
    e.append(265); e.append(282); e.append(295); e.append(433)
    e.append(335); e.append(345); e.append(357); e.append(426)
    e.append(342); e.append(394); e.append(261); e.append(370)
    e.append(268); e.append(414); e.append(444); e.append(335)
    e.append(261); e.append(370); e.append(268); e.append(414)
    e.append(444); e.append(426); e.append(291); e.append(268)
    e.append(414); e.append(444); e.append(286); e.append(399)
    e.append(262); e.append(423); e.append(388); e.append(269)
    return e^


def main() raises:
    var args = argv()
    if len(args) != 4:
        raise Error("usage: bench_parity_battery_a045 <oracle.gguf> <candidate.gguf> <label>")
    var oracle_path = String(args[1])
    var cand_path = String(args[2])
    var label = String(args[3])
    var oracle_ids = _oracle_ids()
    # Candidate first (its tokenizer defines the sequence; the oracle
    # run below must tokenize identically or the row is invalid).
    var cand = AesirEngine(cand_path)
    var prompt_tokens = cand.tokenizer.encode("One day, Timmy went to", True)
    if len(prompt_tokens) != 8:
        raise Error("A045: prompt token count != 8, got " + String(len(prompt_tokens)))
    var seq = prompt_tokens.copy()
    for i in range(len(oracle_ids)):
        seq.append(oracle_ids[i])
    var cand_rows = cand.teacher_forcing_logit_rows(seq)
    var gen = cand.generate_tokens("One day, Timmy went to", 32)
    var gen_match = 0
    for i in range(32):
        if i < gen.generated_token_count() and gen.token_ids[i] == oracle_ids[i]:
            gen_match += 1
    # Oracle (CPU comparator = the same engine on the pinned F16 file).
    var oracle = AesirEngine(oracle_path)
    var o_prompt = oracle.tokenizer.encode("One day, Timmy went to", True)
    if len(o_prompt) != len(prompt_tokens):
        raise Error("A045: oracle/candidate tokenizer prompt length mismatch")
    for i in range(len(prompt_tokens)):
        if o_prompt[i] != prompt_tokens[i]:
            raise Error("A045: oracle/candidate tokenizer drift at " + String(i))
    var oracle_rows = oracle.teacher_forcing_logit_rows(seq)
    if len(cand_rows) != len(seq) or len(oracle_rows) != len(seq):
        raise Error("A045: logit row count != sequence length")
    var faithful = 0; var near_tie = 0; var divergent = 0
    var worst_rank = 0; var max_gap = Float32(0.0); var gap_sum = Float32(0.0)
    var top1_agree = 0; var oracle_faithful = 0
    var prompt_faithful = 0; var prompt_rows = 0
    for p in range(len(seq) - 1):
        var target = seq[p + 1]
        var rank = parity_logit_rank(cand_rows[p], target)
        var gap = parity_logit_gap(cand_rows[p], target)
        var code = parity_verdict_code(rank, gap)
        var o_rank = parity_logit_rank(oracle_rows[p], target)
        if p + 1 < 8:
            prompt_rows += 1
            if code == 0 or code == 1:
                prompt_faithful += 1
            continue
        if code == 0:
            faithful += 1
        elif code == 1:
            near_tie += 1
        else:
            divergent += 1
            print("A045_POS label=", label, " pos=", p, " target=", target, " rank=", rank, " gap=", gap, " cand_top=", parity_top_token(cand_rows[p]), " oracle_rank=", o_rank)
        if rank > worst_rank:
            worst_rank = rank
        if gap > max_gap:
            max_gap = gap
        gap_sum += gap
        if parity_top_token(cand_rows[p]) == parity_top_token(oracle_rows[p]):
            top1_agree += 1
        if o_rank == 1:
            oracle_faithful += 1
    var mean_gap = gap_sum / Float32(32.0)
    print("A045_SUMMARY label=", label, " faithful=", faithful, " near_tie=", near_tie, " divergent=", divergent, " worst_rank=", worst_rank, " max_gap=", max_gap, " mean_gap=", mean_gap, " top1_agree_oracle=", top1_agree, "/32 oracle_rank1=", oracle_faithful, "/32 prompt_faithful=", prompt_faithful, "/", prompt_rows, " greedy_match=", gen_match, "/32")
    var gen_line = String("A045_GEN label=") + label + String(" ids=")
    for i in range(gen.generated_token_count()):
        gen_line += String(gen.token_ids[i]) + String(",")
    print(gen_line)
    print("A045_BATTERY_DONE label=", label)
