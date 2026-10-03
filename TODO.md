## 2026-10-01 — Measured speed-lead program

- [x] Document the installed-provider baseline and publish the focused
  [AESIR speed-lead roadmap](ROADMAP_AESIR_SPEED_LEAD.md), with per-case 2× goals,
  3× stretch goals, ownership, dependencies and numerical/recovery gates.
- [ ] SPD-00: integrate fair 32/128/256-token provider modes, independent
  full-model logits, stage timings and a measured hardware feasibility decision.
- [x] First SPD-00 slice: portable balanced/seeded provider modes, full redacted
  replies and failure-aware scoring; physical native stage/traffic/D2D measurements;
  independent F32-expanded CPU reference for four strict-3B final-prompt vectors.
  See [measurement operation](docs/SPEED_MEASUREMENT.md). Preserve packed-reference
  failures and fixed budgets. The owned CUDA timeline slice below resolves first
  actual kernel/API tracing. Complete cache/residency isolation,
  second-session lead certification and broader numerical/quality gates stay open.
- [x] SPD-00 owned native CUDA trace: matched short/long public replies, validated
  kernel/API/copy rows, non-overwriting raw evidence and split-package importer
  recovery. See [trace operation](docs/NATIVE_CUDA_TRACE.md). Detailed semantic
  stage attribution, cache/residency and broad quality gates remain open.
- [x] SPD-01 first optional SIMT matrix candidate: all 1,658,880 real native
  reference values and 2100 selected independent dots pass fixed primitive
  budgets. It loses at batch 4 and is not promoted. Batch 32 gains are modest
  and shape-specific. See [candidate operation](docs/NATIVE_MATRIX_CANDIDATE.md).
- [x] SPD-01 shared-tile tuning: six configurations repeat all primitive gates,
  preserving 9,953,280 real native-reference values and 12600 selected independent
  dots. Every batch-four candidate loses; default stays strict reference.
  [Physical evidence](docs/evidence/matrix-tile-tuning-2026-10-01/README.md).
- [x] SPD-02 physical primitive prerequisite: public m16n8k8 F16/F32 MMA passes
  all50688 independent exact outputs,5400 guards and9 invalid-span rejections
  on actual sm_75. An isolated PTX6.5 target resolves the pinned PTX6.3 mismatch;
  no library/driver/dependency patch. [Operation](docs/NATIVE_TURING_MMA.md).
- [x] SPD-01/02 optional original packed-weight MMA: split-weight refinement
  passes all1,658,880 native values/2100 selected independent dots after the first
  F16 conversion fails. All28 speed cases lose; no default promotion.
  [Operation](docs/NATIVE_PACKED_TURING_MATRIX.md). Next measure shared staging.
- [x] SPD-01/02 shared Turing staging: three CTA choices pass4,976,640 native
  values/6300 selected independent dots and all guards. Rows64/batch32 earns up
  to1.92x primitive speed; V and every batch4 shape still lose. No promotion.
  Wider staging evidence follows; full-model/control integration stays open.
- [x] SPD-01/02 wider shared-input staging: all four configurations pass6,635,520
  native values/8400 selected independent dots and all guards. Wider timing is
  worse than prior32-column staging; retain its default and complete samples.
  Next gate ordinary F32 activation precision before full-model integration.
- [x] SPD-01/02 captured ordinary native F32 inputs: two public final-layer
  captures pass1,990,656 full native outputs and2520 selected independent dots
  under unchanged budgets. Almost every source value requires F16 rounding.
  Q/K/V use representative FFN-normalized inputs; batch32 repeats four sources.
  No full-model quality/speed promotion. Next scope bounded full-model prefill.
- [x] SPD-01/02 isolated whole-model matrix prefill: all513024 logits per mode
  pass fixed independent .05-max/.005-RMS/matching-argmax gates through1070
  input tokens. Exact repeats/commits and4352 guards pass; long fresh prefill
  improves12.717s to7.578s in this fixture. Small tail-only cases lose slightly.
  Normal policy stays unchanged. Next measure activation-residual precision/cost,
  then separately earn runtime/control/generation/restore/provider gates.
- [x] SPD-01/02 activation-residual precision/cost: both three/four-term
  candidates pass captured-input and original independent model budgets, but
  miss the stricter predeclared .0005 native-model RMS target. Four terms reduce
  long deviation about4.03x; retain all96 timing records and withhold failed
  ratios. Next measure scaled residual representation without relaxing budgets.
- [x] SPD-01/02 scaled residual representation: modes3/4 improve captured
  projection RMS but miss the unchanged .0005 complete-model native goal. All
  original independent budgets pass; retain all96 timings and withhold failed
  ratios. Next harden checked workspace/profile/device admission for the original
  passing matrix candidate before production memory/control/generation gates.
- [x] SPD-01/02 fixture workspace/device admission: strict full geometry and
  observed capability7.5, checked canonical layout/headroom, every field and
  actual span rechecked before tiles. Master188 passes/one skip; new mode0 full
  vectors match previous bytes and independent gates, preserving1.676x long
  fixture prefill. Next separately earn larger-tile control/recovery gates.
- [x] SPD-01/02 larger-tile fixture controls/recovery: actual deadline/SIGINT/
  invalid-descriptor aborts preserve uncommitted position/IDs and require explicit
  reset; recovered complete vectors match prior bytes and allocations. Unexpected
  observer exception poisons reuse. Master189 passes/one skip; disabled mode0
  independent gates preserve1.676x fixture prefill. Generation/sampling/restore
  and production admission/provider gates remain separate.
- [x] SPD-01/02 complete post-prefill decode/seeded replay:96 frames/all12312576
  logits per mode pass unchanged CPU/native budgets after public37/1070 prefixes.
  Greedy32/seeded16 actual samples agree and own fresh vectors replay bit-exactly;
  complete committed IDs/state/draws and4352 guards pass. Bounded streaming
  validation retains all metrics without a speed score. Next separately preserve
  execution boundaries across restoration before production32/provider admission.
- [x] SPD-01/02 owning-context checkpoint replay: copied/sealed exact tile/ID/
  policy/draw/pending/owner plans preflight before reset/GPU. Four continuations
  per greedy/seeded45-ID checkpoint pass1026048 logits per mode, unchanged
  independent/native/source/sample gates and actual own F32 bits. Twelve damaged
  plans refuse without mutation;4352 guards pass. Master190 passes/one skip.
  In-memory same-context only; persisted/long-history/runtime/provider gates open.
  Next scope bounded batched causal attention/launch reduction under exact vectors.

- [x] SPD-03/04 optional batched rotary/cache launches: four/32 grid-y rows retain
  original arithmetic/causal reads, exact513024 logits per model owner and all
  full guarded-cache hashes. Long actual host calls reduce89880 to3192; fresh
  native/fixture medians13.0394/7.43515s give1.75375x exploratory fixture gain.
  Complete96-frame decode and eight-frame checkpoint gates repeat every unchanged
  CPU/sample/state/bit/source/guard condition. Master190 passes/one skip; six new
  portable contracts pass. Production admission stays one/four. [Operation](docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md).
  Next batch independent normalization/residual/SiLU launches under exact state.

- [x] SPD-04 optional batched RMS/residual/SiLU: separate3072/33824 strided
  RMS sibling and disjoint cell grids preserve every complete vector/cache byte.
  Long actual elementwise host calls5321 versus original149801 plan; fresh
  native/fixture medians12.8261/6.94205s earn1.84759x exploratory fixture ratio.
  Complete96-frame decode/eight-frame checkpoint gates repeat all original
  independent/sample/state/bit/source/guard conditions. Master190 passes/one skip;
  seven portable grid contracts pass. [Operation](docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md).
  Next earn enabled controls/recovery on this new strategy before promotion.
- [x] SPD-04 enabled controls for new batched strategy2: actual pre-expired/
  10ms/owned-SIGINT/invalid-fd aborts at0/2/8/0 synced layers, explicit reset
  clears uncommitted sampler state with allocations intact. All513024 recovered
  values per owner equal accepted2 bytes;9792 guards/mask/poison/refusal checks
  pass. Eleven control contracts bind matching strategy/full source/hash and
  preserve mutation/interrupt failures. [Operation](docs/NATIVE_TURING_BATCHED_CONTROLS.md).
  Cooperative only; broader context/concurrency/soak/runtime/provider gates open.
  Next earn owned stage tracing for the accepted batched path.
- [x] SPD-00/04 owned inference-only strategy2 timeline: public37/1070 plain/
  profiled cases preserve all513024 source F32 values, full guarded-cache hashes,
  committed IDs/state/counts and4352 guards. Full-session ownership/correlation
  gates precede same-thread named NVTX selection;4837/120919 kernels pass.
  Retain rejected NVTX-triggered/UTC time-domain exports. No timing score.
  Long observed staged matrix kernels65.43%, attention21.47%; next earn explicit
  projection attribution before another kernel change. [Operation](docs/NATIVE_TURING_PREFILL_TRACE.md).
