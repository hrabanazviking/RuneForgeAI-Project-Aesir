#!/usr/bin/env python3
"""J-087 KV precision census -- inspect / re-derivation script.

Re-derives every number in docs/janas/J087_KV_PRECISION_CENSUS.md
from this tree's own files (no Janas material; this census is about
Aesir's tree only):

- profile constants parsed out of core/dense_gqa_profile.mojo and
  core/gemma4_profile.mojo (not retyped from memory -- the parser
  reads the constructor tuples in the files);
- storage precisions grepped from core/mimir_well.mojo (host
  KVCache), core/llama3_cuda.mojo (dense CUDA cache buffer) and
  core/gemma4_cuda.mojo (Gemma 4 CUDA cache buffer), with the
  inference_memory.mojo byte multipliers as the cross-check;
- layout / capacity / truncation facts grepped from the cache
  kernels and append paths;
- the absence of any 8-bit / quantized KV storage asserted by a
  tree-wide search.

Every check prints PASS/FAIL; the script exits nonzero on any FAIL.
Run from the repo root:  python3 docs/janas/j087_inspect.py
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


def read(p):
    return (CORE / p).read_text()


# ------------------------------------------------------------------
# 1. Storage precisions, grepped from the tree
# ------------------------------------------------------------------
well = read("mimir_well.mojo")
check("host KVCache stores K and V as RuneTensor[f16]",
      "var k: RuneTensor[f16]" in well and "var v: RuneTensor[f16]" in well)
check("host KVCache layout offset is (layer*max_seq + pos)*hidden_dim",
      "(layer_idx * self.max_seq_len + pos) * self.hidden_dim" in well)
check("host KVCache is fixed-capacity: append raises past capacity, no wrap",
      "KVCache.append: pos exceeds fixed cache capacity" in well)
check("PagedKVCache wraps the same f16 KVCache (base_cache: KVCache)",
      "var base_cache: KVCache" in well)
check("PagedKVCache default block_size is 16",
      "block_size: Int = 16" in well)

llama_cuda = read("llama3_cuda.mojo")
check("dense CUDA cache buffer is DType.float16",
      "enqueue_create_buffer[DType.float16](kv_elems)" in llama_cuda)
check("dense CUDA per-layer KV offset is layer*2*context*kv_width (K block then V block)",
      "layer * 2 * self.context_length * self.profile.kv_width()" in llama_cuda)

gemma_cuda = read("gemma4_cuda.mojo")
check("Gemma 4 CUDA cache buffer is DType.float32 (NOT f16)",
      "enqueue_create_buffer[DType.float32](cache_elements)" in gemma_cuda)
check("Gemma 4 CUDA local-layer capacity is the 512 sliding window",
      "512 if self.profile.is_local(layer) else admitted_context" in gemma_cuda)
check("Gemma 4 CUDA cache offsets are per owning layer only",
      "for layer in range(self.profile.layer_count - self.profile.shared_kv_layers)"
      in gemma_cuda)

gemma_kernels = read("gemma4_kernels.mojo")
check("Gemma 4 CUDA cache_kernel wraps local slots: slot = position % capacity",
      "var slot = position % capacity" in gemma_kernels)
check("Gemma 4 CUDA cache_kernel layout: K slots then V slots per layer",
      "offset + capacity * width + slot * width" in gemma_kernels)

llama_kernels = read("llama3_kernels.mojo")
check("dense CUDA llama_cache layout: K at pos*width, V at +capacity*width",
      "slot + Int(capacity_arg) * width" in llama_kernels)

mem = read("inference_memory.mojo")
check("inference_memory prices dense KV at kv_elements * 2 bytes (f16)",
      "profile.kv_elements(context) * 2" in mem)
check("inference_memory prices Gemma 4 KV at kv_elements * 4 bytes (f32)",
      "var kv = kv_elements * 4" in mem)
check("inference_memory Gemma 4 sum skips shared layers and caps local at 512",
      "profile.layer_count - profile.shared_kv_layers" in mem
      and "512 if profile.is_local(layer) else context" in mem)

aesir = (ROOT / "aesir_engine" / "aesir.mojo").read_text()
check("runtime KV ceiling MAX_RUNTIME_CONTEXT is 16000",
      "comptime MAX_RUNTIME_CONTEXT: Int = 16000" in aesir)
check("engine generation allocates KVCache for ALL block_count layers",
      "self.parser.config.block_count" in aesir and "KVCache(" in aesir)

inf = read("inference.mojo")
check("host forward_pass overload caps context at 16000 like the engine",
      "if context_length > 16000:" in inf)
check("CPU Gemma 4 pads local K/V rows to the cache width (zero-pad)",
      "Local K/V rows are zero-padded to the" in inf)
check("Qwen3.5 appends KV only on full-attention layers",
      "if self.is_full_attn:" in inf and "kv_cache.append(self.layer_idx" in inf)

moe = read("moe_session.mojo")
check("MoE session KV is the host KVCache at the file's kv_dim",
      "KVCache(\n            context_length, self.seer.config.kv_dim(), self.well, self.layer_count\n        )"
      in moe or "self.seer.config.kv_dim(), self.well, self.layer_count" in moe)

# No 8-bit / quantized KV storage anywhere in the engine.
# No 8-bit / quantized KV storage anywhere in the engine. Patterns
# require the KV cache itself beside the 8-bit type. Two looser
# patterns were tried first and their only hits adjudicated by hand
# as false positives, recorded here so the tightening is auditable:
# (1) test_gguf_version_interface.mojo -- a GGUF header's kv_count
# field (metadata key-values, not a KV cache); (2)
# test_quantization_autotuner.mojo -- a tuning-cache FILE PATH
# encoded as List[Int8] bytes (a GEMM tuning cache, not KV).
hits = []
for p in (ROOT / "aesir_engine").rglob("*.mojo"):
    t = p.read_text(errors="ignore")
    for pat in (r"(int8|uint8).{0,30}kv[ _]?cache", r"kv[ _]?cache.{0,30}(int8|uint8)",
                r"quant\w* kv cache", r"kv cache quant", r"8-bit kv",
                r"RuneTensor\[int8\]"):
        if re.search(pat, t, re.IGNORECASE):
            hits.append(f"{p.relative_to(ROOT)}: /{pat}/")
check("no 8-bit / quantized KV storage exists anywhere in aesir_engine",
      not hits, "; ".join(hits) if hits else "0 hits")

paged_users = []
for p in (ROOT / "aesir_engine").rglob("*.mojo"):
    if "PagedKVCache" in p.read_text(errors="ignore"):
        paged_users.append(str(p.relative_to(ROOT)))
check("PagedKVCache has no production session user (definition + tests only)",
      all(("mimir_well" in u or "test" in u) for u in paged_users),
      ", ".join(sorted(paged_users)))

# ------------------------------------------------------------------
# 2. Profile constants, parsed from the profile files
# ------------------------------------------------------------------
dense_src = read("dense_gqa_profile.mojo")
comptimes = dict(
    (m.group(1), int(m.group(2)))
    for m in re.finditer(r"comptime (LLAMA3_8B_\w+) = (\d+)", dense_src)
)


def dense_profile(fn_name):
    m = re.search(rf"def {fn_name}\(\).*?DenseGQAProfile\((.*?)\)\n", dense_src, re.S)
    body = m.group(1)
    toks = [t.strip() for t in body.split(",")]
    vals = []
    for t in toks[3:11]:  # after family/arch/name strings
        vals.append(comptimes[t] if t in comptimes else int(t))
    return vals  # layers, hidden, ffn, heads, kv_heads, head_dim, vocab, cap


def per_token(layers, kv_heads, head_dim, elem=2):
    return layers * 2 * kv_heads * head_dim * elem


print()
print("== dense GQA profiles (parsed from dense_gqa_profile.mojo) ==")
dense_expect = {
    "llama3_8b_profile": (131072, 8192),
    "llama3_2_3b_profile": (114688, 8192),
    "qwen3_0_6b_profile": (114688, 32768),
    "qwen2_coder_7b_profile": (57344, 32768),
}
for fn, (exp_pt, exp_cap) in dense_expect.items():
    layers, hidden, ffn, heads, kvh, hd, vocab, cap = dense_profile(fn)
    pt = per_token(layers, kvh, hd)
    print(f"-- {fn}: layers={layers} kv_heads={kvh} head_dim={hd} cap={cap}"
          f" -> {pt:,} B/token (f16); @512={pt*512:,}; @4096={pt*4096:,};"
          f" @8192={pt*8192:,}; @cap={pt*cap:,}")
    check(f"{fn} per-token KV == {exp_pt:,}", pt == exp_pt)
    check(f"{fn} context cap == {exp_cap}", cap == exp_cap)

# The J-053 defect this census corrects: its filed table hardcodes
# 131072 for Llama 3.2 3B; the profile derives 114688.
j053 = (ROOT / "docs" / "janas" / "j053_inspect.py").read_text()
m = re.search(r"Llama 3\.2 3B \(dense GQA\)\", 28, 3072, 3072, 1024, 8192, 128256, (\d+)", j053)
check("J-053 filed 3B KV figure is the defect (131072 != derived 114688)",
      m is not None and int(m.group(1)) == 131072 and per_token(28, 8, 128) == 114688,
      "j053_inspect.py ARCHS row carries 131072 for the 28-layer 3B profile")

print()
print("== Gemma 4 profiles (parsed from gemma4_profile.mojo) ==")
gemma_src = read("gemma4_profile.mojo")


def gemma_profile(fn_name):
    m = re.search(rf'def {fn_name}\(\).*?Gemma4Profile\("(\w+)", (.*?)\)\n', gemma_src, re.S)
    return [int(x) for x in m.group(2).split(",")]


for fn, exp in (("gemma4_e4b_profile", (172032, 57344, 41943040, 32768)),
                ("gemma4_e2b_profile", (71680, 18432, 12582912, 12288))):
    (layers, hidden, ffn, sffn, heads, kvh, ghd, lhd, shared, period,
     vocab, pli, cap, sl, sg) = gemma_profile(fn)
    owning = layers - shared
    local_own = sum(1 for l in range(owning) if l % period != period - 1)
    global_own = owning - local_own
    width = ghd * kvh  # host cache width = global kv_dim
    alloc = layers * 2 * width * 2
    written = owning * 2 * width * 2
    useful = (local_own * 2 * kvh * lhd + global_own * 2 * kvh * ghd) * 2
    cuda_fixed = local_own * 2 * 512 * kvh * lhd * 4
    cuda_marginal = global_own * 2 * kvh * ghd * 4
    print(f"-- {fn}: layers={layers} shared={shared} owning={owning}"
          f" (local {local_own} / global {global_own}) kv_heads={kvh}"
          f" head_dim local {lhd} / global {ghd} cap={cap}")
    print(f"   host f16: allocated {alloc:,}/token; written (padded) {written:,}/token;"
          f" useful {useful:,}/token")
    print(f"   CUDA f32: local ring fixed {cuda_fixed:,}; global marginal {cuda_marginal:,}/token;"
          f" total @cap {cuda_fixed + cuda_marginal * cap:,}")
    check(f"{fn} host allocated/token == {exp[0]:,}", alloc == exp[0])
    check(f"{fn} host useful/token == {exp[1]:,}", useful == exp[1])
    check(f"{fn} CUDA fixed == {exp[2]:,}", cuda_fixed == exp[2])
    check(f"{fn} CUDA marginal/token == {exp[3]:,}", cuda_marginal == exp[3])

print()
print("== OLMoE (MoE session shape, J-015 dims as filed in J-053) ==")
olmoe_pt = per_token(16, 32, 64)  # kv_dim 2048 = 32 kv heads x 64
check("OLMoE per-token KV == 131,072 (16 layers x kv_dim 2048 x K+V x f16)",
      olmoe_pt == 131072 and 16 * 2 * 2048 * 2 == 131072)
print(f"-- olmoe: layers=16 kv_dim=2048 -> {olmoe_pt:,} B/token (f16, host);"
      f" @512={olmoe_pt*512:,}; @4096 (file cap)={olmoe_pt*4096:,}")

print()
print("== 8-bit projection (J-088 baseline arithmetic, NOT a tree fact) ==")
p8 = 32 * 2 * 1024 * 1 + 32 * 2 * 8 * 4
print(f"-- Llama 3 8B at int8 + one f32 scale per (layer, K/V, kv-head) row:"
      f" {32*2*1024:,} payload + {32*2*8*4:,} scales = {p8:,} B/token"
      f" vs f16 131,072 (ratio {p8/131072:.4f})")
check("int8 projection arithmetic closes", p8 == 67584)

print()
print(f"J087_INSPECT: {checks - fails}/{checks} checks PASS")
sys.exit(1 if fails else 0)
