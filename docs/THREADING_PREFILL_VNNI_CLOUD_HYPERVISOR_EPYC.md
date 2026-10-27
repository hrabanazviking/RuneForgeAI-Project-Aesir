# Threading, batched prefill, and VNNI on Cloud Hypervisor / EPYC

Companion to `PERF_AND_MODELS_CLOUD_HYPERVISOR_EPYC.md`. That campaign
left three named gaps — threading (this Mojo stdlib has `vectorize`
but no `parallelize`), batched prefill, and VNNI/BF16 integer dots.
Volmarr ordered all three on 2026-10-27. This document records the
design, the measurements, and the honest gaps. Everything numerical
below comes from runs made on this VM (Cloud Hypervisor guest, AMD
EPYC, 2 vCPU, ~8 GB RAM, AVX-512 incl. `avx512_vnni`/`avx512_bf16`)
against the four catalog models, greedy decoding, 48-token battery
runs (prompts in `~/workspace/model-tests/*/prompts/`, each model's
native chat format).

## Correctness oracle

The pre-campaign binary was preserved before any edit. Every stage
was captured over all 16 battery prompts (4 models × 4 prompts) with
that binary (baseline), then re-captured stage by stage. Generated
token IDs printed by the engine (`Token generated: <id>`) are the
oracle: a stage passes when its token streams are identical to
baseline wherever the design promises identity.

- Threading: **16/16 token-identical** (design promise: bit-identical).
- Batched prefill: **16/16 token-identical** (design promise: bit-identical).
- VNNI int8: approximate by design — drift measured in §3.

## 1. Threading via FFI (bit-identical)

This Mojo/MAX (26.5.0) standard library has no `parallelize` and no
atomic types, and `RuneThreadPool` is cooperative bookkeeping, not OS
threads — all verified by compile probes. The working road is the
same pattern the launcher already uses for the Hailo stub: a small C
shim compiled at build time, called through `std.ffi.external_call`.

- `aesir_engine/thread_par.c` — pthread parallel-for.
  `aesir_par_for(fn, ctx, n, want)` covers `[0, n)` exactly once in
  contiguous chunks; chunk 0 runs on the caller; if a `pthread_create`
  fails, that chunk runs on the caller after the joins. Work is never
  lost and the call never hangs on a spawn failure; it returns the
  chunk count, or −1 only for invalid arguments (no work run).
  `aesir_par_cpu_count()` reports online CPUs.
- `aesir_engine/core/parallel.mojo` — `par_for[f: RangeFn](ctx, n,
  work)`: engages the shim only when the online-CPU count and the
  work estimate justify it, and falls back to a plain serial call of
  the same worker on any shim failure. Two hard-won details:
  a named Mojo `def` passed **directly** as the callback to a linked
  `external_call` works, while the dlopen/`OwnedDLHandle` route
  segfaults with Mojo callbacks — so the shim is link-time, like the
  Hailo bridge; and the worker context must be **heap-allocated** (a
  stack `InlineArray` address silently corrupts once the entry
  function is inlined into callers).
- `scripts/launch.py` compiles `libaesir_par.so` from `thread_par.c`
  (`prepare_par_bridge`, mirroring the Hailo bridge) and links it.

Parallelized kernels (`core/compute.mojo`): `_gemm_k_fast` (Q4_K /
Q6_K), the scalar K-quant path in `gemm_ggml_k` (Q2_K/Q3_K/Q5_K),
and the dense tail of `gemm_f16`. The partition axis is **output
columns**: every output element is computed entirely inside one
call, with the same ascending-K reduction order as the serial body,
so threaded results are **bit-identical** to single-threaded ones —
confirmed on all 16 battery prompts and by identical token IDs with
`AESIR_THREADS=1` vs unset.

Knobs: `AESIR_THREADS` (1 forces serial; N>1 caps chunks; unset uses
online CPUs, capped at 32) and `AESIR_PAR_MIN_WORK` (GEMM engagement
threshold in multiply-accumulates, default 2^20; below it the GEMM
stays serial — set from the spike, not yet tuned per-shape).

Spike measurements (GEMM-shaped micro-benchmark, 2 vCPU): serial
4,143 ms → parallel 2,602 ms (**1.6×**; an earlier smaller shape
measured 1.74×), outputs bitwise identical, real OS threads observed.

End-to-end, threading's isolated contribution shows in the decode
rate derived in §2's table (wall at 48 tokens minus wall at 1 token,
divided by 47): Llama decode improved 1.56× (0.466 → 0.298 s/token),
Gemma2 1.51×, Qwen3.5 2.80× (its per-token cost is dominated by the
248K-vocab LM head, a single-row × huge-N GEMM that output-column
partitioning parallelizes almost ideally), Granite only 1.08× —
Granite streams 2.78 GB of weights per token and is the most
memory-bandwidth-bound of the four on this guest, so a second vCPU
helps it least. (Interpretation labeled as such; the walls themselves
are the measurements.)

Robustness: no leaked threads (the shim creates and joins inside one
call); `taskset -c 0` (single CPU) runs correctly; three repeated
headline runs byte-identical; test suites green (below).