- [x] SPD-00/01/04 actual projection attribution: tensor-bound default-disabled
  NVTX labels and source32/4/1 plans attribute589/7449 child ranges to981/20385
  actual projection kernels in public37/1070 traces. All513024 source F32/cache/
  state values/4352 guards remain; eight attribution/nine probe contracts pass.
  Long batch32 FFN gate/up/down3.46973s (52.04% recorded kernel duration), down
  largest1.26654s. No speed score. [Operation](docs/NATIVE_TURING_PROJECTION_TRACE.md).
  Next scope bounded FFN packed-block decoding/staging with original accumulation.
- [x] SPD-01 bounded block-header reuse: separate default-disabled kernel keeps
  all1658880 cached/original F32 bits and2100 independent dots within fixed
  gates;144 synthetic/12 invalid spans/1622640 guards/840 timings pass. Batch32
  gate/up/down old-to-cached ratios .6843/.6890/.9025 reject this speed candidate.
  Fourteen portable contracts/master190 passes/one skip; defaults remain original.
  [Operation](docs/NATIVE_TURING_BLOCK_HEADERS.md). Next scope larger CTA row reuse
  under exact original bits and bounded shared storage.
- [x] SPD-01 larger row CTA sharing: final128 passes1658880 exact original bits/
  2100 independent dots/144 synthetic/12 invalid spans/1622640 guards/840 timings.
  Batch32 down gains1.10414x, gate/up lose .76896/.76027 old-to-new. Initial256
  physical resource failure is retained and admission removed; actual pre-model
  refusal passes. Sixteen portable contracts/master190 passes/one skip.
  [Operation](docs/NATIVE_TURING_LARGE_ROWS.md). Next gate narrow down-only real-F32
  activation/full-model support before any fixture selection.
- [x] SPD-01 narrow down-only128 actual-F32 gate: two public normal captures retain
  all114688 accepted source inputs/states and1990656 native/original/new F32 bytes.
  All2520 selected independent dots/1938600 guards/12 spans pass unchanged budgets;
  only two batch32 down cases select128. Ten portable contracts/master190 passes/
  one skip, strict source report/model/capture rehash and failure retention pass.
  [Operation](docs/NATIVE_TURING_DOWN_ACTIVATIONS.md). No speed score/full-model
  promotion. Next gate complete down-only model/cache/state before selection.
- [x] SPD-01/04 down-only128 complete model strategy3: all513024 native/matrix
  values/owner, actual IDs/state/full guarded-cache hashes match accepted2;
  unchanged CPU budgets/own fresh F32 bits/4352 guards/eight invalid tiles pass.
  Actual down calls0/28/0/924 and closed trace/control admission pass. Long paired
  native/new12.66775/6.80087s=1.86267x exploratory fixture ratio; no old2/new3 or
  provider score. Eight portable contracts/master190 passes/one skip, atomic
  finite scoring/provenance rehash/failure retention pass. [Operation](docs/NATIVE_TURING_DOWN_MODEL.md).
  Next earn strategy3 decode/sample/replay/enabled-control gates before selection.
- [x] SPD-01/04 down-only128 decode/sample gate: all96 complete frames and
  12312576 F32 values per owner pass fixed independent/native quality, samples,
  causal state, exact own fresh bits,4352 guards and accepted3 initial vectors.
  Actual initial/replay down counts28/924; nine portable contracts plus previous
  gates/master190 passes/one skip. Source numeric/predecessor/hash admission and
  after-oracle all-artifact rehash/interrupt cleanup retain failures; no speed
  score or production selection. [Operation](docs/NATIVE_TURING_DOWN_DECODE.md).
  Next earn strategy3 sealed owning-context replay and enabled-control recovery.
- [x] SPD-01/04 down-only128 sealed owning-context replay: two45-ID greedy/seeded
  checkpoints/eight continued frames/1026048 values per owner/four baseline-
  restored owners pass exact actual bits/causal/sample/draw/config/allocation/
  tile/source/independent budgets and4352 guards. Down calls28 before/after;
  18 damaged-plan/flag refusals preserve healthy state/counters/owners before
  reset. Seven portable contracts/master190 passes/one skip; pure3 owner/seal/
  strategy4/native-mode refusal and all-artifact rehash/cleanup interrupts pass.
  [Operation](docs/NATIVE_TURING_DOWN_CHECKPOINT.md). Preliminary accepted capture
  stays; final strengthens explicit refusal counter/allocation comparisons.
  Next earn strategy3 cooperative control recovery; no elapsed/crash/production gate.
- [x] SPD-01/04 down-only128 opt-in cooperative controls: default-disabled
  capability preserves ordinary3 refusal. Disabled capable model matches all
  prior2/prior3 F32/IDs/full cache and unchanged CPU/own-bit/4352-guard gates.
  Four real aborts at0/2/8/0 synced layers/down calls recover exact513024 values
  per owner after reset, preserve allocations/IDs/owned SIGINT/mask/refusals and
  9792 guards. Observer exception poisons at1 layer/call and refuses reuse/reset.
  Six portable contracts/master190 passes/one skip; actual capability/source/hash
  gates/negative pre-model refusals pass. Disabled long paired native/new
  12.70594/6.83303s=1.85949x exploratory; enabled control time unscored.
  [Operation](docs/NATIVE_TURING_DOWN_CONTROLS.md). Next earn owned3 projection
  tracing before next measured speed change; production/broader/provider gates stay.
- [ ] SPD-01/02: validate real packed-weight matrix prefill and full-model
  support in the locked toolchain before promoting either path.
- [ ] SPD-03–07: improve attention, launch overhead, sustained decode, bounded
  cache/buffer use and verified speculative decode when the ceiling requires it.
- [ ] SPD-08–10: validate concurrent throughput, thermal/recovery/memory soak
  and the complete refreshed provider lead before integration policy changes.

The first measurement slice is implemented; the overall speed-lead program remains
open. Runtime capability statuses stay governed by the ledger. The focused SPD
track fits inside the wider S01–S48 application program.

## 2026-10-01 long-token and buffer acceptance

- [x] Publish task contract before implementation; preserve working binary.
- [x] Add bounded four-token prefill only for exercised strict 3B profile.
- [x] Check compact disjoint spans, actual bytes, context/tile bounds and overflow.
- [x] Physically compare all native sequential/tiled logits in five cases,
  greedy/seeded replies and exact-token restore continuation.
- [x] Prove four-projection tails, long-attention reference/independent equations,
  invalid-tile non-mutation and deadline/reset/API recovery.
- [x] Complete controlled fresh-prompt speed evidence, retaining raw failures
  and whole-response/count equality. Final remote CI/deployment are separately
  recorded by exact revision and binary checksum in publication artifacts.
- [ ] Extend whole-model coverage to maximum context, longer generation and other
  profiles/devices. The first SPD-00 oracle covers four 3B final-prompt vectors;
  broader independent full-model coverage remains open.

# Project A.E.S.I.R. — Evidence-Backed TODO

## Native efficiency follow-up — 2026-10-01

- [x] **[partial, AES-OPS-001]** Bound quant byte arithmetic to Int32 while
  preserving wide spans and reference float order; schedule RMS loads in small
  fixed-width tiles. Physical projection/RMS references and independent equations
  pass. Same-policy whole replies match in all 34 paired HTTP benchmark samples.
- [x] Measure standard cache-disabled and cached work plus 1070-token prefill and
  128-token sustained output. Achieved another 1.60–1.66x on this model/device.
- [x] Add a fail-closed evidence comparator and extended benchmark controls;
  mismatched replies/settings/models/failures cannot publish speed ratios.

See [efficiency operation and verification](docs/NATIVE_EFFICIENCY.md). The open
batched-prefill/full-logit/device/context-recreation gates below remain open.

## Native performance milestone — 2026-10-01

- [x] **[partial, AES-OPS-001]** Profile real 3B CUDA work and optimize packed
  projections without changing reference accumulation; preserve exact whole
  replies across the archived/new binaries. Prepare layer descriptors once.
- [x] **[partial, AES-OPS-001]** Add bounded exact-prefix reuse with cache-disable
  control, fresh final logits, rebuilt sampler state and physical recovery gates.
- [x] Repair persistent Llama snapshot family mapping after actual chat failure.
- [ ] Implement and physically validate true batched matrix prefill, full independent
  logits, representative long-context attention and broader profile/device speeds.
- [ ] Isolate/fix locked-runtime in-process CUDA context recreation; retain process
  replacement for model switching until that gate passes.

See [native performance manual](docs/NATIVE_PERFORMANCE.md). This milestone does
not establish universal optimality, all-model/device speed or an Ollama advantage.

