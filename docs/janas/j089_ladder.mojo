"""J-089 ladder harness: J-088's synthetic KV exercise
extended across a context-length ladder.

Shape (fixed, stated): 1 layer, 8 kv-heads, head_dim 128
(kv_width 1024 -- the Llama-3-class head geometry of
J-088's bench, i.e. the 8B shape's per-layer geometry),
at lengths 128 / 256 / 512 / 2,048 / 8,192 / 32,768
positions. Synthetic values are EXACTLY J-088's: synth(i)
= ((i*37 + (i//13)*7) % 17 - 8) / 8, multiples of 1/8 in
[-1, 1], exactly representable in f16; K rows carry the
+11 offset, V rows the +5000 offset, the per-head query
the +97 offset, all indexed exactly as j088_bench.mojo
indexes them. The 256 rung is therefore the same exercise
J-088 filed (its FAITH_ATTN line: max 0.0023426115, mean
0.0011660499518484357) and must reproduce it -- that
reproduction is the ladder's validation gate, checked in
the filed output by j089_inspect.py. Deterministic:
every rung prints identical numbers on every run.

WHAT IS MEASURED, per length:
- attention deviation: attention_int8_head (J-088's
  store, dequantize-inside-attention) vs the unquantized
  reference attention over the same rows, all 8 heads x
  128 dims -- max and mean absolute deviation. The
  reference is computed by an inline regeneration of the
  synth rows (identical math to core/kv_int8's
  attention_f32_head: same score scale, same
  max-subtracted softmax) because holding all reference
  rows as f32 lists at 32,768 positions would cost
  ~256 MB this VM does not have; at the 256 rung the
  inline reference is cross-checked against
  attention_f32_head itself and the difference printed
  (CROSSCHECK line), so the substitution is verified,
  not assumed.
- logit-PROXY deviation: the 8 heads' attention outputs
  concatenated (1024 values, int8 side and reference
  side) are projected to a fixed 64-wide proxy row by a
  fixed deterministic matrix, w(o, i) = (((o*1021 +
  i*131 + 7) % 29) - 14) / 14 in [-1, 1]. The proxy row
  pair is then graded by J-089's own harness
  (core/kv_faith.grade_kv_step): rank, gap, step class.
  A proxy logit is NOT a model logit: it is a fixed
  linear read-out of attention outputs, named PROXY in
  every line it appears in, and its grade is a synthetic
  diagnostic -- never model faithfulness.

THE VERDICT RULE, PRE-REGISTERED (stated here and in the
J-089 doc section 2 BEFORE this harness was first run;
the filed numbers are judged by exactly this rule):
  Let A(L) = attention max abs deviation at length L.
  The single-element bound B = 0.003937006 (J-088's
  measured max K/V round-trip error: half the widest
  row's scale, scale = 1/127).
  (V1) 8-bit COSTS at length L (synthetic level) iff
       A(L) > B, or the proxy step at L is DIVERGENT
       under the near-tie rule (rank > 2 or gap >= 1000
       milli). The first such L is the first costing
       length at the synthetic level.
  (V2) GROWTH is reported separately and descriptively:
       the ratio A(32768) / A(128), printed, no threshold
       verdict attached to it.
  If no length fires (V1), the verdict is NO SYNTHETIC
  COST FOUND at 128..32,768 -- a statement about this
  synthetic exercise only. The MODEL verdict (a real
  model's rank/gap at int8 vs f16 KV per length) is a
  different claim, NOT PROVEN by anything here; its live
  recipe is section 7 of the J-089 doc.

No wall is measured: this VM is contended and a wall
here would be machine weather (J-088 section 5.3's
lesson). Run: see docs/janas/J089_KV_FAITHFULNESS.md.
"""
from std.math import exp, sqrt

from core.kv_faith import grade_kv_step
from core.kv_int8 import (
    Int8KVStore,
    attention_f32_head,
    attention_int8_head,
)
from core.prefill_grade import (
    STEP_DIVERGENT,
    STEP_EXACT,
    step_class,
)

comptime HEADS = 8
comptime HD = 128
comptime WIDTH = HEADS * HD
comptime PV = 64
comptime BOUND = Float32(0.003937006)


