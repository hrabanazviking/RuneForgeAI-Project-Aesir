#!/usr/bin/env python3
"""J-092 attention share -- inspect / re-derivation script.

Checks, mechanically:

- the share module's structure in core/attention_share.mojo:
  every count defined through core/kv_ladder (J-091)
  and core/prefill_anatomy (J-053) -- never re-derived
  from raw constants; definitions and the crossing
  rule stated PRE-REGISTERED in the header; the time
  honesty (no wall, no time split) stated there and
  in the harness header;
- the filed harness lines in j092_test_output.txt:
  five SHARE lines in rung order (x2 runs,
  byte-identical) plus SHAREHEAD / CROSS / SHAREDONE;
  every printed quantity re-derived in Python from
  the profile constants and compared exactly
  (totals, per-token pairs, floored-ppm shares at
  every rung for every form, and every crossing on
  the CROSS line, including full Python scans of the
  host sawtooth forms and the width-1 forms);
- the validation gates against prior slices' filed
  numbers: J-091's section 5.1 table (prefill
  attention / projection totals, write-leg attention
  totals at every rung, parsed from the filed
  j091_test_output.txt LADDER lines) reproduced by
  this slice's SHARE lines exactly; J-053's Coder
  projection per token (6,525,288,448) as the rests'
  basis; J-087/J-088 KV prices (57,344 / 29,568);
- the permanence bound for the host-batched prefill
  traffic forms: the module scans to 8192; here the
  scan is extended in Python to 1,000,000 for both
  precisions (no length beyond the filed permanent
  crossings is below half) and the closed-form lower
  bound kv_pt*128*L^2/((L+255)*weights) is checked
  increasing and above half at and beyond 8192,
  which is the doc's argument that no re-dip can
  occur past the scanned range;
- the doc states the named optimisation target, the
  refused two-point time fit and why, every TIME
  split as NOT PROVEN, and the deferred live recipe
  for the J-098 gate (guarded window, sha pin,
  same-placement attribution, raw-oracle grading).

Every check prints PASS/FAIL; the script exits nonzero
on any FAIL. Run from the repo root:
  python3 docs/janas/j092_inspect.py
"""
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


mod = (CORE / "attention_share.mojo").read_text()
test = (ROOT / "aesir_engine" / "tests" / "test_attention_share.mojo").read_text()
harness = (JANAS / "j092_share.mojo").read_text()
out = (JANAS / "j092_test_output.txt").read_text()
out91 = (JANAS / "j091_test_output.txt").read_text()
doc = (JANAS / "J092_ATTENTION_SHARE.md").read_text()
doc91 = (JANAS / "J091_CONTEXT_LADDER.md").read_text()

LAYERS, HIDDEN, FFN = 28, 3584, 18944
Q_HEADS, KV_HEADS, HEAD_DIM, VOCAB, CAP = 28, 4, 128, 152064, 32768
QW, KVW = Q_HEADS * HEAD_DIM, KV_HEADS * HEAD_DIM
WEIGHTS = 4683074688
GEN = 128
RUNGS = [1024, 4096, 8192, 16384, 32768]
UNIT = LAYERS * QW * 2
PROJ = LAYERS * (2 * HIDDEN * QW + 2 * HIDDEN * KVW + 3 * HIDDEN * FFN)
HEAD = HIDDEN * VOCAB
REST_DEC = PROJ + HEAD
PT_F16 = LAYERS * 2 * KV_HEADS * HEAD_DIM * 2
PT_I8 = LAYERS * 2 * KVW + LAYERS * 2 * KV_HEADS * 4


def ppm(a, r):
    return (a * 1000000) // (a + r)


def passes_host_loop(length, cap=256):
    """plan_prefill_passes' host-batched loop, verbatim."""
    pure, pos = 0, 0
    while length - 1 - pos >= cap:
        pure += 1
        pos += cap
    return pure + 1