Current program: [best-in-class application gameplan](BEST_IN_CLASS_GAMEPLAN.md).
Its S01–S48 sequence drives new work; this backlog retains detailed historical
items and the capability ledger retains present-tense implementation authority.

This backlog is governed by [`CAPABILITY_LEDGER.md`](CAPABILITY_LEDGER.md) and
[`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`](PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md).
Execution order and anti-fabrication file rules are defined in
[`ROADMAP_REALITY_FIRST_COMPLETION.md`](ROADMAP_REALITY_FIRST_COMPLETION.md).
An enum, interface, banner, synthetic happy path, or predetermined output never
counts as completion of an external capability.

Earlier completed native profile: Stheno Q4_K_S download, Llama 3 CUDA inference
and 20-turn roleplay with an 8K ceiling. See [the evidence and remaining
limits](docs/STHENO_CUDA.md). General model support, full-model logit parity,
and optimized batched prefill remain future work. Native CUDA sampling now has
an independent device/reference gate; see [runtime controls](docs/NATIVE_RUNTIME.md).

- [x] Connect native CPU/CUDA hardware reporting, checked model memory plans,
  fitting-device selection and automatic CUDA single-shot profile detection.
  Five counted cases and both physical CUDA profile integrations passed;
  [limits and commands](docs/NATIVE_RUNTIME.md) retain unverified devices.

- [x] Native CUDA temperature/top-k/top-p/min-p/repetition controls, seeded
  device selection and explicit session reset/settings. Independent GPU sampler
  reference and both real model/control integrations pass.
- [x] Bound pinned host upload staging to 64 MiB; physical exact-byte and
  final-chunk checks pass. GPU weight/KV memory requirements are unchanged.

> “I know that I sat nine days and nights, the friend of Mímir, seeking wisdom, until I was given to myself, and my own mind was won.”
> — Hávamál, Stanza 141


## Status Rules

- `[x]` means the narrowly worded task has executable evidence and its stated
  acceptance boundary passed.
- `[ ]` means work remains. The bracketed ledger status (`partial`, `scaffold`,
  `simulated`, or `missing`) records the current starting point.
- A task moves to `[x]` only in the same change that records its exact proving
  command, result, evidence boundary, and relevant ledger status change.
- A verified narrow primitive may still have unchecked hardening/generalization
  tasks. “Verified” does not mean production-ready.
- The canonical five-value status vocabulary lives in `CAPABILITY_LEDGER.md`.

## Second-brain integration — 2026-10-01

- [x] Strict Llama 3.2 3B Q4_K_M with tied weights and scaled RoPE on sm_75;
  Turing residual PTX repair; 35 real-weight and 52,210 primitive comparisons.
- [x] Add truthful native model/capability discovery and a checked user-service
  recipe; actual HTTP faults and supervisor restart proved in the
  [second-brain evidence](docs/evidence/second-brain-2026-10-01.md).
- [x] Connect independent Bifröst chat routing with bounded admission, explicit
  fallback/circuit recovery and unchanged corpus embeddings. Live read-only
  corpus and recovery checks pass; default remains measured faster Ollama.
- [x] Measure generic versus specialized Q4_K/Q6_K kernels: 15–17% lower native
  warm HTTP latency; observed baseline/optimized native text/count replay matches.
- [ ] Beat Ollama on representative same-weight workloads. Native remains slower;
  batched prefill, prefix reuse and measured kernel/scheduling work are open.

## Verified Forge Milestones

- [x] **Complete reality and function-level audit:** Inventory all 379 tracked
  Mojo declarations, record AER-001 through AER-115, classify affected
  functions, and publish the staged Forge 0 through Stage 10 buildout plan.
- [x] **Forge 0A — fail-closed tests:** Replace identified print-only and
  early-return assertion failures with raised errors; prove a deliberate failed
  expectation exits nonzero.
- [x] **Forge 0B — counted proving summary:** Register 49 executable named cases
  and one explicit external-fixture skip; continue after case failures; emit
  stable case/summary lines; raise after a failing summary.
- [x] **Pinned real GGUF vertical slice:** Validate one external GGUF v3 Llama
  F16 model, mmap F16 matrices, convert F32 norms, load tokenizer metadata,
  execute grouped-query CPU inference, and match first-token `llama.cpp` parity.
- [x] **Pinned deterministic multi-token slice:** Reuse one request KV cache,
  enforce EOS/length/context policy, match all 32 greedy token IDs and exact text,
  preserve the one-token result, and stop safely at the 128-token context edge.
- [x] **Narrow CPU primitive proofs:** Preserve the currently tested CPU GEMM,
  RMSNorm/RoPE/GQA path, SiLU, cosine similarity, host tensor partitioning,
  sequential host reduction/GEMM, and in-memory vector-store invariants. These
  checks do not establish hardware acceleration or general production kernels.
- [x] **Stage 37.1 Hardening — RAG Hidden Dim Parameter Bounds (`AES-RAG-005`):** Hardened `_prepare_prompt()` in `aesir.mojo` for non-positive hidden dimensions (`hidden_dim <= 0`).
- [x] **Stage 38.1 Hardening — Pure Native Mojo Zero-Python Runtime (`AES-FND-004`):** Audited and confirmed zero `std.python` imports in engine runtime execution.
- [x] **Stage 39.1 Hardening — Arena Pool KV Cache Reset Restoration (`AES-MEM-005`):** Hardened `MimirWell.reset_kv_cache(runtime_offset)` pool restoration and offset advancement tests.
- [x] **Stage 40.1 Hardening — Repository Artifact Hygiene & `.gitignore` (`AES-FND-007`):** Configured `.gitignore` protecting against `.pixi/`, binaries, objects, and logs.
- [x] **Stage 41.1 Hardening — Query Embedding Truth Boundary (`AES-RAG-003`):** Removed fabricated fallback embeddings; real query embeddings now require loaded token-embedding weights.
- [x] **Stage 42.1 Hardening — Chat Template Formatter Empty Message List Bounds:** Hardened `format_chatml()`, `format_llama3()`, and `format_llama2()` in `loader/chat_template.mojo` to reject empty message lists.
- [x] **Stage 43.1 Hardening — Deep Bug Audit & Attention Head Bounds:** Hardened `incremental_causal_attention()` in `core/compute.mojo` for non-positive `head_dim` and non-divisible query/kv head ratio safeguards.

### Most Important Issues to Address First - ASAP!!! (TOP PRIORITY: HARDWARE ACCELERATION)

