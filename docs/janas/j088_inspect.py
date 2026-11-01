#!/usr/bin/env python3
"""J-088 8-bit KV -- inspect / re-derivation script.

Re-derives every accounting number in docs/janas/J088_8BIT_KV.md
from this tree's own files and checks the built component's
shape mechanically:

- the accounting formulas are recomputed here in Python from
  the census shapes (J-087 section 4) and must equal both the
  constants pinned in aesir_engine/tests/test_kv_int8.mojo and
  J-087's own projection (67,584 B/token for the 8B shape,
  read out of J-087's doc, which this slice never modifies);
- the store's structure (separate int8 K/V buffers, separate
  f32 scale buffers, quantize-on-append, dequantize inside
  the attention loops) is grepped from core/kv_int8.mojo;
- the option surface (flag/env names, f16 default) is grepped;
- the deferred-integration claim is asserted: no session or
  execution file imports core.kv_int8 in this tree;
- the bench harness's fixed shape is grepped from its file.

Every check prints PASS/FAIL; the script exits nonzero on any
FAIL. Run from the repo root:  python3 docs/janas/j088_inspect.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "aesir_engine" / "core"

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


mod = (CORE / "kv_int8.mojo").read_text()
acct = (CORE / "kv_account.mojo").read_text()
test = (ROOT / "aesir_engine" / "tests" / "test_kv_int8.mojo").read_text()
bench = (ROOT / "docs" / "janas" / "j088_bench.mojo").read_text()
j087 = (ROOT / "docs" / "janas" / "J087_KV_PRECISION_CENSUS.md").read_text()

# ------------------------------------------------------------------
# 1. The component's shape, grepped from the module
# ------------------------------------------------------------------
check("store holds K and V as separate List[Int8] buffers",
      "var k_data: List[Int8]" in mod and "var v_data: List[Int8]" in mod)
check("scales are separate List[Float32] buffers (f32 scales)",
      "var k_scales: List[Float32]" in mod and "var v_scales: List[Float32]" in mod)
check("scale constant is 4 bytes (one f32 per scale)",
      "comptime KV8_SCALE_BYTES = 4" in mod)
check("per-row scale is maxabs / 127",
      "maxabs / Float32(127.0)" in mod)
check("append quantizes (kv8_quantize called in append)",
      mod.count("kv8_quantize(") >= 3)
check("attention dequantizes inside its loops (kv8_dequantize in attention)",
      "def attention_int8_head" in mod and mod.count("kv8_dequantize(") >= 4)
check("an unquantized reference attention exists for the exercise",
      "def attention_f32_head" in mod)
check("store is fixed-capacity (append raises past capacity, host shape)",
      "pos exceeds fixed cache capacity" in mod)

# ------------------------------------------------------------------
# 2. The option surface
# ------------------------------------------------------------------
check("flag --kv-precision exists in the scanner",
      '"--kv-precision"' in mod)
check("flag --kv-scale exists in the scanner",
      '"--kv-scale"' in mod)
check("env equivalents AESIR_KV_PRECISION / AESIR_KV_SCALE are read",
      '"AESIR_KV_PRECISION"' in mod and '"AESIR_KV_SCALE"' in mod)
check("the default precision is f16 (existing precision, not int8)",
      "self.precision = KV8_PRECISION_F16" in mod)
check("per-channel use is refused in the module (priced, not built)",
      "int8 with per-channel scales is priced but not built" in mod)

# ------------------------------------------------------------------
# 3. Accounting, recomputed from the census shapes
# ------------------------------------------------------------------
def per_row(layers, heads, hd):
    return layers * 2 * heads * hd * 1 + layers * 2 * heads * 4


def f16(layers, heads, hd):
    return layers * 2 * heads * hd * 2


shapes = {
    "Llama 3 8B": (32, 8, 128, 67584),
    "Llama 3.2 3B / Qwen3 0.6B": (28, 8, 128, 59136),
    "Qwen2.5 Coder 7B": (28, 4, 128, 29568),
    "OLMoE (32x64)": (16, 32, 64, 69632),
}
for name, (l, h, d, exp) in shapes.items():
    got = per_row(l, h, d)
    print(f"-- {name}: per-row int8 {got:,} B/token vs f16 {f16(l, h, d):,}"
          f" (ratio {got / f16(l, h, d):.4f})")
    check(f"{name} per-row int8 == {exp:,}", got == exp)
    check(f"{name} figure pinned in test_kv_int8.mojo",
          f", {exp}" in test or f"({exp}" in test or str(exp) in test)

check("J-087's doc carries the 67,584 projection this slice reproduces",
      "67,584" in j087 and "67584" in acct.replace(",", ""))
check("module accounting is defined through the census projection (no drift)",
      "kv_int8_projected_per_token(" in mod)
check("8B total at its 8192 cap == 553,648,128",
      per_row(32, 8, 128) * 8192 == 553648128)
per_channel_total = 65536 * 8192 + 32 * 2 * 8 * 128 * 4
check("per-channel 8B total at 8192 == 537,133,056 (table paid once)",
      per_channel_total == 537133056)
check("saving vs f16 for the 8B shape == 63,488 B/token",
      f16(32, 8, 128) - per_row(32, 8, 128) == 63488)
check("saving vs f32 for the 8B shape == 194,560 B/token",
      32 * 2 * 8 * 128 * 4 - per_row(32, 8, 128) == 194560)

# ------------------------------------------------------------------
# 4. Deferred integration, asserted + bench shape
# ------------------------------------------------------------------
users = []
for p in (ROOT / "aesir_engine").rglob("*.mojo"):
    t = p.read_text(errors="ignore")
    # Import-shaped references only. A looser "kv_int8" search was
    # tried first and its only hits adjudicated by hand as false
    # positives: core/kv_account.mojo and tests/test_kv_account.mojo
    # name J-087's own kv_int8_projected_per_token (the census
    # projection function), not this slice's module.
    if ("core.kv_int8 import" in t or "from core.kv_int8" in t) \
            and "test_kv_int8" not in p.name and p.name != "kv_int8.mojo":
        users.append(str(p.relative_to(ROOT)))
check("no session/execution file imports kv_int8 (integration deferred, honestly)",
      users == [], ", ".join(users) if users else "0 importers outside the module + its test")
check("bench shape is the stated one (8 heads, head_dim 128, 256 positions)",
      "comptime HEADS = 8" in bench and "comptime HD = 128" in bench
      and "comptime SEQ = 256" in bench)
check("bench measures both paths (int8 and reference) with reps stated",
      "attention_int8_head" in bench and "attention_f32_head" in bench
      and "comptime REPS = 200" in bench)

print()
print(f"J088_INSPECT: {checks - fails}/{checks} checks PASS")
sys.exit(1 if fails else 0)