def synth(i: Int) -> Float32:
    return Float32((i * 37 + (i // 13) * 7) % 17 - 8) / Float32(8.0)


def ref_attention_inline(
    kv_head: Int, seq_len: Int, query: List[Float32]
) raises -> List[Float32]:
    """The unquantized reference attention for one head,
    regenerating the synth K/V rows instead of holding
    them (identical math to attention_f32_head)."""
    var scores = List[Float32]()
    scores.resize(seq_len, Float32(0))
    var inv = Float32(1.0) / sqrt(Float32(HD))
    var maximum = Float32(-3.4028235e38)
    for t in range(seq_len):
        var base = t * WIDTH + kv_head * HD
        var total = Float32(0)
        for j in range(HD):
            total += query[j] * synth(base + j + 11)
        scores[t] = total * inv
        if scores[t] > maximum:
            maximum = scores[t]
    var denom = Float32(0)
    for t in range(seq_len):
        scores[t] = exp(scores[t] - maximum)
        denom += scores[t]
    var out = List[Float32]()
    out.resize(HD, Float32(0))
    for t in range(seq_len):
        var w = scores[t] / denom
        var base = t * WIDTH + kv_head * HD
        for j in range(HD):
            out[j] += w * synth(base + j + 5000)
    return out^


def proxy_weight(o: Int, i: Int) -> Float32:
    return Float32(((o * 1021 + i * 131 + 7) % 29) - 14) / Float32(14.0)


def proxy_row(concat: List[Float32]) -> List[Float32]:
    var row = List[Float32]()
    row.resize(PV, Float32(0))
    for o in range(PV):
        var total = Float32(0)
        for i in range(WIDTH):
            total += concat[i] * proxy_weight(o, i)
        row[o] = total
    return row^


def class_name(cls: Int) -> String:
    if cls == STEP_EXACT:
        return String("EXACT")
    if cls == STEP_DIVERGENT:
        return String("DIVERGENT")
    return String("NEAR_TIE")


def main() raises:
    var lengths = List[Int]()
    for v in [128, 256, 512, 2048, 8192, 32768]:
        lengths.append(v)
    var first_cost = -1
    var a_first = Float64(0)
    var a_last = Float64(0)
    var sink = Float64(0)
    for li in range(len(lengths)):
        var seq = lengths[li]
        var store = Int8KVStore(1, HEADS, HD, seq)
        for t in range(seq):
            var krow = List[Float32]()
            var vrow = List[Float32]()
            for j in range(WIDTH):
                krow.append(synth(t * WIDTH + j + 11))
                vrow.append(synth(t * WIDTH + j + 5000))
            store.append(0, t, krow, vrow)
        var concat8 = List[Float32]()
        var concatref = List[Float32]()
        var amax = Float32(0)
        var asum = Float64(0)
        var acount = 0
        var cross_max = Float32(0)
        for h in range(HEADS):
            var q = List[Float32]()
            for j in range(HD):
                q.append(synth(h * HD + j + 97))
            var got = attention_int8_head(store, 0, h, q, seq)
            var want = ref_attention_inline(h, seq, q)
            if seq == 256:
                var rk = List[Float32]()
                var rv = List[Float32]()
                for t in range(seq):
                    for j in range(HD):
                        rk.append(synth(t * WIDTH + h * HD + j + 11))
                        rv.append(synth(t * WIDTH + h * HD + j + 5000))
                var modref = attention_f32_head(rk, rv, q, seq, HD)
                for j in range(HD):
                    var cd = want[j] - modref[j]
                    if cd < Float32(0):
                        cd = -cd
                    if cd > cross_max:
                        cross_max = cd
            for j in range(HD):
                var d = got[j] - want[j]
                if d < Float32(0):
                    d = -d
                if d > amax:
                    amax = d
                asum += Float64(d)
                acount += 1
                concat8.append(got[j])
                concatref.append(want[j])
                sink += Float64(got[j])
        var prow8 = proxy_row(concat8)
        var prowref = proxy_row(concatref)
        var pmax = Float32(0)
        var psum = Float64(0)
        for o in range(PV):
            var d = prow8[o] - prowref[o]
            if d < Float32(0):
                d = -d
            if d > pmax:
                pmax = d
            psum += Float64(d)
        var step = grade_kv_step(prowref, prow8)
        var cls = step_class(step.rank, step.gap_milli)
        print(
            "LADDER L=" + String(seq)
            + " attn_max=" + String(amax)
            + " attn_mean=" + String(asum / Float64(acount))
            + " proxy_max=" + String(pmax)
            + " proxy_mean=" + String(psum / Float64(PV))
            + " proxy_rank=" + String(step.rank)
            + " proxy_gap_milli=" + String(step.gap_milli)
            + " proxy_class=" + class_name(cls)
            + " proxy_ref_top=" + String(step.ref_top)
            + " proxy_test_top=" + String(step.test_top)
        )
        if seq == 256:
            print(
                "CROSSCHECK inline_vs_module_ref_max=" + String(cross_max)
                + " ladder256_attn_max=" + String(amax)
                + " ladder256_attn_mean=" + String(asum / Float64(acount))
            )
        var costs = (amax > BOUND) or (cls == STEP_DIVERGENT)
        if costs and first_cost < 0:
            first_cost = seq
        if li == 0:
            a_first = Float64(amax)
        a_last = Float64(amax)
    print(
        "VERDICT first_cost_len=" + String(first_cost)
        + " growth_x1000=" + String(Int(a_last / a_first * 1000.0))
        + " bound=" + String(BOUND)
        + " sink=" + String(sink)
    )
    print("LADDER DONE")