- [x] **Modular Max Support:** Add full support for MAX by Modular
- [x] **Config Data File:** Add config file that is human readable and can be manually edited by the user. All options should be included and explain all options, settings, and features very well.
- [x] **Acceleration Selection:** Add command that allows the User to select which acceleration system is being used. 
- [ ] **[partial, AES-OPS-004] Complete the optional TUI:** The formatter now validates caller-observed snapshots and refuses to invent live values. Connect it to native session measurements, define snapshot freshness, and add terminal integration tests.
- [x] **Add Help Commands:** Add very useful, well written, complete help command system.
- [ ] **[missing, AES-SYS-001] Cognitive Inference Architecture:** Define real semantic state ownership, snapshots, retrieval/reconstruction and model-equivalence evidence; configuration intent currently fails closed.
- [ ] **[missing, AES-SYS-001] Wave Inference Computing:** Supply a falsifiable physical/numerical specification, model transform, reference output and measured hardware evidence; the synthetic cosine path was removed.
- [ ] **[missing, AES-SYS-001] Neural Spectral Fractal Inference:** Define trained representation/conversion, reconstruction error bounds and inference parity; the sine/cosine weight generator was removed.
- [ ] **[verified, AES-GEN-005] Complete SKÁLDBRØÐIR integration:** A bounded exact-period detector and configuration intent exist. Wire its intervention signals into native generation, define reset/session ownership, and verify quality impact; it currently does not compute entropy or modify logits.
- [ ] **[verified, AES-GEN-011] Complete tool use:** Strict bounded schema formatting and call parsing work; add an allowlisted executor, authorization, sandboxing, deadlines, cancellation, result framing, audit records, and model-loop integration.
- [ ] **[verified, AES-GEN-010] Complete thinking control:** Literal thought-block redaction works across split tokens; add per-model reasoning controls and native CUDA streaming integration. Text redaction alone cannot ensure a model did not reason internally.
- [x] **Compute Improvements:** Read RuneForgeAI_Aesir_Compute_Optimization_Manifest.md and implement all suggested improvements.
- [x] **NPU Gate Improvements:** Read RuneForgeAI_NPU_Gate_Optimization_Manifest.md and implement all suggested improvements.
- [ ] **[missing, AES-SYS-001] New inference research:** Treat MQARI or any new method as research until it has a falsifiable method, real model integration, output-equivalence tests and physical speed evidence.
- [ ] **[verified, AES-RES-006] Expand caller-reported failure diagnostics into runtime crash handling:** Persist redacted structured records, capture owned runtime context, add a lifecycle supervisor, define safe restart/backend-switch policies, and prove them with injected failures. The current formatter does not intercept, restart, switch hardware, or call AI.
- [x] **#1 PRIORITY PHASE 1 — NVIDIA CUDA GPU Acceleration (`AES-ACC-001`/`AES-ACC-004`):** Implemented native CUDA driver/runtime FFI bindings (`cuda_gate.mojo`), VRAM allocation, host-to-device transfers, and CUDA GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 2 — Apple Metal GPU Acceleration (`AES-ACC-002`/`AES-ACC-005`):** Implemented native Metal framework FFI bindings (`metal_gate.mojo`), zero-copy buffer allocation, and Metal GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 3 — Intel OneAPI / Level Zero GPU Acceleration (`AES-ACC-003`):** Implemented native Intel Level Zero FFI bindings (`intel_gate.mojo`), VRAM allocation, and Level Zero GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 4 — AMD ROCm / HIP GPU Acceleration (`AES-ACC-004`):** Implemented native AMD HIP FFI bindings (`amd_gate.mojo`), VRAM allocation, and hipBLAS GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 5 — Major NPU Acceleration Integration (`AES-ACC-006`/`AES-ACC-007`):** Implemented vendor NPU driver gateways (`npu_gate.mojo`) for Qualcomm Hexagon, Apple Neural Engine (ANE), Hailo-10, and Intel NPU.
- [x] **#1 PRIORITY HARDENING — Hardware Acceleration Hardening, Crash-Proofing & Self-Healing Resilience (`AES-ACC-008`/`AES-ACC-009`):** Harden all 5 hardware gateways (`CUDAGate`, `MetalGate`, `IntelGate`, `AMDGate`, `NPUGate`) with strict bounds checking, non-positive allocation rejection, self-healing memory reclamation, and crash-proof error isolation.
- [x] **Automated CI/CD Pipeline (`.github/workflows/ci.yml`):** Added GitHub Actions CI workflow executing master test runner (`run_all.mojo`) and doc drift verification on push/PR.
- [x] **Repository Structure & Asset Cleanup:** Consolidated 20+ root image files into `docs/assets/images/`, moved `TASK_*.md` documentation files into `docs/tasks/`, and updated all markdown image links.
- [x] **Quantized GGUF Inference Vertical Slice (Q4_K_M):** Connect `dequantize_q4_k_m()` kernel to `GGUFSeer` loader and `forward_pass()` model execution pipeline with real quantized GGUF model fixture tests.
- [x] **Live OpenAI REST API Inference Connection (`AES-SRV-006`):** Connect bare-metal POSIX socket `/v1/chat/completions` REST endpoint directly to the local GGUF engine runner for streaming inference.
- [x] **[partial, AES-MEM-004] Paged KV Cache Pool:** Add real multi-sequence
  logical page tables, bounded physical ownership, translated K/V access,
  exhaustion, release/reuse, and per-layer initialization guards.
- [ ] Connect paged K/V storage to model attention and scheduling; add eviction,
  prefix sharing/reference counts, copy-on-write, GPU pages, and measured
  fragmentation/memory efficiency (`AES-MEM-004`).
- [x] **Security Fuzzing & Resource Limits:** Add GGUF parser fuzzing harness, enforce system-level generation token limits, and document threat model (`AES-OPS-003`).

### Remaining Audit & Hardening Remedies (Backlog)

- [x] **[verified, AES-CPU-008] Multi-head GQA/MQA Execution Integration:** Extend `incremental_causal_attention` with full multi-head caching and GQA ratio scaling across custom GGUF architectures.
- [x] **[verified, AES-GEN-009] Stop Reason Policy Integration:** Implement full stop token and sequence policy parsing for multi-token streaming generation.
- [ ] **[partial, AES-SRV-006] Live OpenAI REST API Engine Connection:** Live bounded chat execution and incremental SSE exist; official-client conformance and broader API features remain open.

## Forge 0 — Restore Truth Before Expanding Runtime Claims

### Forge 0C — Canonical capability ledger (completed)

- [x] **Publish the canonical capability ledger:** Cover all major
  README, TODO, vision, architecture, interface, and runtime claim families with
  stable IDs, one allowed status, exact evidence, evidence boundaries, next
  acceptance gates, owners, and AER links.
- [x] Mechanically validate unique IDs, allowed statuses, summary counts, cited
  files, and named master-suite cases.
- [x] Link the ledger from README, TODO, the reality audit, and DEVLOG.
- [x] Re-run the 49/0/1/50 master suite, external pinned GGUF integration, clean
  Mojo build, and real built-CLI generation before marking Forge 0C complete.

### Forge 0D — Eliminate fabricated operational output (completed)

- [x] **[verified, AES-GEN-009] Implement or disable Masking Seidr:** Stop
  claiming a thought token is bound to `-inf` until tokenizer resolution and
  real logit masking are verified.
- [x] **[partial, AES-CLI-005] Correct `list`/`show`/`ps` output:** Remove fixed
  catalogs, CUDA utilization, expiry, architecture, parameters, and sampler
  values unless derived from real current state.
- [x] **[partial, AES-CLI-006] Correct `pull`/`push`/`create` output:** `pull`
  performs the documented pinned, verified public GGUF download and `create`
  records a validated durable recipe without inventing model-byte metadata;
  `push` remains explicitly unsupported.
- [x] **[partial, AES-CLI-007] Correct `rm`/`cp`/`stop` output:** Do not report
  storage or process mutations that occurred only in an ephemeral seeded list.
- [x] **[partial, AES-CLI-008] Correct REPL output:** The legacy sample loop is
  bounded; native Gemma/Llama CUDA chat supplies separate real interactive paths.
- [x] **[partial, AES-SRV-006] Correct OpenAI route output:** Stop returning a
  fixed assistant response as successful inference.
- [x] **[missing, AES-SRV-007] Correct llama.cpp route output:** Remove fixed
  completion/token/detokenize/health/metrics responses and parity wording.
- [x] **[partial, AES-ACC-003] Correct device discovery:** Return only
  configured/observed devices, or explicit unavailable status; never append all
  backends as detected.
- [x] **[missing, AES-ACC-006] [partial, AES-ACC-008] Correct accelerator banners:** Do not
  print NPU/GPU “ACTIVE,” CUDA, Tensor Core, or hardware-realm execution when the
  selected function runs on the CPU.
- [x] **[partial, AES-ECO-003] Correct Hugging Face download output:** Return
  unsupported without “downloading”/registration success until bytes are
  transferred and stored.
- [x] **[partial, AES-ECO-004] Correct ONNX output:** Remove fixed IR version,
  node count, and validated/mapped status.
- [x] **[missing, AES-ECO-005] [missing, AES-ECO-006] Correct ExLlama/llama CLI output:**
  Remove fixed completion, server health, bitrate, cache, benchmark, and
  perplexity claims.
- [x] **[missing, AES-RES-005] Correct self-healing output:** Reject the legacy
  recovery entry point without reporting recovery of state that was never lost.
- [x] **[missing, AES-SWM-003] [missing, AES-SWM-004] [missing, AES-SWM-005] Correct swarm output:** Remove fixed
  peers, VRAM, health, join, dispatch, and remote execution success.
- [x] **[partial, AES-OPS-001] Delete fabricated benchmark numbers:** Retain no
  tokens/s, perplexity, model size, backend, or utilization number that was not
  measured by a recorded harness.
- [x] Add negative tests proving unsupported branches fail nonzero and cannot
  emit success/healthy/validated/completed language.

### Forge 0E — Reconcile all present-tense documentation (completed)

- [x] Replace all Chinese in documents or code with the proper English words.
- [x] **[verified, AES-OPS-006] Rewrite README technical claims:** Preserved the
  vision while labeling the pinned CPU slice, partial primitives, scaffolds,
  simulations, and missing capabilities exactly (`python3 scripts/check_doc_drift.py`).
- [x] Replace the README's direct mmap-to-GPU analogy with the verified CPU mmap
  boundary; reserve device-memory claims for real accelerator evidence.
- [x] Replace “PagedAttention” with the actual contiguous request KV-cache
  status until page allocation/mapping exists.
- [x] Replace “stateless sampler” with verified greedy argmax and explicit
  missing sampling/zero-allocation work.
- [x] Remove NVIDIA RTX/Tensor Core optimization language until physical backend
  execution and measurements pass.
- [x] Reconcile `ARCHITECTURE.md`, `DATA_FLOW.md`, `docs/ARCHITECTURE.md`,
  `docs/DATA_FLOW.md`, `docs/SYSTEM_VISION.md`, `docs/Vision.md`,
  `docs/REPO_OVERVIEW.md`, and `docs/DOMAIN_MAP.md` with the ledger.
