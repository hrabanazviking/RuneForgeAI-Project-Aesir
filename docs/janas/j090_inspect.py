#!/usr/bin/env python3
"""J-090 mixed discipline -- inspect / re-derivation script.

Checks, mechanically:

- the accounting module's structure in core/kv_mixed.mojo:
  the pricing and verdict functions exist, prices are
  defined through core/kv_int8 + core/kv_account (the
  J-087/J-088 accountings), and the keep rule is stated
  PRE-REGISTERED in the header with its three conjuncts;
- the concentration harness is J-089's exercise: identical
  synth function text as j089_ladder.mojo, the stated
  lengths, the pre-registered bound, the ORACLE
  CALIBRATION naming for per-channel, the RULEM line;
- J-089's filed verdict re-derived (first_cost_len=-1 in
  j089_test_output.txt): indictment I1 does not fire;
- the filed concentration lines in j090_test_output.txt:
  four lengths in order, 32 per-head lines, CROSSCHECK
  0.0; the BOTH aggregate reproduces J-089's filed ladder
  EXACTLY at all four lengths (the validation gate);
  per-head median / max-median ratio / worst-head control
  recomputed from the filed per-head lines and compared
  with the filed CONC lines; K-only and V-only maxima
  under the bound; indictment flags all zero; the verdict
  the pre-registered rule computes from the filed lines
  is NOT KEPT (no indictment); per-channel identical to
  per-row at every length, as filed;
- an independent Python re-derivation of the 128 rung,
  per head (quantizer + attention in float64, modes
  BOTH / K-only / V-only): every per-head max and the
  BOTH means agree with the filed Mojo figures within
  2e-6;
- the range-saturation fact behind the per-channel
  equality, proven directly: at 128 positions every
  (position, head) row slice and every channel of both
  tensors attains maxabs 1.0, so per-row and per-channel
  scales coincide (1/127) and the two shapes are one
  quantizer on this data;
- the candidate accounting re-derived in Python (8B and
  0.6B tables, the R3 price boundary, the per-channel
  break-even identity at 128 tokens);
- the doc states the NOT KEPT verdict with its code and
  files the deferred live recipe for the J-098 gate, and
  the doc's section-5 table values match the filed CONC
  lines.

Every check prints PASS/FAIL; the script exits nonzero on
any FAIL. Run from the repo root:  python3 docs/janas/j090_inspect.py
"""
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "aesir_engine" / "core"
JANAS = ROOT / "docs" / "janas"

checks = 0
fails = 0


def check(label, cond, detail=""):
    global checks, fails
    checks += 1
    if cond:
        print(f"PASS: {label}" + (f" -- {detail}" if detail else ""))
    else:
        fails += 1
        print(f"FAIL: {label}" + (f" -- {detail}" if detail else ""))


mod = (CORE / "kv_mixed.mojo").read_text()
test = (ROOT / "aesir_engine" / "tests" / "test_kv_mixed.mojo").read_text()
harness = (JANAS / "j090_concentration.mojo").read_text()
ladder89 = (JANAS / "j089_ladder.mojo").read_text()
out = (JANAS / "j090_test_output.txt").read_text()
out89 = (JANAS / "j089_test_output.txt").read_text()
doc = (JANAS / "J090_MIXED_DISCIPLINE.md").read_text()

BOUND = 0.003937006
LENGTHS = [128, 256, 2048, 32768]

# ------------------------------------------------------------------
# 1. Module structure: accounting through J-087/J-088, rule stated
# ------------------------------------------------------------------
check("mixed pricing exists (mixed_bytes_per_token)", "def mixed_bytes_per_token" in mod)
check("keep verdict exists (mixed_keep_verdict)", "def mixed_keep_verdict" in mod)
check("break-even exists (per_channel_break_even_context)",
      "def per_channel_break_even_context" in mod)
check("prices defined through kv_int8 (J-088)",
      "from core.kv_int8 import" in mod and "kv8_bytes_per_token" in mod)
check("prices defined through kv_account (J-087)",
      "from core.kv_account import" in mod and "kv_bytes_per_token" in mod)
check("rule is stated PRE-REGISTERED in the module header",
      "PRE-REGISTERED" in mod and "(R1)" in mod and "(R2)" in mod and "(R3)" in mod)
check("verdict codes include NOT_KEPT_NO_INDICTMENT",
      "MIXED_NOT_KEPT_NO_INDICTMENT" in mod and "NOT_KEPT_NO_INDICTMENT" in mod)
