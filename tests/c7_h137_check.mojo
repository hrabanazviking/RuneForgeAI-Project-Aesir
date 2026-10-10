# tests/c7_h137_check.mojo
# H137 — F1 CPU batching + context management acceptance (TEST-ONLY).
#
# Runs on Mimir (AArch64):
#   Test A — static batching (B=4): batched generate vs 4 separate
#            unbatched runs -> per-stream token-id identity; tok/s measured
#            both ways (honest uplift, no parallel-speedup claim).
#   Test B — prefix-cache reuse exactness: multi-turn session (turn 2
#            prefills only NEW tokens over the cached turn 1) vs a fresh
#            instance prefilling the full transcript -> turn-2 ids identical.
#   Test C — session reset cleanliness: reset() then generate vs a fresh
#            instance on the same prompt -> ids identical.
#   Guards — batch prompt-count mismatch, empty prompt, max_new=0 raise.
#
# Greedy decoding (temp 0, penalty 1.0) keeps the differential exact and
# fast; identity is sampler-independent. Prints H137-ALL-PASS or
# H137-FAIL: <reason>.
#
# Usage: c7_h137_check (run from the repo root)

from std.memory import Pointer
from std.origin import MutUntrackedOrigin

from armvegr.infer import Inference
from armvegr.sp_tokenizer import SPTokenizer
from armvegr.sampler import Sampler
from armvegr.batch import BatchInference
from armvegr.session import Session
from armvegr.f1_config import f1_config_load
from armvegr.util import now_ns


def _logits_to_f32(lp: Pointer[Float16, MutUntrackedOrigin], n: Int) -> List[Float32]:
    var out = List[Float32]()
    for i in range(n):
        out.append(Float32(lp.unsafe_offset(i).unsafe_load()))
    return out^


def _greedy_gen(
    mut inf: Inference,
    prompt: List[Int],
    max_new: Int,
    seed: UInt64,
) raises -> List[Int]:
    """Prefill + greedy decode; returns full id list."""
    var lp = inf.prefill(prompt)
    var seq = prompt.copy()
    var sampler = Sampler(seed)
    for _ in range(max_new):
        var logits = _logits_to_f32(lp, 32000)
        var nt = sampler.sample(
            logits, Float32(0.0), 40, Float32(0.95), seq, Float32(1.0)
        )
        seq.append(nt)
        if nt == 2:
            break
        lp = inf.forward(nt)
    return seq^


