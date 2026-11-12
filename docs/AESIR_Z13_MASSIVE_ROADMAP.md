# Project Aesir — Z13 Massive Roadmap (AMD Strix Halo)

**A standalone roadmap for one named hardware target: the ASUS ROG Flow Z13
(GZ302EA) — "purpleraider" — AMD Ryzen AI Max (Strix Halo).**

Commissioned by Volmarr, 2026-11-11. This roadmap is its OWN roadmap for the
AMD hardware type. It does not merge into, rewrite, or supersede the Hailo-10
roadmap or any other Aesir thread; all Hailo material stands exactly as it is.
Nothing in this roadmap claims anything about Hailo hardware. (For the record,
and because honesty is the house rule: text generation on the Hailo chip itself
was never achieved in the Hailo line, and this roadmap neither changes nor
re-litigates that — it is about AMD silicon.)

**Goal, in Volmarr's words:** make the app work *best, fastest, most robust,
most efficient, and most complete* on the new computer and its various hardware.

## The hardware (verified on-device, 2026-11-11)

| Part | Fact |
|---|---|
| CPU | AMD Ryzen AI Max (Strix Halo), Zen 5, 16 cores / 32 threads |
| GPU | Radeon 8060S integrated, RDNA 3.5, **gfx1151**, wavefront 64 |
| NPU | XDNA 2 (Ryzen AI), ~50 TOPS class, `/dev/accel/accel0` present, `amdxdna` driver healthy |
| Memory | 128 GB LPDDR5X **unified** — CPU and GPU share one pool; zero-copy is the prize |
| Storage | 1.8 TB NVMe |
| OS | Kubuntu 26.10, kernel 7.3.0-10-generic, KDE Plasma (Wayland) |
| Kernel devices | `/dev/kfd` present (ROCm compute path exists at kernel level); `/dev/dri` present |
| GPU software found | Mesa RADV Vulkan (`radeon_icd.json` present, `vulkaninfo` installed); **ROCm userland NOT installed** (`/opt/rocm` absent); **XRT userland absent** (driver only) |

## Standing laws for this campaign

1. **Accelerator-first law (Volmarr, 2026-10-27).** Most of a model runs on the
   accelerator. Device order: **NPU → GPU → CPU**. CPU is used only (a) as
   spillover for what exceeds accelerator capacity, or (b) as an assist that
   *measurably, massively* speeds up the whole run. A CPU-carried setup is a
   defect to report with numbers. Thread across all cores without choking other
   running work; thermal awareness and self-throttling before the danger zone.
2. **Server power ruling.** On AC power purpleraider runs full performance,
   always (it is a server). Power saving is a battery-mode concern only.
