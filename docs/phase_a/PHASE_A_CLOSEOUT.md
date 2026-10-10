# Phase-A Closeout (H020)

**Date:** 2026-10-10
**Campaign:** C1 (Recon & Spikes), MÍMISBRUNNR

## Top 5 lessons

1. **The toolchain is real.** Mojo 1.1.0 compiles natively on the Pi 5 and
   cross-compiles deterministically from x86_64 (bit-identical rebuilds).
   The campaign's "pure Mojo on ARM64" trunk is not aspirational — H001,
   H002, H007, H008, H015 all ran executables on hardware.

2. **Mojo 1.1.0 broke the repo's assumptions.** No module-level `alias`,
   `alias` gone entirely, `InlineArray` removed from std.collections,
   `Pointer` non-nullable, std.io pre-declares libc symbols via
   external_call (hard conflicts). The repo predates 1.1.0; a block
   migration — not per-slice fixes — is the sane response.

3. **The mechanism NO-GO is the finding, not a failure.** H004's VFIO/UIO
   rejection (measured, three blocking facts each) plus H017/H018 turned
   "no driver" from a vague risk into a scoped engineering problem with
   named alternatives (F2) and prerequisites (kernel rebuild).

4. **Spikes beat speculation.** Every number in Phase A was measured: 16.0
   GFLOPS, 0.0 error, byte-identical cross-arch parses, all 7 syscalls with
   named errnos. The dyadic-input trick (H007) and the standalone parser
   (H008) show that small, honest instruments outperform big unverified
   claims.

5. **Names outrun implementations.** Hladgerð exists only as a domain name;
   the "safetensors loader" is fiction. The ledger's discipline — status
   scoped to exact capabilities — is what caught it. Audit names against
   code, not docs.

## Top 5 risks with mitigations

1. **The Wall (H111).** The Hailo-10 configuration interface is
   undocumented; H019 surveys *what* must be expressed but not the bit
   encodings. *Mitigation:* F1 CPU-engine fallback is the guaranteed trunk;
   price the campaign for the NO-GO branch (roadmap already does).
2. **Kernel mechanism gap.** No VFIO/UIO on Mimir's kernel blocks H061–H080
   as drawn. *Mitigation:* H010 Condition 1 — rebuild kernel or re-scope to
   F2 before H061; D1 CPU work proceeds regardless.
3. **Toolchain drift.** Further 1.1.0 incompatibilities lurk in the repo
   (H008 found one; the full suite hasn't been built on 1.1.0 yet).
   *Mitigation:* block-migrate the repo to 1.1.0 before C2 kernel work
   depends on old APIs.
4. **DMA coherence without a kernel partner.** H018's flagged pitfall:
   userspace can't do cache maintenance, and there's no IOMMU.
   *Mitigation:* H066/H067 must choose uncached mappings, a kernel helper,
   or explicit unsafe assumptions — decided before descriptor rings are
   programmed.
5. **Scope creep into vendor formats.** L3 forbids HEF-shaped output, but
   the temptation to "just peek" at vendor encodings grows near the Wall.
   *Mitigation:* clean-room log discipline; SMIÐR generates from
   requirements (H019), never from decompiled artifacts.

## Open questions and who answers them

| Question | Answered by |
|----------|-------------|
| Can the kernel be rebuilt with VFIO/UIO, or does H061 re-scope to F2? | H061 (gated by H010 Condition 1) |
| What are the Hailo-10 context bit encodings? | H101–H110 → H111 (the Wall) |
| Does GGUFSeer build on 1.1.0 after migration? | 1.1.0-migration slice (H010 Condition 2) |
| Implement safetensors/Hladgerð or defer? | Campaign coordinator (H010 Condition 3) |
| Which DMA-coherence strategy for H066/H067? | H066 (uses H018's analysis) |
| MSI or INTx for the first driver interrupt? | H069 (uses H017: MSI first) |
| What is the C2 numerical-correctness contract per kernel? | H037 (oracle suite); targets below |

## H010 gate verdict: RE-CONFIRMED (2026-10-10)

No new evidence since H010. The verdict stands: **GO-WITH-CONDITIONS**.
H016's machine check (36/36) and H017–H019's studies strengthen the
evidence base; none of them contradict the gate review. The three
conditions are unchanged and still open.

## C2 kernel backlog (D1 ARMVEGR)

Numerical contract (all kernels): compared against a scalar FP32 reference
oracle (H037); error tolerances below are max abs err unless noted. Shapes
are the LLM-inference shapes that matter (d_model=2048 class, heads, seq).

| Slice | Kernel | Target shapes | Error tolerance |
|-------|--------|---------------|-----------------|
| H022 | NEON FP16 GEMM micro-kernel | 64×64×64 tiles (H007 baseline: 16.0 GFLOPS) | bit-exact vs scalar on dyadic inputs (0.0) |
| H023 | GEMM blocking/tiling driver | 2048×2048×2048 via 64³ tiles | ≤1e-3 vs FP32 oracle |
| H024 | NEON FP16 GEMV | 2048×2048, 4096×4096 | ≤1e-3 |
| H025 | Elementwise (add, mul, scale, axpy) | vectors to 1M elems | bit-exact (exact ops) |
| H026 | Layernorm (FP16) | norm over 2048/4096 | ≤1e-3 |
| H027 | RMSNorm | norm over 2048/4096 | ≤1e-3 |
| H028 | Softmax (FP16, stable) | rows of 32k (vocab) | ≤1e-3, rows sum to 1±1e-3 |
| H029 | SiLU, GELU | vectors to 1M elems | ≤1e-3 vs FP32 |
| H030 | RoPE rotary embedding | (seq, 128) head-dim pairs | ≤1e-3 |
| H031 | FP32→FP16, FP16→Q8_0, Q8_0 dequant | blocks of 32 | exact for representable; ≤1e-3 dequant |
| H032 | Q4_0 block quantization | blocks of 32 | ≤ quantization noise bound (defined in slice) |
| H033 | Q8_0×Q8_0→FP32 GEMM | 64³ tiles | ≤1e-2 (quant noise dominates) |
| H034 | SDPA + causal mask (FP16) | 8 heads × 128 dim × 2k seq | ≤1e-3 vs FP32 |
| H035 | Multi-head attention orchestration | full MHA, 8–32 heads | ≤1e-3 end-to-end vs oracle |
| H038 | Kernel perf baselines | all above | report GFLOPS/GB/s; no regression vs H007-style baselines |
| H039 | Attention-free toy forward pass | tiny MLP | ≤1e-3 vs FP32 oracle |

H036 (backend selection) and H037 (oracle suite) are infrastructure, not
kernels. H040 is the C2 gate.