## 2. Batched prefill (bit-identical)

Before this campaign the engine fed prompt tokens one per forward
pass, and the Qwen3.5 top level did not even honor `is_prefill` —
every prompt token paid the full LM head. Prefill now processes the
prompt in chunks (default 32, `AESIR_PREFILL_BATCH`, also clamped by
an arena-workspace bound) through batched forward variants whose
numerics are **bit-identical to per-token passes**:

- `KVCache.append_block` (`core/mimir_well.mojo`): destinations are
  consecutive positions of one layer and sources are rows of a
  row-major tensor, so the block write is one flat copy — identical
  bytes to `batch_len` calls of `append`.
- `_embed_token_into` / `_embed_tokens` (`core/inference.mojo`): the
  per-token embedding body with its destination unrolled; a batch is
  `batch_len` single lookups by construction.
- `TransformerBlock.forward_batched`: the single-device body of
  `forward` — which was already row-generic except for three steps —
  with exactly those fixed: (1) per-head Q/K RMSNorm now loops over
  rows as well as heads (`forward`'s version silently normalizes
  only row 0 for multi-row input — a latent bug for any future
  batching, now documented in both places); (2) `append_block`;
  (3) attention runs the existing `flash_attention_gqa` once per row
  with that row's own causal bound (`start_pos + r + 1`) and
  `query_pos` (`start_pos + r`), so per-row numerics match the
  per-token path exactly. The sharded multi-device body has no
  batched form and raises.
- `forward_pass_batched`: batched layers, then the unchanged output
  stage (final norm, LM head, softcap/scale, sampling) on the last
  row only; pure-prefill chunks rewind and return 0, like
  `forward_pass`.
- Qwen3.5: `Qwen35Block.forward_batched` batches the four SSM input
  projections, the output GEMM, and (for full-attention layers)
  everything the llama-like path batches. The conv1d reads taps from
  the extended history `[ring ‖ block rows]` — the same samples in
  the same tap order the per-token path sees — and the ring advances
  once, by the whole block, afterwards. The **delta-rule recurrence
  stays strictly sequential per row** (it is inherently sequential;
  a chunked WY-style rewrite is explicitly out of scope).
  `forward_pass_qwen35_batched` adds the missing `is_prefill` and
  resets SSM state exactly once, at position 0.
- Engine (`aesir.mojo`): `_forward_batch` mirrors `_forward_position`
  (same guards, same dispatch); `_run_generation` prefills in chunks
  of `_prefill_batch_cap()`; `AESIR_PREFILL_BATCH=1` restores the
  original per-token loop.

All GEMMs in the batched path are multi-row calls into the same
kernels campaign #1 built (one weight decode reused across rows) and
compose with §1 threading unchanged.

Measured on each model's t1 battery prompt (172–600 prompt tokens),
quiet guest, wall seconds; peak RSS in MB in parentheses:

| Model | Run | Before | After (threading + prefill) | Ratio |
|---|---|---:|---:|---:|
| Heretic 3.2 1B (llama) | 48 tokens | 67.96 (1,380) | 27.92 (1,380) | **2.43×** |
| | 1 token (prefill-isolating) | 46.07 | 13.91 | **3.31×** |
| Heretic Granite 3.3 2B | 48 tokens | 197.79 (2,776) | 65.58 (2,785) | **3.02×** |
| | 1 token (prefill-isolating) | 168.38 | 38.34 | **4.39×** |
| Hereticsutra Mini 2B (gemma2) | 48 tokens | 147.07 (2,559) | 56.72 (2,560) | **2.59×** |
| | 1 token (prefill-isolating) | 101.31 | 26.45 | **3.83×** |
| Qwen3.5 2B Heretic | 48 tokens | 170.21 (2,101) | 47.27 (2,101) | **3.60×** |
| | 1 token (prefill-isolating) | 111.16 | 26.23 | **4.24×** |

The 1-token wall is load + full prompt prefill + 1 decode, so its
ratio understates the prefill-phase gain alone (load time is common
to both sides and does not shrink). The 48-token ratio is the
combined effect of §1 and §2. Peak RSS is unchanged by either
feature, as designed (the batched workspace is arena-bounded and
rewound per layer). Battery-wide, all 16 prompts re-captured with
the prefill build are **token-identical** to baseline.

## 3. VNNI int8 dots (approximate, opt-in, default OFF)

Reachability was probed first: plain Mojo SIMD does **not** emit
VNNI (it lowers to widen/multiply/reduce sequences, 5–7× slower);
the working route is `std.sys.intrinsics.llvm_intrinsic` with
`llvm.x86.avx512.vpdpbusd.512` (and `llvm.x86.avx512bf16
.dpbf16ps.512` for BF16). Probe rates at K=4096, single thread:
Mojo int8 VNNI 68.7–71.2 GMAC/s, Mojo BF16 ≈30.4, Mojo plain-SIMD
int8 10.0–14.2 — VNNI intrinsics run at native C speed from Mojo.

Integrated as `_gemm_k_vnni_range` (`core/compute.mojo`), selected
per-call inside `_gemm_k_fast` (ctx mode slot) for kinds Q4_K/Q6_K:

