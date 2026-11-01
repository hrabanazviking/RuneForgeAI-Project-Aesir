#!/usr/bin/env python3
"""J-097 sliding-window service -- inspect / re-derivation script.

Checks, mechanically:

- the module's structure in core/kv_window.mojo: the
  window service and suffix invalidation, the workload
  model, the cost definition and the correctness rule,
  all PRE-REGISTERED in the header; the verdict rule
  and its 250,000 ppm bar; the account defined THROUGH
  core/prompt_read (J-094) and core/kv_persistence's
  prices (J-096/J-087/J-088); the overflow-safe
  kw_saved_ppm present and used (no single-step
  avoided * 1000000 remains in the module, the tests
  or the harness);
- the overflow fact itself: at the filed work totals,
  avoided * 1000000 exceeds the Int64 maximum for 6 of
  the 9 shapes and for the mix, so the design commit's
  single-step formula could not have produced the
  filed ppm; the two-step kw_saved_ppm form is
  re-derived in Python (big integers) and equals the
  direct floored ppm on every shape and the mix, and
  its intermediates stay below 2**63;
- the no-wiring fact: no file in the tree references
  kv_window except the module itself, its own test and
  the harness, and tests/run_all.mojo does not register
  test_kv_window;
- the filed harness lines in j097_test_output.txt:
  WINDOWHEAD / WINDOWDONE, x2 runs byte-identical;
  every printed WINDOW field re-derived in Python
  exactly -- the read work from J-053's projection
  formula and the causal-pair account, the reuse from
  the shape table under the final-token cap, the KV
  rewrite bytes from J-087/J-088's per-token prices,
  the saved ppm by direct big-integer division, the
  per-shape verdicts, the MIX totals and the SERVICE
  verdict under the pre-registered rule;
- the validation gate: the filed harness's naive work
  at the 8,192-token shapes equals J-094's filed read
  total for that rung, and the test suite's gate group
  reproduces all five rungs (asserted from the filed
  test output);
- the doc states the verdict (KEPT), the mix numbers,
  every live leg as NOT PROVEN / DEFERRED-WITH-REASON,
  and the deferred live recipe for the J-098 gate
  (guarded window, sha pin, ids-first raw-oracle
  grading, never llama-cli --single-turn,
  teacher-forcing rank + logit gap), and the J-111
  handoff by name.

Every check prints PASS/FAIL; the script exits nonzero
on any FAIL. Run from the repo root:
  python3 docs/janas/j097_inspect.py
"""
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


# --- the witness account, re-derived ------------------------------------
LAYERS, HEADS, HD = 28, 4, 128
HIDDEN, QW, KVW, FFN = 3584, 3584, 512, 18944
PT = {"f16": 57344, "int8": 29568}
PROJ_PT = LAYERS * (2 * HIDDEN * QW + 2 * HIDDEN * KVW + 3 * HIDDEN * FFN)
I64MAX = 2**63 - 1


def work(L):
    if L == 0:
        return 0
    pairs = L * (L + 1) // 2
    return LAYERS * pairs * QW * 2 + PROJ_PT * L


def ppm_direct(avoided, naive):
    return avoided * 1000000 // naive