- [x] Reconcile root/domain `INTERFACE.md` files so contracts distinguish
  implemented behavior from desired interfaces and unsupported backends.
- [x] Classify duplicated/historical docs explicitly; choose canonical files and
  prevent their copies from drifting (`docs/historical/2026-08-16/`).
- [x] Add a documentation drift check for prohibited maturity terms without a
  ledger ID/evidence link (`scripts/check_doc_drift.py`).

## Stage 1 — Memory and Unsafe-Boundary Hardening

### `MimirWell` and allocation ownership (completed)

- [x] **[verified, AES-MEM-001; AER-002] Replace address-1 exhaustion:** Made
  `MimirWell.allocate()` raise catchable `Error("MimirWell: memory pool exhausted")` before returning any invalid pointer (`pixi run mojo run aesir_engine/tests/run_all.mojo`).
- [x] Reject nonpositive pool sizes and negative allocation requests.
- [x] Add checked add/multiply arithmetic for pool sizing and offset advancement.
- [x] Define and enforce alignment for each tensor/buffer allocation.
- [x] Add explicit checkpoint/rewind ownership instead of accepting arbitrary
  offsets in `reset_kv_cache` or related helpers.
- [x] Prove exhaustion, overflow, alignment, repeat-failure, and offset-integrity
  behavior without unsafe dereference.
- [x] Ensure construction and generation failures reclaim owned allocations and
  preserve the persistent runtime boundary.

### Tensor, buffer, and cache contracts

- [x] **[verified, AES-MEM-002; AER-005] Add checked `RuneTensor` construction:**
  Reject negative/overflowed shapes, invalid spans, null/sentinel pointers, and
  provide checked `get_checked` / `set_checked` indexing.
- [x] Define borrowed versus owned, mutable versus immutable, and lifetime
  relationships for mmap-, pool-, shard-, and result-backed tensors.
- [x] Add checked boundary alternatives for `RuneTensor.get()` and `set()`.
- [x] Validate `KVCache` layer count, context, KV width, products, and pool
  capacity during construction.
- [x] Validate `KVCache.append()` layer, position, key width, and value width.
- [x] Validate `get_k_slice()`/`get_v_slice()` layer and requested sequence span.
- [x] **[partial, AES-MEM-004]** Replace the PagedKVCache counter with real
  multi-sequence page tables, physical ownership, translated access,
  per-layer initialization bounds, exhaustion, release, and reuse.
- [ ] Integrate the paged pool with attention/session scheduling and add
  eviction, shared-prefix reference counts/copy-on-write, GPU pages, and
  memory-efficiency measurements (`AES-MEM-004`).
- [x] Remove misleading ring-buffer behavior and wording: fixed-capacity
  appends now reject overflow without mutation; chronological wraparound remains
  explicitly unimplemented.
- [x] Replace sentinel-bearing usable `TransformerBlock` constructors: the
  GGUF-backed path now requires nine usable tensors, the legacy overload raises,
  and the copy path preserves only validated views.
- [x] Make `NPUBuffer`/`GPUBuffer` honest host-view descriptors until real device
  allocation exists; validate sizes and ownership.

### Memory-store and hot-path refinement

- [ ] **[verified, AES-MEM-005] Instrument dynamic allocations:** Extend the
  narrowly verified pool restoration and ownership boundary by defining the exact
  steady-state token region and measure every list/string/block/workspace heap
  allocation.
- [x] Remove per-token transformer-block copies and avoid hot-path list growth.
- [x] Add exception-safe workspace guards around transformer blocks and
  `forward_pass()`.
- [x] Validate `MimirStore` capacity, dimension, products, embedding ownership,
  and copied-document lifetime.
- [x] Make full-capacity/dimension failures explicit results rather than warning
  and silent truncation.

## Stage 2 — CPU Kernel Contract and Numerical Hardening

- [x] **[verified, AES-CPU-008] Create one uniform checked-kernel boundary:**
  Validate tensor shapes, spans, alias rules, output sizes, and finite policies
  before unsafe kernel loops.
- [x] Add randomized F32-reference tests for `gemm_f16` across rectangular
  shapes, zero/one dimensions, lane tails, magnitudes, NaN, and infinity.
- [x] Add direct RMSNorm F32-reference tests across widths/tails/extremes and
  reject mismatched weights or zero width.
- [x] Add RoPE reference tests for positions, head widths, model theta, scaling
  variants, odd-width rejection, and negative positions.
- [x] Add causal GQA/MHA attention reference tests across query/KV head ratios,
  sequence lengths, masks, and finite extremes.
- [x] **[verified, AES-CPU-005] Repair or relabel `flash_attention_2`:** Add safe
  tails and causal semantics, then prove algorithmic parity; otherwise stop
  calling it fused FlashAttention-2.
- [x] Complete SiLU numerical/bounds coverage.
- [x] Define GEGLU math/output shape, reject odd sizes, compare to a reference,
  and clarify the actual SwiGLU transformer path.
- [x] Make `cosine_similarity` reject dimension mismatch; define zero-vector,
  NaN, infinity, and tie behavior.
- [x] Validate all shard list lengths/spans; never silently take a minimum when
  contracts disagree.
- [x] Use wider accumulation where required and publish explicit tolerances.

## Stage 3 — GGUF and Tokenizer Generalization

### GGUF loader

- [x] **[verified, AES-LDR-005] Refactor loader state:** Separate unopened,
  header-parsed, tensor-mapped, validated, failed, and closed states.
- [x] Add checked integer conversions/arithmetic for all offsets, lengths,
  counts, alignments, shapes, and products.
- [x] Define duplicate metadata/tensor-key behavior.
- [x] Replace architecture-unsafe unaligned/native-endian reads with portable
  bounded reads.
- [x] Guarantee unmap/free/close cleanup on every partial parse or mapping error.
- [ ] Build a malformed GGUF corpus covering magic, versions, types, truncation,
  alignment, overlapping/out-of-range tensors, dimensions, duplicate keys,
  invalid UTF-8, and resource limits.
- [ ] Add a loader fuzz harness and regression seeds.
- [ ] Add real F16 fixtures for tied output, RoPE metadata/scaling variants,
  tokenizer variants, and at least one additional architecture only when its
  inference path exists.

### Tokenizer and decoder

- [x] Validate vocabulary finalization, parallel metadata lengths, duplicate
  tokens, sparse IDs, special-token ranges/types, and model add-BOS policy.
- [ ] Replace potentially quadratic greedy merge behavior with a profiled,
  correct candidate data structure without changing reference IDs.
- [x] **[verified, AES-TOK-003] Implement a stateful byte/UTF-8 decoder:** Accumulate
  byte tokens, emit only complete sequences, define invalid-byte and flush rules,
  and handle special/control tokens.
- [x] **[verified, AES-TOK-004] Add multilingual differential corpora:** Cover
  whitespace, combining marks, emoji, CJK, RTL scripts, invalid bytes, controls,
  and tokenizer normalizer metadata against authoritative references.
- [x] Add encode/decode round-trip tests where the source tokenizer contract
  permits round trips.

## Stage 4 — Generation Quality and Request Semantics

- [x] Add one validated `GenerationConfig` with explicit greedy mode and bounds.
- [x] **[verified, AES-GEN-006] Add configurable stop-token sets.**
- [x] Add sequence-aware stop strings spanning token and streaming boundaries,
  with explicit visible-text exclusion behavior.
- [x] Add model-produced EOS fixtures rather than testing EOS policy only as a
  helper function.
- [x] Add `cancelled` and `error` result states with deterministic cleanup.
- [x] **[verified, AES-GEN-005] Implement sampling:** Temperature, top-k, top-p,
  repetition/frequency/presence penalties, optional min-p/typical-p, explicit
  composition order, validated RNG, and deterministic seed.
- [x] Compare seeded sampling vectors and end-to-end sequences with an
  authoritative reference.
- [x] **[verified, AES-GEN-007] Implement GGUF chat templates and message roles:**
  Validate escaping, control tokens, system/user/assistant transitions, and
  model-specific reference transcripts.
- [x] **[verified, AES-GEN-008] Design batching and concurrent sessions:** Explicit
  request/cache ownership, scheduler fairness, cancellation, error isolation,
  and resource limits.
- [x] Add broad multi-model/multi-prompt numerical, token, text, EOS, context,
  stop, failure-cleanup, and cancellation regression corpora.
- [x] Make logit argmax initialization and finite-logit handling correct for all
  representable values.
- [x] **[verified, AES-GEN-009] Implement real thought-token masking and logit suppression.**

## Stage 5 — Persistent CLI, Model Store, and Distribution

### CLI grammar and REPL

