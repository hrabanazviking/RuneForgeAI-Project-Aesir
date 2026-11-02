#!/usr/bin/env python3
"""J-068 inspection: re-derive the J-053 baseline at 8,192 tokens
from this tree, first-hand. Pure arithmetic on profile dims filed
in the tree (dense_gqa_profile / gemma4_profile / J-015 OLMoE dims)
plus the Part IV accounts' filed 8k evaluations. No inference."""
import pathlib, re
root = pathlib.Path(__file__).resolve().parents[2]
N = 8192
pairs = N * (N + 1) // 2
win_pairs = 512 * N - 512 * 511 // 2
print(f"causal pairs/layer at {N} = {pairs}")
print(f"windowed (512) pairs/layer at {N} = {win_pairs}")
print(f"attention quadratic share: pairs(8192)/pairs(4096) = {pairs / (4096*4097//2):.4f}x for 2x tokens")

# arch: (layers, q_width, kv B/token, proj MACs/token, head MACs, attn override)
archs = {
    "Llama 3 8B": (32, 4096, 131072, 6979321856, 525336576, None),
    "Llama 3.2 3B": (28, 3072, 131072, 2818572288, 394002432, None),
    "Qwen3 0.6B": (28, 2048, 114688, 440401920, 155582464, None),
    "Qwen2.5 Coder 7B": (28, 3584, 57344, 6525288448, 544997376, None),
    "Gemma 4 E2B (hybrid)": (35, 0, 18432, 1238630400, 402653184, 2390413541376),
    "OLMoE (routed)": (16, 2048, 131072, 1075838976, 103022592, None),
}
for name, (L, q, kv, proj_tok, head, attn_override) in archs.items():
    proj = proj_tok * N
    attn = attn_override if attn_override is not None else L * pairs * q * 2
    share = attn * 10000 // (attn + proj)
    print(f"{name}: KV@{N}={kv*N} B; proj total={proj}; attn total={attn}; "
          f"attn share={share} bp ({share/100:.2f}%); dominates={share>5000}; head x1={head}")

print(f"OLMoE F1 head waste at {N} (width-1 step): {103022592*(N-1)} MACs "
      f"(head paid {N}x, {N-1} discarded); chunk form (J-058) pays 1x, waste 0")
print(f"OLMoE stream projection at J-030 mean (SIMULATED): {N * 32948699136 // 91} B "
      f"-- arithmetic only; OLMoE file context cap 4096 refuses the run")
print(f"host batched passes at {N} (cap 256): {N//256} total / {N//256-1} pure / 1 head")
print(f"width-1 passes at {N}: {N} / {N-1} pure / 1 head (MoE width-1: {N} head passes)")
# tile-4 replay
p, i = 0, 0
while i < N:
    p += 1; i += 4 if N - 1 - i >= 4 else 1
print(f"CUDA tile-4 passes at {N}: {p} / {p-1} pure / 1 head")

# context caps read from this tree's profiles
dg = (root / "aesir_engine/core/dense_gqa_profile.mojo").read_text()
print("dense_gqa_profile caps:", sorted(set(re.findall(r"LLAMA3_8B_CONTEXT_CAP = (\d+)", dg))),
      "profile rows context fields:", re.findall(r'"(Llama 3\.2|Qwen[^"]*)"[^;]*?(\d{4,5}), \d+, \d+,', dg)[:4])
for line in dg.splitlines():
    if "32768" in line or "8192," in line:
        print("  cap line:", line.strip()[:110])
g4 = (root / "aesir_engine/core/gemma4_profile.mojo").read_text()
print("gemma4 profile context caps in rows:", sorted(set(re.findall(r", (262144|32768|16384),", g4))))

# Part IV filed 8k evaluations (from the slices' own test files in this tree)
t = (root / "aesir_engine/tests/test_gpu_block_prefill.mojo").read_text()
assert "expect_eq(big.batched_gemm_calls, 7168" in t and "expect_eq(big.per_row_attention_calls, 786432" in t
print("J-054 filed at 8192 (Llama 3 8B shape, width 256): chunks 32, GEMM calls 7168, per-row attention calls 786432, scores 256 MiB at full context (test file)")
t = (root / "aesir_engine/tests/test_moe_gpu_prefill.mojo").read_text()
assert "8192, 256, 16, 2048, 8, 270532608, 805306368, 103022592,\n            311027712, 131072, DIVISION_FULL_GPU, 4096, 0, 0" in t
print("J-058 filed: plan_moe_gpu_prefill at 8192 with OLMoE context cap 4096 is a REFUSAL case in its test file")
t = (root / "aesir_engine/tests/test_prompt_progress.mojo").read_text()
assert 'plan_prompt_progress(8192, 256).records_expected, 10' in t and 'plan_prompt_progress(8192, 256).chunks, 32' in t
print("J-059 filed at 8192: host-width read = 32 chunks, records_expected = 10 (watched: >=1024 tokens and >=4 chunks)")
print("== done ==")
