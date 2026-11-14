# A-121 — MoE battery

Wave 14 (Architecture breadth). Roadmap text:
"Mixture-of-experts fixture (real if obtainable
sha-pinned; otherwise a synthetic MoE built from real
tensors, labelled synthetic). Acceptance: expert-
routing outputs judged; synthetic status never hidden."

## What was built

- `aesir_engine/core/moe_battery_a121.mojo` — the
  battery: 16 OLMoE layers x 4 Z13 backends = 64 routing
  rows judged from banked measured records, plus the
  labelled SYNTHETIC fixture's 4 judged cases.
- `aesir_engine/tests/test_moe_battery_a121.mojo` — 13
  E-MASTER cases (`moe.battery_*`).
- `aesir_engine/tests/bench_moe_battery_a121.mojo` —
  one-command driver; log `hidden_files/a121_battery.log`.

## The fixture — real first, synthetic labelled

Real model: OLMoE-1B-7B-0924 Instruct Q4_K_M (arch
olmoe, 16 layers, 64 experts, top-8), sha-pinned in
`docs/janas/J015_MOE_ANATOMY.md` (sha256
8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94d
a1ac32f3f, 4,213,512,672 bytes). The file is NOT on
purpleraider (it lives in the purplelongship wave
store), so no engine execution of the real model is
claimed. The graded real evidence is banked in-repo:
`docs/janas/j016_olmoe_stats.json` — a measured
reference forward (gguf-py dequant + numpy float32
prefill; NOT the Aesir engine) over the real tensors:
577 tokens, 6 prompts, 73,856 routing accesses,
integrity PASS.

Synthetic fixture (labelled SYNTHETIC everywhere): 8
experts, top-2, its router score tensor built from
real tensors — the J-016 aggregate hit counts of the
eight most-hit real experts (6, 62, 23, 9, 58, 38, 14,
2; hits 1749, 1607, 1601, 1431, 1380, 1377, 1359, 1352).

## Judging — pre-registered rule M1-M3 (module header)

- M1: non-cpu -> NOT_GRADED (BACKEND_NO_CPU_COMPARATOR;
  CPU vs CPU only, no device-execution evidence filed,
  accelerator-visible is not accelerator-run), policy
  obligation still filed. The obligation is read from
  the BANKED A-115 policy by call: Q4_K_M ->
  TOKEN_EXACTNESS_OWED (all 64 rows).
- M2: cpu layer rows judged by routing checks over the
  J-016 record: integrity (accesses == 577 x 8 == 4616),
  liveness (dead == 0, distinct == 64), balance
  (entropy in [5.0, 6.0] bits), concentration (top
  expert hits x 8 <= accesses). All pass -> FAITHFUL.
- M3: synthetic cases judged under the engine's own
  routing rule (core/moe_session.mojo: top-k, RAW
  weights, never renormalised): SYN_RAW selects experts
  6 and 62 with raw mass 283 milli -> FAITHFUL;
  SYN_RENORM -> DIVERGENT (J022_B1_RENORMALISATION, the
  filed J-022 defect); SYN_COLLAPSE -> DIVERGENT
  (ROUTER_COLLAPSE_DEAD_EXPERTS); SYN_MISMATCH ->
  COMPARATOR_ARTIFACT (BACKEND_MISMATCH).

## Filed battery (banked J-016 records)

- FAITHFUL 16 — every OLMoE layer on cpu (accesses
  4616, distinct 64, dead 0 per layer; entropy x10000
  54349..58502; top-expert hits at most 382 of 4616).
- NOT_GRADED 48 — every non-cpu row, reason named.
- Policy rows: owed 64, coherence 0. Zero unexplained.
- Synthetic: total 4, faithful 1, divergent 2,
  artifact 1 — status SYNTHETIC, never hidden.
- Digest: filed in hidden_files/a121_battery.log and
  hidden_files/A121_LEDGER.md.

Integration points (named, honest): core/moe_session
.mojo is the engine's OLMoE forward (fail-closed on
other archs); when the sha-pinned file is on this
machine, test_olmoe_layers / test_olmoe_stream are the
engine-side re-run the M2 checks grade. A-116 remains
the tool for divergent ENGINE rows; this battery files
none, so A-116's Wave-14 in-anger condition is not
claimed met here. A-119 / A-120 build in parallel; no
dependency taken on either. The battery executes no
model on this machine and claims no accelerator
execution.

Addendum (fixture audit, this session): a filesystem-
wide audit confirmed no other usable MoE fixture on
purpleraider. The vault holds one real MoE file
(Gemma-4 26B A4B Q8_0, 128 experts, top-8) — considered
and NOT used: it is unpinned in every project registry
and the engine refuses its arch (core/moe_session
.mojo admits olmoe only), so using it would need a new
engine slice, not a battery. Qwen3 vault files carry no
expert metadata in their own headers.