- [x] **[partial, AES-CLI-009] Implement CLI flag option parser:** `--verbose`, `--format json|text`, `--keepalive <duration>`, `--modelfile <path>`, `--raw`, `--insecure`, `--max-tokens N`, configuration/acceleration intent, and duration parsing. Operational wiring remains incomplete for the broader capability.
- [x] Replace the line-based configuration approximation with strict bounded
  nested JSON syntax, schema/type/range checks, duplicate rejection, and
  adversarial parser coverage.
- [x] **[verified, AES-CLI-003] Complete the chosen Modelfile grammar:** Quoting,
  multiline directives, validation, errors, and compatibility corpus.
- [ ] Connect parsed parameters, templates, system messages, and licenses to the
  actual stored model/generation configuration.
- [ ] **[partial, AES-CLI-008] Build a general interactive REPL:** Unify
  multi-turn conversation state, slash commands (`/set`, `/show`, `/clear`,
  `/bye`), parameter tuning, and stream execution beyond the native Gemma/Llama
  CUDA chat profiles.
- [x] Reject ordinary legacy REPL input and bare interactive `run` without
  turning model/runtime errors into assistant messages or mutating history.

### Persistent model store

- [x] **[partial, AES-CLI-004] Add the content-addressed model store:** The
  empty versioned catalog now owns immutable `blobs/sha256/<digest>` objects.
  `create --model` hashes the exact opened inode, records its measured size,
  deduplicates safely, and `verify` performs a full rehash.
- [x] Compute real SHA-256 digests and sizes from imported bytes; recipe-only
  manifests retain their explicitly unknown byte metadata.
- [x] Implement atomic add/copy/remove/update with rollback and restart tests.
- [x] **[partial, AES-CLI-005] Connect catalog output:** `list`, `show`, `create`, `cp`, and `rm` use the restart-safe recipe catalog with built-CLI process evidence.
- [ ] Connect `ps` and `stop` only after a real live-session registry exists.
- [x] Define model-in-use, not-found, duplicate, permission, corruption, and
  concurrent mutation semantics.
- [x] Add locked, reference-aware blob garbage collection. `gc` validates the
  complete directory and every catalog size before deletion, removes unreachable
  blobs and strict stale-stage names, synchronizes the directory, and reports
  exact accounting. Systematic process-crash/fault injection at every filesystem
  boundary remains open.

### Network distribution

- [ ] **[partial, AES-ECO-003] Implement real Hugging Face HTTPS download:**
  Revisions, filenames, URL encoding, redirects, authentication, resume/range,
  timeouts, cancellation, byte counts, and errors.
- [x] Verify expected size/digest again inside the locked store transaction
  before atomic catalog promotion; mismatch rolls back a newly created blob.
- [ ] Protect tokens/secrets from logs, command output, crash reports, and
  committed files.
- [x] Connect public pinned `pull --name` to the content-addressed store and
  prove it with a live external GGUF registration/reverification harness.
- [ ] Scope `push` separately with authentication, conflict, retry, and integrity
  semantics; otherwise return explicit unsupported.
- [ ] Implement `create` as real manifest/layer construction from a validated
  Modelfile.
- [ ] **[partial, AES-CLI-009] Build an Ollama CLI differential conformance suite
  for only the explicitly supported version and commands.**

## Stage 6 — Service Boundary and Protocol Conformance

Native milestone (2026-08-31): authenticated loopback `/health` and
`/v1/generate` now execute on both loaded CUDA profiles with strict bounds,
deadline recovery and active shutdown. See [native service](docs/NATIVE_SERVICE.md).
The legacy formatters below are not exposed compatibility APIs.

### Socket and HTTP foundation

- [ ] Move transport serialization and socket ownership out of `AesirEngine`
  behind a service/request API.
- [x] **[verified, AES-SRV-001] Add loopback bind/listen/accept/close tests:** POSIX socket setup, `SO_REUSEADDR`, `set_nonblocking()` (`fcntl`), and deterministic cleanup.
- [ ] Build a platform-safe socket abstraction before claiming another OS.
- [x] **[verified, AES-SRV-002] Implement HTTP/1.1 request parser & router:** Request line (method, path, protocol), header block (`Content-Length`), body isolation, and route dispatching (`HTTPRequest`).
- [x] **[verified, AES-SRV-003] Implement write-all and HTTP response framing:** `write_all_bytes()`, `build_http_response()`, `build_sse_chunk()`, and `build_http_chunk()`.
- [x] Use a real JSON serializer/escaper for prompts, model output, errors, and
  Unicode rather than concatenating untrusted strings.
- [x] **[verified, AES-SRV-010] Native serialized service:** request sequence,
  bounded errors/I/O, deadlines, cancellation and cooperative shutdown.
- [ ] Add multi-client session ownership, scheduling, streaming backpressure
  and sustained load/security evidence.

### Compatibility surfaces

- [ ] Choose one first compatibility API and record its exact supported version,
  endpoints, schemas, and exclusions.
- [ ] **[partial, AES-SRV-005] [partial, AES-SRV-006] OpenAI:** Extend the live
  text-only request/response subset, usage/error contracts and incremental SSE
  with official-client tests; embeddings remain a separate unshipped capability.
- [ ] **[missing, AES-SRV-007] llama.cpp server:** Connect real tokenize,
  detokenize, completion, health, props, slots, and metrics only where supported;
  pass differential tests against a pinned server.
- [ ] **[partial, AES-SRV-008] Ollama HTTP:** Extend the live generate/chat/model
  subset and incremental NDJSON with real-client differential tests.
- [ ] **[verified, AES-SRV-004] Streaming:** Extend the narrowly verified framing
  utilities: pick protocol framing, use stateful
  UTF-8 decoding, escape chunks, handle partial writes/backpressure/disconnect,
  propagate cancellation, and prove the final frame.
- [ ] **[partial, AES-SRV-009] Add bounded concurrent service operation:** Worker
  ownership, queue limits, fairness, cancellation, race, soak, and load tests.

## Stage 7 — Real Embeddings and RAG

- [x] Harden cosine similarity dimension/finite/zero-vector contracts and
  randomized reference coverage.
- [x] Harden `MimirStore` dimensions, capacity, ownership, result/tie semantics,
  and hot allocations.
- [ ] **[partial, AES-RAG-003] Replace the constant query tensor with a real
  embedding model or verified extraction path.**
- [ ] **[partial, AES-RAG-004] Build corpus ingestion:** File/document parsing,
  deterministic chunking, metadata, embedding batches, versioning, and durable
  index storage.
- [ ] Add update/delete/reindex, corruption, restart, and compatibility behavior.
- [ ] Build a retrieval evaluation corpus with recall/ranking metrics and
  reproducible expected results.
- [ ] **[partial, AES-RAG-005] Complete end-to-end RAG:** Query embedding,
  retrieval, context budgeting, prompt integration, source metadata/citations,
  grounded-answer tests, and explicit no-result behavior.

## Stage 8 — Quantized Inference, One Format at a Time

- [x] Choose one authoritative GGML quantized format; Q4_K_M is the current
  advertised candidate and is implemented (`AES-QNT-001`).
- [x] Replace toy block structs with the exact upstream byte layout, scales,
  minima/zeros, packing, alignment, and tail contract.
- [x] Validate exact input byte spans and reject unsupported/tail cases before
  reads or writes (`AES-QNT-002`).
- [x] Compare full dequantized blocks against an independent authoritative
  decoder across fixed and randomized fixtures (`AES-QNT-002`).
- [x] Extend `GGUFSeer` to map/own that one quantized type safely (`AES-QNT-003`).
- [x] Implement a correct dequantized or fused quantized matmul path (`AES-QNT-003`).
- [ ] **[partial, AES-QNT-003] Load a real quantized GGUF and compare logits,
  first token, and a deterministic sequence with pinned `llama.cpp`.**
- [ ] Add each additional GGML format only with its own exact fixture and oracle.
- [ ] Connect the working GPTQ, AWQ, EXL2, HQQ, and SmoothQuant host primitives
  to parsed model tensors, external fixtures, and measured accelerator kernels.
- [x] Implement canonical IQ2_XXS 66-byte host decoding/GEMM with the upstream
  codebook and an independent raw-block oracle regression (`AES-QNT-010`).
- [x] Implement canonical IQ1_S 50-byte host decoding/GEMM with the complete
  upstream grid and an independent raw-block oracle regression (`AES-QNT-010`).
- [x] Implement canonical GGML TQ1_0 54-byte ternary host decoding/GEMM, retain
  `TERNARY_155BIT` as a compatibility alias, and verify all packed regions with
  an independent raw-block oracle regression (`AES-QNT-010`).
- [x] Replace guessed quantization metadata with exact fixed-block records and
  explicit external-metadata boundaries for every internal discriminant
  (`AES-QNT-011`).
