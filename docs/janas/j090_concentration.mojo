"""J-090 concentration harness: where does J-088's 8-bit
KV error live in J-089's synthetic exercise -- per head,
per tensor, per scale shape?

Shape (fixed, stated): EXACTLY J-089's ladder exercise --
1 layer, 8 kv-heads, head_dim 128 (kv_width 1024), the
same synth values and offsets, the same per-head queries,
one final-position query per head -- at lengths 128 /
256 / 2,048 / 32,768. J-089 aggregated its deviation
across all 8 heads into one max/mean per length; this
harness disaggregates the SAME exercise:

- PER HEAD: for each head, the attention-output max/mean
  deviation of per-row int8 vs the unquantized reference,
  with K and V quantized together (mode BOTH), with only
  K quantized (KONLY), and with only V quantized
  (VONLY) -- so a concentration in one head, or in one
  tensor, is visible if it exists.
- PER-CHANNEL (mode CHAN): K and V quantized with
  per-channel scales under ORACLE CALIBRATION -- each
  channel's scale is the maxabs of that channel over the
  WHOLE sequence (the calibrator has seen every position,
  including future ones). That is an upper bound on
  per-channel quality, not an append-time scheme: a real
  per-channel store must calibrate on past data or a
  held-out pass (J-088 section 5.1's open question). The
  mode answers only: would perfect channel scales have
  changed the deviation picture?
- THE RESTORATION CONTROL: the aggregate deviation when
  the single worst head (by BOTH max) is left
  unquantized and the other seven stay int8
  (worstheadf16) -- the exact candidate J-090's rule
  would try first under a per-head indictment, exercised
  here whether or not an indictment fires, as a control.

Per-layer concentration is NOT exercisable here and is
not claimed: the ladder has one layer, and error
compounding across a model's depth is a live-model
question (J-089 section 7's recipe, re-cited at J-098).

THE VERDICT RULE, PRE-REGISTERED (stated here and in
the J-090 doc section 2 and in core/kv_mixed.mojo's
header BEFORE this harness was first run; the filed
numbers are judged by exactly this rule). Let B =
0.003937006 (J-088's measured max single-element
round-trip error, J-089's bound) and let H(L) be the
per-head BOTH max deviations at length L, M(L) their
median:
  (I1) uniform indictment: J-089's rule fired
       (first_cost_len != -1 in its filed output).
  (I2) concentration indictment: at some L, max H(L) > B
       AND max H(L) >= 2 x M(L).
  (I3) tensor indictment: at some L, the KONLY or the
       VONLY aggregate max deviation > B.
  A mixed layout is KEPT only if an indictment fires
  (I1 or I2 or I3), the candidate covering the indicted
  subset restores max <= B in this same exercise (for
  I2, the worstheadf16 control is that exercise), and
  the candidate's price passes R3 of core/kv_mixed
  (overhead strictly less than half the int8 saving).
  Otherwise the verdict is NOT KEPT, with the reason
  named by mixed_keep_verdict's codes.

VALIDATION GATE: this harness's BOTH aggregate at every
length must reproduce J-089's filed ladder lines
(attn_max / attn_mean in j089_test_output.txt) -- the
inspect script checks that mechanically; and at 256 the
inline exact reference is cross-checked against
core/kv_int8.attention_f32_head for head 0 (CROSSCHECK
line, must be 0.0). Either failure voids the harness's
numbers, not the rule.

No wall is measured: this VM is contended and a wall
here would be machine weather. Run: see
docs/janas/J090_MIXED_DISCIPLINE.md.
"""
from std.math import exp, sqrt

from core.kv_int8 import (
    attention_f32_head,
    kv8_dequantize,
    kv8_quantize,
    kv8_row_scale,
)

comptime HEADS = 8
comptime HD = 128
comptime WIDTH = HEADS * HD
comptime BOUND = Float32(0.003937006)

comptime MODE_EXACT = 0
comptime MODE_ROW = 1
comptime MODE_CHAN = 2