def ppm_two_step(avoided, naive):
    scaled = avoided * 1000
    return (scaled // naive) * 1000 + ((scaled % naive) * 1000) // naive


# shape table: name, divergence, new_len (the header's section (b))
SHAPES = [
    ("EDIT_LATE", 6144, 8192),
    ("EDIT_EARLY", 512, 8192),
    ("EDIT_FIRST", 0, 8192),
    ("MOVE_LATE", 6400, 8192),
    ("MOVE_EARLY", 512, 8192),
    ("INSERT_MID", 2048, 8256),
    ("DELETE_MID", 2048, 8128),
    ("APPEND", 8192, 8256),
    ("NO_CHANGE", 8192, 8192),
]
OLD_LEN = 8192


def reuse_of(div, new_len):
    return min(div, new_len - 1, OLD_LEN)


# --- 1. module structure --------------------------------------------------
module = (CORE / "kv_window.mojo").read_text()
for needle in (
    "from core.kv_persistence import",
    "from core.prompt_read import",
    "(a) THE WINDOW SERVICE",
    "SUFFIX INVALIDATION",
    "(b) WORKLOAD MODEL",
    "(c) COST DEFINITION",
    "CORRECTNESS RULE",
    "VERDICT RULE (pre-registered)",
    "KEPT ONLY IF IT",
    "KW_MIN_SAVED_PPM = 250000",
    "kw_first_divergence",
    "kw_reusable",
    "kw_saved_ppm",
    "kw_service_verdict",
    "NOT PROVEN",
    "J-098",
    "J-111",
    "INTEGRATION_BLOCKED",
):
    check(needle in module, "module structure: " + needle)

harness_src = (JANAS / "j097_window.mojo").read_text()
check("NO WALL" in harness_src, "harness header states no live leg")
check("from core.kv_window import" in harness_src,
      "harness defined through core/kv_window")

# the overflow fix is in force everywhere ppm is computed
for path, label in (
    (CORE / "kv_window.mojo", "module"),
    (ROOT / "aesir_engine" / "tests" / "test_kv_window.mojo", "tests"),
    (JANAS / "j097_window.mojo", "harness"),
):
    src = path.read_text()
    check("kw_saved_ppm" in src, label + " uses kw_saved_ppm")
    check("* 1000000 //" not in src,
          label + " has no single-step scaled ppm (overflow form)")

# --- 2. the overflow fact and the two-step form ---------------------------
over = 0
ok = True
ta = tn = 0
for name, div, new_len in SHAPES:
    r = reuse_of(div, new_len)
    a, n = work(r), work(new_len)
    ta += a
    tn += n
    if a * 1000000 > I64MAX:
        over += 1
    ok &= ppm_two_step(a, n) == ppm_direct(a, n)
    ok &= a * 1000 <= I64MAX and (a * 1000 % n) * 1000 <= I64MAX
check(over == 6,
      "overflow fact: avoided * 1000000 exceeds Int64 max on exactly 6 of 9 shapes (got %d)" % over)
check(ta * 1000000 > I64MAX, "overflow fact: the mix total also overflows single-step")
check(ok and ppm_two_step(ta, tn) == ppm_direct(ta, tn) == 450780,
      "two-step kw_saved_ppm == direct big-integer ppm on every shape and the mix (450,780); intermediates fit Int64")

# --- 3. no wiring -----------------------------------------------------------
offenders = []
for path in (ROOT / "aesir_engine").rglob("*.mojo"):
    rel = path.relative_to(ROOT / "aesir_engine")
    if str(rel) in ("core/kv_window.mojo", "tests/test_kv_window.mojo"):
        continue
    if "kv_window" in path.read_text():
        offenders.append(str(rel))
check(not offenders, "no other tree file references kv_window (found: %s)"
      % offenders)
run_all = (ROOT / "aesir_engine" / "tests" / "run_all.mojo").read_text()
check("test_kv_window" not in run_all,
      "run_all does not register test_kv_window")

# --- 4. filed harness lines -------------------------------------------------
out = (JANAS / "j097_test_output.txt").read_text()
harness_lines = [
    ln for ln in out.splitlines()
    if ln.startswith(("WINDOWHEAD", "WINDOW ", "MIX", "SERVICE", "WINDOWDONE"))
]
check(out.count("WINDOWHEAD") == 2, "WINDOWHEAD x2 runs")
check(out.count("WINDOWDONE") == 2, "WINDOWDONE x2 runs")
half = harness_lines[:len(harness_lines) // 2]
check(half == harness_lines[len(harness_lines) // 2:],
      "harness runs byte-identical")

rows = {}
for ln in half:
    if ln.startswith("WINDOW "):
        d = parse_kv(ln)
        rows[d["shape"]] = d
mix = [parse_kv(ln) for ln in half if ln.startswith("MIX")][0]
svc = [parse_kv(ln) for ln in half if ln.startswith("SERVICE")][0]

ok = True
for name, div, new_len in SHAPES:
    d = rows[name]
    r = reuse_of(div, new_len)
    naive, avoided = work(new_len), work(r)
    ok &= int(d["old_len"]) == OLD_LEN
    ok &= int(d["new_len"]) == new_len
    ok &= int(d["div_predicted"]) == div
    ok &= int(d["div_computed"]) == div
    ok &= int(d["reuse"]) == r
    ok &= int(d["naive"]) == naive
    ok &= int(d["avoided"]) == avoided
    ok &= int(d["cost"]) == naive - avoided
    ok &= int(d["saved_ppm"]) == ppm_direct(avoided, naive)
    ok &= int(d["kv_rewritten_f16"]) == (new_len - r) * PT["f16"]
    ok &= int(d["kv_rewritten_int8"]) == (new_len - r) * PT["int8"]
    ok &= d["verdict"] == ("NO_SAVE" if r == 0 else "SAVES")
check(ok and len(rows) == 9,
      "window account re-derived: every WINDOW field for all 9 shapes (divergence, reuse under the final-token cap, work, ppm, KV rewrite at both precisions, verdicts)")

check(int(mix["avoided"]) == ta and int(mix["naive"]) == tn
      and int(mix["saved_ppm"]) == 450780
      and mix["exact"] == "True" and mix["never_worse"] == "True",
      "mix re-derived: avoided 244,430,291,861,504 of naive 542,238,528,634,880 = 450,780 ppm >= the 250,000 bar")
check(svc["verdict"] == "KEPT",
      "service verdict re-derived: KEPT under the pre-registered rule")

# --- 5. validation gate -----------------------------------------------------
check(rows["EDIT_LATE"]["naive"] == "60190493769728",
      "gate: harness naive at 8,192 == J-094's filed read total for the rung (60,190,493,769,728)")
check("validation gate -- J-094 read-work totals reproduced EXACTLY at all 5 rungs"
      in out, "gate: filed test output reproduces J-094 totals at all 5 rungs")
check("ALL PASS: kv window (10 groups)" in out,
      "filed test output: test_kv_window ALL PASS (10 groups)")
for nb in ("kv persistence (11 groups)", "kv int8 (8 groups)",
           "kv account (10 groups)", "prompt read (11 groups)",
           "kv drafts (11 groups)"):
    check(("ALL PASS: " + nb) in out, "filed neighbour PASS: " + nb)

# --- 6. doc honesty ---------------------------------------------------------
doc = (JANAS / "J097_SLIDING_WINDOW.md").read_text()
for needle in (
    "KEPT",
    "450,780",
    "244,430,291,861,504",
    "542,238,528,634,880",
    "729,021",
    "NOT PROVEN",
    "DEFERRED-WITH-REASON",
    "J-098",
    "J-111",
    "guarded",
    "never `llama-cli --single-turn`",
    "teacher-forcing rank + logit gap",
    "kw_saved_ppm",
    "INTEGRATION_BLOCKED",
):
    check(needle in doc, "doc states: " + needle)

print("INSPECT: %d checks, %d fails" % (checks, fails))
sys.exit(1 if fails else 0)