- [x] Measure fused packed and dequantize-then-F16 host GEMM candidates, require
  numerical agreement, publish atomically from caller-owned scratch, and cache
  the exact-device/format/shape winner in memory (`AES-QNT-011`).
- [x] Serialize and transactionally restore a bounded, checksummed v1 tuning
  cache tied to caller-supplied build and device identities (`AES-QNT-011`).
- [x] Add locked, no-follow, bounded, private-stage/fsync/rename/fsync Linux
  cache-file persistence around the core codec (`AES-QNT-011`).
- [ ] Derive automatic executable/physical-device fingerprints, add synchronized
  CUDA and metadata-bearing candidates, and build a representative statistical
  benchmark matrix (`AES-QNT-011`).
- [x] Remove any dispatcher fallback that silently treats an unknown format as a
  different format (`AES-QNT-003`).

## Stage 9 — Real Hardware and Multi-Device Execution

### Honest discovery and unsupported behavior

- [ ] **[partial, AES-ACC-003] Separate configured from discovered devices:**
  Probe the platform and return only available backends with capability/error
  metadata.
- [x] Make absent GPU/NPU backends return explicit unsupported errors, never CPU
  fallback under a hardware execution label (`AES-ACC-003`).
- [x] Rename/describe host SIMD variants honestly; compiling a lane width does
  not prove ARM NEON, CUDA, OpenCL, or a vendor NPU (`AES-ACC-003`).

### First physical accelerator vertical slice

- [x] Select exactly one physically available GPU or NPU backend: NVIDIA CUDA
  through MAX 26.5 on the observed RTX host.
- [x] Implement real runtime/driver discovery and version/capability checks for
  the selected CUDA slice.
- [x] Implement backend allocation, ownership, host/device transfer or a precise
  zero-copy contract, synchronization, and error propagation.
- [x] Implement at least one genuine device kernel and compare its output with a
  CPU F32/verified reference on physical hardware.
- [x] Connect GPU-2 resource ownership to one reusable production-core CUDA F16
  GEMM and prove exact/tolerance parity, rejected-request safety, repeatability,
  and a deliberate post-kernel mismatch on physical hardware.
- [ ] Connect the kernel to one real-model inference slice and preserve token/
  logit parity.
- [x] Record reproducible GPU-0 through GPU-3 physical commands, device/toolchain
  identity, independent reference checks, repeated processes, and negative
  controls before promoting `AES-ACC-008` to `partial`. Trusted hardware CI
  remains open.
- [ ] Measure actual latency/throughput/memory only after correctness passes.

### Multi-device

- [x] Harden host shard functions for counts, divisibility, list lengths, spans,
  ownership, and cleanup while retaining honest host-only names (`AES-ACC-004`).
- [ ] **[missing, AES-ACC-004] Redesign multi-device GQA inference:** Explicit
  placement, correct Q/K/V partitioning, reconstruction, attention ownership,
  and cache layout.
- [ ] Implement asynchronous device work, transfer/compute overlap where valid,
  real collectives, synchronization, failure propagation, and cancellation.
- [ ] Prove single-device parity, multi-device correctness, device-loss behavior,
  and scaling on physical systems.
- [ ] **[missing, AES-ACC-009] Make any direct mmap/device-memory claim
  backend-specific and evidence-backed; otherwise keep it unsupported.**

## Stage 10 — Optional Ecosystems as Separate Projects

### ONNX

- [x] **[partial, AES-ECO-004] Decode bounded ONNX protobuf metadata:** Real
  file-backed/in-memory IR, producer, default opset and node fields with strict
  wire bounds, UTF-8 validation, rollback and recognized-operator rejection.
- [ ] Parse a pinned ONNX conformance model's TensorProto initializers,
  attributes, graph inputs/outputs, types and shapes.
- [ ] Define and implement an executable operator/type/shape subset; then build
  a planner and compare outputs with ONNX Runtime conformance fixtures.

### ExLlama/EXL2

- [ ] **[missing, AES-ECO-005] Scope an actual EXL2 parser/runtime for AESIR.**
- [x] Require a real EXL2 model, authoritative decoder/runtime comparison, and
  physical CUDA evidence before any parity claim (`AES-ECO-005`).

### llama.cpp CLI

- [ ] **[missing, AES-ECO-006] Define an intentionally supported subcommand and
  version subset; pass differential argument/output/error/exit tests.**
- [x] Never infer CLI/server parity from the pinned token-oracle comparison alone (`AES-ECO-006`).

### Grammar-constrained generation

- [x] **[verified, AES-ECO-007] Implement real decoded-token prefix automata
  and logit masking for the exact boolean and JSON-number schemas.**
- [x] Reject token-ID-only masking and unsupported JSON/general-GBNF requests
  without mutating logits or claiming constrained model generation.
- [ ] Parse a versioned GBNF subset, connect real tokenizer vocabulary text and
  the generation loop, and pass independent constrained-generation fixtures.

### Speculative decoding

- [x] **[verified, AES-ECO-008] Implement and validate the isolated sequential
  `min(1, p_target/p_draft)` token acceptance-prefix arithmetic.**
- [x] Remove fabricated repeated-argmax proposals, logits-as-probabilities and
  silent normal-generation fallback; incomplete integration paths fail closed.
- [ ] Implement real per-step draft proposals, batched target probabilities,
  residual correction sampling and transactional target/draft KV coordination.
- [ ] Prove target-distribution equivalence and a measured speed benefit before
  enabling speculative generation.

### Resilience, eventing, and concurrency

- [ ] Expand `ErrorGuard` into checked ownership/span/alignment/finite boundaries
  or remove the implication that a helper can sanitize unsafe pointers globally.
- [ ] **[verified, AES-RES-002] Expand the restart-safe `StateVault` marker:**
  Versioned bounded marker records, corruption checks, atomic replacement, and
  restart parsing work. Define complete session-state ownership, coordinate
  concurrent writers, add authenticated records where required, and prove
  injected write/sync/permission failures before calling it runtime recovery.
- [ ] **[verified, AES-RES-003] Expand the bounded synchronous local event bus:**
  Define ownership and add synchronization, reentrancy, durable replay,
  acknowledgement/retry, and cross-thread failure semantics.
- [ ] **[verified, AES-RES-004] Expand the bounded task descriptor queue into a real worker pool:** Threads, bounded
  queue, task completion/errors, synchronization, cancellation, and shutdown.
- [ ] **[missing, AES-RES-005] Define real recoverable failure boundaries and
  inject faults:** Prove model/KV/session/socket continuity or document explicit
  loss semantics.

### Swarm/distributed execution

- [ ] **[verified, AES-SWM-001] Expand the local protocol/version and node
  descriptors into an authenticated, authorized, encrypted discovery and
  membership model.**
- [ ] Replace the current caller-owned peer records with observed cross-process
  state and real heartbeat freshness/failure handling (`AES-SWM-003`).
- [ ] Extend the local capacity selector with reservations, concurrent updates,
  fairness, staleness, and scheduling policy (`AES-SWM-002`).
- [ ] **[missing, AES-SWM-003] Prove join/leave/heartbeat between separate
  authenticated processes.**
- [ ] **[missing, AES-SWM-004] Execute one real inference request remotely:**
  Model availability, prompt/result transport, streaming, cancellation,
  timeout, retry/idempotency, and validation.
- [ ] Derive CLI/REST state from a live cluster and pass multi-process failure
  tests before emitting `ONLINE`, `HEALTHY`, `JOINED`, or `DISPATCHED` (`AES-SWM-004`).

## Stage 11 — Operations, Security, Portability, and Release Readiness

### Continuous integration and portability

- [ ] **[partial, AES-FND-005] Complete CI coverage:** The clean Linux checkout,
  dependency lock, `E-BUILD`, `E-MASTER`, deliberate negative control, ledger,
  fixture, and artifact/path gates exist. Add required branch protection,
  supported-target coverage, formatting, and content-level secret scanning.
- [ ] Add opt-in/cached external-fixture jobs without committing model weights.
- [ ] **[missing, AES-FND-006] Build platform abstractions and CI for every
  explicitly supported OS/architecture; keep untested platforms unsupported.**
- [ ] Define dependency/toolchain update, lockfile, compatibility, and rollback
  policy.

### Benchmarks and efficiency

- [ ] **[partial, AES-OPS-001] Build a real benchmark harness:** Timer, token
  accounting, correctness gate, warmup, repeated samples/statistics, raw output,
  hardware/software/model/prompt metadata, and reproducibility command.
- [ ] **[missing, AES-OPS-002] Measure latency, throughput, memory, utilization,
  power, and thermal behavior before claiming fast, efficient, cold, or maximum
  hardware use.**
- [ ] Compare only equivalent models, precisions, prompts, contexts, sampling,
  and correctness outcomes.