check("tests pin the candidate table (69568 / 75520 / 99328)",
      "69568" in test and "75520" in test and "99328" in test)
check("tests pin the price boundary as NOT KEPT on price",
      "MIXED_NOT_KEPT_PRICE" in test and "half the saving" in test)

# ------------------------------------------------------------------
# 2. Harness is J-089's exercise, disaggregated
# ------------------------------------------------------------------
synth_def = "Float32((i * 37 + (i // 13) * 7) % 17 - 8) / Float32(8.0)"
check("harness synth is byte-identical to J-089's ladder synth",
      synth_def in harness and synth_def in ladder89)
check("harness lengths are the stated four",
      "[128, 256, 2048, 32768]" in harness)
check("pre-registered bound is J-088's round-trip bound",
      "comptime BOUND = Float32(0.003937006)" in harness)
check("per-channel is named ORACLE CALIBRATION (upper bound, not a scheme)",
      "ORACLE CALIBRATION" in harness and "upper bound" in harness)
check("harness exercises the worst-head restoration control",
      "worstheadf16" in harness)
check("harness states per-layer concentration is NOT exercisable here",
      "Per-layer concentration is NOT exercisable" in harness)

# ------------------------------------------------------------------
# 3. Suites filed green; J-089's verdict re-derived (I1)
# ------------------------------------------------------------------
check("filed suites: kv mixed 6/6", "ALL PASS: kv mixed (6 groups)" in out)
check("filed suites: neighbour kv int8 8/8", "ALL PASS: kv int8 (8 groups)" in out)
check("filed suites: neighbour kv account 10/10", "ALL PASS: kv account (10 groups)" in out)
check("filed suites: neighbour kv faith 6/6", "ALL PASS: kv faith (6 groups)" in out)
mv89 = re.search(r"VERDICT first_cost_len=(-?\d+)", out89)
check("J-089's filed verdict found (first_cost_len)", mv89 is not None)
i1 = mv89 is not None and int(mv89.group(1)) != -1
check("indictment I1 (J-089 uniform) does NOT fire", not i1,
      f"first_cost_len={mv89.group(1) if mv89 else '?'}")

# ------------------------------------------------------------------
# 4. Filed concentration lines: gate, disaggregation, rule applied
# ------------------------------------------------------------------
rungs89 = {}
for m in re.finditer(
    r"LADDER L=(\d+) attn_max=([\d.]+) attn_mean=([\d.]+)", out89):
    rungs89[int(m.group(1))] = (float(m.group(2)), float(m.group(3)))

heads = {}
for m in re.finditer(
    r"CONCHEAD L=(\d+) h=(\d+) both_max=([\d.]+) both_mean=([\d.]+) "
    r"k_max=([\d.]+) v_max=([\d.]+) chan_max=([\d.]+)", out):
    heads.setdefault(int(m.group(1)), {})[int(m.group(2))] = {
        "both_max": float(m.group(3)), "both_mean": float(m.group(4)),
        "k_max": float(m.group(5)), "v_max": float(m.group(6)),
        "chan_max": float(m.group(7)),
    }
check("32 per-head lines filed (4 lengths x 8 heads)",
      sum(len(v) for v in heads.values()) == 32
      and all(sorted(heads.get(L, {})) == list(range(8)) for L in LENGTHS))

conc = {}
for m in re.finditer(
    r"CONC L=(\d+) both_max=([\d.]+) both_mean=([\d.]+) "
    r"konly_max=([\d.]+) vonly_max=([\d.]+) chan_max=([\d.]+) "
    r"chan_mean=([\d.]+) worst_head=(\d+) worstheadf16_max=([\d.]+) "
    r"head_max_median=([\d.]+) ratio_x1000=(\d+) "
    r"indicted_conc=(\d) indicted_tensor=(\d)", out):
    conc[int(m.group(1))] = {
        "both_max": float(m.group(2)), "both_mean": float(m.group(3)),
        "konly_max": float(m.group(4)), "vonly_max": float(m.group(5)),
        "chan_max": float(m.group(6)), "chan_mean": float(m.group(7)),
        "worst_head": int(m.group(8)), "ctrl_max": float(m.group(9)),
        "median": float(m.group(10)), "ratio_x1000": int(m.group(11)),
        "ind_conc": int(m.group(12)), "ind_tensor": int(m.group(13)),
    }
check("four CONC lines filed, in the stated order",
      list(conc) == LENGTHS, ", ".join(str(k) for k in conc))