- Weight operand: the **raw integer codes** (Q4_K nibbles 0–15,
  Q6_K 6-bit values 0–63) in natural order — VPDPBUSD's unsigned side.
- Activation operand: activations dynamically quantized once per
  (row, **sub-block**) to int8 with a max-abs scale (32 values per
  scale for Q4_K, 16 for Q6_K) — the signed side.
- Each sub-block contributes `coef_a · (xs · int_dot − coef_b ·
  sum_x)`: `int_dot` is the **exact** integer dot; `sum_x` is the
  exact f32 sum of the true activations over the sub-block, folding
  the affine terms (Q4_K's minimum via `coef_b`; Q6_K's −32 zero
  point as `coef_b = 32 · coef`). Super-blocks accumulate ascending,
  one contribution per sub-block, as in the f32 body. Output columns
  partition across threads exactly as in §1.

Gate: `AESIR_VNNI=1` enables, `=0` disables, unset uses the compiled
default (**off**). Every case is additionally gated by a runtime
CPUID + XCR0 probe in the shim (`aesir_cpu_vnni`), so the path can
never engage where the instruction cannot run.

**Drift (one reason it is opt-in):** the only approximation is the
int8 activation quantization, but greedy decoding amplifies small
logit errors at near-ties, and recurrent state compounds them.
Measured on the battery (48 tokens per prompt; identical-prefix
length vs baseline, then the streams diverge): | Model | t1 | t2 | t3 | t4 |
|---|---:|---:|---:|---:|
| Heretic 3.2 1B (llama) | 21 | 21 | 48 | 48 |
| Heretic Granite 3.3 2B | 42 | 48 | 48 | 17 |
| Hereticsutra Mini 2B (gemma2) | 9 | 16 | 48 | 48 |
| Qwen3.5 2B Heretic | 3 | 37 | 3 | 48 |

7 of 16 prompts stay token-identical for all 48 tokens; the rest
flip at a near-tie (earliest at token 4, Qwen t1/t3 — its recurrent
SSM state compounds small errors fastest).
Per-super-block scales (v1) flipped Llama t1 after 10 tokens;
per-sub-block scales (v2, shipped) after 21. Generations stay
coherent — the flip is a near-tie choosing the other plausible
token — but they are **not** the f32 path's outputs.

**Speed (the other reason):** on this guest, at these GEMM shapes
(K ≤ 8192, rows ≤ 32), the integrated VNNI path is **slower**
end-to-end than the tuned f32 SIMD kernel it would replace —
Llama 43.41 s vs 27.92 s, Granite 125.93 vs 65.58, Gemma2 90.74 vs
56.72, Qwen3.5 70.27 vs 47.27 for the same 48-token t1 runs. The
raw VPDPBUSD dot is fast (probe, above), but the production kernel
pays a scalar reduction of the 64 int32 partials per super-block
plus dynamic quantization per (row, sub-block), and at these sizes
that tail costs more than the f32 path's 16-wide FMA chain. Closing
that gap wants a SIMD lane-tree reduction of the partials and the
code unpack hoisted across row chunks — named future work, not
done here. The exact f32 path therefore remains the default on
both speed and exactness grounds, and VNNI ships as a measured,
gated, opt-in experiment (`AESIR_VNNI=1`), not a silent change.

**BF16 disposition:** proven reachable from Mojo at probe level
(~30 GMAC/s, ≈2.3× slower than int8 VNNI on this silicon) but **not
integrated**: it is slower than the int8 path for this kernel and —
because both operands would be rounded to bf16 — it restores no
exactness advantage that would justify a second approximate path.
The f32 path remains the exact default; if a future kernel is
activation-bound in a way int8 cannot serve, BF16 is the documented
next road, not a guess.

## Verification

- Suites on the final tree: test_inference **10/10**, test_cli
  **7/7** (built with `-laesir_par` linked, `--target-accelerator
  sm_89`, run from the repo root).
- Battery token-ID oracle per stage (see above).
- Headline run token IDs identical across pre-change binary,
  threaded binary, and `AESIR_THREADS=1`.
- Single-CPU (`taskset -c 0`) run OK; 3× headline repeats identical;
  no hangs or leaked threads observed across ~<RUN_COUNT> engine runs
  in this campaign (~100 across all stages).
- Hailo path untouched and still fail-closed on this machine.

## Honest gaps

- `AESIR_PAR_MIN_WORK` (2^20) and the prefill workspace heuristic are
  set from the spike/design values, not swept per shape; a tuning
  sweep on more vCPU counts is future work.
- End-to-end threading speedup on 2 shared vCPUs is bounded by the
  second vCPU's availability; walls in this doc were measured on a
  quiet guest but the vCPUs are host-shared.
- VNNI drift is characterized on this battery (48-token greedy);
  longer generations diverge further once a flip occurs. It is a
  measured trade, not a bounded-error guarantee for arbitrary text.
- The batched sharded (multi-device) block path does not exist;
  `forward_batched` raises for `num_devices > 1` (the engine runs
  `DeviceTopology(1)` on this build).