### Security and observability

- [ ] **[partial, AES-OPS-003] Complete the threat model:** Untrusted GGUF/ONNX/
  Modelfile inputs, local/network clients, model registries, secrets, filesystem,
  unsafe pointers, resource exhaustion, and swarm peers.
- [ ] Add parser fuzzing, resource limits, secure filesystem permissions,
  checksum/signature policy, secret redaction, and dependency review.
- [ ] Decide safe network exposure defaults; add authentication/TLS policy before
  recommending non-loopback use.
- [ ] **[partial, AES-OPS-004] Add structured logs, real health/metrics, request/
  session correlation, error taxonomy, and observed-state consistency tests.**

### Repository and release hygiene

- [x] Prevent new tracked executable/build/model/archive/runtime-state/private-key
  format artifacts, tiny placeholder models, and duplicate canonical root assets
  with a baseline-locked policy, deterministic self-tests, and fatal CI
  enforcement.
- [x] Require fixture classification, ownership, purpose, consumer, evidence
  boundary, license, immutable source/construction, exact size, and SHA-256;
  keep registered external references outside Git.
- [ ] **[partial, AES-FND-007] Remove generated executables from source tracking
  through a reviewed, recoverable migration; preserve required source/history.**
- [ ] Add ignore and CI checks for binaries, model weights, secrets, caches,
  absolute local paths, and unrelated generated artifacts.
- [ ] Define supported build artifact formats, checksums/signatures, provenance,
  installation/uninstallation, configuration, data paths, and upgrade behavior.
- [ ] Keep AGPL/NOTICE/third-party attribution synchronized with every imported
  dependency or adapted source.

### Production readiness gate

- [ ] **[missing, AES-OPS-005] Do not label A.E.S.I.R. production-ready until:**
  all applicable safety blockers close; supported capabilities have external
  evidence; CI is sustained; platform, security, observability, release,
  recovery, concurrency, load, and upgrade gates pass; and no operational output
  is fabricated.

### Ongoing Ledger and Audit Discipline

- [x] Mechanically reject unknown or ledger-mismatched status tags in this TODO;
  keep checkbox completion distinct from capability maturity.
- [x] Separate current evidence from preserved historical milestone claims in
  both active vision documents and reject pre-boundary status drift.
- [ ] Update the capability ledger in the same commit as every material status
  change; never silently promote a claim.
- [ ] Add a stable capability ID when splitting a broad claim; never repurpose an
  existing ID for different behavior.
- [ ] Keep every `verified` entry tied to an executable command and explicit
  evidence boundary.
- [ ] Keep every simulated/scaffolded/missing behavior visible until its
  acceptance gate passes or Volmarr approves removal.
- [ ] Add every newly found missing, incomplete, buggy, unsafe, misleading, or
  refinement-needing function to the reality audit and link it from this TODO.
- [ ] Re-run function census and claim search after every major stage so new
  public declarations and marketing language cannot escape accounting.

### Future After All Core Systems Work and Are Stable (These are immutable until fully won)

- [ ] Crush all bugs and send them to Hel!
- [ ] Make Project A.E.S.I.R. so stable that even Ragnarok could not crash it!
- [ ] Create a roadmap to add back in all previously rejected or removed features, and get every single one of those features to a true working stable state, and then follow that roadmap all the way to Valhalla.
- [ ] Create a roadmap to make Project A.E.S.I.R. the number one best and most popular Local-LLM-Inference-Server on Earth Midgard, and then carry out that roadmap till it turns into manifest reality.
- [ ] Create a roadmap to get all AI harnesses to have support for using Project A.E.S.I.R. and follow that roadmap till it turns into manifest reality!
- [ ] Create a roadmap to get RuneForgeAI so well known that all the Cyber-Viking skalds in all the Nine Worlds are writing poetry to sing its praises! Follow that roadmap till it becomes manifest reality!

- [x] SPD-00/04 explicit strategy3 projection resources: public37/1070 plain/
  profiled vectors/cache/IDs/state match accepted3 exactly. Full4837/120919 kernels
  and recorded resources precede589/7449 ordered ranges and981/20385 projection
  correlations. Down32 selects actual grid24/block256/static19008/register255;
  gate/up/down long3.452520s of6.648634s summed kernels (51.9283%). Ten contracts/
  master190 passes/one skip. No cause/occupancy/spill/service ratio inferred.
  [Operation](docs/NATIVE_TURING_DOWN_PROJECTION_TRACE.md). Next measure narrower
  shared staging as a register/resource experiment, retaining original kernels.

- [x] SPD-01/02 isolated16-column staging: rows64/128 preserve complete1658880
  F32 bits per configuration/2100 independent dots/1622640 guards/840 timings;
  all56 same-capture comparisons lose to original64 (best.946255), no promotion.
  Nineteen contracts/master190/one skip; finite atomic scores now reject per-call
  underflow/ratio overflow with complete metrics retained.
  [Operation](docs/NATIVE_TURING_NARROW_STAGING.md). Next keep proven32-column
  width and measure bounded loop structure.

- [x] SPD-01/02 bounded runtime-group32 staging: both64/128 numerical/bit/guard/
  independent gates pass, all56 original64 comparisons lose (best.826220); no
  promotion.22 portable contracts/master190/one skip.
  [Operation](docs/NATIVE_TURING_LOOP_STAGING.md). Next test paired FFN gate/up
  input staging reuse under independent complete bytes/span/timing gates.

- [x] SPD-01/02 paired FFN gate/up experiment: 983040 complete values per owner,
  original F32 bits, 600 independent dots, 6720 guards, 144 synthetic pairs,
  12 span refusals and all120 rotated timings pass. Batch4 original/pair1.136289
  loses native; batch32 original/pair0.778242 loses staged. No selection.
  Ten contracts/master190/one skip; retained checker-formula failure and new
  exclusive successful revalidation. [Operation](docs/NATIVE_TURING_PAIRED_FFN.md).
  Next isolate causal attention under independent complete math/guard gates.

- [x] **[verified, AES-ACC-010] SPD-03 bounded shared-score causal primitive:**
  39 cases /1370112 complete original F32 bits and independent outputs /364518
  guards/full query and KV input immutability/16 span refusals/all780 rotated
  times pass. Full4/32 improve in one capture; long single queries lose. No
  selection. Nine contracts/master190/one skip, checked fixture33824 stride.
  [Operation](docs/NATIVE_FUSED_CAUSAL_ATTENTION.md).
- [ ] SPD-03 actual model Q/K/V or source-bound full-model exact state/CPU
  quality; generation/replay/controls/context/device/concurrency/soak/runtime
  gates before production selection. Keep original slow-case path.

- [x] SPD-03 optional strategy4 full-model prefill: all513024 values per owner
  retain source3 F32 bits/IDs/full cache; independent CPU/own-repeat/4352 guards/
  eight invalid tiles/32 paired timings pass. Actual fused196/56/196/1008 and
  original queries56/28/84/56 prove selection. Seven contracts/master190/one skip.
  Explicit CLI/binary/source/after-hash gates; controls/tracing/replay4 closed.
  [Operation](docs/NATIVE_FUSED_ATTENTION_MODEL.md).
- [x] SPD-03 strategy4 causal greedy/seeded generation: all96 full frames /
  12312576 values per owner / independent CPU / own UInt32 fresh replay / exact
  source4 initial bits / causal samples/state /4352 guards / actual fused/down/
  original-query counters pass. Eleven contracts/master190/one skip; exclusive
  source CSV/report/binary and current binary before/after hash fences.
  [Operation](docs/NATIVE_FUSED_ATTENTION_DECODE.md). No speed score.
- [x] SPD-03 strategy4 sealed owning-context replay:45-ID checkpoints/eight
  full continuation frames/all four vectors/actual UInt32 bits/CPU/source choices/
  sample/state/4352 guards/28 mutation-free refusals and down/fused/original
  counters pass. Nine contracts/master190/one skip; explicit plan/live/source
  capability/current and accepted decode binary hashes. No speed score.
  [Operation](docs/NATIVE_FUSED_ATTENTION_CHECKPOINT.md).
- [x] SPD-03 strategy4 enabled-control recovery: final default-false capability,
  fresh disabled4 full source4 bits/IDs/cache/CPU/binary gate; healthy synced
  uncommitted/reset-required timeout/cancel/fd aborts, preserved allocations and
  all513024 recovered vectors/9792 guards/actual layer counters/caller mask plus
  observer poison policy pass.15 adversarial contracts/master190/one skip.
  [Operation](docs/NATIVE_FUSED_ATTENTION_CONTROLS.md). No enabled-control speed score.
- [ ] SPD-03 strategy4 owned tracing/control-capable sealed replay and broader context/device/concurrency/soak/runtime/
  refreshed-provider acceptance before production selection.