3. **Raw-oracle discipline (Aesir wave lessons).** Never grade against
   `llama-cli --single-turn` or any template-rendered prompt. Grade with
   teacher-forcing rank + logit gap on the RAW prompt; record the oracle
   backend per row; CPU engine vs CPU comparator only. Near-tie band: rank ≤ 2
   with sub-logit gap = faithful. IQ-family token-exact parity is NOT demanded
   (ggml's own kernels disagree with each other); grade coherence there.
4. **Comparator artifacts are a verdict class.** Template rendering, BOS
   rendering, backend mismatch, and prompt-boundary step-0 effects each fake
   divergences that are in neither engine's maths. Check the comparator before
   suspecting the engine.
5. **Scalar decode is the cost.** In single-row GEMMs the scalar dequant pocket
   dominates. Decode is the lever; prefill batching buys comparatively little.
6. **Accelerator-visible ≠ accelerator-run.** A device being visible (or a
   suite running "with the device present") is not proof kernels ran on it.
   Every accelerator claim needs evidence the work executed on the device
   (timelines, counters, or device-side profiling) and must state the backend
   of record. A run at minimal device memory is a CPU run and is recorded as one.
7. **Trust only disk.** Every number comes from files, git objects, catalogue
   listings, or on-device logs read back — never from a worker's say-so. Model
   files are sha256-pinned before running.
8. **Bank incrementally.** One slice per commit, explicit-refspec push,
   `git ls-remote` verification that the remote moved. Never force-push.
   Never edit or overwrite any README.md.
9. **Never leave a discovered bug unfixed.** Fix it inside the slice's scope,
   or record it as the immediate next work in the campaign state with the
   discovery written down.
10. **No Docker. Ever.** Native installs only (apt, pixi, systemd units).

## Verified baseline (repo state, read from git 2026-11-11)

- Repo `hrabanazviking/RuneForgeAI-Project-Aesir`, `main` @ `d9f88b9a`, 1,020
  tracked files, 269 `.mojo` files. Engine in `aesir_engine/` (Mojo + MAX via
  pixi; `pixi.toml` pins mojo ≥1.0,<2, max ≥26.5,<27).
- Existing strengths to build on (per `CAPABILITY_LEDGER.md` and its evidence
  keys): E-MASTER suite of 250 named cases; a verified real-GGUF CPU path
  (pinned stories260K F16 fixture, E-REAL); a native HTTP server with
  Ollama/OpenAI-compatible routes, streaming, model catalog, conversations,
  crash-atomic state (evidence batteries E-API-CONTRACT, E-NATIVE-STREAM,
  E-COMPAT-STREAM, E-STORE, E-CRASH, E-HF-RESUME and more); a full CUDA path
  (`core/cuda_*.mojo`, Gemma CUDA profile) proven on NVIDIA hardware.
- AMD state today: `aesir_engine/core/amd_gate.mojo` is a **dlopen probe only**
  — it can tell whether `libamdhip64.so`/`libhipblas.so` loads. Its own docs
  state device discovery, HIP allocation, transfers, and kernel launch are
  unsupported. There is no Vulkan compute path and no NPU path. That gap is
  what this roadmap closes.
- Prior planning this roadmap succeeds (for AMD only): the 2026-08-29
  *Real GPU/NPU Execution Gameplan* deliberately proved one narrow CUDA path
  first and deferred AMD generalization. This is that generalization, on named
  hardware, with the wave lessons applied.

## How slices work

- Slices are numbered **A-001 … A-216**, taken **strictly in roadmap order**,
  grouped in **24 waves of 9** — one slice per team (9 teams × 6 Mythic
  Engineering sub-agents). A slice banks only in roadmap order.
- Every slice is a complete vertical slice: inspect → build → test → repair →
  continue (Forge Protocol). Acceptance criteria are testable; evidence lives
  in on-device logs and the campaign's PROJECT_MEMORY_MAP.md.
- Banking (on purpleraider, per slice): full test suite green in the team's
  worktree → merge into `~/aesir-forge` main checkout → `git fetch` +
  remote-diff → push `HEAD:refs/heads/main` → verify with `git ls-remote` →
  update WAVE_PLAN.md + PROJECT_MEMORY_MAP.md. Commit subject: `A-NNN: <title>`.
- Verdict language comes from the Capability Ledger contract
  (`verified / partial / scaffold / simulated / missing`). No slice may claim
  a wider status than its evidence key supports.

---

# Part I — Ground Truth & Bring-Up (Waves 1–3)

*Know the machine exactly, make every runtime honestly present or honestly
absent, and build the unified-memory foundation everything else stands on.*

## Wave 1 — Census and first light (A-001 … A-009)

- **A-001 — Hardware census in `doctor`.** Extend the CLI hardware report to
  enumerate this machine: CPU model/cores, GPU (gfx1151, VRAM = unified pool),
  NPU (XDNA 2 via `/dev/accel/accel0`), memory size/speed, NVMe, kernel, OS.
  *Acceptance:* report output matches the verified facts table above, read
  from sysfs/proc/devices — no hardcoded strings.
- **A-002 — Pixi environment + CPU build on the Z13.** `pixi install` from the
  repo lockfile on purpleraider; build the engine's CPU path with no NVIDIA
  target flags. *Acceptance:* build succeeds; binary `--help` smoke exits 0;
  exact commands + versions recorded in the campaign ledger.
- **A-003 — E-MASTER baseline on Z13 CPU.** Run `aesir_engine/tests/run_all.mojo`
  on purpleraider. *Acceptance:* pass/skip/fail counts read from the log and
  filed as the campaign baseline; every failure triaged to a named cause or a
  named road-slice.
- **A-004 — E-REAL on Z13 CPU.** Run the pinned stories260K F16 fixture
  (sha256 recorded before the run). *Acceptance:* metadata, tokenizer IDs,
  first token, and 32 greedy token IDs match the pinned oracle exactly.
- **A-005 — ROCm userland, natively.** Install ROCm from native packages (no
  Docker); pin the version. *Acceptance:* `rocminfo` reports a gfx1151 agent;
  `libamdhip64.so` loads via the existing AMDGate probe; versions filed.
- **A-006 — Vulkan compute readiness.** Prove the RADV path end to end at the
  system level: device properties, compute queue family, SPIR-V toolchain
  (glslang/spirv-tools) installed and versioned. *Acceptance:* a filed probe
  transcript showing gfx1151 Vulkan device + a compiled trivial SPIR-V module.
- **A-007 — XRT userland bring-up.** Install XRT (native packages/source per
  availability for Kubuntu 26.10 — the other install crew found no safe 26.10
  package; a source build or AMD's official packages are the roads).
  *Acceptance:* `xbutil examine` (or successor tool) reports the XDNA 2
  device — or the blocker is named with evidence and the NPU waves re-plan
  around it honestly.
- **A-008 — Unified-memory semantics probe.** Micro-benchmarks establishing
  what "unified" means here in practice: CPU-written buffers read by GPU
  (HIP managed / host-pinned / Vulkan host-coherent), bandwidth each way,
  page-fault costs. *Acceptance:* numbers table filed from on-device runs;
  the zero-copy design rule for Part I Wave 3 written from those numbers.
- **A-009 — Backend registry skeleton.** Turn `amd_gate` from a probe into a
  typed capability record: per-runtime status (HIP / Vulkan / XRT / CPU) with
  version + device identity, surfaced in `doctor`. *Acceptance:* unit tests
  cover present/absent combinations; `doctor` output on the Z13 shows the
  true state of all four.

## Wave 2 — Runtime gates made real (A-010 … A-018)

- **A-010 — HIP device gate.** FFI through AMDGate: device count, properties
  (name, gfx arch, total memory, wavefront size). *Acceptance:* test asserts
  exactly one gfx1151 device with plausible properties, or honest-absent.
- **A-011 — HIP memory.** `hipMalloc`/`hipFree` + `hipMallocManaged` round
  trips with leak accounting. *Acceptance:* alloc/write/read/free tests pass;
  zero leaked bytes across 1,000 iterations.
- **A-012 — HIP transfer + streams.** Memcpy H2D/D2H and stream sync vs a CPU
  oracle buffer, incl. async overlap smoke. *Acceptance:* byte-exact round
  trips; timing filed.
- **A-013 — Vulkan context wrapper.** Instance/device/queue/command-pool FFI
  wrapper (`libvulkan`) with the repo's error taxonomy on every failure.
  *Acceptance:* context creates on gfx1151; forced-failure tests map to
  taxonomy entries, never to crashes.
- **A-014 — Vulkan buffers.** Buffer allocation with host-visible coherent
  mapping; write/read oracle test. *Acceptance:* byte-exact round trip
  through a mapped buffer; alignment rules documented from the device limits.
- **A-015 — Vulkan compute dispatch smoke.** One trivial SPIR-V kernel
  (vector add) dispatched and read back. *Acceptance:* results byte-exact vs
  CPU oracle at several sizes incl. non-multiples of the workgroup size.
- **A-016 — XRT buffer objects.** XRT BO alloc/map/write/read round trip on
  the NPU device. *Acceptance:* byte-exact round trip, or a named, evidenced
  blocker with the NPU plan adjusted (never a silent skip).
- **A-017 — Device selection policy.** Implement the accelerator-first order
  (NPU → GPU → CPU) as the engine's placement default, with per-op override
  and the reasoning logged. *Acceptance:* policy tests + `doctor` shows the
  effective order on this machine.
- **A-018 — Thermal & power sensing.** Read amdgpu hwmon + CPU power (RAPL)
  into `doctor`/status. *Acceptance:* values track `sensors` output within
  tolerance; the readings feed the later self-throttling slices.

## Wave 3 — Unified-memory architecture (A-019 … A-027)

- **A-019 — Zero-copy allocator.** One allocation type serving CPU and GPU
  behind the existing checked-span discipline, built on A-008's findings.
  *Acceptance:* a buffer written by CPU is read by a Vulkan/HIP kernel with
  no copy call in the path (proven by instrumentation counters).
- **A-020 — Weight residency.** GGUF mmap weights become GPU-visible without a
  duplicate resident copy. *Acceptance:* RSS + device-visible accounting for a
  real fixture shows a single residency; load still passes E-REAL-class checks.
- **A-021 — KV cache in unified memory.** KV layout allocated from the unified
  allocator, usable by both CPU and GPU kernels. *Acceptance:* layout/bounds
  tests + a CPU decode step reads GPU-written KV byte-exactly (and reverse).
- **A-022 — Buffer ownership law.** Ownership/fd rules for every buffer type,
  enforced in code. *Acceptance:* adversarial tests (double-free, use-after-
  hand-off, cross-device misuse) all fail closed.
- **A-023 — Memory budget governor.** A configurable cap keeps the engine from
  starving the desktop/other work on the shared 128 GB. *Acceptance:* under
  synthetic pressure the engine degrades (spills/refuses) instead of OOMing
  the machine; the cap is honoured in measurements.
- **A-024 — Thread placement map.** Zen 5 topology-aware affinity helper for
  CPU work (16 cores/32 threads). *Acceptance:* affinity API + a benchmark
  showing the placed configuration is never worse than unplaced.
- **A-025 — Copy-path verdict.** If any staged copy remains necessary, measure
  pinned-staging vs direct paths. *Acceptance:* numbers filed; the slower
  path removed or justified in the memory design doc.
- **A-026 — Arena/pool allocator for inference.** Per-request arenas with
  reset semantics for activations. *Acceptance:* fragmentation stress test
  (10k mixed alloc/free) passes with bounded waste.
- **A-027 — Part I gate.** Evidence doc + Capability Ledger entries for every
  Part I claim. *Acceptance:* a fresh reader can reproduce every number from
  the filed commands; go/no-go recorded for GPU kernel work.

---

# Part II — Engine Core on the Z13 (Waves 4–6)

*The CPU path becomes the trusted reference oracle on this machine, its known
scalar pockets are fixed, and the loader/format breadth is proven here.*

## Wave 4 — Build & target hygiene (A-028 … A-036)

- **A-028 — Target-flag audit.** Every `sm_89`-style assumption in build
  scripts/tests found and made backend-explicit. *Acceptance:* the fast suite
  builds and runs on the Z13 with zero NVIDIA flags; a build matrix script
  (cpu / amd) exists and passes.
- **A-029 — Mojo GPU target investigation.** Determine, with evidence, what
  Mojo/MAX 26.x can target on gfx1151 (native GPU kernels vs FFI-only).
  *Acceptance:* a decision doc backed by compiled probes; the campaign's
  kernel strategy (Mojo-native, FFI SPIR-V/HIP, or hybrid) is chosen from
  evidence, not preference.
- **A-030 — CPU performance baseline.** Tokens/s (prefill + decode) for the
  pinned fixtures on the Z13 CPU path. *Acceptance:* baseline table filed
  from on-device logs; this is the number every later wave is judged against.
- **A-031 — Loader performance.** GGUF load + tokenizer init timed on NVMe,
  cold and warm cache. *Acceptance:* timings filed; any >2× cold/warm anomaly
  explained.
- **A-032 — Backend config surface.** `auto/cpu/vulkan/hip/npu` selection in
  config + CLI, fail-closed on unavailable requests. *Acceptance:* config
  tests incl. requesting an absent backend = clear named error, never a
  silent CPU fallback presented as the requested backend.
- **A-033 — Structured errors everywhere.** Every backend failure path maps
  to the repo ERROR_TAXONOMY. *Acceptance:* fault-injection tests per backend
  produce taxonomy-coded errors.
- **A-034 — Deterministic replay.** Seeded runs reproduce exactly on the CPU
  path. *Acceptance:* two runs of the standard battery produce identical
  token streams and identical filed hashes.
- **A-035 — Two-tier test gates.** Fast gate (<10 min) and full battery,
  both one-command scripts on the Z13. *Acceptance:* both run green on the
  CPU path; timings filed.
- **A-036 — Phase timing hooks.** Load/prefill/decode/sample timings emitted
  as JSON by the engine. *Acceptance:* a standard run's JSON accounts for
  ≥95% of wall time across phases.

## Wave 5 — CPU decode cost attack (A-037 … A-045)

*The wave lessons say scalar decode is the cost. Prove it here, then remove it.*

- **A-037 — Decode hotspot census.** Profile CPU decode on the Z13; top-5
  kernels by self-time. *Acceptance:* census table filed from profiler logs;
  every later slice in this wave names its census row.
- **A-038 — Wide-SIMD Q8_0 dequant GEMV.** Width-16-class SIMD decode for
  Q8_0 single-row GEMV (the proven S-030 pattern), numerics unchanged.
  *Acceptance:* outputs bit-identical (or within filed tolerance) vs the
  scalar path; decode speed delta measured on the census fixture.
- **A-039 — Wide-SIMD IQ dequant.** Same treatment for the IQ family paths
  present in the engine (IQ1/IQ2/IQ3 variants). *Acceptance:* parity battery
  per format + measured deltas.
- **A-040 — K-quant GEMV audit.** Q4_K/Q5_K/Q6_K single-row paths audited for
  scalar pockets; fixed where found. *Acceptance:* per-format before/after
  timings + parity.
- **A-041 — Thread scaling law.** Decode scaling 1→32 threads measured; the
  choke-guard default (leave headroom for the machine's other work) chosen
  from the curve. *Acceptance:* scaling table filed; default thread policy
  implemented + tested.
- **A-042 — CPU prefill batching audit.** Batched GEMM vs row-by-row on Zen 5
  measured honestly (the lessons say prefill buys less — verify, don't assume).
  *Acceptance:* numbers filed; the better path is the default.
- **A-043 — CPU fused attention.** Current fused attention measured; SIMD/
  layout gaps fixed. *Acceptance:* before/after timings + reference parity.
- **A-044 — Sampling cost proof.** CPU sampling measured per token.
  *Acceptance:* either <1% of token time proven, or the hotspot is fixed and
  re-measured.
- **A-045 — CPU parity battery.** All quant formats × teacher-forcing
  rank/logit-gap vs the pinned oracle set, CPU engine vs CPU comparator.
  *Acceptance:* every row judged (faithful / near-tie / divergence with a
  verdict class); the battery is scripted for reuse by every later backend.

## Wave 6 — Loader & format breadth on the Z13 (A-046 … A-054)

- **A-046 — Quant census.** Every quant type the engine claims, enumerated
  with a load + short-inference smoke on the Z13. *Acceptance:* census table
  with a status per format — no format unaccounted for.
- **A-047 — Precision paths.** F32/F16/BF16 compute paths verified on Z13 CPU
  vs reference values. *Acceptance:* per-precision error bounds filed.
- **A-048 — Architecture load matrix.** Llama/Qwen/Gemma-family fixtures
  present in the repo, loaded + smoked on the Z13. *Acceptance:* matrix
  filed; failures are named with causes.
- **A-049 — Oversized-model streaming.** A model too large for comfortable
  residency runs via mmap streaming on unified memory (fixture: largest
  obtainable, sha-pinned; synthetic oversized fixture acceptable if built
  from real tensors). *Acceptance:* coherent short generation + memory
  accounting showing streaming, not full residency.
- **A-050 — Tokenizer edge battery.** Unicode, emoji, control tokens, empty
  and oversized inputs vs reference outputs. *Acceptance:* battery green or
  divergences filed with verdicts.
- **A-051 — Chat-template goldens.** Per-family template rendering vs golden
  files. *Acceptance:* goldens pass; note the oracle rule — goldens are raw
  renderings kept for template tests only, never as inference-grading inputs.
- **A-052 — Long context on CPU.** 32k-token context run: KV growth,
  correctness spot-checks at depth. *Acceptance:* run completes; depth probes
  (needle-style) pass at filed rates.
- **A-053 — State on Z13 storage.** Conversation autosave + catalog state
  verified on this filesystem. *Acceptance:* the existing crash-recovery
  batteries pass against the Z13 build.
- **A-054 — Part II gate.** The Z13 CPU path is declared the campaign's
  reference oracle. *Acceptance:* Capability Ledger updated with Z13 evidence
  keys; A-030 baseline + A-045 matrix attached; no open Part II bug unfixed
  or unrecorded.

---

# Part III — GPU Compute via Vulkan (Waves 7–9)

*RADV/Vulkan is the first GPU road because it is already on the machine and is
the proven road for gfx1151-class silicon. HIP gets its own fair trial in
Part IV. Every kernel is judged against the Z13 CPU oracle (A-054).*

## Wave 7 — Vulkan kernel foundation (A-055 … A-063)

- **A-055 — SPIR-V build pipeline.** glslang-compiled kernels embedded and
  versioned in-repo, compiled at build time (never fetched at runtime).
  *Acceptance:* pipeline builds all wave kernels from a clean checkout;
  shader hashes recorded.
- **A-056 — Vulkan Q8_0 GEMV.** Dequant + single-row GEMV on GPU.
  *Acceptance:* outputs vs CPU oracle within filed tolerance across shapes;
  device-execution evidence (timeline/counters) filed — law 6.
- **A-057 — Vulkan Q4_K GEMV.** *Acceptance:* same oracle discipline as A-056.
- **A-058 — Vulkan Q6_K + Q5_K GEMV.** *Acceptance:* same oracle discipline.
- **A-059 — Vulkan IQ GEMV.** IQ2_XXS first, then the IQ formats the census
  (A-046) found. *Acceptance:* coherence-grade parity per law 3 (IQ is
  graded on rank/logit-gap + coherence, never token-exactness).
- **A-060 — Vulkan RMSNorm + RoPE.** *Acceptance:* reference parity per op,
  incl. adversarial shapes from the existing compute test patterns.
- **A-061 — Vulkan elementwise + softmax.** SiLU/mul/add/residual and a
  numerically careful softmax. *Acceptance:* reference parity; softmax
  max-subtraction proven on adversarial logits.
- **A-062 — Vulkan decode attention.** Single-query attention over unified
  KV. *Acceptance:* parity vs CPU attention at multiple head counts, head
  dims, and KV lengths incl. GQA ratios used by repo fixtures.
- **A-063 — Vulkan sampling.** Greedy + temperature/top-k sampling on GPU.
  *Acceptance:* greedy token-exact vs CPU greedy on fixtures; temperature
  distribution matches the existing sampling oracle tests.

## Wave 8 — GPU inference integration (A-064 … A-072)

- **A-064 — GPU weight residency.** Fixture weights resident once, in unified
  memory, shared with the CPU path (A-020). *Acceptance:* memory accounting
  shows single residency; repeated runs do not re-upload.
- **A-065 — One full layer on GPU.** A whole transformer layer (norm → attn →
  norm → MLP) composed from Wave 7 kernels. *Acceptance:* layer-output
  parity vs CPU oracle per layer index on a real fixture.
- **A-066 — Full decode loop on GPU (small fixture).** stories260K-class
  model generating entirely on the GPU path. *Acceptance:* greedy output
  token-exact vs the Z13 CPU oracle (A-004 discipline).
- **A-067 — Real-model GPU decode.** A 7–8B-class Q4_K_M fixture (sha-pinned)
  decoding on GPU. *Acceptance:* teacher-forcing rank/logit-gap battery vs
  CPU oracle judged per law 3 + a coherence-graded generation sample filed.
- **A-068 — GPU prefill GEMM.** Batched matrix kernels for prompt processing.
  *Acceptance:* parity vs CPU prefill; prefill tokens/s filed vs A-030.
- **A-069 — Chunked prefill.** Long prompts processed in chunks with KV
  written incrementally on GPU. *Acceptance:* 8k-prompt prefill completes
  with bounded memory; outputs identical to unchunked.
- **A-070 — Lawful CPU assist.** Any CPU participation in the GPU path is
  measured; only assists that massively help survive. *Acceptance:* an
  assist inventory with per-item measurements; unmeasured assists removed.
- **A-071 — Async dispatch.** No per-token host sync stalls: queued
  submissions with timeline profiling. *Acceptance:* timeline trace filed
  showing GPU busy fraction per token; host wait time per token measured.
- **A-072 — Continuous batching v1.** Multiple sequences decoded together on
  GPU. *Acceptance:* 4-sequence run, per-sequence outputs match their
  single-sequence runs (greedy), aggregate tokens/s filed.

## Wave 9 — GPU path hardening (A-073 … A-081)

- **A-073 — Wavefront-64 tuning.** GEMV kernels tuned for gfx1151 wavefront
  size and occupancy. *Acceptance:* before/after bandwidth numbers per
  kernel; no regressions in the parity battery.
- **A-074 — Subgroup reductions.** Subgroup/shuffle reductions in softmax
  and attention where profitable. *Acceptance:* parity + measured deltas;
  unprofitable uses reverted with the numbers kept.
- **A-075 — Accumulation policy.** FP32 vs FP16/BF16 accumulate per kernel,
  chosen by numerics evidence. *Acceptance:* policy table with the logit-gap
  evidence behind each choice.
- **A-076 — GPU memory pressure.** When the unified pool is squeezed, the
  engine spills to CPU paths gracefully. *Acceptance:* pressure test —
  no crash, no corruption, degradation is logged and bounded.
- **A-077 — GPU soak.** One hour of continuous decode on the GPU path.
  *Acceptance:* soak log with memory + thermal traces; zero errors; RSS
  slope ≈ 0.
- **A-078 — GPU fuzz.** Random prompts/shapes/context lengths vs CPU oracle
  sampling. *Acceptance:* fuzz battery green or every divergence verdicted.
- **A-079 — Device-lost recovery.** Injected Vulkan device-lost mid-run.
  *Acceptance:* engine fails over to CPU or fails closed with state intact —
  never hangs, never corrupts the conversation state.
- **A-080 — Equivalence gate.** GPU↔CPU output equivalence scripted into the
  fast battery (A-035). *Acceptance:* gate runs in the fast tier and blocks
  banking on regression (keeper enforces).
- **A-081 — Part III gate.** *Acceptance:* GPU path declared primary for
  decode **only if** it beats the A-030 CPU baseline by ≥2× on the 8B-class
  Q4 fixture decode; otherwise an honest verdict with the blocking causes
  named as new road-slices. Ledger updated either way.

---

# Part IV — HIP Second Road & the NPU (Waves 10–12)

## Wave 10 — HIP/ROCm fair trial (A-082 … A-090)

- **A-082 — HIP Q8_0 GEMV.** Via the A-010–A-012 gate. *Acceptance:* CPU-
  oracle parity + device-execution evidence.
- **A-083 — HIP Q4_K GEMV.** *Acceptance:* same discipline.
- **A-084 — HIP attention + norms.** Minimal set matching A-060/A-062 scope.
  *Acceptance:* parity per op.
- **A-085 — The bake-off.** HIP vs Vulkan on identical kernels and fixtures:
  speed, bandwidth, stability, code health. *Acceptance:* verdict doc with
  numbers; one road declared primary, the other parked with written re-open
  criteria (never silently dropped).
- **A-086 — Winner integration.** The bake-off winner is the registry's
  first-class GPU backend; the loser remains probe-only. *Acceptance:*
  registry + `doctor` reflect the verdict; tests cover both states.
- **A-087 — ROCm install reproducibility.** The A-005 install becomes a
  scripted, pinned, native setup. *Acceptance:* script re-run on the Z13
  converges to the same versions (idempotent).
- **A-088 — HIP zero-copy measurement.** Managed-memory path vs the Vulkan
  residency path (A-064). *Acceptance:* numbers filed; residency design
  updated if HIP's model is better.
- **A-089 — HIP error semantics.** HIP error codes mapped into the taxonomy
  (extends A-033). *Acceptance:* fault-injection tests per mapped code.
- **A-090 — HIP soak or instability verdict.** One-hour decode soak on the
  HIP path if integrated; else the instability evidence is filed as the
  verdict. *Acceptance:* soak log or verdict doc — one of the two, honestly.

## Wave 11 — NPU first light (A-091 … A-099)

*The NPU earns its place by measurement or not at all (accelerator-first law
orders the preference; it does not fake the result).*

- **A-091 — XDNA 2 capability census.** AIE tile count, supported data types
  and ops, memory model — from XRT tooling + AMD documentation, distinguished
  as observed vs documented. *Acceptance:* census doc with the source of
  every claim marked.
- **A-092 — NPU hello-compute.** One real matmul executed on the NPU via the
  chosen stack (XRT with an AIE kernel path, e.g. IRON/mlir-aie or the Ryzen
  AI software stack — chosen by A-007's outcome). *Acceptance:* result vs
  CPU oracle within tolerance + device-execution evidence; "it ran on the
  NPU" is proven, not inferred.
- **A-093 — NPU memory sharing.** dma-buf/BO sharing between NPU and the
  CPU/GPU unified pool probed. *Acceptance:* a buffer produced by one device
  is consumed by another, byte-exact, or the copy cost is measured and filed.
- **A-094 — NPU-shaped ops analysis.** Which engine ops fit the NPU
  (embedding projection, small GEMMs, layernorm-class ops) with size
  thresholds from A-092 measurements. *Acceptance:* candidate table with
  measured crossover points.
- **A-095 — NPU offload #1.** The best A-094 candidate implemented behind
  the registry. *Acceptance:* oracle parity + end-to-end effect measured
  (positive, neutral-with-value, or removed with numbers).
- **A-096 — NPU prefill-assist experiment.** NPU computes a prefill chunk
  while the GPU decodes the previous token. *Acceptance:* overlap benefit
  measured on a mixed workload — or an honest negative verdict filed.
- **A-097 — NPU sampler experiment.** Argmax/sampling assist measured.
  *Acceptance:* verdict with numbers either way (a measured "no" is a
  completed slice; an unmeasured "yes" is not).
- **A-098 — NPU power profile.** Perf-per-watt of the offloaded op on NPU vs
  GPU vs CPU. *Acceptance:* power table from A-018 sensors, filed.
- **A-099 — NPU fallback contract.** Any NPU failure degrades to GPU/CPU:
  silent to the user, loud in the logs. *Acceptance:* fault-injection tests
  prove the degradation path per NPU feature.

## Wave 12 — Heterogeneous scheduling (A-100 … A-108)

- **A-100 — Placement planner.** Per-op device assignment driven by the
  measured cost tables from Parts III–IV, not by hand-waving. *Acceptance:*
  planner decisions on standard fixtures match the measured optima.
- **A-101 — Pipeline overlap.** Prefill (GPU) ∥ sampling prep (CPU) ∥ NPU
  assist where enabled. *Acceptance:* timeline trace showing real overlap;
  end-to-end latency delta filed.
- **A-102 — Spillover policy.** Capacity pressure spills accelerator → CPU
  per the accelerator-first law, in the open. *Acceptance:* oversized-model
  run (A-049 fixture class) places layers per policy with the placement
  logged and reproducible.
- **A-103 — Mid-run device failure re-planning.** A device error during
  generation re-plans remaining work onto survivors. *Acceptance:* injected
  failure drill passes (extends A-079 to the planner level).
- **A-104 — Big-model placement.** The largest sha-pinned fixture that fits
  the 128 GB pool runs with a GPU/CPU layer split. *Acceptance:* coherent
  generation + placement + memory accounting filed.
- **A-105 — Two-model fairness.** Two models served concurrently share
  devices without starvation. *Acceptance:* fairness test with per-model
  latency bounds.
- **A-106 — Scheduler telemetry.** Per-device utilisation + placement
  decisions exposed in status/`doctor`. *Acceptance:* telemetry matches
  external observation (GPU/NPU utilisation tools) within tolerance.
- **A-107 — Placement regression battery.** The planner's decisions on the
  standard fixture set are pinned as tests. *Acceptance:* battery in the
  full tier; decision changes require a numbers-backed slice.
- **A-108 — Part IV gate.** *Acceptance:* placement planner default-on or
  honestly scoped to where it wins; Capability Ledger updated; every
  Part IV experiment has a filed verdict (positive or negative).

---

# Part V — The Correctness Program (Waves 13–15)

*Run under the wave lessons, verbatim: raw-oracle discipline, comparator
artifacts as a verdict class, near-tie band, coherence grading where
token-exactness is not owed. No unexplained rows — every divergence gets a
written verdict class or a named road with re-open criteria.*

## Wave 13 — Oracle infrastructure (A-109 … A-117)

- **A-109 — Teacher-forcing harness v2.** Rank + logit gap computed on RAW
  prompts for every backend from one harness. *Acceptance:* harness
  reproduces the A-045 CPU matrix results; a deliberately template-rendered
  input is detected and rejected by the harness itself.
- **A-110 — Oracle pin registry.** Every matrix row records: model sha256,
  oracle backend, oracle build hash, prompt hash. *Acceptance:* registry
  file in-repo; a row without pins cannot be marked judged.
- **A-111 — Near-tie band, encoded.** Rank ≤2 with sub-logit gap = faithful,
  as a gate rule (not a human judgement call per row). *Acceptance:* gate
  unit tests cover band edges.
- **A-112 — Comparator-artifact checklist, automated.** Template, BOS,
  backend-mismatch, and step-0 boundary checks run before any engine
  divergence is filed. *Acceptance:* seeded fake divergences of each class
  are caught by the checklist and verdicted as comparator artifacts.
- **A-113 — Golden corpus.** Prompts across lengths, languages, code, and
  unicode edge cases with pinned expectations per fixture. *Acceptance:*
  corpus in-repo with hashes; harness consumes it unchanged.
- **A-114 — The full matrix runner.** Quant × architecture × backend, one
  command. *Acceptance:* a full run completes on the Z13 and emits the
  matrix with a verdict per cell.
- **A-115 — Token-exactness policy, encoded.** Per quant family: where
  token-exactness is owed (most GEMV paths), where only coherence is owed
  (IQ family), the gates encode it. *Acceptance:* policy table + gate tests.
- **A-116 — First-divergence localisation.** Tooling that, given a failing
  row, finds the first layer/op where outputs separate. *Acceptance:*
  demonstrated on a seeded divergence; used in anger at least once in
  Wave 14 or the slice re-opens.
- **A-117 — Local gate script.** The whole matrix as one local command (no
  GitHub Actions — house law). *Acceptance:* script + timing filed; keeper
  can run it as the full-tier gate.

## Wave 14 — Architecture breadth (A-118 … A-126)

- **A-118 — Llama-family battery** on all Z13 backends. *Acceptance:* rows
  judged per A-115 policy.
- **A-119 — Qwen-family battery.** *Acceptance:* rows judged.
- **A-120 — Gemma-family battery.** *Acceptance:* rows judged (the existing
  CUDA Gemma work is the comparator reference where relevant — CPU engine vs
  CPU comparator rule still governs grading).
- **A-121 — MoE battery.** Mixture-of-experts fixture (real if obtainable
  sha-pinned; otherwise a synthetic MoE built from real tensors, labelled
  synthetic). *Acceptance:* expert-routing outputs judged; synthetic status
  never hidden.
- **A-122 — Attention variants.** GQA and MLA-style variants parity.
  *Acceptance:* per-variant rows judged.
- **A-123 — Sliding-window attention parity.** *Acceptance:* rows judged at
  window-boundary lengths specifically.
- **A-124 — RoPE scaling parity.** NTK/YaRN-scaled long-context rows.
  *Acceptance:* rows judged at ≥32k context.
- **A-125 — Wrong-tokenizer adversarial.** Mismatched tokenizer/model pairs
  must fail loudly at load. *Acceptance:* adversarial set passes (all
  rejected with named errors, none silently generate).
- **A-126 — Special-token handling.** EOS/BOS/pad behaviour per family
  across backends. *Acceptance:* battery judged; stop-reason correctness
  included.

## Wave 15 — Coherence & quality (A-127 … A-135)

- **A-127 — Coherence grading harness.** Sampled generations scored for
  coherence (the S-095 road pattern) for the quant/backend cells where
  exactness is not owed. *Acceptance:* harness scores filed for the IQ
  matrix; scorer sanity-checked against known-good and known-broken samples.
- **A-128 — Long-generation stability.** 4,000-token generations on the main
  backends without degeneration. *Acceptance:* filed samples + degeneration
  metrics per backend.
- **A-129 — Loop pathology battery.** Repetition traps across samplers;
  guardrails verified. *Acceptance:* battery judged; any pathology gets a
  sampler fix or a named road.
- **A-130 — Long-context drift.** Logit-gap growth vs context depth curve.
  *Acceptance:* curve filed per backend; anomalies verdicted.
- **A-131 — Cross-backend agreement report.** A living doc generated from
  the matrix: where backends agree, where they lawfully differ, where they
  must not. *Acceptance:* report regenerates from matrix data by script.
- **A-132 — Regression sentinel.** Any matrix row changing verdict class
  blocks banking until re-judged. *Acceptance:* sentinel wired into the
  keeper's banking rules + a drill proving it blocks.
- **A-133 — Prompt fuzz.** Random token soups and malformed inputs on all
  backends. *Acceptance:* no crash/hang; bounded, logged behaviour.
- **A-134 — Determinism audit.** Greedy decode bit-stability per backend
  across runs. *Acceptance:* stable, or the nondeterminism source is named
  and bounded (e.g. atomics order) with a verdict.
- **A-135 — Part V gate.** *Acceptance:* the A-114 matrix is fully judged —
  zero unexplained rows; Capability Ledger updated from the matrix.

---

# Part VI — The Performance Program (Waves 16–18)

*Decode is the lever (law 5). Every number from on-device logs; contention-
poisoned measurements are not baselines (a wall measured while the machine
was busy is recorded as contended, or re-measured).*

## Wave 16 — Decode speed (A-136 … A-144)

- **A-136 — GPU decode bottleneck census.** Kernel-level timing table for
  the primary GPU path at 8B-class Q4. *Acceptance:* census filed; every
  later Wave 16 slice names its census row.
- **A-137 — Bandwidth saturation.** GEMV kernels driven toward the practical
  LPDDR5X ceiling. *Acceptance:* achieved % of measured stream bandwidth
  (from A-008) filed per kernel; the gap explained.
- **A-138 — Kernel fusion.** Dequant+GEMV(+norm) fusions where the census
  says profitable. *Acceptance:* per-fusion before/after + parity; losses
  reverted with numbers kept.
- **A-139 — Decode attention optimisation.** KV layout + vectorised loads
  for the decode attention kernel. *Acceptance:* timings at 1k/8k/32k KV
  lengths + parity.
- **A-140 — Sampling ≈ free.** Final sampling fused so its cost is noise.
  *Acceptance:* per-token sampling time measured <1% of token time at 8B.
- **A-141 — Host overhead budget.** Per-token host-side overhead <5% of
  token time at 8B on the GPU path. *Acceptance:* measured breakdown filed;
  overruns fixed or verdicted.
- **A-142 — Small-model floor.** stories260K-class fixture at maximum rate:
  the overhead floor of the whole stack. *Acceptance:* tokens/s + floor
  analysis filed.
- **A-143 — Big-model rate.** Largest fitting fixture (70B-class Q4 if
  obtainable sha-pinned) decode rate on the placement planner. *Acceptance:*
  rate + placement + memory filed; if no such fixture is obtainable, the
  synthetic-largest run is filed and labelled.
- **A-144 — Perf regression gate.** Decode/prefill sentinels with tolerance
  bands in the full tier. *Acceptance:* a seeded 10% slowdown is caught by
  the gate in a drill.

## Wave 17 — Prefill & batching (A-145 … A-153)

- **A-145 — Prefill GEMM efficiency.** Achieved vs theoretical throughput,
  tiling tuned for gfx1151. *Acceptance:* efficiency table per prompt-length
  class.
- **A-146 — Long-prompt prefill.** 32k prompt: time + chunked scheduling
  behaviour. *Acceptance:* completes within the memory governor; time filed
  vs A-068/A-069 baselines.
- **A-147 — Continuous batching v2.** Fair scheduling + preemption for the
  server. *Acceptance:* mixed-load test — interactive request latency stays
  bounded while batch work runs.
- **A-148 — Batched decode.** GEMM-shaped decode for multi-sequence batches.
  *Acceptance:* batch throughput curve 1/2/4/8/16 sequences filed.
- **A-149 — Prefix caching.** Shared prompt prefixes cached across requests.
  *Acceptance:* hit-rate + correctness (cached runs bit-match uncached
  greedy) on a realistic workload.
- **A-150 — Speculative decoding evaluation.** Draft (CPU or NPU) + verify
  (GPU) measured end-to-end. *Acceptance:* shipped if it wins on the
  standard fixtures; an honest negative verdict is an equally complete
  slice.
- **A-151 — 8-bit KV cache.** KV quantisation (the Janas-study line) with
  the full quality battery. *Acceptance:* memory saved + matrix rows
  re-judged under A-115 policy; shipped only if rows hold.
- **A-152 — Bandwidth QoS.** Decode protected while prefill runs (shared
  LPDDR5X is the contended resource). *Acceptance:* contention test —
  decode rate degradation bounded and filed.
- **A-153 — Server throughput battery.** Concurrent clients against the
  HTTP server on the GPU path. *Acceptance:* p50/p95 latency + throughput
  table filed from client-side logs.

## Wave 18 — Efficiency & thermals (A-154 … A-162)

- **A-154 — Perf-per-watt curves.** Per backend, per fixture class, from
  A-018 sensors. *Acceptance:* curves filed; the most efficient backend per
  class named from data.
- **A-155 — Thermal soak + self-throttling.** 30-min sustained decode; the
  engine's own throttle policy engages before any danger zone. *Acceptance:*
  thermal trace filed; policy trigger points verified against sensor logs.
- **A-156 — Quiet mode.** A fan-aware operating point with its measured
  cost. *Acceptance:* dB-proxy (fan RPM) + perf delta filed; mode is opt-in.
- **A-157 — Idle cost.** Engine loaded, zero requests: power draw and wake
  latency. *Acceptance:* both measured; idle draw minimised or verdicted.
- **A-158 — Battery profile.** On DC power: sane caps (AC stays full-power
  per the server ruling). *Acceptance:* profile switches on power-source
  change in a drill; AC behaviour provably unchanged.
- **A-159 — Weight sharing.** Concurrent instances share resident weights.
  *Acceptance:* two instances, one residency in memory accounting.
- **A-160 — Cold-start budget.** Process start → first token, timed and
  attacked. *Acceptance:* budget set from measurement; the top costs fixed
  or filed.
- **A-161 — Load-path choice.** mmap-lazy vs preload per model size, chosen
  by measurement. *Acceptance:* decision table + implementation matches it.
- **A-162 — Part VI gate.** Performance report published to docs/.
  *Acceptance:* every headline number traceable to an on-device log file
  named in the report.

---

# Part VII — Robustness (Waves 19–20)

## Wave 19 — Failure behaviour (A-163 … A-171)

- **A-163 — AMD error taxonomy completion.** HIP/Vulkan/XRT error codes all
  mapped into the repo taxonomy. *Acceptance:* mapping table + a test per
  code class.
- **A-164 — GPU reset recovery.** Simulated GPU hang/reset during decode.
  *Acceptance:* engine recovers on a surviving backend or fails closed with
  conversation state intact; the drill is scripted.
- **A-165 — Corrupt-model battery.** Truncated GGUF, bad magic, hostile
  metadata, lying tensor directories. *Acceptance:* all fail closed with
  named errors; zero crashes (extends the existing header-adversarial line).
- **A-166 — OOM injection.** Allocation failure injected at each site class
  incl. the unified allocator. *Acceptance:* graceful taxonomy errors
  everywhere; no partial-state corruption.
- **A-167 — Signal behaviour.** SIGINT/SIGTERM mid-generation and mid-load.
  *Acceptance:* clean shutdown, state durable, exit codes correct.
- **A-168 — Client abuse.** Slow readers, mid-stream disconnects, oversized
  and malformed requests against the accelerated server (extends the
  E-BACKPRESSURE line). *Acceptance:* server stays responsive for
  well-behaved clients throughout.
- **A-169 — Hostile storage.** Disk-full and read-only model directories
  during catalog/download/state operations. *Acceptance:* named errors,
  no corruption of existing state.
- **A-170 — Kernel watchdog.** A hung accelerator kernel is detected and
  the request/worker recovered or failed closed. *Acceptance:* injected
  hang drill passes; watchdog timings filed.
- **A-171 — State durability on Z13.** The crash-atomicity battery
  (E-CRASH pattern) re-run against accelerated-path state. *Acceptance:*
  battery green on the Z13 build.

## Wave 20 — Endurance (A-172 … A-180)

- **A-172 — 24-hour soak harness.** Scripted long soak with sampled health
  checks (may span days of wall time; the harness, not the calendar, is the
  deliverable — plus its first full run's evidence). *Acceptance:* harness
  + first complete run filed with zero unexplained events.
- **A-173 — Leak hunt.** RSS/device-memory slope over long decode ≈ 0 on
  every backend. *Acceptance:* slope measurements filed; any leak fixed or
  road-sliced with the evidence.
- **A-174 — API fuzz.** Grammar-aware fuzzing of the HTTP surface.
  *Acceptance:* fuzz run filed; crashes/hangs = bugs fixed in-slice or
  road-sliced, never just logged.
- **A-175 — Parser fuzz.** Mutated GGUF fixtures against the loader
  (extends A-165). *Acceptance:* as A-174.
- **A-176 — Race hunt.** Shared-state stress + targeted review of the
  planner/registry concurrency. *Acceptance:* stress suite green across
  100 runs; found races fixed with regression tests.
- **A-177 — Failover drill.** Each backend killed at runtime in turn while
  serving. *Acceptance:* service continues on survivors in every drill;
  client-visible behaviour matches the documented contract.
- **A-178 — State compatibility.** State files written by the campaign's
  first Z13 build open cleanly in the current build. *Acceptance:*
  compatibility test in the full tier.
- **A-179 — Power-cut drills.** `kill -9` at random points ×20 across
  load/generate/save. *Acceptance:* state recoverable in all 20; any
  exception is a bug fixed in-slice.
- **A-180 — Part VII gate.** Robustness evidence doc. *Acceptance:* every
  failure mode exercised has a verdict; the doc names what was NOT tested.

---

# Part VIII — Completeness (Waves 21–22)

*Everything the engine already does on other hardware must do its work here,
on the accelerated paths, with Z13 evidence — and anything still scaffold or
simulated must say so in the ledger, in those words.*

## Wave 21 — Surface parity on the Z13 (A-181 … A-189)

- **A-181 — API contract battery.** E-API-CONTRACT-pattern battery green
  against the Z13-built binary on the GPU path. *Acceptance:* 29-case-class
  battery green; failures verdicted per case.
- **A-182 — Streaming batteries.** Native + compat streaming patterns
  (E-NATIVE-STREAM / E-COMPAT-STREAM) green on the Z13 GPU path.
  *Acceptance:* first-text-before-final, replay determinism, cancellation
  recovery all proven on-device.
- **A-183 — CLI parity.** Every command in `aesir_engine/cli/` exercised on
  the Z13 with smoke evidence. *Acceptance:* per-command checklist filed;
  no command unaccounted for.
- **A-184 — Sampler completeness matrix.** Temperature / top-k / top-p /
  min-p / penalties × backends. *Acceptance:* matrix judged; distribution
  oracles reused from the existing sampling tests.
- **A-185 — Grammar/structured output** on the accelerated path.
  *Acceptance:* grammar-constrained generations valid per their grammars
  on GPU decode.
- **A-186 — Tool-use shapes.** Function-calling request/response shapes via
  the API on the Z13. *Acceptance:* shape battery green; anything beyond
  shapes (actual tool execution) is scoped honestly in the ledger.
- **A-187 — Embeddings.** If the API matrix includes embeddings: run them
  on the best-measured device. *Acceptance:* vectors vs CPU oracle within
  tolerance; if embeddings are absent from the engine, the slice's verdict
  is `missing` recorded in the ledger — a completed slice either way.
- **A-188 — Catalog lifecycle on Z13.** E-STORE / E-CATALOG-LIFECYCLE
  pattern batteries green. *Acceptance:* batteries pass against the Z13
  build incl. concurrent writers.
- **A-189 — Download resilience on Z13.** E-HF-RESUME-pattern battery.
  *Acceptance:* partial/corrupt/race cases all behave per the existing
  contract, on this network and filesystem.

## Wave 22 — Breadth & honesty (A-190 … A-198)

- **A-190 — Template end-to-end.** Chat templates for every supported
  family driven through the real API on the GPU path. *Acceptance:*
  per-family filed transcripts with stop-reason correctness.
- **A-191 — Multimodal honesty pass.** Vision/audio surfaces: either
  working with a real fixture and evidence, or marked `scaffold`/`simulated`/
  `missing` in the ledger in those words. *Acceptance:* ledger rows match
  demonstrated reality — the audit is the deliverable.
- **A-192 — Config completeness.** Every config key documented and
  doctor-verified on the Z13. *Acceptance:* key census — no undocumented
  key, no documented key that does nothing.
- **A-193 — REPL/TUI smoke.** Interactive surfaces run on the Z13 terminal.
  *Acceptance:* scripted smoke transcripts filed.
- **A-194 — Conversation batteries.** Library + autosave pattern batteries
  green on the Z13 accelerated build. *Acceptance:* batteries pass.
- **A-195 — Offline preparation.** E-OFFLINE-pattern workflow on the Z13.
  *Acceptance:* the four-case workflow battery passes.
- **A-196 — Error UX audit.** Every user-facing error on the Z13 paths
  names its cause or its fix. *Acceptance:* audit table; vague errors
  rewritten in-slice.
- **A-197 — Final model breadth.** ≥6 architecture families generating
  coherently on the GPU path. *Acceptance:* the A-114 matrix's breadth rows
  + filed samples.
- **A-198 — Part VIII gate.** Completeness pass over CAPABILITY_LEDGER.
  *Acceptance:* every ledger row re-verdicted with Z13 evidence keys or
  explicitly carried with a named road.

---

# Part IX — Packaging, Docs & Final Proving (Waves 23–24)

## Wave 23 — Ship-shape (A-199 … A-207)

- **A-199 — Fresh-machine install.** The full Z13 setup (system packages,
  ROCm, XRT, pixi env, build) as one native script — no Docker — proven on
  a clean user account on purpleraider. *Acceptance:* script + a from-clean
  run transcript ending in a passing fast gate.
- **A-200 — systemd user service.** The server as a native systemd user
  unit honouring the server power ruling. *Acceptance:* service survives
  logout/reboot drills; power profile verified on AC.
- **A-201 — Dependency drift watch.** ROCm/XRT/Mesa version checks in
  `doctor` against the campaign's pinned expectations. *Acceptance:*
  doctor warns by name on drift; the check is tested by a simulated drift.
- **A-202 — Shipped benchmark tool.** The campaign's headline benchmarks as
  a repo tool anyone can run. *Acceptance:* tool reproduces the A-162
  report's numbers on the Z13 within tolerance.
- **A-203 — Z13 tuning guide.** Kernel parameters, CPU governor, GPU power
  profile — each with its measured delta, in docs/. *Acceptance:* every
  recommendation carries its measurement; unmeasured folklore is excluded.
- **A-204 — Z13 architecture chapter.** Backends, placement, unified memory
  — how it actually works now, in docs/. *Acceptance:* chapter reviewed
  against the code by a fresh reader (another team) with corrections filed.
- **A-205 — Operator runbook.** Start/stop/recover/update for Volmarr, one
  page, plain language first. *Acceptance:* runbook steps executed verbatim
  in a drill.
- **A-206 — Ledger final pass (AMD rows).** Every AMD-backend capability in
  CAPABILITY_LEDGER carries a Z13 evidence key. *Acceptance:* no AMD row
  rests on another machine's evidence.
- **A-207 — Repo hygiene.** Scratch/models/binaries out of git; `.gitignore`
  completed; repo size audited. *Acceptance:* fresh clone size filed and
  materially smaller than the 2026-11-11 working copies; no tracked model
  weights remain unless deliberately pinned as fixtures.

## Wave 24 — Final proving (A-208 … A-216)

- **A-208 — E-MASTER final.** Full suite on the final Z13 build.
  *Acceptance:* counts vs the A-003 baseline — zero unexplained regressions.
- **A-209 — Matrix final.** The A-114 full matrix re-run on the final
  build. *Acceptance:* fully judged, zero unexplained rows.
- **A-210 — Headline numbers final.** Decode / prefill / throughput /
  perf-per-watt re-measured on the final build. *Acceptance:* the numbers
  table with log references, published to docs/.
- **A-211 — Soak final.** The A-172 harness's full run against the final
  build. *Acceptance:* evidence filed; zero unexplained events.
- **A-212 — Cross-hardware honesty appendix.** One page in docs/ stating
  plainly: what this roadmap did (AMD Z13), what it did not do (the Hailo
  line stands untouched, with its own history), and which claims rest on
  which machines' evidence. *Acceptance:* appendix reviewed for any
  sentence that over-claims; over-claims are defects fixed in-slice.
- **A-213 — Fresh-eyes reproduction.** A fresh clone on purpleraider, built
  and batteried from the docs alone by a worker who did not write them.
  *Acceptance:* reproduction transcript; every doc gap found is fixed.
- **A-214 — Release candidate.** Tag + changelog for the Z13 line.
  *Acceptance:* tag pushed and verified by ls-remote; changelog complete
  per banked slice.
- **A-215 — Volmarr's acceptance page.** The exact commands a user runs to
  see it work — install, doctor, run a model on the GPU, run the server —
  all on one page, all verified green in a final drill. *Acceptance:* the
  drill transcript is the page's evidence.
- **A-216 — Closure.** Final report: every one of the 216 slices banked, or
  explicitly carried with a named road and re-open criteria. *Acceptance:*
  report filed in docs/ + the goal workspace; the keeper is stood down by
  Volmarr's word or by this slice's completion note.

---

*End of roadmap. 216 slices, A-001…A-216, 24 waves of 9. Filed 2026-11-11.
Campaign home: purpleraider `~/aesir-forge`; keeper: `aesir-z13-forge-keeper`.*
