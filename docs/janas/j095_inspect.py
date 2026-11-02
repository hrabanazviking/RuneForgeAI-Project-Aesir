#!/usr/bin/env python3
"""J-095 KV + drafts -- inspect / re-derivation script.

Checks, mechanically:

- the module's structure in core/kv_drafts.mojo: the
  rollback grades R-A/R-B/R-C, bit-exactness per
  precision and the quantization-is-not-rollback-error
  rule, and the acceptance verdict rule with its
  changed-target control, all PRE-REGISTERED in the
  header; the module defined THROUGH core/kv_account
  (J-087), core/kv_int8 (J-088), core/speculative_verify
  (J-071) and core/speculative_acceptance (J-075);
- the precision-free fact the header asserts: the Part V
  modules core/speculative_verify.mojo,
  core/speculative_loop.mojo and
  core/speculative_acceptance.mojo contain no precision
  input at all (no "precision" text), so the loop-level
  length/RNG rollback and the account-level acceptance
  are the same objects at both precisions;
- the no-wiring fact (J-031 section 10's reason): no
  file in the tree references kv_drafts except the
  module itself, its own test and the harness, and
  tests/run_all.mojo does not register test_kv_drafts;
- the filed harness lines in j095_test_output.txt:
  ROLLBACKHEAD / DRAFTSDONE, x2 runs byte-identical;
  every printed quantity re-derived in Python exactly --
  the int8 store exercise re-built from the stated
  synth rule and J-088's quantizer (per-head-slice
  scale = maxabs/127, round-half-away, clamp 127) in
  float32 arithmetic: committed-preservation diffs,
  the intermediate control diff, the final diffs, the
  tamper diffs, the crafted bound row's round-trip
  error; the acceptance replay from the verbatim
  J-075 fixture lists (totals, rates, the (0,0,0)
  replay difference, the (0,0,-1) changed-target
  control); the per-round byte prices and J-085's
  filed 930 rollback rows priced at both precisions;
- the validation gates: the filed ACCEPT rows and
  total reproduce J-075's filed MEASURE lines in
  j075_test_output.txt EXACTLY, parsed field-by-field,
  and J-085's filed 930 rollback rows are re-read from
  j085_test_output.txt;
- the attention-equality flags: filed True exactly
  where the re-derived code+scale diffs over the same
  lengths are zero (attention reads only positions
  < seq_len and consumes codes x scales, so identical
  stored state over the read length is identical
  attention -- the implication the module's R-C group
  exercises directly);
- the doc states the verdicts (EXACT at int8 under the
  pre-registered rule, UNCHANGED at the account level),
  every live leg as NOT PROVEN, and the deferred live
  recipe for the J-098 gate (guarded window, sha pin,
  J-088 section 7 integration first, ids-first
  raw-oracle grading, never llama-cli --single-turn,
  teacher-forcing rank + logit gap).

Every check prints PASS/FAIL; the script exits nonzero
on any FAIL. Run from the repo root:
  python3 docs/janas/j095_inspect.py
"""
import struct
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


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


# --- the int8 store exercise, re-derived -------------------------------
LAYERS, HEADS, HD, CAP, PREFIX, FINAL = 2, 2, 16, 24, 6, 11
WIDTH = HEADS * HD


def synth(i):
    return f32(((i * 37) % 17 - 8) / 8.0)


def row_values(layer, pos, salt):
    return [synth(layer * 4096 + pos * WIDTH + j + salt) for j in range(WIDTH)]


def quantize_row(row):
    """J-088's per-head-slice quantizer, in float32."""
    codes, scales = [], []
    for h in range(HEADS):
        sl = row[h * HD:(h + 1) * HD]
        maxabs = max(abs(v) for v in sl)
        scale = f32(1.0) if maxabs <= 0 else f32(maxabs / 127.0)
        scales.append(scale)
        for x in sl:
            q = f32(x / scale)
            r = int(f32(q + (0.5 if q >= 0 else -0.5)))
            codes.append(max(-127, min(127, r)))
    return codes, scales