def _ids_equal(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def main() raises:
    var fails = List[String]()
    var cfg = f1_config_load("data/fallback/f1_config.json")
    var tok = SPTokenizer()
    tok.load(cfg.tokenizer_path)

    var prompts_text = List[String]()
    prompts_text.append("The old gods remember hospitality")
    prompts_text.append("Mead is brewed from honey")
    prompts_text.append("The raven flies at dawn")
    prompts_text.append("Runes carved in oak wood")
    var prompts = List[List[Int]]()
    for i in range(4):
        prompts.append(tok.encode(prompts_text[i]))

    # ---- Guards (no model needed beyond load). ----
    var batch = BatchInference(4, cfg.max_seq)
    batch.load(cfg.model_path)
    try:
        var bad = List[List[Int]]()
        bad.append(prompts[0].copy())
        _ = batch.generate_batch(bad, 4, cfg.seed, True)
        fails.append("guard: prompt-count mismatch did not raise")
    except:
        print("H137 guard 1/3 PASS: prompt-count mismatch raises")
    try:
        var badp = List[List[Int]]()
        for _ in range(4):
            badp.append(List[Int]())
        _ = batch.generate_batch(badp, 4, cfg.seed, True)
        fails.append("guard: empty prompt did not raise")
    except:
        print("H137 guard 2/3 PASS: empty prompt raises")
    try:
        _ = batch.generate_batch(prompts, 0, cfg.seed, True)
        fails.append("guard: max_new=0 did not raise")
    except:
        print("H137 guard 3/3 PASS: max_new=0 raises")

    # ---- Test A: batch vs unbatched token identity + timing. ----
    var tb0 = now_ns()
    var bout = batch.generate_batch(prompts, 24, cfg.seed, True)
    var tb1 = now_ns()
    var batch_s = Float64(tb1 - tb0) / 1e9
    var batch_toks = 0
    for b in range(4):
        batch_toks += len(bout[b])
    var batch_tps = Float64(batch_toks) / batch_s

    var tu0 = now_ns()
    var uout = List[List[Int]]()
    for b in range(4):
        var ri = Inference(cfg.max_seq)
        ri.model = batch.model.shallow_copy()
        var seq = _greedy_gen(ri, prompts[b], 24, cfg.seed + UInt64(b))
        uout.append(seq^)
        ri.free()
    var tu1 = now_ns()
    var unbatch_s = Float64(tu1 - tu0) / 1e9
    var unbatch_toks = 0
    for b in range(4):
        unbatch_toks += len(uout[b])
    var unbatch_tps = Float64(unbatch_toks) / unbatch_s

    var ident_a = True
    for b in range(4):
        if not _ids_equal(bout[b], uout[b]):
            ident_a = False
            fails.append("Test A: stream " + String(b) + " ids differ")
    if ident_a:
        print("H137 Test A PASS: 4/4 streams batch==unbatched token identity")
    print(
        "H137 Test A timing: batch " + String(batch_tps) + " tok/s vs "
        + "unbatched " + String(unbatch_tps) + " tok/s (uplift x"
        + String(unbatch_s / batch_s) + ")"
    )
    batch.free()

    # ---- Test B: prefix-cache reuse exactness (multi-turn). ----
    var sess = Session(cfg.max_seq)
    sess.load(cfg.model_path)
    var u1 = String("What is hospitality?")
    var p1 = sess.build_prompt(u1)
    var ids1 = tok.encode(p1)
    var lp1 = sess.inf.prefill(ids1)
    var seq1 = ids1.copy()
    var s1 = Sampler(cfg.seed)
    for _ in range(24):
        var lg = _logits_to_f32(lp1, 32000)
        var nt = s1.sample(lg, Float32(0.0), 40, Float32(0.95), seq1, Float32(1.0))
        seq1.append(nt)
        if nt == 2:
            break
        lp1 = sess.inf.forward(nt)
    var gen1_ids = List[Int]()
    for i in range(len(ids1), len(seq1)):
        gen1_ids.append(seq1[i])
    sess.commit_assistant(tok.decode(gen1_ids))
    # Turn 2: prefill ONLY the new tokens over the cached turn 1.
    # The session's cached token sequence is exactly ids1 + gen1_ids
    # (no re-encoding); the delta chunk is encoded on its own.
    var u2 = String("And what of generosity?")
    var chunk2 = String("<|user|>\n") + u2 + String("\n<|assistant|>\n")
    var chunk2_ids = tok.encode(chunk2)
    _ = sess.build_prompt(u2)  # extend the text transcript for the record
    var lp2 = sess.inf.prefill(chunk2_ids)
    var seq2 = List[Int]()
    var s2 = Sampler(cfg.seed + 1)
    for _ in range(24):
        var lg2 = _logits_to_f32(lp2, 32000)
        var nt2 = s2.sample(lg2, Float32(0.0), 40, Float32(0.95), seq2, Float32(1.0))
        seq2.append(nt2)
        if nt2 == 2:
            break
        lp2 = sess.inf.forward(nt2)
    # Reference: fresh instance prefills the IDENTICAL token sequence
    # (ids1 + gen1_ids + chunk2_ids) from scratch, then generates.
    var ref_inf = Inference(cfg.max_seq)
    ref_inf.model = sess.inf.model.shallow_copy()
    var full_ids = ids1.copy()
    for i in range(len(gen1_ids)):
        full_ids.append(gen1_ids[i])
    for i in range(len(chunk2_ids)):
        full_ids.append(chunk2_ids[i])
    var rlp = ref_inf.prefill(full_ids)
    var rseq = List[Int]()
    var rs = Sampler(cfg.seed + 1)
    for _ in range(24):
        var lg3 = _logits_to_f32(rlp, 32000)
        var nt3 = rs.sample(lg3, Float32(0.0), 40, Float32(0.95), rseq, Float32(1.0))
        rseq.append(nt3)
        if nt3 == 2:
            break
        rlp = ref_inf.forward(nt3)
    if _ids_equal(seq2, rseq):
        print("H137 Test B PASS: prefix-cache reuse exact (turn-2 ids identical)")
    else:
        fails.append("Test B: turn-2 ids differ (prefix reuse inexact)")
    ref_inf.free()

    # ---- Test C: session reset cleanliness. ----
    sess.reset()
    var u3 = String("Tell me of the old ways.")
    var p3 = sess.build_prompt(u3)
    var ids3 = tok.encode(p3)
    var s3out = _greedy_gen(sess.inf, ids3, 24, cfg.seed + 2)
    var ref3 = Inference(cfg.max_seq)
    ref3.model = sess.inf.model.shallow_copy()
    var r3out = _greedy_gen(ref3, ids3, 24, cfg.seed + 2)
    if _ids_equal(s3out, r3out):
        print("H137 Test C PASS: reset() clean (ids identical to fresh)")
    else:
        fails.append("Test C: post-reset ids differ from fresh instance")
    ref3.free()
    sess.free()

    if len(fails) == 0:
        print("H137-ALL-PASS")
    else:
        print("H137-FAIL:")
        for i in range(len(fails)):
            print("  - " + fails[i])
        raise Error("c7_h137: acceptance failed")
