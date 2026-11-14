# tests/grade_quantize_qc_3.mojo
# QC-3a grade driver (not a suite test).
#
# Teacher-forcing grade of the QC-3a Q8_0 conversion against its own
# F16 source, Aesir CPU engine vs Aesir CPU engine, per the campaign
# discipline (QC-0-PLAN sections 0/6, Q35-3b harness pattern):
# - RAW prompts only (plain text, the model's own tokenizer with
#   add_bos, no template rendering -- the harness asserts no
#   template marker is present).
# - Token IDs are produced ONCE by the source model's tokenizer;
#   the quantized model's tokenizer must reproduce the identical
#   stream (asserted), and the identical IDs are teacher-forced
#   into both runs.
# - Per position, the record is the rank + logit gap of the
#   COMPARATOR's (source's) argmax in the CANDIDATE's (Q8_0) logit
#   row -- the Q35-3b rank_comp/gap_comp account -- filed through
#   core/near_tie_gate (rank 0 = top; band: rank <= 2 AND
#   gap_milli < 1000). The true-next-token rank/gap in both rows
#   rides beside it in the CSV.
# - The graded stream per prompt is the RAW prompt plus the SOURCE
#   model's own greedy continuation (16 tokens): continuation
#   positions are teacher-forced on the identical stream in both
#   runs (the A-045 convention), and prompt-internal positions are
#   reported as their own subtotal beside the full-stream account.
# - Greedy continuations from both models are compared token by
#   token; the first divergence is named, never averaged away.
#
# Usage: grade_quantize_qc_3 <source.gguf> <quant.gguf> <out.csv>

from std.sys import argv

from core.mimir_well import KVCache
from core.near_tie_gate import gate_steps, gate_verdict_name
from core.parity_battery import parity_logit_gap, parity_logit_rank
from core.teacher_forcing_harness import tf_detect_template
from aesir import AesirEngine, GenerationConfig
from loader.tokenizer import RuneStreamDecoder


def raw_prompts() -> List[String]:
    var prompts = List[String]()
    prompts.append(String("One day, Timmy went to"))
    prompts.append(String("Once upon a time, there was a little girl"))
    prompts.append(String("The dog ran to the"))
    prompts.append(String("Mom said, come here and"))
    prompts.append(String("One day, a little boy named Tom"))
    prompts.append(String("The sun was shining and the birds"))
    return prompts^


def argmax_row(row: List[Float32]) -> Int:
    var best = 0
    for i in range(len(row)):
        if row[i] > row[best]:
            best = i
    return best


def is_finite(v: Float32) -> Bool:
    return v == v and v < Float32(1e30) and v > Float32(-1e30)


def collect_rows(
    mut engine: AesirEngine, tokens: List[Int], cfg: GenerationConfig
) raises -> List[List[Float32]]:
    """Teacher-forced logit rows: row p is the row after tokens[p],
    captured by the KVCache sink exactly as the sampler sees it."""
    engine.pool.offset = engine.runtime_offset
    var kv = KVCache(
        len(tokens) + 64,
        engine.parser.config.kv_dim(),
        engine.pool,
        engine.parser.config.block_count,
    )
    kv.capture_logit_row = True
    var rows = List[List[Float32]]()
    for pos in range(len(tokens) - 1):
        _ = engine._forward_position(tokens, kv, pos, cfg, False)
        var row = kv.last_logit_row.copy()
        for i in range(len(row)):
            if not is_finite(row[i]):
                raise Error("non-finite logit at pos " + String(pos))
        rows.append(row^)
    return rows^


def greedy_continuation(
    mut engine: AesirEngine,
    tokens: List[Int],
    cfg: GenerationConfig,
    count: Int,
) raises -> List[Int]:
    engine.pool.offset = engine.runtime_offset
    var kv = KVCache(
        len(tokens) + count + 64,
        engine.parser.config.kv_dim(),
        engine.pool,
        engine.parser.config.block_count,
    )
    var stream = tokens.copy()
    var nxt = -1
    for pos in range(len(stream)):
        nxt = engine._forward_position(stream, kv, pos, cfg, False)
    var gen = List[Int]()
    for _ in range(count):
        gen.append(nxt)
        if nxt == engine.tokenizer.eos_token_id:
            break
        stream.append(nxt)
        nxt = engine._forward_position(stream, kv, len(stream) - 1, cfg, False)
    return gen^


def decode_ids(mut engine: AesirEngine, ids: List[Int]) raises -> String:
    var dec = RuneStreamDecoder()
    var text = String("")
    for i in range(len(ids)):
        text += dec.decode_id(ids[i], engine.tokenizer)
    text += dec.flush()
    return text


