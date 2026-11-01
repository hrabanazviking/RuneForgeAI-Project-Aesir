#!/usr/bin/env python3
"""J-089 KV faithfulness -- inspect / re-derivation script.

Checks, mechanically:

- the harness's structure in core/kv_faith.mojo: the step
  and pair reductions exist, pair verdicts compose through
  J-060's grade_prefill_cell, and the module carries NO
  near-tie constant of its own (no second verdict rule);
- the filed definitions (forced token = reference top,
  first-maximum ties, strictly-greater rank count, the
  sub-milli refusal) are present in the module header;
- the ladder harness is J-088's exercise: identical synth
  function text as j088_bench.mojo, the stated lengths,
  the pre-registered bound, the PROXY naming;
- the filed ladder lines in j089_test_output.txt: six
  rungs in order; the 256 rung reproduces J-088's filed
  FAITH_ATTN numbers exactly (read out of
  j088_test_output.txt); the CROSSCHECK is 0.0; the
  VERDICT line is exactly what the pre-registered rule
  (V1) computes from the filed rungs;
- an independent Python re-derivation of the 128 and 256
  rungs (quantizer + attention + proxy + grade, written
  from the module definitions, in float64): every
  deviation figure agrees with the filed Mojo figures
  within 2e-6 (float32 vs float64 arithmetic) and the
  proxy rank / gap / tops agree exactly;
- the doc states the live verdict NOT PROVEN and files
  the deferred recipe.

Every check prints PASS/FAIL; the script exits nonzero on
any FAIL. Run from the repo root:  python3 docs/janas/j089_inspect.py
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


mod = (CORE / "kv_faith.mojo").read_text()
test = (ROOT / "aesir_engine" / "tests" / "test_kv_faith.mojo").read_text()
ladder = (JANAS / "j089_ladder.mojo").read_text()
bench88 = (JANAS / "j088_bench.mojo").read_text()
out = (JANAS / "j089_test_output.txt").read_text()
out88 = (JANAS / "j088_test_output.txt").read_text()
doc = (JANAS / "J089_KV_FAITHFULNESS.md").read_text()

# ------------------------------------------------------------------
# 1. Harness structure: the reduction, composition, no second rule
# ------------------------------------------------------------------
check("step reduction exists (grade_kv_step)", "def grade_kv_step" in mod)
check("pair reduction exists (grade_kv_pair)", "def grade_kv_pair" in mod)
check("pair verdicts compose through J-060's grade_prefill_cell",
      "grade_prefill_cell" in mod and "from core.prefill_grade import" in mod)
check("module defines NO near-tie constant (no second verdict rule)",
      "NEAR_TIE_MAX" not in mod and "comptime" not in mod)
check("forced token is the reference row's top (argmax over ref)",
      "var ref_top = _argmax_first(ref_row)" in mod)
check("ties resolve to the first (lowest-index) maximum",
      "First (lowest-index) maximum" in mod)
check("rank counts strictly-greater test logits only",
      "if test_row[j] > target:" in mod)
check("gap is measured inside the test row (test top - forced logit)",
      "var gap = test_row[test_top] - target" in mod)
check("sub-milli positive-rank gap is refused, not reclassified",
      "sub-milli-logit gap" in mod and "refusing rather than reclassifying" in mod)
check("non-finite logits are refused (NaN / infinite)",
      "NaN logit" in mod and "infinite logit" in mod)
check("tests pin the band edges (999 in, 1000 out, rank 3 out)",
      "edge gap 999" in test and "edge gap 1000" in test
      and "rank3 divergent" in test)
check("tests reproduce the J-022 pattern through logit rows",
      "23 exact + 1 near" in test and "witness exact count" in test)

# ------------------------------------------------------------------
# 2. Ladder harness is J-088's exercise, extended
# ------------------------------------------------------------------
synth_def = "Float32((i * 37 + (i // 13) * 7) % 17 - 8) / Float32(8.0)"
check("ladder synth is byte-identical to J-088's bench synth",
      synth_def in ladder and synth_def in bench88)
check("ladder lengths are the stated six",
      "[128, 256, 512, 2048, 8192, 32768]" in ladder)
check("pre-registered bound is J-088's round-trip bound",
      "comptime BOUND = Float32(0.003937006)" in ladder)
check("proxy is named PROXY in the ladder header (not model logits)",
      "logit-PROXY" in ladder and "NOT a model logit" in ladder)
check("ladder grades its proxy rows through the new harness",
      "grade_kv_step(prowref, prow8)" in ladder)

# ------------------------------------------------------------------
# 3. Filed ladder lines: gate, table, verdict consistency
# ------------------------------------------------------------------
rungs = {}
for m in re.finditer(
    r"LADDER L=(\d+) attn_max=([\d.]+) attn_mean=([\d.]+) "
    r"proxy_max=([\d.]+) proxy_mean=([\d.]+) proxy_rank=(\d+) "
    r"proxy_gap_milli=(\d+) proxy_class=(\w+) "
    r"proxy_ref_top=(\d+) proxy_test_top=(\d+)", out):
    rungs[int(m.group(1))] = {
        "attn_max": float(m.group(2)), "attn_mean": float(m.group(3)),
        "proxy_max": float(m.group(4)), "proxy_mean": float(m.group(5)),
        "rank": int(m.group(6)), "gap": int(m.group(7)),
        "cls": m.group(8), "ref_top": int(m.group(9)),
        "test_top": int(m.group(10)),
    }
check("six ladder rungs filed, in the stated order",
      list(rungs) == [128, 256, 512, 2048, 8192, 32768],
      ", ".join(str(k) for k in rungs))

m88 = re.search(r"FAITH_ATTN elements=1024 max_abs_dev=([\d.]+) "
                r"mean_abs_dev=([\d.]+)", out88)
check("J-088's filed FAITH_ATTN found in its output file", m88 is not None)
if m88 and 256 in rungs:
    check("256 rung reproduces J-088's FAITH_ATTN exactly (validation gate)",
          abs(rungs[256]["attn_max"] - float(m88.group(1))) == 0.0
          and abs(rungs[256]["attn_mean"] - float(m88.group(2))) < 1e-12,
          f"max {rungs[256]['attn_max']} vs filed {m88.group(1)}")
mc = re.search(r"CROSSCHECK inline_vs_module_ref_max=([\d.]+)", out)
check("inline reference == module attention_f32_head at 256 (CROSSCHECK 0.0)",
      mc is not None and float(mc.group(1)) == 0.0)

BOUND = 0.003937006
first_cost = -1
for L in [128, 256, 512, 2048, 8192, 32768]:
    r = rungs.get(L, {})
    if r and (r["attn_max"] > BOUND or r["cls"] == "DIVERGENT"):
        first_cost = L
        break
mv = re.search(r"VERDICT first_cost_len=(-?\d+) growth_x1000=(\d+)", out)
check("VERDICT line matches the pre-registered rule applied to the rungs",
      mv is not None and int(mv.group(1)) == first_cost,
      f"rule gives first_cost_len={first_cost}")
if mv and 128 in rungs and 32768 in rungs:
    growth = int(rungs[32768]["attn_max"] / rungs[128]["attn_max"] * 1000)
    check("growth_x1000 recomputes from the filed rungs",
          int(mv.group(2)) == growth, f"{growth}")
check("every rung's proxy grade is EXACT (rank 0, gap 0)",
      all(r["cls"] == "EXACT" and r["rank"] == 0 and r["gap"] == 0
          for r in rungs.values()))
check("no rung's attention max exceeds the bound B",
      all(r["attn_max"] <= BOUND for r in rungs.values()))

# ------------------------------------------------------------------
# 4. Independent Python re-derivation of the 128 / 256 rungs
# ------------------------------------------------------------------
HEADS, HD, WIDTH, PV = 8, 128, 1024, 64


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


def py_rung(L):
    dqK, dqV = [], []
    for t in range(L):
        krow = [synth(t * WIDTH + j + 11) for j in range(WIDTH)]
        vrow = [synth(t * WIDTH + j + 5000) for j in range(WIDTH)]
        dk, dv = [], []
        for h in range(HEADS):
            dk.extend(quantize_slice(krow[h * HD:(h + 1) * HD]))
            dv.extend(quantize_slice(vrow[h * HD:(h + 1) * HD]))
        dqK.append(dk)
        dqV.append(dv)
    amax, asum, acount = 0.0, 0.0, 0
    concat8, concatref = [], []

    def attn(getk, getv, q):
        scores = [sum(q[j] * getk(t, j) for j in range(HD)) / math.sqrt(HD)
                  for t in range(L)]
        mx = max(scores)
        ex = [math.exp(s - mx) for s in scores]
        den = sum(ex)
        return [sum(ex[t] / den * getv(t, j) for t in range(L))
                for j in range(HD)]

    for h in range(HEADS):
        q = [synth(h * HD + j + 97) for j in range(HD)]
        got = attn(lambda t, j: dqK[t][h * HD + j],
                   lambda t, j: dqV[t][h * HD + j], q)
        want = attn(lambda t, j: synth(t * WIDTH + h * HD + j + 11),
                    lambda t, j: synth(t * WIDTH + h * HD + j + 5000), q)
        for j in range(HD):
            d = abs(got[j] - want[j])
            amax = max(amax, d)
            asum += d
            acount += 1
            concat8.append(got[j])
            concatref.append(want[j])

    def prow(concat):
        return [sum(concat[i] * (((o * 1021 + i * 131 + 7) % 29) - 14) / 14.0
                    for i in range(WIDTH)) for o in range(PV)]

    p8, pref = prow(concat8), prow(concatref)
    pmax = max(abs(a - b) for a, b in zip(p8, pref))
    pmean = sum(abs(a - b) for a, b in zip(p8, pref)) / PV
    ref_top = pref.index(max(pref))
    test_top = p8.index(max(p8))
    rank = sum(1 for v in p8 if v > p8[ref_top])
    gap_milli = math.floor((max(p8) - p8[ref_top]) * 1000 + 0.5)
    return {"attn_max": amax, "attn_mean": asum / acount,
            "proxy_max": pmax, "proxy_mean": pmean,
            "rank": rank, "gap": gap_milli,
            "ref_top": ref_top, "test_top": test_top}


for L in (128, 256):
    py = py_rung(L)
    f = rungs.get(L, {})
    ok = (abs(py["attn_max"] - f.get("attn_max", -1)) < 2e-6
          and abs(py["attn_mean"] - f.get("attn_mean", -1)) < 2e-6
          and abs(py["proxy_max"] - f.get("proxy_max", -1)) < 2e-6
          and abs(py["proxy_mean"] - f.get("proxy_mean", -1)) < 2e-6
          and py["rank"] == f.get("rank") and py["gap"] == f.get("gap")
          and py["ref_top"] == f.get("ref_top")
          and py["test_top"] == f.get("test_top"))
    check(f"Python re-derivation of the {L} rung agrees (deviations < 2e-6, grade exact)",
          ok, f"py attn_max={py['attn_max']:.7f} vs filed {f.get('attn_max')}")

# ------------------------------------------------------------------
# 5. The doc's honesty statements
# ------------------------------------------------------------------
check("doc states the live model verdict NOT PROVEN",
      "NOT PROVEN in either direction" in doc)
check("doc files the deferred live recipe for the J-098 gate",
      "Deferred leg" in doc and "J-098 gate" in doc)
check("doc names the proxy as not a model logit at the table",
      "it is not a model logit" in doc)
check("doc's synthetic verdict is the rule's verdict",
      "NO SYNTHETIC COST FOUND at 128..32,768" in doc)

print()
print(f"J089_INSPECT: {checks - fails}/{checks} checks PASS")
sys.exit(1 if fails else 0)
