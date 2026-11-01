#!/usr/bin/env python3
"""J-094 prompt-read economics -- inspect / re-derivation script.

Checks, mechanically:

- the read module's structure in core/prompt_read.mojo:
  work defined THROUGH core/kv_ladder (J-091) over
  core/prefill_anatomy (J-053), the KV-read shape and
  weight-pass bytes THROUGH core/attention_share
  (J-092), the block counterfactual through
  core/gpu_block_prefill's constants (J-054), the
  split through core/split_prompt (J-056); the
  definition of prompt read, the Part IV effect forms
  and the time honesty stated PRE-REGISTERED in the
  header;
- the no-wiring fact (J-031 section 10's reason): no
  file in the tree imports core.prompt_read except
  its own test, and tests/run_all.mojo does not
  register test_prompt_read;
- the filed harness lines in j094_test_output.txt:
  READHEAD / READDONE, READ lines for 5 rungs x 2
  precisions and EFFECT lines for 5 rungs, x2 runs
  byte-identical; every printed quantity re-derived
  in Python from the profile constants and compared
  exactly (work, KV written / read shape, passes,
  weight-pass bytes, touch shapes, syncs, verdicts
  under the tree's caps and integration facts, GPU
  read admission + placement; the Part IV deltas:
  chunk weight delta, precision KV deltas, the
  J-054 block account, the J-056 split plan fields
  and its rule's verdict under the read-placement
  parent flag);
- the validation gates: the filed READ work/KV
  columns reproduce J-091's filed LADDER lines
  (prefill attention / projection / KV totals /
  pairs / head) EXACTLY, parsed field-by-field; the
  GPU read admission totals reproduce J-093's filed
  CEILING gpu_read fields EXACTLY; the KV read
  shapes reproduce J-092's filed SHARE pre_kv fields
  EXACTLY, and J-092's prompt-average ppm (head in
  rest) is re-derived beside this slice's read-work
  ppm (head excluded) with the difference explained
  by exactly that head pass;
- the headline: the 32k read's accounted totals and
  the only ACCOUNTED line for it (GPU f16, spill);
- the doc states the Janas figure as shape/form
  only, every wall as NOT PROVEN, and the deferred
  live recipe for the J-098 gate (guarded window,
  sha pin, ids-first raw-oracle grading, llama-bench
  comparator, never llama-cli --single-turn).

Every check prints PASS/FAIL; the script exits nonzero
on any FAIL. Run from the repo root:
  python3 docs/janas/j094_inspect.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "aesir_engine" / "core"
JANAS = ROOT / "docs" / "janas"

checks = 0
fails = 0


def check(cond, label):
    global checks, fails
    checks += 1
    if cond:
        print("PASS: " + label)
    else:
        fails += 1
        print("FAIL: " + label)


def parse_kv(line):
    out = {}
    for tok in line.split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            out[k] = v
    return out


# Witness constants (J-091 profile, filed pins).
LAYERS, HIDDEN, QW, KVW, FFN = 28, 3584, 3584, 512, 18944
KV_HEADS, HEAD_DIM, VOCAB, CAP = 4, 128, 152064, 32768
WEIGHTS = 4683074688
ACT_FIXED, ACT_PER, SAMPLING, USABLE = 208896, 28, 905728, 5368709120
HOST_CAP = 16000
RUNGS = [1024, 4096, 8192, 16384, 32768]
PROJ_PT = LAYERS * (2 * HIDDEN * QW + 2 * HIDDEN * KVW + 3 * HIDDEN * FFN)
HEAD = HIDDEN * VOCAB
UNIT = LAYERS * QW * 2
KVPT = {"f16": 57344, "int8": 29568}


def verdict(line, prec, rung):
    if prec == "int8":
        return "INTEGRATION_BLOCKED"
    cap = HOST_CAP if line == "cpu" else CAP
    return "CAP_REFUSED" if rung > cap else "ACCOUNTED"


def expected_read(rung, prec):
    pairs = rung * (rung + 1) // 2
    attn = LAYERS * pairs * QW * 2
    proj = PROJ_PT * rung
    total = attn + proj
    kvw = KVPT[prec] * rung
    kvr = KVPT[prec] * pairs
    passes_host = -(-rung // 256)
    weight_host = passes_host * WEIGHTS
    weight_gpu = rung * WEIGHTS
    required = WEIGHTS + KVPT[prec] * rung + (ACT_FIXED + ACT_PER * rung) * 4 + SAMPLING
    return {
        "pairs": pairs, "work_attn": attn, "work_proj": proj,
        "work_total": total, "work_per_token": total // rung,
        "attn_share_ppm": attn * 1000000 // total, "head": HEAD,
        "kv_written": kvw, "kv_read_shape": kvr,
        "passes_host": passes_host, "weight_host": weight_host,
        "touch_host": kvr + weight_host + kvw,
        "passes_gpu": rung, "weight_gpu": weight_gpu,
        "touch_gpu": kvr + weight_gpu + kvw, "syncs_gpu": rung,
        "verdict_cpu": verdict("cpu", prec, rung),
        "verdict_gpu": verdict("gpu", prec, rung),
        "gpu_required": required,
        "gpu_place": "WHOLE_GPU" if required <= USABLE else "SPILL_REQUIRED",
    }


def expected_effect(rung):
    pairs = rung * (rung + 1) // 2
    chunks = -(-rung // 256)
    req_f16 = WEIGHTS + KVPT["f16"] * rung + (ACT_FIXED + ACT_PER * rung) * 4 + SAMPLING
    fits = req_f16 <= USABLE
    return {
        "chunk_weight_delta": (rung - chunks) * WEIGHTS,
        "kvw_delta": (KVPT["f16"] - KVPT["int8"]) * rung,
        "kvr_delta": (KVPT["f16"] - KVPT["int8"]) * pairs,
        "block_chunks": chunks, "block_syncs": chunks,
        "block_gemm": chunks * LAYERS * 7,
        "block_attn_calls": rung * LAYERS * 3,
        "block_weight": chunks * WEIGHTS,
        "block_admission": "unbuilt",
        "split_fits": str(fits),
        "split_join": rung * HIDDEN * 4,
        "split_transfers": chunks,
        "split_crossings": 3 * chunks,
        "split_verdict": (
            "accounted_and_rejected_dominated" if fits
            else "parent_absent_spill_fallback_shape"
        ),
    }


# --- 1. module structure ---------------------------------------------
module = (CORE / "prompt_read.mojo").read_text()
for needle in (
    "from core.kv_ladder import",
    "from core.attention_share import",
    "from core.gpu_block_prefill import",
    "from core.prefill_anatomy import",
    "from core.split_prompt import",
    "PROMPT READ, DEFINED (pre-registered)",
    "PRE-REGISTERED",
    "NOT PROVEN",
    "J-098",
    "ladder_cell_verdict",
    "share_prefill_kv_shape_bytes",
    "plan_split_prompt",
    "evaluate_split_accounting",
):
    check(needle in module, "module structure: " + needle)

harness = (JANAS / "j094_read.mojo").read_text()
check("NO WALL AND NO READ TIME IS" in harness, "harness header states no wall")
check("core.prompt_read import" in harness or "from core.prompt_read import" in harness,
      "harness defined through core/prompt_read")

# --- 2. no wiring ------------------------------------------------------
offenders = []
for path in (ROOT / "aesir_engine").rglob("*.mojo"):
    rel = path.relative_to(ROOT / "aesir_engine")
    if str(rel) in ("core/prompt_read.mojo", "tests/test_prompt_read.mojo"):
        continue
    if "prompt_read" in path.read_text():
        offenders.append(str(rel))
check(not offenders, "no other tree file references prompt_read (found: %s)" % offenders)
run_all = (ROOT / "aesir_engine" / "tests" / "run_all.mojo").read_text()
check("test_prompt_read" not in run_all, "run_all does not register test_prompt_read")

# --- 3. filed harness lines --------------------------------------------
out = (JANAS / "j094_test_output.txt").read_text()
read_lines = [ln for ln in out.splitlines() if ln.startswith("READ L=")]
effect_lines = [ln for ln in out.splitlines() if ln.startswith("EFFECT L=")]
check(out.count("READHEAD") == 2, "READHEAD x2 runs")
check(out.count("READDONE") == 2, "READDONE x2 runs")
check(len(read_lines) == 20, "READ lines: 5 rungs x 2 precisions x 2 runs (%d)" % len(read_lines))
check(len(effect_lines) == 10, "EFFECT lines: 5 rungs x 2 runs (%d)" % len(effect_lines))
check(read_lines[:10] == read_lines[10:], "READ runs byte-identical")
check(effect_lines[:5] == effect_lines[5:], "EFFECT runs byte-identical")

filed_read = {}
for ln in read_lines[:10]:
    d = parse_kv(ln)
    filed_read[(int(d["L"]), d["prec"])] = d
filed_effect = {}
for ln in effect_lines[:5]:
    d = parse_kv(ln)
    filed_effect[int(d["L"])] = d

all_read_ok = True
for rung in RUNGS:
    for prec in ("f16", "int8"):
        exp = expected_read(rung, prec)
        got = filed_read[(rung, prec)]
        for key, val in exp.items():
            if str(val) != got[key]:
                all_read_ok = False
                print("  mismatch READ L=%d %s %s: expected %s got %s"
                      % (rung, prec, key, val, got[key]))
check(all_read_ok, "every READ field re-derived exactly (all rungs/precisions)")

all_eff_ok = True
for rung in RUNGS:
    exp = expected_effect(rung)
    got = filed_effect[rung]
    for key, val in exp.items():
        if str(val) != got[key]:
            all_eff_ok = False
            print("  mismatch EFFECT L=%d %s: expected %s got %s"
                  % (rung, key, val, got[key]))
check(all_eff_ok, "every EFFECT field re-derived exactly (all rungs)")

# --- 4. validation gates vs J-091 / J-093 / J-092 filed lines ---------
j091 = (JANAS / "j091_test_output.txt").read_text()
ladder = {}
for ln in j091.splitlines():
    if ln.startswith("LADDER L="):
        d = parse_kv(ln)
        ladder[int(d["L"])] = d
gate = True
for rung in RUNGS:
    d = ladder[rung]
    f = filed_read[(rung, "f16")]
    i = filed_read[(rung, "int8")]
    gate &= f["work_attn"] == d["prefill_attn_macs"]
    gate &= f["work_proj"] == d["prefill_proj_macs"]
    gate &= f["pairs"] == d["pairs"] and f["head"] == d["head_macs"]
    gate &= f["kv_written"] == d["kv_f16"] and i["kv_written"] == d["kv_int8"]
    gate &= f["verdict_cpu"] == d["cpu_f16_read"] and f["verdict_gpu"] == d["gpu_f16_read"]
check(gate, "gate: READ work/KV/verdict columns == J-091 filed LADDER lines exactly")

j093 = (JANAS / "j093_test_output.txt").read_text()
ceil = {}
for ln in j093.splitlines():
    if ln.startswith("CEILING L="):
        d = parse_kv(ln)
        ceil[(int(d["L"]), d["prec"])] = d
gate = True
for rung in RUNGS:
    for prec in ("f16", "int8"):
        gate &= filed_read[(rung, prec)]["gpu_required"] == ceil[(rung, prec)]["gpu_read"]
        gate &= filed_read[(rung, prec)]["verdict_gpu"] == ceil[(rung, prec)]["gpu_read_verdict"]
        gate &= filed_read[(rung, prec)]["verdict_cpu"] == ceil[(rung, prec)]["cpu_read_verdict"]
check(gate, "gate: GPU read admission == J-093 filed CEILING gpu_read exactly (both precisions)")

j092 = (JANAS / "j092_test_output.txt").read_text()
share = {}
for ln in j092.splitlines():
    if ln.startswith("SHARE L="):
        d = parse_kv(ln)
        share[int(d["L"])] = d
gate = True
for rung in RUNGS:
    gate &= filed_read[(rung, "f16")]["kv_read_shape"] == share[rung]["pre_kv_f16"]
    gate &= filed_read[(rung, "int8")]["kv_read_shape"] == share[rung]["pre_kv_int8"]
    # J-092's prompt-average ppm has the head in its rest;
    # this slice's read-work ppm excludes it. Re-derive both.
    attn = LAYERS * (rung * (rung + 1) // 2) * QW * 2
    proj = PROJ_PT * rung
    ppm_j092 = attn * 1000000 // (attn + proj + HEAD)
    ppm_j094 = attn * 1000000 // (attn + proj)
    gate &= str(ppm_j092) == share[rung]["pre_ppm"]
    gate &= str(ppm_j094) == filed_read[(rung, "f16")]["attn_share_ppm"]
check(gate, "gate: KV shapes == J-092 filed SHARE pre_kv exactly; ppm forms differ only by the head")

# --- 5. headline ---------------------------------------------------------
top = filed_read[(32768, "f16")]
check(top["work_total"] == "321576079720448", "headline: 32k read work total")
check(top["work_per_token"] == "9813723136", "headline: 32k mean work/token")
check(top["verdict_gpu"] == "ACCOUNTED" and top["gpu_place"] == "SPILL_REQUIRED",
      "headline: 32k f16 read ACCOUNTED on GPU line only, SPILL_REQUIRED")
check(filed_read[(32768, "f16")]["verdict_cpu"] == "CAP_REFUSED",
      "headline: 32k CPU read CAP_REFUSED")
check(filed_effect[32768]["chunk_weight_delta"] == "152855557816320",
      "headline: chunking delta @32768")
check(filed_effect[32768]["split_join"] == "469762048"
      and filed_effect[32768]["split_verdict"] == "parent_absent_spill_fallback_shape",
      "headline: split @32768 parent-absent, join 469,762,048")

# --- 6. doc honesty -------------------------------------------------------
doc = (JANAS / "J094_PROMPT_READ_ECONOMICS.md").read_text()
for needle in (
    "15 minutes",
    "NOT PROVEN",
    "CAP_REFUSED",
    "INTEGRATION_BLOCKED",
    "321,576,079,720,448",
    "J-098",
    "guarded",
    "8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b",
    "llama-bench",
    "never `llama-cli --single-turn`",
    "teacher-forcing rank + logit gap",
):
    check(needle in doc, "doc states: " + needle)

print("INSPECT: %d checks, %d fails" % (checks, fails))
sys.exit(1 if fails else 0)