def main() raises:
    var arguments = argv()
    if len(arguments) != 4:
        raise Error("usage: grade_quantize_qc_3 <source.gguf> <quant.gguf> <out.csv>")
    var source_path = arguments[1]
    var quant_path = arguments[2]
    var prompts = raw_prompts()
    for i in range(len(prompts)):
        if tf_detect_template(prompts[i]):
            raise Error("prompt carries a template marker; RAW prompts only: " + prompts[i])
    var cfg = GenerationConfig(
        max_new_tokens=48,
        temperature=Float32(0.0),
        top_k=40,
        top_p=Float32(0.9),
        repetition_penalty=Float32(1.0),
        seed=UInt64(42),
    )

    # Tokenize once, with the SOURCE model's own tokenizer.
    var engine_src = AesirEngine(source_path, knowledge_capacity=1)
    print("LOADED source:", engine_src.parser.config.architecture, "blocks:", engine_src.parser.config.block_count, "vocab:", engine_src.tokenizer.vocab_size)
    var streams = List[List[Int]]()
    for i in range(len(prompts)):
        var ids = engine_src.tokenizer.encode(prompts[i], True)
        streams.append(ids.copy())
        var line = String("PROMPT ") + String(i) + " tokens:"
        for j in range(len(ids)):
            line += String(" ") + String(ids[j])
        print(line)

    var src_greedy = List[List[Int]]()
    for i in range(len(prompts)):
        src_greedy.append(greedy_continuation(engine_src, streams[i], cfg, 16))
    var full_streams = List[List[Int]]()
    for i in range(len(prompts)):
        var full = streams[i].copy()
        for j in range(len(src_greedy[i])):
            full.append(src_greedy[i][j])
        full_streams.append(full^)
    var src_rows = List[List[List[Float32]]]()
    for i in range(len(prompts)):
        src_rows.append(collect_rows(engine_src, full_streams[i], cfg))

    var engine_q8 = AesirEngine(quant_path, knowledge_capacity=1)
    print("LOADED quantized:", engine_q8.parser.config.architecture, "blocks:", engine_q8.parser.config.block_count, "vocab:", engine_q8.tokenizer.vocab_size)
    for i in range(len(prompts)):
        var ids = engine_q8.tokenizer.encode(prompts[i], True)
        if len(ids) != len(streams[i]):
            raise Error("tokenizer stream length differs between source and quantized model on prompt " + String(i))
        for j in range(len(ids)):
            if ids[j] != streams[i][j]:
                raise Error("tokenizer stream differs between source and quantized model on prompt " + String(i))
    print("TOKENIZER PARITY: quantized model reproduces the identical token-ID streams on all prompts")
    var q8_rows = List[List[List[Float32]]]()
    for i in range(len(prompts)):
        q8_rows.append(collect_rows(engine_q8, full_streams[i], cfg))
    var q8_greedy = List[List[Int]]()
    for i in range(len(prompts)):
        q8_greedy.append(greedy_continuation(engine_q8, streams[i], cfg, 16))

    # Grade: comparator-argmax rank/gap in the candidate row.
    var csv = String("prompt,pos,segment,true_next,src_argmax,q8_argmax,agree,rank_comp,gap_comp_milli,rank_true_q8,gap_true_q8_milli,rank_true_src,gap_true_src_milli\n")
    var all_ranks = List[Int]()
    var all_gaps = List[Int]()
    var prompt_ranks = List[Int]()
    var prompt_gaps = List[Int]()
    var cont_ranks = List[Int]()
    var cont_gaps = List[Int]()
    var total = 0
    var agree_total = 0
    for i in range(len(prompts)):
        var p_ranks = List[Int]()
        var p_gaps = List[Int]()
        var p_agree = 0
        var p_count = 0
        for pos in range(len(full_streams[i]) - 1):
            var segment = 1 if pos + 1 >= len(streams[i]) else 0
            var srow = src_rows[i][pos].copy()
            var qrow = q8_rows[i][pos].copy()
            var true_next = full_streams[i][pos + 1]
            var s_arg = argmax_row(srow)
            var q_arg = argmax_row(qrow)
            var agree = 1 if s_arg == q_arg else 0
            var rank_comp = parity_logit_rank(qrow, s_arg) - 1
            var gap_comp = parity_logit_gap(qrow, s_arg)
            var rank_tq = parity_logit_rank(qrow, true_next) - 1
            var gap_tq = parity_logit_gap(qrow, true_next)
            var rank_ts = parity_logit_rank(srow, true_next) - 1
            var gap_ts = parity_logit_gap(srow, true_next)
            csv += String(i) + "," + String(pos) + "," + String(segment) + "," + String(true_next) + "," + String(s_arg) + "," + String(q_arg) + "," + String(agree) + "," + String(rank_comp) + "," + String(Int(gap_comp * Float32(1000.0))) + "," + String(rank_tq) + "," + String(Int(gap_tq * Float32(1000.0))) + "," + String(rank_ts) + "," + String(Int(gap_ts * Float32(1000.0))) + "\n"
            p_ranks.append(rank_comp)
            p_gaps.append(Int(gap_comp * Float32(1000.0)))
            all_ranks.append(rank_comp)
            all_gaps.append(Int(gap_comp * Float32(1000.0)))
            if segment == 0:
                prompt_ranks.append(rank_comp)
                prompt_gaps.append(Int(gap_comp * Float32(1000.0)))
            else:
                cont_ranks.append(rank_comp)
                cont_gaps.append(Int(gap_comp * Float32(1000.0)))
            p_agree += agree
            agree_total += agree
            p_count += 1
            total += 1
        var p_summary = gate_steps(p_ranks, p_gaps, True)
        print(
            "PROMPT", i, "verdict", gate_verdict_name(p_summary.verdict),
            "steps", p_summary.steps, "exact", p_summary.exact_count,
            "near_tie", p_summary.near_tie_count, "divergent", p_summary.divergent_count,
            "worst_rank", p_summary.worst_rank, "worst_gap_milli", p_summary.worst_gap_milli,
            "argmax_agree", p_agree, "/", p_count,
        )
    var handle = open(arguments[3], "w")
    handle.write(csv)
    handle.close()
    print("GRADE CSV WRITTEN:", arguments[3])

    var summary = gate_steps(all_ranks, all_gaps, True)
    var band = summary.exact_count + summary.near_tie_count
    print(
        "AGGREGATE verdict", gate_verdict_name(summary.verdict),
        "steps", summary.steps, "exact", summary.exact_count,
        "near_tie", summary.near_tie_count, "divergent", summary.divergent_count,
        "first_divergent_step", summary.first_divergent_step,
        "worst_rank", summary.worst_rank, "worst_gap_milli", summary.worst_gap_milli,
    )
    print("BAND_COUNT", band, "OF", total)
    print("ARGMAX_AGREEMENT", agree_total, "OF", total)
    var prompt_summary = gate_steps(prompt_ranks, prompt_gaps, True)
    print(
        "PROMPT_SEGMENT verdict", gate_verdict_name(prompt_summary.verdict),
        "steps", prompt_summary.steps, "exact", prompt_summary.exact_count,
        "near_tie", prompt_summary.near_tie_count, "divergent", prompt_summary.divergent_count,
        "worst_rank", prompt_summary.worst_rank, "worst_gap_milli", prompt_summary.worst_gap_milli,
    )
    var cont_summary = gate_steps(cont_ranks, cont_gaps, True)
    print(
        "CONTINUATION_SEGMENT verdict", gate_verdict_name(cont_summary.verdict),
        "steps", cont_summary.steps, "exact", cont_summary.exact_count,
        "near_tie", cont_summary.near_tie_count, "divergent", cont_summary.divergent_count,
        "first_divergent_step", cont_summary.first_divergent_step,
        "worst_rank", cont_summary.worst_rank, "worst_gap_milli", cont_summary.worst_gap_milli,
    )

    # Greedy comparison, first divergence named per prompt.
    for i in range(len(prompts)):
        var s = src_greedy[i].copy()
        var q = q8_greedy[i].copy()
        var divergence = -1
        var shared = len(s) if len(s) < len(q) else len(q)
        for j in range(shared):
            if s[j] != q[j]:
                divergence = j
                break
        if divergence < 0 and len(s) != len(q):
            divergence = shared
        var s_ids = String("")
        for j in range(len(s)):
            s_ids += String(s[j]) + String(" ")
        var q_ids = String("")
        for j in range(len(q)):
            q_ids += String(q[j]) + String(" ")
        print("GREEDY prompt", i, "first_divergence", divergence)
        print("GREEDY prompt", i, "source ids:", s_ids)
        print("GREEDY prompt", i, "quant  ids:", q_ids)
        print("GREEDY prompt", i, "source text:", decode_ids(engine_src, s))
        print("GREEDY prompt", i, "quant  text:", decode_ids(engine_q8, q))
    print("QC-3a grade driver: DONE")