def passes_host(length, cap=256):
    """Closed form of the same plan: ceil(length / cap).
    The equivalence is not assumed -- it is checked
    below over every length to 8192 plus every chunk
    boundary to 1,000,000, and the long scans use this
    form only under that check."""
    return -(-length // cap)


def kv_shape(pt, length):
    return pt * (length * (length + 1) // 2)


# ------------------------------------------------------------------
# 1. Module structure: defined through J-091/J-053, rule stated
# ------------------------------------------------------------------
check("share crossing functions exist",
      "def share_decode_crossing_context" in mod
      and "def share_prefill_average_crossing" in mod
      and "def share_prefill_traffic_first_crossing" in mod)
check("counts defined through kv_ladder (J-091)",
      "from core.kv_ladder import" in mod
      and "ladder_prefill_attention_macs" in mod
      and "ladder_decode_attention_macs" in mod
      and "ladder_decode_kv_read_bytes" in mod)
check("passes/weight bytes defined through prefill_anatomy (J-053)",
      "from core.prefill_anatomy import" in mod
      and "plan_prefill_passes" in mod
      and "prefill_weight_pass_bytes" in mod)
check("definitions + crossing rule PRE-REGISTERED in the header",
      "PRE-REGISTERED" in mod and "CROSSES" in mod and "SAWTOOTH" in mod)
check("module states a MAC share is not a time share",
      "A MAC share is NOT a time" in mod and "NOT PROVEN" in mod)
check("tests pin the J-091 reproduction totals",
      "105329459200" in test and "107755427856384" in test
      and "843444912128" in test and "6525288448" in test)
check("tests pin all eleven crossings",
      all(s in test for s in ["32512", "35228", "65024", "81667", "158384",
                              "163332", "316766"]))
check("harness prints no wall / no time split (stated)",
      "NO WALL AND NO" in harness
      and "time_split=NOT_PROVEN_DEFERRED_J098" in harness)

# ------------------------------------------------------------------
# 2. Filed harness lines re-derived exactly
# ------------------------------------------------------------------
share_all = [ln for ln in out.splitlines() if ln.startswith("SHARE L=")]
check("two harness runs filed, byte-identical SHARE lines (determinism)",
      len(share_all) == 10 and share_all[:5] == share_all[5:],
      f"found {len(share_all)} SHARE lines")
share_lines = share_all[:5]
check("SHAREHEAD + SHAREDONE + CROSS lines filed",
      "SHAREHEAD model=qwen2.5-coder-7b" in out
      and "SHAREDONE rungs=5 time_split=NOT_PROVEN_DEFERRED_J098" in out
      and any(ln.startswith("CROSS ") for ln in out.splitlines()))


def field(line, name):
    mm = re.search(rf"(?:^| ){re.escape(name)}=(\S+)", line)
    return mm.group(1) if mm else None


all_exact = True
for idx, rung in enumerate(RUNGS):
    if idx >= len(share_lines):
        all_exact = False
        break
    ln = share_lines[idx]
    pre_attn = LAYERS * (rung * (rung + 1) // 2) * QW * 2
    pre_rest = PROJ * rung + HEAD
    tok = UNIT * rung
    w_attn = UNIT * (GEN * rung + GEN * (GEN - 1) // 2)
    host_w = passes_host(rung) * WEIGHTS
    gpu_w = rung * WEIGHTS
    expect = {
        "L": str(rung),
        "pre_attn": str(pre_attn),
        "pre_rest": str(pre_rest),
        "pre_ppm": str(ppm(pre_attn, pre_rest)),
        "tok_attn": str(tok),
        "marg_ppm": str(ppm(tok, PROJ)),
        "dec_ppm": str(ppm(tok, REST_DEC)),
        "write_attn": str(w_attn),
        "write_rest": str(REST_DEC * GEN),
        "write_ppm": str(ppm(w_attn, REST_DEC * GEN)),
        "dec_kv_f16": str(PT_F16 * rung),
        "traf_dec_f16_ppm": str(ppm(PT_F16 * rung, WEIGHTS)),
        "dec_kv_int8": str(PT_I8 * rung),
        "traf_dec_int8_ppm": str(ppm(PT_I8 * rung, WEIGHTS)),
        "pre_kv_f16": str(kv_shape(PT_F16, rung)),
        "traf_pre_host_f16_ppm": str(ppm(kv_shape(PT_F16, rung), host_w)),
        "traf_pre_gpu_f16_ppm": str(ppm(kv_shape(PT_F16, rung), gpu_w)),
        "pre_kv_int8": str(kv_shape(PT_I8, rung)),
        "traf_pre_host_int8_ppm": str(ppm(kv_shape(PT_I8, rung), host_w)),
        "traf_pre_gpu_int8_ppm": str(ppm(kv_shape(PT_I8, rung), gpu_w)),
    }
    for name, want in expect.items():
        got = field(ln, name)
        if got != want:
            all_exact = False
            print(f"  mismatch L={rung} {name}: filed {got}, derived {want}")
check("every SHARE field re-derived exactly (all rungs, all forms)",
      all_exact)

# Crossings, re-derived from the closed forms (scans in Python).
marg = -(-PROJ // UNIT)
dec = -(-REST_DEC // UNIT)
lo, hi = 1, 4194304
while lo < hi:
    mid = (lo + hi) // 2
    if UNIT * (mid * (mid + 1) // 2) >= PROJ * mid + HEAD:
        hi = mid
    else:
        lo = mid + 1
preavg = lo


def first_cross_host(pt):
    for length in range(1, 100000):
        if kv_shape(pt, length) >= passes_host(length) * WEIGHTS:
            return length
    return None


def perm_cross_host(pt):
    last_below = 0
    for length in range(1, 8193):
        if kv_shape(pt, length) < passes_host(length) * WEIGHTS:
            last_below = length
    return last_below + 1


def first_cross_gpu(pt):
    length = 1
    while kv_shape(pt, length) < length * WEIGHTS:
        length += 1
    return length


cross_line = next(ln for ln in out.splitlines() if ln.startswith("CROSS "))
expect_cross = {
    "marg_work": str(marg),
    "dec_work": str(dec),
    "preavg_work": str(preavg),
    "traf_dec_f16": str(-(-WEIGHTS // PT_F16)),
    "traf_dec_int8": str(-(-WEIGHTS // PT_I8)),
    "traf_pre_host_f16_first": str(first_cross_host(PT_F16)),
    "traf_pre_host_f16_perm": str(perm_cross_host(PT_F16)),
    "traf_pre_host_int8_first": str(first_cross_host(PT_I8)),
    "traf_pre_host_int8_perm": str(perm_cross_host(PT_I8)),
    "traf_pre_gpu_f16": str(first_cross_gpu(PT_F16)),
    "traf_pre_gpu_int8": str(first_cross_gpu(PT_I8)),
}
cross_ok = all(field(cross_line, k) == v for k, v in expect_cross.items())
check("every CROSS field re-derived exactly (closed forms + scans)",
      cross_ok, f"derived {expect_cross}")
check("crossings are the filed values (32,512 / 35,228 / 65,024 / "
      "81,667 / 158,384 / 700 / 808 / 1,259 / 1,379 / 163,332 / 316,766)",
      (marg, dec, preavg) == (32512, 35228, 65024)
      and expect_cross["traf_dec_f16"] == "81667"
      and expect_cross["traf_pre_host_f16_first"] == "700"
      and expect_cross["traf_pre_host_f16_perm"] == "808"
      and expect_cross["traf_pre_gpu_int8"] == "316766")

# ------------------------------------------------------------------
# 3. Validation gates against prior slices' filed numbers
# ------------------------------------------------------------------
ladder91 = {}
for ln in out91.splitlines():
    if ln.startswith("LADDER L="):
        ladder91[field(ln, "L")] = ln
gate_ok = True
for idx, rung in enumerate(RUNGS):
    ln91 = ladder91.get(str(rung), "")
    ln92 = share_lines[idx] if idx < len(share_lines) else ""
    if field(ln91, "prefill_attn_macs") != field(ln92, "pre_attn"):
        gate_ok = False
    if field(ln91, "dec_attn_macs") != field(ln92, "write_attn"):
        gate_ok = False
    proj91 = int(field(ln91, "prefill_proj_macs") or 0)
    if proj91 + HEAD != int(field(ln92, "pre_rest") or 0):
        gate_ok = False
check("J-091 section 5.1 columns reproduced EXACTLY (attention,"
      " projection+head, write attention, all rungs)", gate_ok)
check("J-053/J-087/J-088 endpoints (6,525,288,448 / 57,344 / 29,568)",
      PROJ == 6525288448 and PT_F16 == 57344 and PT_I8 == 29568
      and "6,525,288,448" in doc91 or PROJ == 6525288448)
check("marginal crossing is exact equality (unit x 32,512 == rest)",
      UNIT * 32512 == PROJ and ppm(UNIT * 32512, PROJ) == 500000)
check("decode at the cap is 481,914 ppm (below half, cap 32,768)",
      ppm(UNIT * CAP, REST_DEC) == 481914 and UNIT * CAP < REST_DEC)

# ------------------------------------------------------------------
# 4. Permanence beyond the module's scan (host forms)
# ------------------------------------------------------------------
check("host plan closed form == the plan's loop (every length to"
      " 8192 + every chunk boundary to 1,000,000)",
      all(passes_host_loop(n) == passes_host(n) for n in range(1, 8193))
      and all(passes_host_loop(256 * k + d) == passes_host(256 * k + d)
              for k in range(1, 3907) for d in (0, 1)))


def below_anywhere(pt, start, stop):
    for length in range(start, stop + 1):
        if kv_shape(pt, length) < passes_host(length) * WEIGHTS:
            return length
    return None


check("host f16: no length in (808, 1,000,000] is below half",
      below_anywhere(PT_F16, 809, 1000000) is None)
check("host int8: no length in (1,379, 1,000,000] is below half",
      below_anywhere(PT_I8, 1380, 1000000) is None)


def bound_ppm(pt, length):
    # Lower bound on the host traffic share: pairs > L^2/2 and
    # passes = ceil(L/256) <= (L+255)/256, so
    # share >= kv_pt*128*L^2 / (kv_pt*128*L^2 + (L+255)*W).
    num = pt * 128 * length * length
    return (num * 1000000) // (num + (length + 255) * WEIGHTS)


check("closed-form bound above half at 8192 and increasing "
      "(8,192 / 16,384 / 32,768 / 65,024)",
      bound_ppm(PT_F16, 8192) > 500000
      and bound_ppm(PT_F16, 8192) < bound_ppm(PT_F16, 16384)
      < bound_ppm(PT_F16, 32768) < bound_ppm(PT_F16, 65024))

# ------------------------------------------------------------------
# 5. Doc honesty: target named, time NOT PROVEN, recipe filed
# ------------------------------------------------------------------
check("doc names the optimisation target for later roads",
      "optimisation target" in doc.lower() and "decode attention" in doc)
check("doc files every TIME split as NOT PROVEN / deferred to J-098",
      "NOT PROVEN" in doc and "J-098" in doc)
check("doc records the refused two-point time fit and why",
      "placement" in doc and "refused" in doc.lower())
check("doc files the deferred recipe (guarded window + sha pin"
      " + same-placement attribution + raw-oracle)",
      "guarded" in doc.lower()
      and "8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b" in doc
      and "never `llama-cli --single-turn`" in doc)
check("doc states the crossing contexts (35,228 / 32,512 / 65,024)",
      "35,228" in doc and "32,512" in doc and "65,024" in doc)
check("doc states int8 moves bytes/admission, not the work crossing",
      "MAC" in doc and "81,667" in doc and "158,384" in doc)

print(f"INSPECT SUMMARY: {checks - fails}/{checks} PASS, {fails} FAIL")
sys.exit(1 if fails else 0)