mc = re.search(r"CROSSCHECK L=256 inline_vs_module_ref_max=([\d.]+)", out)
check("inline reference == module attention_f32_head at 256 (CROSSCHECK 0.0)",
      mc is not None and float(mc.group(1)) == 0.0)

gate_ok = all(
    L in conc and L in rungs89
    and conc[L]["both_max"] == rungs89[L][0]
    and abs(conc[L]["both_mean"] - rungs89[L][1]) < 1e-12
    for L in LENGTHS)
check("VALIDATION GATE: BOTH aggregate reproduces J-089's ladder exactly (4 lengths)",
      gate_ok)

recompute_ok = True
for L in LENGTHS:
    if L not in conc or L not in heads:
        recompute_ok = False
        break
    mx = sorted(h["both_max"] for h in heads[L].values())
    median = (mx[3] + mx[4]) / 2.0
    worst = max(range(8), key=lambda h: heads[L][h]["both_max"])
    ctrl = max(heads[L][h]["both_max"] for h in range(8) if h != worst)
    c = conc[L]
    if not (abs(median - c["median"]) < 1e-9
            and abs(int(mx[7] / median * 1000) - c["ratio_x1000"]) <= 2
            and worst == c["worst_head"]
            and abs(ctrl - c["ctrl_max"]) < 1e-9
            and abs(max(h["k_max"] for h in heads[L].values()) - c["konly_max"]) < 1e-9
            and abs(max(h["v_max"] for h in heads[L].values()) - c["vonly_max"]) < 1e-9):
        recompute_ok = False
check("median / ratio / worst head / control / tensor maxima recompute from per-head lines",
      recompute_ok)

i2 = any(conc[L]["both_max"] > BOUND
         and conc[L]["both_max"] >= 2.0 * conc[L]["median"] for L in conc)
i3 = any(conc[L]["konly_max"] > BOUND or conc[L]["vonly_max"] > BOUND
         for L in conc)
check("indictment I2 (concentration) does NOT fire (max <= B and ratio < 2.0 everywhere)",
      not i2 and all(conc[L]["ind_conc"] == 0 for L in conc),
      f"max ratio {max(conc[L]['ratio_x1000'] for L in conc) / 1000.0}")
check("indictment I3 (tensor) does NOT fire (K-only and V-only maxima < B)",
      not i3 and all(conc[L]["ind_tensor"] == 0 for L in conc),
      f"worst V-only {max(conc[L]['vonly_max'] for L in conc)}")
mr = re.search(r"RULEM concentration_or_tensor_indicted=(\d)", out)
check("filed RULEM line agrees: no concentration/tensor indictment",
      mr is not None and int(mr.group(1)) == 0 and not (i2 or i3))
check("verdict under the pre-registered rule is NOT KEPT (no indictment)",
      not (i1 or i2 or i3))
check("per-channel == per-row exactly at every length, as filed",
      all(conc[L]["chan_max"] == conc[L]["both_max"]
          and conc[L]["chan_mean"] == conc[L]["both_mean"] for L in conc))
check("every head at every length is under the bound B",
      all(h["both_max"] <= BOUND for L in heads for h in heads[L].values()))

# ------------------------------------------------------------------
# 5. Independent Python re-derivation of the 128 rung + saturation
# ------------------------------------------------------------------
HEADS, HD, WIDTH = 8, 128, 1024


