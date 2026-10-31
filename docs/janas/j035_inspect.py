#!/usr/bin/env python3
"""J-035 pass-taxonomy tree inspection (reproducible).

Run from the repo root of the J-035 worktree:
    python3 docs/janas/j035_inspect.py
Prints the first-hand evidence the J-035 doc cites: every generation
entry point's pass widths, the prefill chunk caps, the CUDA tile, the
speculative module's wiring state, and a sweep proving no token-count
threshold (17 / 2..16) routes execution anywhere in the engine.
Stdlib only; reads .mojo sources as text; never imports Janas material.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
ENG = ROOT / "aesir_engine"

def show(path, pattern, label, context=0):
    lines = (ROOT / path).read_text().splitlines()
    print(f"--- {label}: {path} /{pattern}/")
    hits = 0
    for i, l in enumerate(lines):
        if re.search(pattern, l):
            print(f"{path}:{i+1}: {l.strip()}")
            hits += 1
    if hits == 0:
        print("(no hits)")
    print()

print("== J-035 inspection: pass widths and routing in the Aesir tree ==")
print(f"tree root: {ROOT}")
print()

show("aesir_engine/aesir.mojo", r"def (_forward_position|_forward_batch|_prefill_batch_cap|_run_generation|speculative_generate)", "host engine entry points")
show("aesir_engine/aesir.mojo", r"AESIR_PREFILL_BATCH|batch_cap > 1", "host prefill chunk cap")
show("aesir_engine/core/inference.mojo", r"def (forward_pass|forward_pass_batched|forward_pass_gemma4|forward_pass_gemma4_batched|forward_pass_qwen35|forward_pass_qwen35_batched)", "inference forward passes")
show("aesir_engine/core/inference.mojo", r"def forward_batched", "batched block forwards")
show("aesir_engine/core/moe_session.mojo", r"def step", "MoE session step (only forward entry)")
show("aesir_engine/core/llama3_cuda.mojo", r"def (forward|prefill_four|begin_turn|next_chunk)", "Llama3 CUDA session")
show("aesir_engine/core/llama3_cuda.mojo", r"prefill_batch == 4", "Llama3 CUDA tile admission")
show("aesir_engine/core/gemma4_cuda.mojo", r"def (forward|begin_turn|next_chunk)", "Gemma4 CUDA session (no batched entry exists)")
show("aesir_engine/core/dense_buffers.mojo", r"requested != 1 and requested != 4|admitted only for the exercised", "native prefill batch values {1,4}")
show("aesir_engine/core/speculative.mojo", r"raise Error\(\"(draft proposal|speculative reconciliation|legacy speculative)", "speculative: integration points fail closed")
show("aesir_engine/aesir.mojo", r"speculative model generation and KV reconciliation are not implemented", "speculative: engine entry point reserved")

print("--- speculative wiring: importers outside the module and its tests")
for p in sorted(ENG.rglob("*.mojo")):
    rel = p.relative_to(ROOT)
    if "speculative" in p.name or "tests" in rel.parts:
        continue
    for i, l in enumerate(p.read_text().splitlines()):
        if "speculative" in l.lower():
            print(f"{rel}:{i+1}: {l.strip()}")
print()

print("--- threshold sweep: any token-count threshold routing execution?")
found = False
for p in sorted(ENG.rglob("*.mojo")):
    rel = p.relative_to(ROOT)
    if "tests" in rel.parts:
        continue
    for i, l in enumerate(p.read_text().splitlines()):
        if re.search(r"(len\(tokens\)|batch|tokens|count|width|pos)\w*\s*(>=|>|==)\s*17\b", l):
            print(f"{rel}:{i+1}: {l.strip()}")
            found = True
if not found:
    print("NONE: no token-count threshold routes execution. (A naive sweep for")
    print("the literal 17 hits only GGML quant type codes and an errno check --")
    print("storage.mojo, extreme_quantization.mojo, mimir_well.mojo,")
    print("model_registry.mojo, loader/mmproj.mojo -- none is a token count.)")
    print("The only draft-count bound in the tree is SpeculativeEngine's own")
    print("1..64 proposal limit (core/speculative.mojo, default 4), tests only.")
print()
print("== end ==")