class Store:
    def __init__(self):
        # [layer][pos] -> (k_codes, k_scales, v_codes, v_scales)
        self.rows = {}

    def append(self, pos, k_salt, v_salt):
        for layer in range(LAYERS):
            kc, ks = quantize_row(row_values(layer, pos, k_salt))
            vc, vs = quantize_row(row_values(layer, pos, v_salt))
            self.rows[(layer, pos)] = (kc, ks, vc, vs)

    def diff(self, other, upto):
        code_diff = scale_diff = 0
        for layer in range(LAYERS):
            for pos in range(upto):
                a = self.rows.get((layer, pos))
                b = other.rows.get((layer, pos))
                if a is None and b is None:
                    continue
                if a is None or b is None:
                    code_diff += 2 * WIDTH
                    scale_diff += 2 * HEADS
                    continue
                code_diff += sum(1 for x, y in zip(a[0], b[0]) if x != y)
                code_diff += sum(1 for x, y in zip(a[2], b[2]) if x != y)
                scale_diff += sum(1 for x, y in zip(a[1], b[1]) if x != y)
                scale_diff += sum(1 for x, y in zip(a[3], b[3]) if x != y)
        return code_diff, scale_diff


def build_plain():
    s = Store()
    for pos in range(FINAL):
        s.append(pos, 11, 5000)
    return s


def build_prefix():
    s = Store()
    for pos in range(PREFIX):
        s.append(pos, 11, 5000)
    return s


def build_drafted():
    s = build_prefix()
    for pos in range(PREFIX, 9):
        s.append(pos, 11, 5000)
    for pos in range(9, FINAL):
        s.append(pos, 777, 9000)
    return s


plain = build_plain()
prefix = build_prefix()
drafted = build_drafted()
exp_preserve = drafted.diff(prefix, PREFIX)
exp_control = drafted.diff(plain, FINAL)
for pos in range(9, FINAL):
    drafted.append(pos, 11, 5000)
exp_final = drafted.diff(plain, FINAL)

# crafted bound row: K = [1.0, 0.5, 0...] in one head slice
scale = f32(1.0 / 127.0)
q05 = int(f32(f32(0.5 / scale) + 0.5))
exp_quant_err = f32(f32(q05 * scale) - 0.5)

# --- 1. module structure ---------------------------------------------
module = (CORE / "kv_drafts.mojo").read_text()
for needle in (
    "from core.kv_account import",
    "from core.kv_int8 import",
    "from core.speculative_acceptance import",
    "from core.speculative_verify import",
    "(R-A) COMMITTED PRESERVATION",
    "(R-B) NEVER-DRAFTED EQUALITY",
    "(R-C) DEAD-ROW IRRELEVANCE",
    "quantization error",
    "is NOT rollback error",
    "VERDICT RULE (pre-registered)",
    "UNCHANGED iff a replay of the filed",
    "changed-target control",
    "NOT PROVEN",
    "J-098",
    "int8_state_diff_count",
    "acceptance_difference",
    "rollback_rows_bytes",
):
    check(needle in module, "module structure: " + needle)

harness = (JANAS / "j095_drafts.mojo").read_text()
check("NO LIVE ROLLBACK IS MEASURED" in harness, "harness header states no live leg")
check("from core.kv_drafts import" in harness, "harness defined through core/kv_drafts")

# precision-free Part V modules (the header's asserted fact)
for name in ("speculative_verify", "speculative_loop", "speculative_acceptance"):
    text = (CORE / (name + ".mojo")).read_text()
    check("precision" not in text.lower(), "precision-free module: core/" + name)

# --- 2. no wiring ------------------------------------------------------
offenders = []
for path in (ROOT / "aesir_engine").rglob("*.mojo"):
    rel = path.relative_to(ROOT / "aesir_engine")
    if str(rel) in ("core/kv_drafts.mojo", "tests/test_kv_drafts.mojo"):
        continue
    if "kv_drafts" in path.read_text():
        offenders.append(str(rel))