def synth(i):
    return ((i * 37 + (i // 13) * 7) % 17 - 8) / 8.0


def quantize_slice(vals):
    m = max(abs(v) for v in vals)
    s = m / 127.0 if m > 0 else 1.0
    out = []
    for v in vals:
        q = v / s
        r = math.floor(q + 0.5) if q >= 0 else -math.floor(-q + 0.5)
        r = max(-127, min(127, r))
        out.append(r * s)
    return out


L = 128
# Full rows precomputed once (per-head-slice quantization,
# exactly the store's per-row shape), as in J-089's inspect.
eK, eV, dK, dV = [], [], [], []
for t in range(L):
    krow = [synth(t * WIDTH + j + 11) for j in range(WIDTH)]
    vrow = [synth(t * WIDTH + j + 5000) for j in range(WIDTH)]
    dk, dv = [], []
    for h in range(HEADS):
        dk.extend(quantize_slice(krow[h * HD:(h + 1) * HD]))
        dv.extend(quantize_slice(vrow[h * HD:(h + 1) * HD]))
    eK.append(krow)
    eV.append(vrow)
    dK.append(dk)
    dV.append(dv)


def py_head(h, mode):
    q = [synth(h * HD + j + 97) for j in range(HD)]
    sl = slice(h * HD, (h + 1) * HD)

    def attn(K, V):
        scores = [
            sum(q[j] * K[t][sl][j] for j in range(HD)) / math.sqrt(HD)
            for t in range(L)
        ]
        mx = max(scores)
        ex = [math.exp(s - mx) for s in scores]
        den = sum(ex)
        return [
            sum(ex[t] / den * V[t][sl][j] for t in range(L))
            for j in range(HD)
        ]

    ref = attn(eK, eV)
    got = attn(dK if mode in ("both", "k") else eK,
               dV if mode in ("both", "v") else eV)
    devs = [abs(a - b) for a, b in zip(got, ref)]
    return max(devs), sum(devs) / HD


red_ok = True
for h in range(HEADS):
    f = heads.get(L, {}).get(h, {})
    for mode, key in (("both", "both_max"), ("k", "k_max"), ("v", "v_max")):
        mx, _ = py_head(h, mode)
        if abs(mx - f.get(key, -1)) >= 2e-6:
            red_ok = False
    mx, mean = py_head(h, "both")
    if abs(mean - f.get("both_mean", -1)) >= 2e-6:
        red_ok = False
check("Python re-derivation of the 128 rung agrees per head (maxima + BOTH means < 2e-6)",
      red_ok)

sat_ok = True
for off in (11, 5000):
    for t in range(L):
        for h in range(HEADS):
            if max(abs(synth(t * WIDTH + h * HD + j + off))
                   for j in range(HD)) != 1.0:
                sat_ok = False
    for idx in range(WIDTH):
        if max(abs(synth(t * WIDTH + idx + off)) for t in range(L)) != 1.0:
            sat_ok = False
check("range saturation proven: every row slice and every channel attains maxabs 1.0 "
      "(per-row scale == per-channel scale == 1/127, so chan == both mechanically)",
      sat_ok)

# ------------------------------------------------------------------
# 6. Candidate accounting re-derived in Python
# ------------------------------------------------------------------
def price(layers, hdrs, hd, fk, fv):
    return layers * 2 * hdrs * hd + layers * 2 * hdrs * 4 + (fk + fv) * (hd - 4)


check("8B candidate table re-derives (int8 67584; first 69568; one head 75520; half/K/V 99328; f16 131072)",
      price(32, 8, 128, 0, 0) == 67584 and price(32, 8, 128, 8, 8) == 69568
      and price(32, 8, 128, 32, 32) == 75520
      and price(32, 8, 128, 128, 128) == 99328
      and price(32, 8, 128, 256, 0) == 99328
      and price(32, 8, 128, 256, 256) == 131072)
check("0.6B candidate table re-derives (59136 / 61120 / 66080 / 114688)",
      price(28, 8, 128, 0, 0) == 59136 and price(28, 8, 128, 8, 8) == 61120
      and price(28, 8, 128, 28, 28) == 66080
      and price(28, 8, 128, 224, 224) == 114688)
check("R3 price boundary re-derives: half-layers overhead x2 EQUALS the saving (strict rule refuses)",
      2 * (99328 - 67584) == 131072 - 67584)
check("per-channel break-even re-derives: totals agree at 128 tokens (8,650,752 B)",
      65536 * 128 + 262144 == 67584 * 128 == 8650752)

# ------------------------------------------------------------------
# 7. The doc's honesty statements + table fidelity
# ------------------------------------------------------------------
check("doc states the verdict NOT KEPT with its mechanical code",
      "NOT KEPT" in doc and "NOT_KEPT_NO_INDICTMENT" in doc)
check("doc files the deferred live recipe for the J-098 gate",
      "Deferred leg" in doc and "J-098 gate" in doc)
check("doc states the live model verdict remains NOT PROVEN",
      "NOT PROVEN in either direction" in doc)
check("doc's section-5 medians match the filed CONC lines",
      all(f"{conc[L]['median']:.10f}".rstrip('0').rstrip('.') in doc
          or str(conc[L]['median']) in doc for L in conc))
check("doc's section-5 V-only maximum at 2,048 matches the filed line (0.002039522)",
      "0.002039522" in doc and conc.get(2048, {}).get("vonly_max") == 0.002039522)

print()
print(f"J090_INSPECT: {checks - fails}/{checks} checks PASS")
sys.exit(1 if fails else 0)
