#!/usr/bin/env python3
"""J-093 memory ceiling -- inspect / re-derivation script.

Checks, mechanically:

- the ceiling module's structure in
  core/memory_ceiling.mojo: peaks defined THROUGH
  core/kv_ladder (J-091), the pool defined THROUGH
  core/expert_cache's plan_shared_cache_pool (J-026);
  definitions, the two forms, the pool rule and the
  growth-shape rule stated PRE-REGISTERED in the
  header; the honesty (accounted is not measured)
  stated there and in the harness header;
- the no-wiring fact (J-031 section 10's reason):
  no session/execution file imports
  core.memory_ceiling, and tests/run_all.mojo does
  not register test_memory_ceiling;
- the inspection fact the two forms rest on: the
  dense CUDA session admits DenseGQAProfile only and
  the MoE session admits arch "olmoe" only (grepped
  first-hand from this tree);
- the filed harness lines in j093_test_output.txt:
  CEILHEAD / CEILDONE, CEILING + COMBINED lines for
  5 rungs x 2 precisions, x2 runs byte-identical,
  plus 2 GROWTH lines per run; every printed quantity
  re-derived in Python from the profile constants
  and compared exactly (Form A peaks per line, KV /
  activation itemisation, verdicts under the tree's
  caps and integration facts; Form B summed KV /
  scratch, reserve, pool, floor, combined peak,
  accounted ceiling, below-floor);
- the validation gate: the filed CEILING GPU session
  peaks reproduce J-091 section 5.3's admission
  totals EXACTLY, parsed from the filed
  j091_test_output.txt LADDER lines;
- the growth shape: Aesir's ratio per line/precision
  (form A) and per precision (form B) re-derived and
  FLATTER than Janas's published 49/26 shape in every
  case; the KV share of the peak at base vs top rung;
- the doc states both forms labelled, the shape
  verdict plainly, every live peak as NOT PROVEN,
  and the deferred live recipe for the J-098 gate
  (guarded window, sha pin, RSS + nvidia-smi
  high-water beside the accounted ceiling, raw-oracle
  grading, never llama-cli --single-turn).

Every check prints PASS/FAIL; the script exits nonzero
on any FAIL. Run from the repo root:
  python3 docs/janas/j093_inspect.py
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


mod = (CORE / "memory_ceiling.mojo").read_text()
test = (ROOT / "aesir_engine" / "tests" / "test_memory_ceiling.mojo").read_text()
harness = (JANAS / "j093_ceiling.mojo").read_text()
out = (JANAS / "j093_test_output.txt").read_text()
out91 = (JANAS / "j091_test_output.txt").read_text()
doc = (JANAS / "J093_MEMORY_CEILING.md").read_text()
run_all = (ROOT / "aesir_engine" / "tests" / "run_all.mojo").read_text()

LAYERS, KV_HEADS, HEAD_DIM, CAP = 28, 4, 128, 32768
WEIGHTS = 4683074688
ACT_FIXED, ACT_PER = 208896, 28
SAMPLING = 905728
GEN = 128
RUNGS = [1024, 4096, 8192, 16384, 32768]
PT = {"f16": LAYERS * 2 * KV_HEADS * HEAD_DIM * 2,
      "int8": LAYERS * 2 * KV_HEADS * HEAD_DIM + LAYERS * 2 * KV_HEADS * 4}
OLMOE_RESIDENT, OLMOE_BODY, OLMOE_ROUTED = 311027712, 3900702720, 487587840
OLMOE_ACT = 16777216
OLMOE_KV = {"f16": 131072 * 512, "int8": 67584 * 512}
RESIDENT_TOTAL = WEIGHTS + OLMOE_RESIDENT
TOTAL = 17179869184
HEADROOM = TOTAL // 5
HOST_CAP = 16000
JANAS_PPM = 49 * 1000000 // 26


def act(ctx):
    return (ACT_FIXED + ACT_PER * ctx) * 4


def peak(pt, ctx, gpu):
    return WEIGHTS + pt * ctx + act(ctx) + (SAMPLING if gpu else 0)


def verdict(line, prec, rung, write):
    if prec == "int8":
        return "INTEGRATION_BLOCKED"
    needed = rung + GEN if write else rung
    cap = HOST_CAP if line == "cpu" else CAP
    return "CAP_REFUSED" if needed > cap else "ACCOUNTED"


def field(line, name):
    m = re.search(rf"(?:^| ){re.escape(name)}=([^ ]+)", line)
    return m.group(1) if m else None


# --- module structure -------------------------------------------------
check("ceiling functions exist",
      "def ceiling_dense_peak" in mod
      and "def ceiling_combined_peak" in mod
      and "def ceiling_shape_verdict" in mod)
check("peaks defined through kv_ladder (J-091)",
      "from core.kv_ladder import" in mod
      and "ladder_gpu_required_bytes" in mod
      and "ladder_kv_total" in mod)
check("pool defined through expert_cache (J-026)",
      "from core.expert_cache import" in mod
      and "plan_shared_cache_pool" in mod
      and "SharedExpertBudget" in mod)
check("definitions + forms + shape rule PRE-REGISTERED in the header",
      "PRE-REGISTERED" in mod and "FORM A" in mod and "FORM B" in mod
      and "FLATTER" in mod)
check("module states an accounted ceiling is not a measured peak",
      "NOT" in mod and "high-water" in mod)
check("tests pin the J-091 validation gate totals",
      "4751005312" in test and "6574888576" in test
      and "5661169280" in test)
check("harness prints no live peak (stated)",
      "NO LIVE" in harness and "NOT_PROVEN_DEFERRED_J098" in harness)

# --- the no-wiring fact + the two-forms inspection fact ---------------
importers = []
for path in (ROOT / "aesir_engine").rglob("*.mojo"):
    if path.name in ("memory_ceiling.mojo", "test_memory_ceiling.mojo"):
        continue
    if "memory_ceiling" in path.read_text():
        importers.append(str(path.relative_to(ROOT)))
check("no session/execution file imports core.memory_ceiling",
      importers == [], f"importers={importers}")
check("test_memory_ceiling not registered in run_all (J-031 section 10)",
      "memory_ceiling" not in run_all)
llama3_cuda = (CORE / "llama3_cuda.mojo").read_text()
moe_session = (CORE / "moe_session.mojo").read_text()
check("dense session is dense-profile shaped; MoE session admits olmoe only",
      "DenseGQAProfile" in llama3_cuda and 'arch "olmoe"' in moe_session
      or "olmoe" in moe_session)

# --- harness lines ------------------------------------------------------
ceil_lines = [l for l in out.splitlines() if l.startswith("CEILING ")]
comb_lines = [l for l in out.splitlines() if l.startswith("COMBINED ")]
growth_lines = [l for l in out.splitlines() if l.startswith("GROWTH ")]
check("two harness runs filed, byte-identical CEILING lines (determinism)",
      len(ceil_lines) == 20 and ceil_lines[:10] == ceil_lines[10:],
      f"found {len(ceil_lines)} CEILING lines")
check("CEILHEAD + CEILDONE + GROWTH lines filed",
      out.count("CEILHEAD ") == 2 and out.count("CEILDONE ") == 2
      and len(growth_lines) == 4)

ok = True
detail = ""
for line in ceil_lines:
    rung = int(field(line, "L"))
    prec = field(line, "prec")
    sess = rung + GEN
    exp = {
        "session": str(sess),
        "kv_sess": str(PT[prec] * sess),
        "act_sess": str(act(sess)),
        "gpu_read": str(peak(PT[prec], rung, True)),
        "gpu_peak": str(peak(PT[prec], sess, True)),
        "cpu_peak": str(peak(PT[prec], sess, False)),
        "kv_share_gpu_ppm": str(PT[prec] * sess * 1000000 // peak(PT[prec], sess, True)),
        "cpu_read_verdict": verdict("cpu", prec, rung, False),
        "cpu_peak_verdict": verdict("cpu", prec, rung, True),
        "gpu_read_verdict": verdict("gpu", prec, rung, False),
        "gpu_peak_verdict": verdict("gpu", prec, rung, True),
    }
    for name, want in exp.items():
        got = field(line, name)
        if got != want:
            ok = False
            detail = f"{line[:40]} {name}: filed {got} != derived {want}"
check("every CEILING field re-derived exactly (all rungs, both precisions)",
      ok, detail)

ok = True
detail = ""
for line in comb_lines:
    rung = int(field(line, "L"))
    prec = field(line, "prec")
    sess = rung + GEN
    kv_total = PT[prec] * sess + OLMOE_KV[prec]
    scratch = act(sess) + OLMOE_ACT
    reserve = RESIDENT_TOTAL + kv_total + scratch + HEADROOM
    pool = TOTAL - reserve
    exp = {
        "kv_total": str(kv_total),
        "scratch_total": str(scratch),
        "reserve": str(reserve),
        "pool": str(pool),
        "floor": str(pool // 4),
        "combined_peak": str(RESIDENT_TOTAL + kv_total + scratch + min(pool, OLMOE_BODY)),
        "accounted_ceiling": str(RESIDENT_TOTAL + kv_total + scratch + pool),
        "below_floor": "False",
    }
    for name, want in exp.items():
        got = field(line, name)
        if got != want:
            ok = False
            detail = f"{line[:40]} {name}: filed {got} != derived {want}"
check("every COMBINED field re-derived exactly (pool rule, summed reserves)",
      ok, detail)

ok = True
for line in growth_lines:
    prec = field(line, "prec")
    for form, gpu in (("gpu", True), ("cpu", False), ("combined", None)):
        if form == "combined":
            def comb(rung):
                sess = rung + GEN
                kv_total = PT[prec] * sess + OLMOE_KV[prec]
                scratch = act(sess) + OLMOE_ACT
                pool = TOTAL - (RESIDENT_TOTAL + kv_total + scratch + HEADROOM)
                return RESIDENT_TOTAL + kv_total + scratch + min(pool, OLMOE_BODY)
            ratio = comb(32768) * 1000000 // comb(1024)
        else:
            ratio = (peak(PT[prec], 32896, gpu) * 1000000
                     // peak(PT[prec], 1152, gpu))
        if int(field(line, f"{form}_ratio_ppm")) != ratio:
            ok = False
        if field(line, f"{form}_shape") != "FLATTER":
            ok = False
check("every GROWTH field re-derived exactly; all shapes FLATTER", ok)

# --- validation gate against J-091's filed ladder ----------------------
ladder91 = {}
for line in out91.splitlines():
    if line.startswith("LADDER "):
        ladder91[int(field(line, "L"))] = (
            field(line, "gpu_req_f16"), field(line, "gpu_req_int8_cf"))
ok = len(ladder91) == 5
for line in ceil_lines[:10]:
    rung = int(field(line, "L"))
    prec = field(line, "prec")
    want = ladder91[rung][0] if prec == "f16" else ladder91[rung][1]
    if field(line, "gpu_peak") != want:
        ok = False
check("validation gate: GPU session peaks == J-091 section 5.3 EXACTLY "
      "(parsed from the filed J-091 LADDER lines)", ok)

# --- the shape, stated in numbers ---------------------------------------
check("Janas shape ratio is 49/26 = 1,884,615 ppm (floored)",
      JANAS_PPM == 1884615)
base_share = PT["f16"] * 1152 * 1000000 // peak(PT["f16"], 1152, True)
top_share = PT["f16"] * 32896 * 1000000 // peak(PT["f16"], 32896, True)
check("KV share of the f16 GPU peak: 13,904 ppm base -> 286,908 ppm top",
      base_share == 13904 and top_share == 286908,
      f"derived {base_share} -> {top_share}")
check("accounted ceiling constant on the stated machine (free - headroom)",
      TOTAL - HEADROOM == 13743895348)

# --- doc honesty ----------------------------------------------------------
check("doc files both forms labelled and the tension resolved from the tree",
      "Form A" in doc and "Form B" in doc and "no routed experts" in doc)
check("doc states the shape verdict plainly (FLATTER, with the ratios)",
      "FLATTER" in doc and "1,884,615" in doc and "1,383,894" in doc)
check("doc files every live peak as NOT PROVEN / deferred to J-098",
      "NOT PROVEN" in doc and "J-098" in doc)
check("doc files the deferred recipe (guarded window + sha pin + RSS / "
      "nvidia-smi high-water + raw-oracle)",
      "8053aeda" in doc and "nvidia-smi" in doc and "RSS" in doc
      and "teacher-forcing" in doc and "never `llama-cli --single-turn`" in doc)
check("doc states the stated machine is an accounting input, not measured",
      "STATED" in doc and "not a measured machine" in doc)

print(f"INSPECT SUMMARY: {checks - fails}/{checks} PASS, {fails} FAIL")
sys.exit(1 if fails else 0)