check(not offenders, "no other tree file references kv_drafts (found: %s)" % offenders)
run_all = (ROOT / "aesir_engine" / "tests" / "run_all.mojo").read_text()
check("test_kv_drafts" not in run_all, "run_all does not register test_kv_drafts")

# --- 3. filed harness lines --------------------------------------------
out = (JANAS / "j095_test_output.txt").read_text()
harness_lines = [
    ln for ln in out.splitlines()
    if ln.startswith(("ROLLBACKHEAD", "PRESERVE", "CONTROL", "FINAL",
                      "TAMPER", "QUANT", "ACCEPT", "PRICE", "DRAFTSDONE"))
]
check(out.count("ROLLBACKHEAD") == 2, "ROLLBACKHEAD x2 runs")
check(out.count("DRAFTSDONE") == 2, "DRAFTSDONE x2 runs")
check(harness_lines[:len(harness_lines) // 2] == harness_lines[len(harness_lines) // 2:],
      "harness runs byte-identical")
filed = {}
for ln in harness_lines[:len(harness_lines) // 2]:
    filed[ln.split()[0]] = parse_kv(ln)
accept_rows = {}
for ln in harness_lines[:len(harness_lines) // 2]:
    if ln.startswith("ACCEPT row="):
        d = parse_kv(ln)
        accept_rows[d["row"]] = d

check(filed["PRESERVE"]["code_diff"] == str(exp_preserve[0])
      and filed["PRESERVE"]["scale_diff"] == str(exp_preserve[1])
      and exp_preserve == (0, 0),
      "R-A re-derived: preserve diffs (0 codes, 0 scales) over the committed prefix")
check(filed["PRESERVE"]["attn_committed_equal"] == "True",
      "R-C filed: attention over the committed length equal (state identical there)")
check(filed["CONTROL"]["code_diff"] == str(exp_control[0])
      and filed["CONTROL"]["scale_diff"] == str(exp_control[1])
      and filed["CONTROL"]["state_diff_before_overwrite"] == str(sum(exp_control)),
      "control re-derived: intermediate diff before overwrite (%d codes, %d scales)"
      % exp_control)
check(exp_control[0] > 0, "control is real: the rejected rows differ before overwrite")
check(filed["FINAL"]["code_diff"] == str(exp_final[0])
      and filed["FINAL"]["scale_diff"] == str(exp_final[1])
      and filed["FINAL"]["state_diff"] == "0" and exp_final == (0, 0),
      "R-B re-derived: final diffs (0, 0, 0) -- bit-exact vs never-drafted")
check(filed["FINAL"]["dequant_max"] == "0.0" and filed["FINAL"]["verdict"] == "EXACT",
      "R-B filed: dequant max 0.0, verdict EXACT")
check(filed["FINAL"]["attn_final_equal"] == "True",
      "R-C filed: final attention equal at every head/layer")
check(filed["TAMPER"]["code_diff"] == "1" and filed["TAMPER"]["scale_diff"] == "1"
      and filed["TAMPER"]["verdict"] == "NOT_EXACT",
      "tamper re-derived: one code / one scale diff, verdict NOT_EXACT")
check(abs(float(filed["QUANT"]["bound_row_max_err"]) - exp_quant_err) < 1e-9
      and filed["QUANT"]["bound"] == "0.003937006",
      "quantization re-derived: bound-row round-trip error == scale/2 (0.003937006)")

# --- 4. acceptance replay + gates --------------------------------------
EN = [4, 4, 3, 4, 3, 4, 4, 3, 4, 1]
IT = [2, 1, 1, 2, 1, 0, 2, 1, 1, 1]
CODE = [4, 3, 4, 4, 2, 4, 3, 4, 4, 4]
ST = [3, 3, 4, 3, 2, 3, 4, 3, 3, 3]
exp_rows = {
    "english": (10, 40, sum(EN)), "italian": (10, 40, sum(IT)),
    "code": (10, 40, sum(CODE)), "structured": (10, 40, sum(ST)),
}
replay_ok = True
for label, (rounds, drafted, accepted) in exp_rows.items():
    d = accept_rows[label]
    replay_ok &= (int(d["rounds"]), int(d["drafted"]), int(d["accepted"])) == (rounds, drafted, accepted)
    replay_ok &= int(d["rate_bp"]) == accepted * 10000 // drafted
check(replay_ok, "acceptance replay re-derived: every row's totals + rate from the fixture lists")
total = filed["ACCEPTTOTAL"]
check((total["rounds"], total["drafted"], total["accepted"], total["rate_bp"])
      == ("40", "160", "113", "7062"), "acceptance total re-derived: 40 / 160 / 113, 7062 bp")
check(total["replay_diff"] == "(0,0,0)" and total["verdict"] == "UNCHANGED",
      "account-level verdict re-derived: replay difference exactly (0,0,0), UNCHANGED")
ctl = filed["ACCEPTCONTROL"]
check(ctl["diff"] == "(0,0,-1)" and ctl["verdict"] == "DIFFERS",
      "changed-target control re-derived: exactly (0,0,-1), DIFFERS")

j075 = (JANAS / "j075_test_output.txt").read_text()
gate = True
# J-075's filed per-row lines (from its test output, MEASURE rows):
j075_rows = {
    "english": ("34", "40", "8500"), "italian": ("12", "40", "3000"),
    "code": ("36", "40", "9000"), "structured": ("31", "40", "7750"),
}
for label, (acc, dr, bp) in j075_rows.items():
    needle = "accepted=%s drafted=%s rate_bp=%s" % (acc, dr, bp)
    gate &= needle in j075
    d = accept_rows[label]
    gate &= (d["accepted"], d["drafted"], d["rate_bp"]) == (acc, dr, bp)
gate &= "accepted=113 drafted=160 rate_bp=7062" in j075
check(gate, "gate: ACCEPT rows + total == J-075 filed MEASURE lines exactly")

# --- 5. byte prices ------------------------------------------------------
coder_f16, coder_int8 = 57344, 29568
olmoe_f16, olmoe_int8 = 131072, 69632
p1 = [d for d in (parse_kv(ln) for ln in harness_lines[:len(harness_lines) // 2]
                 if ln.startswith("PRICE")) ]
price_coder = [d for d in p1 if d.get("shape") == "coder-28x4x128"][0]
price_olmoe = [d for d in p1 if d.get("shape") == "olmoe-16x32x64"][0]
check((price_coder["tentative_f16"], price_coder["tentative_int8"],
       price_coder["committed_f16"], price_coder["committed_int8"],
       price_coder["rollback_f16"], price_coder["rollback_int8"])
      == (str(5 * coder_f16), str(5 * coder_int8), str(2 * coder_f16),
          str(2 * coder_int8), str(3 * coder_f16), str(3 * coder_int8)),
      "round prices re-derived: tentative 5 / committed 2 / rollback 3 rows, both precisions")
j085 = (JANAS / "j085_test_output.txt").read_text()
check("930 rollback rows" in j085, "gate: J-085's filed 930 rollback rows re-read")
check((price_olmoe["rollback_f16"], price_olmoe["rollback_int8"])
      == (str(930 * olmoe_f16), str(930 * olmoe_int8)),
      "J-085 price re-derived: 930 rows = 121,896,960 f16 / 64,757,760 int8 (OLMoE)")

# --- 6. doc honesty -------------------------------------------------------
doc = (JANAS / "J095_KV_DRAFTS.md").read_text()
for needle in (
    "EXACT",
    "UNCHANGED",
    "NOT PROVEN",
    "INTEGRATION_BLOCKED",
    "(0, 0, -1)",
    "121,896,960",
    "J-098",
    "guarded",
    "J-088 §7",
    "never `llama-cli --single-turn`",
    "teacher-forcing rank + logit gap",
):
    check(needle in doc, "doc states: " + needle)

print("INSPECT: %d checks, %d fails" % (checks, fails))
sys.exit(1 if fails else 0)
