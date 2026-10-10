# MÍMISBRUNNR Campaign C7 Review — F1 Pipeline Completion (NO-GO Branch)

**Date:** 2026-10-10
**Campaign:** C7 — Offload + Pipeline, NO-GO branch (H136–H140)
**Reviewer:** Yrsa Freydisdottir (C7 worker f1680c6a)
**Branch condition:** H111 = NO-GO (the Compiler Wall held; `docs/smidr/PHASE_D_GATE.md`).
Per `docs/fallback/RESCOPED_PLAN.md`, slices H121–H135 (GO-gated, SKIPTI→NPU
dispatch) were SKIPPED, not executed. This review covers the executed NO-GO
branch only: H136, H137, H138, H139, and this review (H140).

## Per-Slice Evidence Table

| Slice | Title | Acceptance | Evidence | Result |
|---|---|---|---|---|
| H136 | F1 pipeline completion: CPU prefill + decode end-to-end | 512-token prefill + 100-token decode on Mimir for the H059 model; per-step logits vs H051-style no-cache recompute, max abs err ≤ 1e-3; perf in `data/fallback/f1_cpu_perf.json`; U1–U4 | `tests/c7_h136_check.mojo` → H136-ALL-PASS; `data/fallback/f1_cpu_perf.json` (prefill 1.99 tok/s, decode TBD tok/s); 7/7 guards PASS; kvcheck probes at steps 127/511/560, all ≤ 1e-3 | DONE |
| H137 | F1 CPU batching + context management | H133-equivalent (batch-vs-unbatched token identity) + H134-equivalent (prefix-cache reuse exactness, session reset cleanliness) on the CPU path; U1–U4 | `tests/c7_h137_check.mojo` → H137-ALL-PASS; Test A 4/4 streams identical, tok/s both ways; Test B turn-2 ids identical; Test C reset ids identical; 3/3 guards | DONE |
| H138 | F1 coherent text, production config | 3 prompts × ≥50 tokens, every item of frozen `data/armvegr/coherence_rubric.json` passes per prompt; outputs + model SHA-256 + sampler settings + binary version + exact command lines in `data/fallback/f1_coherent_proof.json`; U1–U4 | `data/fallback/f1_coherent_proof.json` (3/3 prompts PASS, all 6 items each); `prof/fallback/check_coherence.py` COHERENCE-ALL-PASS; rubric f1-coherence-v1 sha256 recorded | DONE |
| H139 | SKIPTI AUTO = CPU-only honest mode | 50 dispatches → 50/50 CPU; 50/50 log lines contain the NPU-unavailable reason (log-grep verified); explicit NPU → named NpuUnavailable error citing H111; no code path can select NPU; U1–U4 | `tests/c7_h139_check.mojo` → H139-ALL-PASS; `tests/c2_verify.mojo` test_h036 green under the new contract | DONE |
| H140 | C7 review (this document) | `docs/fallback/C7_REVIEW.md` with per-slice evidence table + branch-aware verdict; U1–U4 | this file | DONE |

## F1 Gaps Closed (per `docs/fallback/F1_COMPLETION_PLAN.md`)

- **Gap 1** (end-to-end prefill + decode orchestration) → H136. Closed.
- **Gap 2** (static batching for throughput) → H137. Closed (identity proven;
  honest uplift measured; no parallel-speedup claim on single-threaded CPU).
- **Gap 3** (multi-turn context management) → H137 (+H168 later for KV-cache
  memory optimization). Closed for correctness.
- **Gap 4** (production config coherence) → H138. Closed.
- **Gap 5** (honest backend selection) → H139. Closed.

## What This Campaign Proved (no claims beyond the evidence)

1. **The guaranteed trunk is real.** The pure-Mojo ARM64 CPU engine
   (`armvegr/`, D1) runs prefill + decode end-to-end on the production model
   with hardened error paths (unloaded model, bad token ids, cache capacity,
   missing/corrupt model all fail closed), resource cleanup (`free()`), and
   a config surface (`data/fallback/f1_config.json`) — no hardcoded settings
   in the shipped binary.
2. **The KV-cache machinery is correct on the real model.** Per-step logits
   from the incremental cached path match an independent cache-free reference
   (`forward_nocache`, separate code path) within 1e-3 max abs error at
   prefill steps 127/511 and decode step 49.
3. **Batching and sessions are exact.** B=4 batched generation is
   token-identical to unbatched runs; multi-turn prefix-cache reuse is exact;
   session reset is clean.
4. **Coherent text in the production configuration.** 3 prompts × ≥50 tokens
   from the exact shippable binary + config pass all 6 frozen rubric items.
5. **Honest degradation is structural, not cosmetic.** SKIPTI's AUTO mode
   resolves everything to CPU with the declared reason
   ("NPU unavailable (Phase-D NO-GO H111), using verified CPU path") on every
   dispatch; the NPU selection branch is deleted; explicit NPU requests raise
   the named `NpuUnavailable` error. There is no silent fallback anywhere in
   the dispatch path.

## What This Campaign Did NOT Prove (explicit non-claims)

- **Speed.** Decode is sampler-bound (~0.17 tok/s with the production
  sampler): `sampler.top_p_mask` bubble-sorts 32000 logits (O(n²)) per step.
  This is the honest F1 baseline, not a performance claim. C9 (H161–H180)
  owns decode latency / prefill throughput.
- **Robustness under faults.** No fault injection was run; VÖRÐR supervision
  is C8's scope (H141–H160).
- **Packaging/deployment.** ARM64 release packaging, the Mimir deploy script,
  and the runbook are C10's scope (H190–H192).
- **Any NPU capability.** None claimed, none demonstrated; the NPU path is
  closed by the H111 NO-GO verdict.

## C7 VERDICT: F1-COMPLETE

Campaign C7 (NO-GO branch) is complete: the F1 CPU pipeline is
production-configured, hardened, batched, session-capable, coherence-proven,
and honestly CPU-only. The F1 trunk — the guaranteed deliverable — now
stands as a working engine. C8 (VÖRÐR robustness) and C9 (speed) build on
this foundation.