def synth(i: Int) -> Float32:
    return Float32((i * 37 + (i // 13) * 7) % 17 - 8) / Float32(8.0)


def _abs32(x: Float32) -> Float32:
    return x if x >= Float32(0) else -x


struct Scales(Movable):
    """Per-row scales [position][head] and oracle
    per-channel scales [head][channel] for one tensor
    (K or V) at one length, computed in one pass."""

    var row: List[Float32]
    var chan: List[Float32]

    def __init__(out self, seq: Int, is_k: Bool):
        self.row = List[Float32]()
        self.row.resize(seq * HEADS, Float32(1.0))
        self.chan = List[Float32]()
        self.chan.resize(WIDTH, Float32(0))
        var off = 11 if is_k else 5000
        var chanmax = List[Float32]()
        chanmax.resize(WIDTH, Float32(0))
        for t in range(seq):
            for h in range(HEADS):
                var m = Float32(0)
                for j in range(HD):
                    var idx = h * HD + j
                    var a = _abs32(synth(t * WIDTH + idx + off))
                    if a > m:
                        m = a
                    if a > chanmax[idx]:
                        chanmax[idx] = a
                self.row[t * HEADS + h] = kv8_row_scale(m)
        for i in range(WIDTH):
            self.chan[i] = kv8_row_scale(chanmax[i])


def elem(
    t: Int, h: Int, j: Int, is_k: Bool, mode: Int, sc: Scales
) raises -> Float32:
    var off = 11 if is_k else 5000
    var x = synth(t * WIDTH + h * HD + j + off)
    if mode == MODE_EXACT:
        return x
    if mode == MODE_ROW:
        var s = sc.row[t * HEADS + h]
        return kv8_dequantize(kv8_quantize(x, s), s)
    var cs = sc.chan[h * HD + j]
    return kv8_dequantize(kv8_quantize(x, cs), cs)


def attn_mode(
    h: Int,
    seq: Int,
    query: List[Float32],
    kmode: Int,
    vmode: Int,
    ks: Scales,
    vs: Scales,
) raises -> List[Float32]:
    """Attention for one head with K/V element modes
    selected independently (identical math to
    core/kv_int8.attention_f32_head: same score scale,
    same max-subtracted softmax)."""
    var scores = List[Float32]()
    scores.resize(seq, Float32(0))
    var inv = Float32(1.0) / sqrt(Float32(HD))
    var maximum = Float32(-3.4028235e38)
    for t in range(seq):
        var total = Float32(0)
        for j in range(HD):
            total += query[j] * elem(t, h, j, True, kmode, ks)
        scores[t] = total * inv
        if scores[t] > maximum:
            maximum = scores[t]
    var denom = Float32(0)
    for t in range(seq):
        scores[t] = exp(scores[t] - maximum)
        denom += scores[t]
    var out = List[Float32]()
    out.resize(HD, Float32(0))
    for t in range(seq):
        var w = scores[t] / denom
        for j in range(HD):
            out[j] += w * elem(t, h, j, False, vmode, vs)
    return out^


def dev_stats(
    got: List[Float32], want: List[Float32]
) -> Tuple[Float32, Float64]:
    var mx = Float32(0)
    var sm = Float64(0)
    for j in range(len(want)):
        var d = _abs32(got[j] - want[j])
        if d > mx:
            mx = d
        sm += Float64(d)
    return (mx, sm)


def main() raises:
    var lengths = List[Int]()
    for v in [128, 256, 2048, 32768]:
        lengths.append(v)
    var ind_any = False
    for li in range(len(lengths)):
        var seq = lengths[li]
        var ks = Scales(seq, True)
        var vs = Scales(seq, False)
        # Per-head BOTH / KONLY / VONLY, aggregates for
        # every mode, and the exact references held per
        # head only while that head is processed.
        var head_max = List[Float32]()
        head_max.resize(HEADS, Float32(0))
        var both_sum = Float64(0)
        var both_max = Float32(0)
        var k_max = Float32(0)
        var v_max = Float32(0)
        var chan_max = Float32(0)
        var chan_sum = Float64(0)
        var worst_head = 0
        for h in range(HEADS):
            var q = List[Float32]()
            for j in range(HD):
                q.append(synth(h * HD + j + 97))
            var want = attn_mode(h, seq, q, MODE_EXACT, MODE_EXACT, ks, vs)
            var both = attn_mode(h, seq, q, MODE_ROW, MODE_ROW, ks, vs)
            var konly = attn_mode(h, seq, q, MODE_ROW, MODE_EXACT, ks, vs)
            var vonly = attn_mode(h, seq, q, MODE_EXACT, MODE_ROW, ks, vs)
            var chan = attn_mode(h, seq, q, MODE_CHAN, MODE_CHAN, ks, vs)
            if seq == 256 and h == 0:
                var rk = List[Float32]()
                var rv = List[Float32]()
                for t in range(seq):
                    for j in range(HD):
                        rk.append(synth(t * WIDTH + h * HD + j + 11))
                        rv.append(synth(t * WIDTH + h * HD + j + 5000))
                var modref = attention_f32_head(rk, rv, q, seq, HD)
                var cmax = Float32(0)
                for j in range(HD):
                    var cd = _abs32(want[j] - modref[j])
                    if cd > cmax:
                        cmax = cd
                print(
                    "CROSSCHECK L=256 inline_vs_module_ref_max="
                    + String(cmax)
                )
            var sb = dev_stats(both, want)
            var sk = dev_stats(konly, want)
            var sv = dev_stats(vonly, want)
            var sc2 = dev_stats(chan, want)
            head_max[h] = sb[0]
            if sb[0] > both_max:
                both_max = sb[0]
            both_sum += sb[1]
            if sk[0] > k_max:
                k_max = sk[0]
            if sv[0] > v_max:
                v_max = sv[0]
            if sc2[0] > chan_max:
                chan_max = sc2[0]
            chan_sum += sc2[1]
            if sb[0] > head_max[worst_head]:
                worst_head = h
            print(
                "CONCHEAD L=" + String(seq)
                + " h=" + String(h)
                + " both_max=" + String(sb[0])
                + " both_mean=" + String(sb[1] / Float64(HD))
                + " k_max=" + String(sk[0])
                + " v_max=" + String(sv[0])
                + " chan_max=" + String(sc2[0])
            )
        # Restoration control: worst head exact, the
        # other seven at per-row int8 (mode BOTH).
        var ctrl_max = Float32(0)
        for h in range(HEADS):
            if h == worst_head:
                continue
            if head_max[h] > ctrl_max:
                ctrl_max = head_max[h]
        # Median of the eight head maxes.
        var sorted = List[Float32]()
        for h in range(HEADS):
            sorted.append(head_max[h])
        for a in range(HEADS):
            for b in range(a + 1, HEADS):
                if sorted[b] < sorted[a]:
                    var tmp = sorted[a]
                    sorted[a] = sorted[b]
                    sorted[b] = tmp
        var median = (Float64(sorted[3]) + Float64(sorted[4])) / 2.0
        var ratio = Float64(both_max) / median if median > 0 else Float64(0)
        var ind_conc = (both_max > BOUND) and (ratio >= 2.0)
        var ind_tensor = (k_max > BOUND) or (v_max > BOUND)
        if ind_conc or ind_tensor:
            ind_any = True
        print(
            "CONC L=" + String(seq)
            + " both_max=" + String(both_max)
            + " both_mean=" + String(both_sum / Float64(WIDTH))
            + " konly_max=" + String(k_max)
            + " vonly_max=" + String(v_max)
            + " chan_max=" + String(chan_max)
            + " chan_mean=" + String(chan_sum / Float64(WIDTH))
            + " worst_head=" + String(worst_head)
            + " worstheadf16_max=" + String(ctrl_max)
            + " head_max_median=" + String(median)
            + " ratio_x1000=" + String(Int(ratio * 1000.0))
            + " indicted_conc=" + String(1 if ind_conc else 0)
            + " indicted_tensor=" + String(1 if ind_tensor else 0)
        )
    print(
        "RULEM concentration_or_tensor_indicted=" + String(1 if ind_any else 0)
        + " bound=" + String(BOUND)
    )
    print("CONCENTRATION DONE")
