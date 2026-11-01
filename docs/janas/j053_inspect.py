#!/usr/bin/env python3
"""J-053 prefill anatomy inspection + baseline-table generator.

Read-only: greps the tree for the prefill loop anchors the doc
cites, then computes the baseline table's by-construction
quantities (pass plans, KV bytes written, causal pairs, MACs) with
the same arithmetic core/prefill_anatomy.mojo pins in its unit
tests. No inference runs; no wall is computed or claimed here.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

ANCHORS = [
    ("aesir_engine/aesir.mojo", r"def _prefill_batch_cap"),
    ("aesir_engine/aesir.mojo", r"def _forward_batch"),
    ("aesir_engine/aesir.mojo", r"def _run_generation"),
    ("aesir_engine/aesir.mojo", r"AESIR_PREFILL_BATCH"),
    ("aesir_engine/core/inference.mojo", r"def forward_pass\("),
    ("aesir_engine/core/inference.mojo", r"def forward_pass_batched"),
    ("aesir_engine/core/inference.mojo", r"def forward_pass_gemma4_batched"),
    ("aesir_engine/core/inference.mojo", r"def forward_pass_qwen35_batched"),
    ("aesir_engine/core/inference.mojo", r"def forward_batched\("),
    ("aesir_engine/core/llama3_cuda.mojo", r"def prefill_four"),
    ("aesir_engine/core/llama3_cuda.mojo", r"def begin_turn"),
    ("aesir_engine/core/gemma4_cuda.mojo", r"def begin_turn"),
    ("aesir_engine/core/gemma4_cuda.mojo", r"def forward\(mut self, token"),
    ("aesir_engine/core/moe_session.mojo", r"def step\(mut self, token"),
    ("aesir_engine/core/moe_session.mojo", r"def _layer_forward"),
    ("aesir_engine/core/mimir_well.mojo", r"def append_block"),
    ("aesir_engine/core/dense_buffers.mojo", r"def effective_prefill_batch"),
    ("aesir_engine/cli/native_serve.mojo", r"prefill_started_ms"),
    ("aesir_engine/cli/native_serve.mojo", r"timings_ms"),
]

print("== anchors (file:line: text) ==")
for rel, pat in ANCHORS:
    lines = (ROOT / rel).read_text().splitlines()
    hits = [i + 1 for i, l in enumerate(lines) if re.search(pat, l)]
    print(f"{rel} /{pat}/ -> lines {hits}")

print()
print("== pass plans (passes / pure-prefill / LM-head passes) ==")
LENGTHS = [256, 1024, 4096, 8192]


def host_batched(n, cap=256):
    pure, pos = 0, 0
    while n - 1 - pos >= cap:
        pure += 1
        pos += cap
    return pure + 1, pure, 1


def tile4(n):
    passes, i = 0, 0
    while i < n:
        if n - 1 - i >= 4:
            passes += 1
            i += 4
        else:
            passes += 1
            i += 1
    return passes, passes - 1, 1


SURFACES = {
    "host batched (cap 256)": lambda n: host_batched(n),
    "host per-token / CUDA width-1": lambda n: (n, n - 1, 1),
    "CUDA tile-4 (llama3-3B only)": tile4,
    "MoE width-1 (step)": lambda n: (n, 0, n),
}
for name, fn in SURFACES.items():
    row = " | ".join(
        f"n={n}: {fn(n)[0]}/{fn(n)[1]}/{fn(n)[2]}" for n in LENGTHS
    )
    print(f"{name}: {row}")

print()
print("== per-arch baseline quantities ==")
# (label, layers, hidden, q_width, kv_width, ffn, vocab, kv_bytes/token,
#  window) -- profiles from core/dense_gqa_profile.mojo,
# core/gemma4_profile.mojo, J-015 (OLMoE). Gemma4 E2B kv bytes use
# its 15 owning layers (12 local x 256 + 3 global x 512 kv width);
# its attention pairs are split local/global in the doc, here the
# full-causal figure is printed and the windowed figure beside it.
ARCHS = [
    ("Llama 3 8B (dense GQA)", 32, 4096, 4096, 1024, 14336, 128256, 131072, 0),
    ("Llama 3.2 3B (dense GQA)", 28, 3072, 3072, 1024, 8192, 128256, 131072, 0),
    ("Qwen3 0.6B (dense GQA)", 28, 1024, 2048, 1024, 3072, 151936, 114688, 0),
    ("Qwen2.5 Coder 7B (dense GQA)", 28, 3584, 3584, 512, 18944, 152064, 57344, 0),
    ("Gemma 4 E2B (hybrid SWA)", 35, 1536, 2048, 256, 6144, 262144, 18432, 512),
    ("OLMoE 1B-7B (streamed MoE)", 16, 2048, 2048, 2048, 1024, 50304, 131072, 0),
]
for (label, layers, hidden, q, kv, ffn, vocab, kvb, window) in ARCHS:
    proj = (2 * hidden * q + 2 * hidden * kv + 3 * hidden * ffn) * layers
    print(f"-- {label}: proj MACs/token = {proj:,}; LM head MACs = {hidden * vocab:,}")
    for n in LENGTHS:
        pairs = n * (n + 1) // 2
        attn = layers * pairs * q * 2
        print(
            f"   n={n}: KV written = {kvb * n:,} B; causal pairs/layer = {pairs:,};"
            f" attention MACs (all layers, full-causal) = {attn:,};"
            f" proj MACs total = {proj * n:,}"
        )
    if window:
        wpairs = window * 8192 - window * (window - 1) // 2
        print(f"   windowed pairs/layer at 8192 (window {window}) = {wpairs:,}")
        # Gemma 4 E2B layer classes: period 5 -> 28 local layers
        # (q width 8x256) and 7 global layers (q width 8x512).
        local_macs = 28 * wpairs * 2048 * 2
        global_macs = 7 * (8192 * 8193 // 2) * 4096 * 2
        print(
            f"   E2B attention MACs at 8192 by layer class: local 28L = {local_macs:,};"
            f" global 7L = {global_macs:,}; total = {local_macs + global_macs:,}"
        )

print()
print("== OLMoE routed MACs (replaces the dense-formula row above) ==")
# Per token per layer: attention projections 4*hidden*hidden (Q,K,V,O
# all 2048-wide, MHA) + router hidden*64 + top-8 experts x
# 3*hidden*expert_ffn (1024). The dense table's OLMoE proj row used
# the dense FFN formula and is NOT the MoE figure.
moe_layer = 4 * 2048 * 2048 + 2048 * 64 + 8 * 3 * 2048 * 1024
print(f"   per token per layer = {moe_layer:,}; x16 layers = {moe_layer * 16:,} MACs/token")
for n in LENGTHS:
    print(f"   n={n}: routed proj MACs total = {moe_layer * 16 * n:,}")

print()
print("== MoE stream projection at the J-030 filed mean ==")
TOTAL, TOKENS = 32948699136, 91
for n in LENGTHS:
    print(f"   n={n}: {n * TOTAL // TOKENS:,} B (SIMULATED projection of a measured rate)")
print("== done ==")
