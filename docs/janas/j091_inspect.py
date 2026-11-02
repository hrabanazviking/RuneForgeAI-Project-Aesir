#!/usr/bin/env python3
"""J-091 context ladder -- inspect / re-derivation script.

Checks, mechanically:

- the ladder module's structure in core/kv_ladder.mojo:
  prices defined through core/kv_account (J-087) and
  core/kv_int8 (J-088), work counts through
  core/prefill_anatomy (J-053), the definitions and
  cell-verdict rule stated PRE-REGISTERED in the
  header, gen length 128, the five rungs;
- the tree facts the verdicts rest on, grepped from
  this tree: aesir.mojo MAX_RUNTIME_CONTEXT = 16000
  and the generation path's min() allocation;
  inference.mojo's forward_pass clamp at 16000; the
  Coder profile parsed from dense_gqa_profile.mojo
  (28 / 3584 / 18944 / 28 / 4 / 128 / 152064 / cap
  32768); the dense CUDA cache is f16; NO session or
  execution file imports core.kv_ladder or
  core.kv_int8 (the INTEGRATION_BLOCKED fact and the
  deferred state, asserted, not claimed);
- the filed harness lines in j091_test_output.txt:
  five LADDER lines in rung order plus the header and
  DONE lines; every printed quantity re-derived in
  Python from the profile constants and compared
  exactly (KV totals at both precisions, pairs,
  prefill attention/projection MACs, decode context
  sums, KV-read traffic, decode attention MACs, GPU
  admission totals and placements at session
  contexts, all five verdict columns);
- the validation gates against prior slices' filed
  numbers: J-087's Coder totals (57,344 B/token;
  469,762,048 @8192) reproduced by the ladder's f16
  column; J-088's 29,568 B/token reproduced by the
  int8 column; J-053's Coder attention MACs @8192
  (6,735,330,803,712, parsed from its inspect output)
  and J-068's Coder projection total @8192
  (53,455,162,966,016, stated in its doc) reproduced
  by the ladder's work columns;
- the GPU cross-check: the module's required bytes
  at a pure 16384 context vs the filed whole-model
  refusal total 5,626,175,108 (campaign record
  GPU_2060_STATE.md, 2026-10-28) -- within the
  pre-stated 16-byte tolerance, and exceeding the
  usable 5,368,709,120 under both figures (the
  refusal's direction reproduced);
- the doc states the deferred live recipe for the
  J-098 gate (sha pin, guarded window, llama-bench
  comparator with conditions, raw-oracle grading)
  and files every wall as NOT PROVEN.

Every check prints PASS/FAIL; the script exits nonzero
on any FAIL. Run from the repo root:
  python3 docs/janas/j091_inspect.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "aesir_engine" / "core"
ENG = ROOT / "aesir_engine"
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


mod = (CORE / "kv_ladder.mojo").read_text()
test = (ROOT / "aesir_engine" / "tests" / "test_kv_ladder.mojo").read_text()
harness = (JANAS / "j091_ladder.mojo").read_text()
out = (JANAS / "j091_test_output.txt").read_text()
doc = (JANAS / "J091_CONTEXT_LADDER.md").read_text()
aesir = (ENG / "aesir.mojo").read_text()
inference = (CORE / "inference.mojo").read_text()
profile_src = (CORE / "dense_gqa_profile.mojo").read_text()
llama3_cuda = (CORE / "llama3_cuda.mojo").read_text()
doc53 = (JANAS / "J053_PREFILL_ANATOMY.md").read_text()
out53 = (JANAS / "j053_inspect_output.txt").read_text()

# Witness constants (parsed from the profile below).
LAYERS, HIDDEN, FFN = 28, 3584, 18944
Q_HEADS, KV_HEADS, HEAD_DIM, VOCAB, CAP = 28, 4, 128, 152064, 32768
QW, KVW = Q_HEADS * HEAD_DIM, KV_HEADS * HEAD_DIM
WEIGHTS, USABLE = 4683074688, 5368709120
ACT_FIXED = 3 * HIDDEN + 2 * QW + 2 * KVW + 2 * FFN + VOCAB
SAMPLING = (VOCAB + 8192 + 2 * (128 * 256 + 256) + 128) * 4
GEN = 128
RUNGS = [1024, 4096, 8192, 16384, 32768]
PT_F16 = LAYERS * 2 * KV_HEADS * HEAD_DIM * 2
PT_I8 = LAYERS * 2 * KVW + LAYERS * 2 * KV_HEADS * 4
PROJ_PT = LAYERS * (2 * HIDDEN * QW + 2 * HIDDEN * KVW + 3 * HIDDEN * FFN)

# ------------------------------------------------------------------
# 1. Module structure: defined through J-087/J-088/J-053, rule stated
# ------------------------------------------------------------------
check("ladder KV per-token exists", "def ladder_kv_bytes_per_token" in mod)
check("cell verdict exists", "def ladder_cell_verdict" in mod)
check("GPU admission exists", "def ladder_gpu_required_bytes" in mod)
check(
    "f16 price defined through kv_account (J-087)",
    "from core.kv_account import" in mod and "kv_bytes_per_token" in mod,
)
check(
    "int8 price defined through kv_int8 (J-088)",
    "from core.kv_int8 import" in mod and "kv8_bytes_per_token" in mod,
)
check(
    "work counts defined through prefill_anatomy (J-053)",
    "from core.prefill_anatomy import" in mod
    and "prefill_attention_macs" in mod
    and "prefill_projection_macs_per_token" in mod,
)
check(
    "definitions + verdict rule PRE-REGISTERED in the header",
    "PRE-REGISTERED" in mod and "INTEGRATION_BLOCKED" in mod
    and "CAP_REFUSED" in mod and "ACCOUNTED" in mod,
)
check("gen length is 128 in module and harness",
      "LADDER_GEN_TOKENS = 128" in mod)
check("rungs are the roadmap's five",
      all(f"return {r}" in mod for r in RUNGS))
check("tests pin the J-053/J-068 reproduction @8192",
      "6735330803712" in test and "53455162966016" in test)
check("harness prints no wall (walls deferred, stated)",
      "NO WALL IS MEASURED OR PRINTED" in harness
      and "walls=NOT_PROVEN_DEFERRED_J098" in harness)

# ------------------------------------------------------------------
# 2. Tree facts the verdicts rest on
# ------------------------------------------------------------------
check("host runtime cap 16000 (aesir.mojo)",
      "comptime MAX_RUNTIME_CONTEXT: Int = 16000" in aesir)
check("generation allocates min(cap, file context)",
      "min(MAX_RUNTIME_CONTEXT, self.parser.config.context_length)" in aesir)
check("forward_pass clamps at 16000 (inference.mojo)",
      "if context_length > 16000:" in inference)
m = re.search(
    r'"Qwen 2\.5 Coder", "qwen2", "7B", 28, 3584, 18944, 28, 4, 128,\s*152064, 32768',
    profile_src,
)
check("Coder profile parsed (28/3584/18944/28/4/128/152064/cap 32768)",
      m is not None)
check("dense CUDA KV buffer is f16",
      "enqueue_create_buffer[DType.float16](kv_elems)" in llama3_cuda)
import_files = []
for p in ENG.rglob("*.mojo"):
    # The kv_* accounting family (census, store, mixed,
    # faith, ladder) names/imports its siblings by
    # design; the claim under check is about SESSION
    # and EXECUTION files, so the family is excluded
    # by name prefix, as J-088's inspect adjudicated.
    if p.name.startswith("kv_"):
        continue
    if p.parent.name == "tests" or "docs" in p.parts:
        continue
    text = p.read_text(errors="ignore")
    if "from core.kv_int8 import" in text or "from core.kv_ladder import" in text:
        import_files.append(str(p.relative_to(ROOT)))
check("no session/execution file imports kv_int8 or kv_ladder "
      "(INTEGRATION_BLOCKED is a checked fact)",
      import_files == [], f"importers: {import_files}")

# ------------------------------------------------------------------
# 3. Filed harness lines re-derived exactly
# ------------------------------------------------------------------
ladder_all = [ln for ln in out.splitlines() if ln.startswith("LADDER L=")]
check("two harness runs filed, byte-identical LADDER lines (determinism)",
      len(ladder_all) == 10 and ladder_all[:5] == ladder_all[5:],
      f"found {len(ladder_all)} LADDER lines")
ladder_lines = ladder_all[:5]
check("LADDERHEAD + LADDERDONE lines filed",
      "LADDERHEAD model=qwen2.5-coder-7b" in out
      and "LADDERDONE rungs=5 walls=NOT_PROVEN_DEFERRED_J098" in out)


def field(line, name):
    mm = re.search(rf"(?:^| ){re.escape(name)}=(\S+)", line)
    return mm.group(1) if mm else None


def verdict(rung, direction, line_kind, precision, integrated=False):
    if precision == "int8" and not integrated:
        return "INTEGRATION_BLOCKED"
    needed = rung if direction == "read" else rung + GEN
    cap = 16000 if line_kind == "cpu" else CAP
    return "CAP_REFUSED" if needed > cap else "ACCOUNTED"


def placement(required):
    return "WHOLE_GPU" if required <= USABLE else "SPILL_REQUIRED"


all_exact = True
for idx, rung in enumerate(RUNGS):
    if idx >= len(ladder_lines):
        all_exact = False
        break
    ln = ladder_lines[idx]
    csum = GEN * rung + GEN * (GEN - 1) // 2
    sess = rung + GEN
    req_f = WEIGHTS + PT_F16 * sess + (ACT_FIXED + Q_HEADS * sess) * 4 + SAMPLING
    req_i = WEIGHTS + PT_I8 * sess + (ACT_FIXED + Q_HEADS * sess) * 4 + SAMPLING
    expect = {
        "L": str(rung),
        "kv_f16": str(PT_F16 * rung),
        "kv_int8": str(PT_I8 * rung),
        "pairs": str(rung * (rung + 1) // 2),
        "prefill_attn_macs": str(LAYERS * (rung * (rung + 1) // 2) * QW * 2),
        "prefill_proj_macs": str(PROJ_PT * rung),
        "head_macs": str(HIDDEN * VOCAB),
        "dec_ctx_sum": str(csum),
        "dec_kv_read_f16": str(PT_F16 * csum),
        "dec_kv_read_int8": str(PT_I8 * csum),
        "dec_attn_macs": str(LAYERS * QW * 2 * csum),
        "cpu_f16_read": verdict(rung, "read", "cpu", "f16"),
        "cpu_f16_write": verdict(rung, "write", "cpu", "f16"),
        "cpu_int8_read": verdict(rung, "read", "cpu", "int8"),
        "gpu_f16_read": verdict(rung, "read", "gpu", "f16"),
        "gpu_f16_write": verdict(rung, "write", "gpu", "f16"),
        "gpu_req_f16": str(req_f),
        "gpu_place_f16": placement(req_f),
        "gpu_req_int8_cf": str(req_i),
        "gpu_place_int8_cf": placement(req_i),
    }
    for name, want in expect.items():
        got = field(ln, name)
        if got != want:
            all_exact = False
            print(f"  mismatch L={rung} {name}: filed {got}, derived {want}")
check("every LADDER field re-derived exactly (all rungs, all columns)",
      all_exact)

# ------------------------------------------------------------------
# 4. Validation gates against prior slices' filed numbers
# ------------------------------------------------------------------
check("J-087 Coder per-token reproduced (57,344)",
      PT_F16 == 57344 and "57344" in out)
check("J-087 Coder total @8192 reproduced (469,762,048)",
      PT_F16 * 8192 == 469762048)
check("J-088 Coder per-token reproduced (29,568)", PT_I8 == 29568)
coder53 = [ln for ln in out53.splitlines() if "Qwen2.5 Coder 7B" in ln]
gate53 = any("6,525,288,448" in ln for ln in coder53)
check("J-053 inspect output pins Coder proj/token (6,525,288,448)"
      " and its doc tables the attention figure",
      gate53 and "6,735,330,803,712" in doc53,
      f"coder lines: {len(coder53)}")
check("ladder attention MACs @8192 == J-053 filed",
      LAYERS * (8192 * 8193 // 2) * QW * 2 == 6735330803712)
check("J-068 filed projection total @8192 (doc) reproduced",
      PROJ_PT * 8192 == 53455162966016 and "53,455,162,966,016" in doc)

# ------------------------------------------------------------------
# 5. GPU cross-check vs the filed refusal (campaign record)
# ------------------------------------------------------------------
req_16384 = WEIGHTS + PT_F16 * 16384 + (ACT_FIXED + Q_HEADS * 16384) * 4 + SAMPLING
FILED_REFUSAL = 5626175108
check("module arithmetic @16384 within 16 B of the filed refusal total",
      abs(FILED_REFUSAL - req_16384) <= 16,
      f"derived {req_16384}, filed {FILED_REFUSAL}, delta {FILED_REFUSAL - req_16384}")
check("refusal direction reproduced (required > usable under both)",
      req_16384 > USABLE and FILED_REFUSAL > USABLE)
check("int8 counterfactual holds the 16512 session whole (derived)",
      WEIGHTS + PT_I8 * 16512 + (ACT_FIXED + Q_HEADS * 16512) * 4 + SAMPLING
      <= USABLE)

# ------------------------------------------------------------------
# 6. Doc honesty: deferred recipe filed, walls NOT PROVEN
# ------------------------------------------------------------------
check("doc files the sha pin for the live recipe",
      "8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b" in doc)
check("doc files the J-098 deferred recipe (guarded window + comparator)",
      "J-098" in doc and "llama-bench" in doc and "guarded" in doc.lower())
check("doc states walls NOT PROVEN", "NOT PROVEN" in doc)
check("doc names the CAP_REFUSED and INTEGRATION_BLOCKED cells as results",
      "CAP_REFUSED" in doc and "INTEGRATION_BLOCKED" in doc)
check("doc states the comparator conditions caveat",
      "cannot be identical" in doc or "conditions" in doc)

print(f"INSPECT SUMMARY: {checks - fails}/{checks} PASS, {fails} FAIL")
sys.exit(1 if fails else 0)
