# MÍMISBRUNNR Progress Log

**Campaign:** 200-slice Hailo-10 moonshot for Project Aesir
**Roadmap:** `HAILO10_200_SLICE_ROADMAP.md` (source of truth — follow each slice's acceptance criteria exactly)
**Blessed by Volmarr:** 2026-10-10 ~03:47 EDT
**Coordinator:** MÍMISBRUNNR forge coordinator (subagent session 7d8a7a60-674c-4cec-9817-6f59f069850d)

## Laws (every worker reads these first)
- PURE MOJO: no libraries in shipped code, ever. Python for TESTS ONLY.
- ChatGPT Work cuts slices on this repo too — `git fetch origin`, read `git log -20` and branches before each campaign; never collide (additive changes only, never rewrite her in-flight work).
- Never edit README.md. Never force-push. Before every push: `git fetch origin`, diff remote vs local, preserve Volmarr's edits, push, verify with `git ls-remote origin HEAD`.
- Tests green after every campaign. No pseudocode, no placeholders, no fabricated benchmarks, no invented results.
- Honesty law: simulated success is marked **Simulated**; fail-closed; no mock results.

## Gate log
| Gate | Slice | Result | Date | Notes |
|------|-------|--------|------|-------|
| Phase-A gate review | H010 | GO-WITH-CONDITIONS | docs/phase_a/PHASE_A_GATE_REVIEW.md | 2026-10-10 |
| Phase-B go gate | H077 | pending | — | — |
| Phase-C gate | H095 | pending | — | — |
| **H111 GO/NO-GO (Compiler Wall)** | H111 | **NOT YET EVALUATED** | — | Honest evaluation required. NO-GO is a valid outcome; follow roadmap branch plan. |
| Phase-E go gate | H128 | pending | — | — |
| Victory gates 1-3 | H195-H197 | pending | — | — |

## Campaign 1 — Recon & Spikes (H001–H020)
- Status: COMPLETE 2026-10-10 ~04:32 EDT — all 20 slices, pushed f364849, remote HEAD verified f36484931b3647afce8dd9a1c8ba9abce146e35e
- Key: Mojo 1.1.0 NATIVE-WORKS on Pi 5 (pixi shim); mechanism verdict NO-GO (no VFIO/UIO — Phase-B driver blocked until kernel rebuild or F2 re-scope); NEON FP16 GEMM 16.0 GFLOPS bit-exact; GGUFSeer blocked by 1.1.0 InlineArray removal; Hladgerð has no implementation
- [x] H001 — Mojo toolchain native attempt on Pi 5
- [x] H002 — Cross-compile fallback x86_64 → aarch64
- [x] H003 — PCIe census of Mimir
- [x] H004 — Mechanism verdict document
- [x] H005 — Clean-room transport study
- [x] H006 — HEF-container study
- [x] H007 — NEON baseline spike
- [x] H008 — Loader port check on ARM64
- [x] H009 — Version pinning record
- [x] H010 — Phase-A gate review
- [x] H011 — Retire the npu_gate.mojo dlopen stub
- [x] H012 — VFIO environment probe
- [x] H013 — UIO fallback readiness probe
- [x] H014 — Firmware blob catalogue
- [x] H015 — Mojo POSIX external_call baseline
- [x] H016 — TEST-ONLY (PRÓF): Phase-A evidence aggregator
- [x] H017 — Interrupt capability study
- [x] H018 — DMA coherence model study
- [x] H019 — Chip-executable configuration surface survey
- [x] H020 — Phase-A closeout and C2 planning

## Campaign 2 — ARM64 CPU Core / ARMVEGR (H021–H040)
- Status: COMPLETE (replacement worker session 4abaed20-1d24-45aa-acf4-ede4fd3e1441, 2026-10-10; previous worker 22eadabd died of infra error, work verified and completed)
- C2 VERDICT (H040): READY — `docs/armvegr/C2_REVIEW.md`
- Evidence: `tests/c2_verify.mojo` 241/241 PASS; H037 oracle 26/26 PASS; `data/armvegr/kernel_perf.json` v1 (22 entries)

### SÓLRÚN AUDIT — C2 pre-execution (2026-10-10)
All 20 slices reviewed against their acceptance criteria before execution. Findings:
- H021–H028: feasible as specified. GO.
- **H029 RE-SCOPED (not killed):** the criterion "SiLU is verified non-decreasing on [-10, 10] at 0.01 steps" is mathematically false for a correct SiLU — SiLU(x)=x·σ(x) has a global minimum at x≈−1.2785 (value ≈−0.2785) and strictly decreases on (−∞, −1.2785); any correct implementation FAILS the criterion as written. Re-scoped to: (a) non-decreasing on [0, 10] at 0.01 steps (true for SiLU); (b) dip check — minimum over [−10,10] attained at x∈[−1.30,−1.25] with value∈[−0.29,−0.27] (catches approximation sign errors, stronger than the original intent). Recorded here, in DEVLOG, and in the code comment.
- H030–H040: feasible as specified. GO.
- H023 perf target (≥32 GFLOPS = 2× H007 on 1024³): ambitious for single-core Cortex-A76; the criterion explicitly permits a DEVLOG shortfall analysis — will measure honestly and analyze if missed. No threading introduced in C2.
- H037 execution site: the PRÓF oracle suite runs ON MIMIR (Python3 stdlib there); it generates the oracle Mojo test from the fixed seed corpus, builds it via the pixi shim, runs it via subprocess, and fails non-zero on any bound violation. Large-shape cases use SUM-checksum comparison against the independent fp64 Python reference (embedding multi-MB reference arrays as source literals is infeasible); small/medium cases use per-element max-abs-err. The split is documented in the corpus and C2 review.
- Mojo 1.1.0 API facts verified on-device 2026-10-10 (probe): multi-file `armvegr/` package imports work from repo root; scalar types have NO `.bitcast` (use exact-decimal Float16/Float64 literals for oracle data — exact round-trip); `exp`/`sqrt`/`log` called as `exp(SIMD[DType.float32,1](x))` (no explicit type params); `unsafe_store[W]` works; Float64 prints 17 sig digits.
- No slices killed.

### SÓLRÚN RE-SCOPES APPLIED DURING EXECUTION (2026-10-10)
- **H032 contract recorded:** max ≤ 0.43, rms ≤ 0.25 (derivation: max_abs/14, scale/√12); measured 0.424/0.237 — inside with margin.
- **H022/H023/H024/H026/H027/H029 ulp envelope:** per-element `|got−ref| ≤ base + 2^-10·|ref|` — strict absolute bounds infeasible when kernel and reference round independently to fp16 (double rounding = exactly 1 ulp at output magnitude; all observed failures were exact powers of two = ulp signatures, no bugs).
- **H023 shortfall (honest):** 7.16 GFLOPS measured vs ≥32 target; H007's 16 GFLOPS used fp16 accumulation, shipped kernel widens to fp32 (speed for accuracy).
- Bugs fixed: MHA strided-offset gather; `q80_gemm_bytes` N-term; H031/H032 n=10016 tail + 0x1400 constant; full Mojo 1.1.0 API port.
- [x] H021 — ARMVEGR module skeleton
- [x] H022 — NEON FP16 GEMM micro-kernel
- [x] H023 — GEMM integration (blocking driver)
- [x] H024 — NEON FP16 GEMV
- [x] H025 — Elementwise kernels
- [x] H026 — Layernorm
- [x] H027 — RMSNorm
- [x] H028 — Softmax
- [x] H029 — SiLU, GELU (re-scoped monotonicity — see audit)
- [x] H030 — RoPE
- [x] H031 — Q8_0 quant kernels
- [x] H032 — Q4_0 quant kernels
- [x] H033 — Quantized GEMM
- [x] H034 — Fused attention
- [x] H035 — MHA orchestration
- [x] H036 — Backend selection
- [x] H037 — PRÓF oracle suite (26/26 PASS on Mimir)
- [x] H038 — Perf baseline (kernel_perf.json v1 + BENCHMARK_METHOD.md)
- [x] H039 — Toy forward pass (h=128/512, maxerr ≤ 5e-3, finite)
- [x] H040 — C2 review verdict (READY)

## Campaign 3 — Loaders, Tokenizer, KV Cache (H041–H060)
- Status: COMPLETE 2026-10-10 ~08:08 EDT — all 20 slices + H059R1–R3 remediation. Root cause of H059 incoherence found and fixed (Q4_0 split-half layout, Q4_0 −8 bias, Q6_K ggml blocked layout, RoPE double-log). Coherence proven on Mimir ("Hospitality refers to the act of providing hospital..."). C3 verdict revised: **F1-CORE-READY**. Pushed e69e0db; remediation fc35ddb; remote HEAD verified.

### SÓLRÚN AUDIT — C3 pre-execution (2026-10-10)
All 20 slices reviewed against acceptance criteria before execution.

**Finding A (H041) — GGUFSeer 1.1.0 breakage is REAL, lazily compiled:**
Probed on forge (Mojo 1.1.0 via pixi): `from std.collections import InlineArray`
fails at parse. BUT `from loader.gguf import GGUFSeer` + struct construction
BUILD SUCCEEDS — Mojo 1.1.0 compiles lazily per-symbol: the error fires only
when a method body on the InlineArray path (the fstat path in `open()`,
gguf.mojo:415) is compiled. Proof: probe module with bad top-level import —
importing/instantiating the struct builds (exit 0); calling the method that
uses the imported name fails with the InlineArray error. Consequence: any
FUNCTIONAL use of GGUFSeer (open/parse) is broken; H041 ("every parse path
exercised") cannot proceed without the migration.
**DECISION: MIGRATE GGUFSeer to the 1.1.0 API (parent task's preferred option).**
Surgical change confined to aesir_engine/loader/gguf.mojo: line 4 import drops
InlineArray; lines 415-422 fstat buffer becomes `unsafe_alloc[UInt64](18)`
(from std.memory.alloc) + zero-fill + unsafe_free, same 144-byte semantics.
Zero behavior change. This is a toolchain-drift fix in the loader domain,
explicitly authorized by the parent task's H041 instruction; the general
additive guideline yields to that explicit instruction for these 2 touchpoints
only. Recorded here, in DEVLOG, and in the commit message. No cuda_* touches,
no README touches. Alternative (parallel ARM64 loader ignoring GGUFSeer)
rejected: would duplicate a 749-line validated module.

**Finding B (H043/H044) — Hladgerð: GREEN-FIELD CONFIRMED.** No module/struct/
function named Hladgerd exists anywhere in the repo (re-grepped 2026-10-10).
**DECISION:** build the safetensors parser + loader as NEW files in the D1
ARMVEGR domain (`armvegr/safetensors.mojo`), hand-rolled JSON per L1, zero
edits to existing domains. Whether to name it Hladgerð deferred to a later
slice; C3 ships it as the armvegr safetensors loader.

**Finding C (H042) — dequantize kernels are portable.** `q80_to_fp16` /
`q40_to_fp16` / `fp32_to_fp16` (quant.mojo, q4.mojo) contain ZERO NEON
intrinsics — pure portable Mojo (`Float16(Float32(q) * scale)`). **DECISION:**
new additive module `armvegr/gguf_loader.mojo` (mmap + self-contained
v2/v3 header parse + dequantize via H031/H032 kernels). The x86_64 cross-check
("same tensor dequantized by the x86_64 Aesir loader, same code path") builds
THE SAME module + kernel sources on the forge (x86_64) in a TEST-ONLY harness
(bypassing armvegr/build.sh's arch gate, which is package policy, not a code
constraint) and compares against the Mimir (ARM64) output: max abs err ≤1e-6.
Same Mojo source on both archs = the truest "same code path". GGUFSeer itself
does NOT dequantize (stores raw Q4_0/Q8_0 bytes as RuneTensor is_q views;
only F16 zero-copy and F32→F16 convert), so it cannot serve as the x86_64
dequantize reference — the portable-kernel cross-check is the honest design.

**Finding D (H046/H047) — reference tooling.** tiktoken 0.14.0 + sentencepiece
0.2.2 installed on forge 2026-10-10 (TEST-ONLY, `--user --break-system-packages`);
Mimir already has sentencepiece. GPT-2 vocab/merges + a real .model file to be
downloaded; frozen vectors generated once by TEST-ONLY scripts, then frozen.

**Finding E (H059) — model choice.** Constraints: loader supports
F32/F16/Q8_0/Q4_0 only (no K-quants); tokenizer must be H046-BPE or
H047-SentencePiece; must fit 16GB; must plausibly pass the frozen coherence
rubric. **DECISION: TinyLlama-1.1B-Chat-v1.0 Q4_0 GGUF (TheBloke) + its
tokenizer.model (SentencePiece, vocab 32000).** Rationale: legacy Q4_0 quant
(only Q4_0/F32 tensors — inside the supported set), chat-tuned (coherence),
SentencePiece exercises H047 in the real run, Llama arch (RMSNorm/RoPE/SwiGLU)
matches the ARMVEGR kernels, GQA (32Q/4KV heads) forces a real GQA decode
path. Inference loop: new `armvegr/infer.mojo` (decode-only, batch=1) reusing
gemv_fp16, rmsnorm_fp16, rope_fp16, silu_fp16, softmax_fp16 + a new GQA decode
attention over the H050 KV cache. Fallback if the file carries unsupported
dtypes: fail closed, document, pick the documented equivalent (SmolLM2-135M
F16). No simulation: if it cannot run, H059 reports the blocker honestly.

**Per-slice verdicts:** H041 GO (migrate). H042 GO (new module, portable-kernel
cross-check). H043/H044 GO (green-field). H045 GO (new module, JSON plan).
H046/H047/H048/H049 GO. H050/H051/H052 GO (new kv_cache.mojo; H051 cache-vs-
recompute on a tiny random transformer in the c3 test binary). H053–H057 GO
(new sampler.mojo; splitmix64 PRNG implemented in-module — stdlib `random`
not relied upon; determinism testable). H058 GO (TEST-ONLY python; runs the
H059 inference binary on a tiny random GGUF). H059 GO per Finding E.
H060 GO (review doc). **No slices killed.**

- [x] H041 — GGUFSeer ARM64 full port (1.1.0 migration)
  - Evidence (2026-10-10): 1.1.0 migration (InlineArray→unsafe_alloc fstat buffer) + aarch64 struct-stat ABI fix (st_mode word 2 vs 3) in aesir_engine/loader/gguf.mojo — the two authorized touchpoints only. 6-file corpus (5 deterministic via prof/armvegr/make_gguf_corpus.py + real TinyLlama-1.1B-Chat-v1.0 Q4_0 637699456 B), v2+v3, dtypes F32/F16/Q4_0/Q8_0/Q4_1/Q5_0/Q8_1/Q6_K. Canonical dumps byte-identical x86_64 vs ARM64 on all six (data/armvegr/gguf_port_diff.txt, empty diff). Existing x86_64 suite (test_gguf_parsing, test_ggml_type) passes unmodified.
- [x] H042 — GGUF tensor loader (mmap + dequantize to FP16)
  - Evidence (2026-10-10): new armvegr/gguf_loader.mojo (self-contained v2/v3 parse, mmap, FP16 dequantize via H031/H032 kernels). Cross-check: 68 tensors dequantized per arch, byte-identical (aggregate sha256 49391f64… both; max abs err 0 ≤ 1e-6). 1.1 GB file: peak RSS 320 KiB (budget file+256 MiB). 3 corrupt files fail closed with named errors, exit 0. Evidence: data/armvegr/gguf_loader_xcheck.txt. Note: draft bug (misread u32@24 as header alignment — v3 header is 24 bytes, no alignment field) caught by the x86_64 self-test before Mimir ran.
- [x] H043 — safetensors parser in pure Mojo
  - Evidence (2026-10-10): new armvegr/safetensors.mojo (hand-rolled JSON parser, L1). 5 real files (F16/BF16/F32/mixed/tiny model): every descriptor matches the Python struct+json cross-check exactly. 6 adversarial headers fail closed with named errors. Corpus: prof/armvegr/make_safetensors_corpus.py.
- [x] H044 — safetensors tensor loader (dtype mapping incl. BF16)
  - Evidence (2026-10-10): load_fp16 (F16 copy, F32 via H031, BF16 via bf16_to_fp16_rne with documented RNE contract). Exhaustive 65536-pattern BF16 test bit-exact vs integer reference on x86_64 + ARM64 (dae5a613...). Two real bugs fixed (shift overflow; arch-dependent NaN). 18-tensor FP16 checksums identical across arches (3f8e1497...). Evidence: data/armvegr/safetensors_xcheck.txt.
- [x] H045 — Weight layout planner
  - Evidence (2026-10-10): new armvegr/layout.mojo (deterministic planner, pre-pack, packed GEMM driver). 6-tensor model: byte-identical plan JSON on repeat runs; packed_b vs naive and packed_a vs naive max abs err 0.0 (<= 1e-3) on Mimir.
- [ ] H046 — BPE tokenizer (vocab + merges)
- [ ] H047 — SentencePiece-style tokenizer support
- [ ] H048 — TEST-ONLY (PRÓF): tokenizer differential suite
- [ ] H049 — Special tokens handling (BOS/EOS/pad)
- [ ] H050 — KV-cache structure (FP16)
- [ ] H051 — KV-cache update/append during decode
- [ ] H052 — Context eviction policy (sliding window)
- [ ] H053 — Sampler: greedy
- [ ] H054 — Sampler: temperature
- [ ] H055 — Sampler: top-k
- [ ] H056 — Sampler: top-p (nucleus)
- [ ] H057 — Sampler: repetition penalty
- [ ] H058 — TEST-ONLY (PRÓF): CPU pipeline smoke test
- [x] H059 — CPU inference with a real small open LLM (BLOCKED — see Blocker log)
- [x] H060 — C3 review: ARMVEGR CPU pipeline verdict (F1 core complete) — VERDICT: F1-CORE-NOT-READY

## Campaign 4 — Hailbrú Driver (H061–H080)
- Status: not started

## Campaign 5 — Bring-up & Firmware (H081–H100)
- Status: not started

## Campaign 6 — The Wall / SMIÐR (H101–H120)
- Status: not started — contains H111 GO/NO-GO gate

## Campaign 7 — Offload + Pipeline (H121–H140)
- Status: not started — branch-aware (H121-H135 need GO; H136-H139 NO-GO branch)

## Campaign 8 — Vörðr Robustness (H141–H160)
- Status: not started

## Campaign 9 — Speed (H161–H180)
- Status: not started — H171-H172 need GO

## Campaign 10 — Gauntlet + Hardening (H181–H200)
- Status: not started — H184 needs GO

## Blocker log

### 2026-10-10 — H059 BLOCKED: TinyLlama inference incoherent output

**Status:** Blocked, remediation slices H059R1–R3 named in `docs/armvegr/C3_REVIEW.md`.

**What was done:** Built `armvegr/infer.mojo` (TinyLlama + Inference), Q6_K support
(`armvegr/quant.mojo`, `armvegr/gguf_loader.mojo`), driver `tests/c3_h059_infer.mojo`.
Fixed 3 real bugs: (1) `fp16_from_bits` subnormal flush zeroed Q6_K scales;
(2) driver double-forwarded last prompt token; (3) RoPE called with theta instead
of ln_theta. Verified: Q6_K matches Python, gemv correct, RoPE correct in isolation,
all 201 tensors load, tokenizer correct.

**Failure:** Output incoherent ("Hello" → "nederbörd"; chat prompt → Cyrillic
fragments). Logit distribution peaked (entropy 4.73) but wrong. Root cause not
isolated — suspects: weight layout/transpose, RoPE application, attention, or
corrupted model file. Requires differential debug vs reference (H059R1).

**Commit:** 2027a08 (H059 scaffolding + Q6_K, marked BLOCKED).
**Review:** `docs/armvegr/C3_REVIEW.md` (H060) — verdict F1-CORE-NOT-READY.

### 2026-10-10 — H059R1 ROOT CAUSE FOUND + FIXED: Q4_0/Q6_K dequant layout bugs

**Status:** Root cause isolated via differential debug vs ggml ground truth.
Fixed in commits 2764508, 1d6016d. Coherence verified on Mimir.

**Root causes (3):**
1. **Q4_0 nibble layout** (`armvegr/q4.mojo`): Used interleaved `(2b, 2b+1)`;
   GGML `dequantize_row_q4_0` uses split-half `(b, b+16)`. Permuted all 200
   Q4_0 weight tensors. Fixed.
2. **Q4_0 sign bias** (`armvegr/q4.mojo`): Used `if q>=8: q-=16`; GGML does
   `(q & 0xF) - 8` (values biased by +8). Wrong for q<8. Fixed.
3. **Q6_K layout** (`armvegr/quant.mojo`): Used naive `i//2` interleaving;
   GGML `dequantize_row_q6_K` uses blocked `(j,l,g)` structure. Prior
   "<1e-4 vs Python" check was circular (both wrong). Rewritten, verified
   maxdiff 0.0 vs ggml via ctypes.
4. **RoPE double-log** (`armvegr/infer.mojo`): Passed `ln(theta)` to
   `rope_fp16` which does `log()` internally → effective base e^2.22 not
   10000. Fixed (pass raw theta).

**Eliminated:** Model file EXONERATED (sha256 matches HF authoritative
`da3087fb...`); reference `llama-cli` gives coherent output; numpy reference
with correct dequant gives coherent top-5.

**Verification (Mimir, Pi 5):** "What is the meaning of hospitality?" →
"Hospitality refers to the act of providing hospital..." (coherent English).
Before: "laglag rangeesen Vere" / "nederbörd" / Cyrillic.

**Performance:** ~0.15 tokens/sec on Mimir (Pi 5, 1.1B Q4_0). Slow but functional.

**Commits:** 2764508 (layouts + RoPE), 1d6016d (Q4_0 bias).
**Remote HEAD verified:** 1d6016d832bffa94e832981f1995a32d7a39e94c.

