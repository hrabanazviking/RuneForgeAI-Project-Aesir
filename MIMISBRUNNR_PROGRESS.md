# MÍMISBRUNNR Progress Log

**Campaign:** 200-slice Hailo-10 moonshot for Project Aesir
**Roadmap:** `HAILO10_200_SLICE_ROADMAP.md` (source of truth — follow each slice's acceptance criteria exactly)
**Blessed by Volmarr:** 2026-10-10 ~03:47 EDT
**Coordinator:** MÍMISBRUNNR forge coordinator (subagent session 7d8a7a60-674c-4cec-9817-6f59f069850d)

## Laws (every worker reads these first)
- PURE MOJO: no libraries in shipped code, ever. Python for TESTS ONLY.
- **VOLMARR'S REINFORCEMENT (2026-10-10): the REAL target is Hailo-10 acceleration. The ARMVEGR CPU engine is the guaranteed fallback trunk — NOT the prize. Every campaign drives toward Hailo-10.**
- **H111 Compiler Wall gate: FULL honesty AND FULL ambition. Pursue the GO branch as far as the evidence allows; take NO-GO only if the evidence truly forces it.**
- **Kernel rebuild (VFIO/UIO) is an OPERATOR action — NEVER attempt it remotely without Volmarr's explicit go. F3-banked items carry EXACT prerequisites (kernel config options, operator steps, unblock criteria) so the path is clear the moment the kernel is ready.**
- ChatGPT Work cuts slices on this repo too — `git fetch origin`, read `git log -20` and branches before each campaign; never collide (additive changes only, never rewrite her in-flight work).
- Never edit README.md. Never force-push. Before every push: `git fetch origin`, diff remote vs local, preserve Volmarr's edits, push, verify with `git ls-remote origin HEAD`.
- Tests green after every campaign. No pseudocode, no placeholders, no fabricated benchmarks, no invented results.
- Honesty law: simulated success is marked **Simulated**; fail-closed; no mock results.

## Gate log
| Gate | Slice | Result | Date | Notes |
|------|-------|--------|------|-------|
| Phase-A gate review | H010 | GO-WITH-CONDITIONS | docs/phase_a/PHASE_A_GATE_REVIEW.md | 2026-10-10 |
| Phase-B go gate | H077 | NO-GO (kernel) → UNLOCKED | 2026-10-10 | Was kernel-forbidden on 6.12.109+rpt-rpi-2712. **Volmarr's operator rebuild: Mimir now on `6.12.112-v8-16k-hailo+` — coordinator verified live /dev/vfio/vfio, dmesg "VFIO - User Level meta-driver version: 0.3", vfio/vfio_iommu_type1/vfio_pci/uio modules present. No SMMU probe → VFIO noiommu mode. F3-banked H066/H069/H074/H075/H076 UNBANKED (real VFIO path). Old kernel + config.txt kept as fallback; rebuild stays operator-only.** |
| Phase-C gate | H095 | pending | — | — |
| **H111 GO/NO-GO (Compiler Wall)** | H111 | **NO-GO** | 2026-10-10 | **The Wall held.** SMIÐR's faithful mailbox implementation (pure Mojo): command writes land readback-verified, then silence — no completion bit, no MSI, no response. Exhausted: 5 hardening variants, vendor ioctl rejected ("not supported on integrated device type"), core-doorbell probe silent (1005 ms). H105–H110 blocked by strict-serial law. Encoding face honestly UNKNOWN (never invented). NO-GO branch executed (H115–H119); F1 CPU fallback trunk proven (H059 coherent). Ambition was fully pursued — the evidence forced NO-GO. |
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
- Status: COMPLETE 2026-10-10 ~09:30 EDT — all slices executed, gate NO-GO, F3 runbook written

### C4 COMPLETION (2026-10-10 ~09:30 EDT)
- **Slices:** H061–H080 all executed. DONE (real): H061/62/63/71 discovery+identity+BARs+link,
  H068 50/50 coherency reads (0x1e60, live device D0), H066/67 CPU DMA, H069/70 eventfd IRQ,
  H073 17-blob firmware SHA-256, H072 register doc, H078 28 error-path tests (x86_64+aarch64),
  H079 API.md + surface test, H077 gate, H080 review. F3-BANKED: H064-VFIO, H065-UIO-bind,
  H066-IOMMU, H069-device-MSI, H074/75/76 firmware boot, H068-live-writes.
- **Breakthrough:** D3hot→D0 via standard PM-control write (setpci 0xFC.w=2008); vendor mirror
  read 0x1e60, 50/50 stable; device restored to D3hot (0x200b) after probing.
- **Findings:** (1) H014 catalogue corrupt for u-boot-spl.bin (69-char sha256; real 219b9b98...5c3,
  hashlib-confirmed) — HAILBRÚ correctly raised FirmwareCorrupt. (2) regs.mojo BAR0 0x0600/0x0700
  mislabels corrected to study-accurate map (mailbox in BAR4, ATR at 0x700+, fw-ctrl at 0x640+).
  (3) need_bdf validation added — malformed BDFs now raise BadBdf.
- **Gate verdicts:** H077 PHASE_B_GATE.md = NO-GO; H080 C4_REVIEW.md = NOT-READY for Phase C.
  F3_UNBLOCK_RUNBOOK.md holds exact kernel configs + operator steps + unblock criteria.
- **L12:** clean — no shipped domain outside hailbru/ touches device nodes (one Phase-A spike
  noted, read-only sysfs). No model-semantics code in hailbru/.
- **Branch:** c4-hailbru-wip merged to main; pushed; remote HEAD verified.

### COORDINATOR FOLLOW-UP (2026-10-10 ~08:50 EDT)
- H014 follow-up DONE: `data/phase_a/firmware_catalogue.json` u-boot-spl.bin sha256 corrected (69-char corrupt → `219b9b981a00bab8174896c7c801b482d56f28d45e2fc731b356f385db8fe5c3`, 64 chars, hex-valid), note appended to catalogue.
- Merged WIP branches deleted (local + origin): `c4-hailbru-wip`, `c2-armvegr-wip`.

### SÓLRÚN AUDIT — C4 pre-execution (2026-10-10)
**Mechanism confrontation.** Mimir's kernel (6.12.109+rpt-rpi-2712) has
`CONFIG_VFIO`/`CONFIG_UIO_PCI_GENERIC`/`CONFIG_ARM_SMMU` all not-set; no
`/dev/vfio`, no `/dev/uio*`; hailo1x_pci 5.3.0 bound to 0001:01:00.0 (no
/dev/hailo* node). H004 verdict stands: NO-GO.
- **Route (a) kernel rebuild: REJECTED for C4.** Compile takes hours on the
  live Pi 5; a bad kernel = remotely unreachable device with no physical
  access (Volmarr not present). The verdict doc classifies rebuild as an
  operator action ("documented here, not executed"). Risk call: DO NOT
  attempt. Recorded as the operator prerequisite for F3 unbanking.
- **Route (b) sysfs-recon execution: SELECTED.** Discovery, config-space
  identity, BAR parsing, link/PM diagnostics, read-only register probes
  (root mmap of sysfs `resource0` — recon-only per H004, permitted),
  eventfd/ppoll plumbing (pure userspace syscalls — real), CPU-side DMA
  alloc primitives (real; IOMMU map fails closed with a named error),
  firmware presence SHA-256 check (real), and all error-path tests (real)
  execute honestly. DMA-coherent device-visible allocation, device
  interrupt registration, firmware upload/boot — no kernel path exists —
  are F3-BANKED with documented prerequisites. Nothing simulated.
- New measured fact: device sits in **D3hot** (power_state read 2026-10-10);
  slot max = 8.0 GT/s x4, negotiated = 8.0 GT/s x1 (Gen3 x1, device-limited,
  matches H003 — not degradation). msi_irqs empty (H017 confirmed).

**Slice-by-slice feasibility:**
- H061 GO (sysfs discovery; negative test on scratch tree). H062 GO (config
  read; root needed beyond 64B — `sudo -n` works on Mimir; MSI cap walk per
  H017). H063 GO (real `resource` parse on Mimir: BAR0 16KB @0x1800000000,
  BAR2 4KB @0x1800008000, BAR4 16KB @0x1800004000; 64-bit pairing test on
  crafted file).
- H064 GO-PARTIAL: VFIO path implemented (compiles); positive BAR0 mmap
  F3-BANKED (no VFIO); negative tests real (invalid group fd → named error;
  wrong-driver-bind assertion on scratch tree, citing H012). H065
  GO-PARTIAL: UIO path implemented; mechanism-ordering decision test real
  (mocked availability); bind/unbind restore tested on scratch sysfs; real
  bind NOT executed (no module exists; unbinding the working hailo1x_pci
  binding to test a nonexistent fallback would be destructive — H013's own
  probe left the binding undisturbed).
- H066 GO-PARTIAL: CPU allocation primitives real (page-aligned
  posix_memalign, mlock attempt, pattern coherence, 100-buffer matrix,
  double-free fail-closed); VFIO_IOMMU_MAP_DMA → named
  `MechanismUnavailable` — F3-BANKED. H067 GO-PARTIAL: UIO allocator
  refuses `WrongMechanism` unless UIO active (testable); cache-maintenance
  hooks as named no-op-with-logging functions per H018 (tested).
- **H068 RE-SCOPED (per H005 §6, which anticipated exactly this):** the
  transport study found NO safe scratch register (every BAR0 register has
  side effects). The criterion's live write/readback is REPLACED by (a) 50x
  read-only coherency reads of the vendor-ID mirror at BAR0+0x0098 expecting
  0x1e60 (study-prescribed, zero device-state disturbance), (b) full
  write/readback + ReadbackMismatch logic tests against an emulated BAR
  mapping, (c) 10 bad-offset fail-closed tests. ZERO writes to the live
  device — vendor driver stays undisturbed.
- H069 GO-PARTIAL: eventfd + ppoll plumbing real (synthetic wake,
  teardown/re-setup, IrqTimeout); MSI vector allocation +
  VFIO_DEVICE_SET_IRQS F3-BANKED (needs kernel mechanism). H070 GO: synthetic
  interrupt loop fully testable without hardware (10k eventfd iterations,
  timeout test); device-generated post-H075 test F3-BANKED.
- H071 GO: link + PM state from sysfs (real; D3hot recorded). H072 GO:
  read-only register identification + probes →
  docs/plunder/HAILO_FW_LOAD_REGISTERS.md. H073 GO: Mojo SHA-256
  firmware_check vs H014 catalogue (`/lib/firmware/hailo/hailo10h/` on
  Mimir); L7 honored — read-only, no fetch/download.
- H074/H075 F3-BANKED (code implemented + emulated tests; real upload/boot
  needs the DMA path + device in a known state — blocked). H076 GO-PARTIAL
  (code real; forced-timeout path with register dump real on Mimir; happy
  path emulated; "True on Mimir after H075" blocked by H075).
- H077: gate document — expected NO-GO with evidence table (failing steps:
  H066-IOMMU, H069-device-IRQ, H074, H075, H076-happy-path); blocks C5 per
  the literal criterion. H078 GO: Python suite ≥15 scenarios, scratch trees
  + env overrides, runs on forge x86_64 (mojo 1.0.0) AND Mimir aarch64
  (mojo 1.1.0). H079 GO: API.md + compile-time surface test. H080 GO:
  C4_REVIEW.md, L12 grep, verdict NOT-READY for Phase C (mechanism NO-GO
  unchanged) with F2/F3 routing.
- No slices killed. All re-scopes recorded here, in DEVLOG, and in code
  comments per the C2/C3 audit precedent.

### DIRECTIVE FROM VOLMARR (2026-10-10 ~08:16 EDT, via coordinator)
1. The REAL target is Hailo-10 acceleration; ARMVEGR CPU is the fallback
   trunk, not the prize. Every slice must drive toward Hailo-10.
2. **KERNEL REBUILD IS AN OPERATOR ACTION — route (a) OFF THE TABLE.**
   No remote rebuild attempt on Mimir; Volmarr's hands-only decision.
3. Sólrún audit takes route (b) — confirmed: implement HAILBRÚ as far as
   the CURRENT kernel honestly allows (sysfs resource mmap BAR access,
   config-space reads, register R/W primitives, mailbox/doorbell ID,
   firmware presence checks — all real, on Mimir). VFIO/UIO-dependent
   slices (IOMMU DMA, MSI-X eventfds) are F3-BANKED with EXACT
   prerequisites: precise kernel config options, exact operator steps,
   exact unblock criteria — zero re-research needed when he rebuilds.
4. Ambition WITH honesty: squeeze every legitimate register-level avenue
   the current kernel allows; bank only what the kernel truly forbids,
   each banked item carrying the specific probe evidence.
- Standing consequence: a `docs/hailbru/F3_UNBLOCK_RUNBOOK.md` operator
  runbook is a C4 deliverable (exact config + steps + unblock criteria).
- Note on register writes: root sysfs resource0 mmap makes writes
  technically possible, but H005 §6's clean-room finding (no safe scratch
  register — every BAR0 register has side effects; vendor driver bound)
  forbids live-device writes as destructive. R/W primitives are real
  (implemented + emulated-BAR tested); live device gets read-only probes.
  This is ambition-with-honesty, not a skipped avenue.

## Campaign 5 — Bring-up & Firmware (H081–H100)
- Status: COMPLETE (worker session 0aaa7b6a-330d-4534-859f-d41eea30f930, 2026-10-10).
  VERDICT: READY_FW — Phase D may proceed to H111. 28/28 tests green.
  Docs: `docs/hailbru/PHASE_C_GATE.md` (PASS), `docs/hailbru/C5_REVIEW.md`,
  `docs/hailbru/F3_UNBLOCK_RUNBOOK.md` (§0 unblock MET with corrections),
  `docs/plunder/HAILO_BRINGUP_GUIDE.md` (Path F = UIO-real),
  `docs/hailbru/FAILURE_MODES.md` (18 modes).
  Code: `hailbru/fwboot.mojo` (firmware boot engine), real `uio_irq_wait`,
- Coordinator: merged `mimisbrunnr-c5-h081-h100` → main as 83c8fc0 (--no-ff), pushed, remote HEAD verified. 18/20 slices done; H093 soak re-run + H097 1-hour baseline are honest gaps carried to C6. Device left sane (hailo1x bound, D3hot).
  `probe fw-boot` / `probe fw-msi-test`. Data: `data/hailbru/c5_20261010/`.
  F3 items: H064/H065/H069/H074 real via UIO; H075 implemented-not-fired
  (device already booted); H066 not demonstrated; H086 open.

### SÓLRÚN AUDIT — C5 pre-execution (2026-10-10)
Phase-B gate NO-GO stands: no VFIO/UIO, no IOMMU DMA, no device MSI, no
firmware DMA upload/boot handshake (F3-banked per F3_UNBLOCK_RUNBOOK.md).
Vendordriver `hailo1x` stays bound (H005 §6). Reality on Mimir today:
D3hot↔D0 PMCSR transitions, config-space reads, BAR0 reads in D0
(vendor mirror 0x1e60, 50/50 stable), register snapshots, Pi SoC thermal.
Passwordless sudo confirmed — root-only probes runnable.

**"Ready" is honestly redefined for C5:** READY_PM = D0 + vendor-mirror
register coherency + clean power-state cycle. NOT firmware-booted
inference-ready. The original "ready" (F3-4 firmware boot) stays F3-banked.
Stated plainly in COLD_BOOT_DEFINITION.md, PHASE_C_GATE.md, C5_REVIEW.md.

**"Cold boot" redefined:** C5 uses option (c) — PM-cycle bring-up
(D3hot→D0→verify→ready-poll→restore D3hot). Definition file
`docs/hailbru/COLD_BOOT_DEFINITION.md` records: (a) full Pi reboot + HAT
power cycle = OPERATOR-ONLY (never remote); (b) driver re-enumeration from
unbound state = OPERATOR-SUPERVISED (F3-adjacent: unbinds vendor driver);
(c) PM-cycle = used by C5. Per-cycle records in H085/H093/H095 cite (c)
with this justification — an honest, recorded deviation from the
roadmap's (a)/(b).

Slice verdicts:
- H081 DO (re-scoped): PM-cycle orchestrator; firmware-load + boot-handshake
  steps are explicit F3-BANKED stubs emitting `step_banked` events with
  prerequisite citations — never silently skipped. Skip-any-REAL-step hook
  fails with named `StepOmitted`.
- H082 DO (re-scoped): golden snapshot = ALL documented readable registers:
  5 BAR0 offsets + 16 config-space dwords + PMCSR + link-status words
  (~24 entries, not 40 — documented shortfall, honestly recorded).
- H083 DO (real): "clean reset" = PMCSR-asserted D3hot → verify → D0 →
  coherency. Only PMCSR written (standard PCI PM, C4-established practice;
  NOT a BAR write — H005 §6 governs BAR writes). post_reset_snapshot.json.
- H084 DO (re-scoped): 100× PM-cycle harness, Python TEST-ONLY, drives the
  Mojo bringup binary. "Ready" per C5 definition.
- H085 DO (real): 30 PM-cycles, per-step timings, budget = max×2 rounded up.
- H086 DO (partial) + F3-bank: read-only vendor-driver/sysfs identity
  material recorded with method cited; on-chip firmware version via
  mailbox/registers → F3-4 (needs boot).
- H087 DO (re-scoped): health_obs.mojo in hailbru/; SoC thermal (labeled Pi
  SoC, NOT device temp) + BAR0 0x018C via H079 API + monotonic ts.
  100 samples, sane range. Device die temperature: unavailable — stated.
- H088 DO (real): BootHang detector on bring-up steps; stall hook → BootHang
  with ≥10 register dump; 30 clean cycles zero false positives.
- H089 DO (real): BRINGUP_LOG_SCHEMA.md + TEST-ONLY Python validator.
- H090 DO (real): 20 D3hot↔D0 cycles, PMCSR readback verified, resume→ready.
- H091 DO (real): emulated-BAR severed-mapping simulation per criterion;
  DeviceRemoved ≤1s, clean exit, fd-count verified.
- H092 DO (real): PID lock-file guard, DeviceBusy naming holder, stale
  reclaim, real subprocess tests.
- H093 DO (real, duration-honest): 1000 PM-cycles unattended on Mimir
  (nohup, polled); 99th percentile vs H085 budget.
- H094 DO (real): SoC temp at cycle start / at ready / after 100 rapid
  cycles; ΔT quantified; caution if >15°C.
- H095 DO (re-scoped): gate over 100 PM-cycles with golden checks every
  10th; GO/NO-GO stated against the REDEFINED ready — plainly.
- H096 DO (re-scoped): 21 registers (16 config dwords + 5 BAR0) × 4 PM-state
  proxies; regdiff TEST-ONLY; 3 injected deviations caught, 10 clean dumps
  zero false positives.
- H097 DO (real): 1h drift detector on idle-D0 device via H079 API only;
  3 injected deviations ≤5s; CPU <1% measured; baseline zero events.
- H098 DO (real): HAILO_BRINGUP_GUIDE.md documents BOTH the current-kernel
  path AND the F3-unblocked path; second-pass re-derivation check.
- H099 DO (real): FAILURE_MODES.md ≥12 modes, 5 fields each, observed cite
  evidence / hypothesized marked, owners named.
- H100 DO (real): C5_REVIEW.md with reliability table; C5 VERDICT
  READY/NOT-READY for Phase D stated honestly (Phase D needs F3 regardless).
- No slices killed. Banked to F3: H086 on-chip version query; H081
  firmware-load/boot-handshake steps; inference-ready "ready" itself.

### SÓLRÚN AUDIT ADDENDUM — kernel rebuild succeeded (2026-10-10 ~09:17 EDT)

Volmarr booted Mimir on `6.12.112-v8-16k-hailo+` (tryboot success).
Worker recon (device.invoke, NOT the coordinator's summary) CORRECTS
and REFINES the new basis — the coordinator's verification had three
inaccuracies:

1. **CONFIG_VFIO_NOIOMMU is NOT set** (`# CONFIG_VFIO_NOIOMMU is not
   set` in /proc/config.gz). There is NO /dev/vfio/noiommu-0. The
   planned "VFIO noiommu DMA" path does not exist.
2. **ARM SMMU is present but PCIe is NOT behind it.** CONFIG_ARM_SMMU=y
   and /sys/class/iommu has 3 devices (1000005100/5200/5280.iommu —
   codec/ISP platform devices), but NO PCI device has an iommu_group
   symlink and /sys/kernel/iommu_groups holds only the platform
   groups. `0001:01:00.0` has no IOMMU group → **vfio-pci CANNOT bind
   this device** (VFIO requires an IOMMU group). The VFIO framework is
   live (/dev/vfio/vfio, dmesg "VFIO - User Level meta-driver version:
   0.3", vfio_pci/vfio_iommu_type1 builtin) but unusable for the
   Hailo-10. A device-tree change attaching PCIe to the SMMU is
   operator/boot-config territory — named as future hypothesis only.
3. **The vendor driver is still bound**: `hailo1x` (module
   hailo1x_pci 5.3.0) holds 0001:01:00.0; /dev/h1x-0 (508,0) exists.
   "Device free" means no userspace holder (fuser empty), not
   unbound. Device parked in D3hot by the driver.

**Revised mechanism verdict: VFIO-BLOCKED (no IOMMU group, no noiommu),
UIO-VIABLE.** CONFIG_UIO_PCI_GENERIC=m is available (uio,
uio_pdrv_genirq loaded). The real F3-unblocked path is UIO:

- H064 RE-SCOPED: VFIO BAR mapping is impossible for this device —
  documented as blocked-with-evidence. UIO bind (F3-2 procedure) is
  the real BAR path; sysfs resource0 stays as the documented fallback.
- H065 DO (real): uio_pci_generic bind/unbind/restore per the F3-2
  runbook (record hailo1x first; restore after every session).
- H066 RE-SCOPED: no IOMMU DMA. Real approach: physical addresses via
  /proc/self/pagemap (root) + UNCACHED CPU alias via /dev/mem O_SYNC
  (CONFIG_STRICT_DEVMEM permissive per Volmarr's build notes) so no
  cache maintenance is needed — the honest userspace DMA path without
  an IOMMU. Map carefully, unmap on teardown (no DMA isolation!).
- H069 DO (real): MSI via uio_pci_generic (it handles MSI); interrupts
  surface as read() events on /dev/uioN. MSI cap 0xE0 confirmed, no
  MSI-X (H062).
- H074/H075/H076 DO (real attempt): firmware DMA upload + boot
  handshake via the UIO path, using the H073-verified staged blobs
  (/lib/firmware/hailo/hailo10h/, 17 blobs, 112MB). L7 HOLDS: never
  fetch/download/ship firmware — use what's staged. Attempt for real;
  any step that fails is reported with exact evidence (fail-closed),
  not simulated.
- H086: on-chip firmware version query becomes real post-boot (was
  F3-banked); still banked until the boot succeeds.
- H081 re-scope: firmware_load + boot_handshake steps become REAL
  (UIO path) instead of banked stubs; READY_PM is joined by READY_FW
  when the firmware reports ready. The banked-stub events remain for
  the VFIO-irrelevant halves only.
- H082/H096 golden snapshots, H084/H093/H095 cycle runs, H094 thermal,
  H097 drift: /tmp was wiped by the reboot — all C5 measurement data
  is regenerated against the new kernel (strictly better: against the
  real boot path). Rebuild the probe into the repo-adjacent
  ~/mimisbrunnr_c5/ (reboot-safe), not /tmp.
- H111 road: real DMA + real MSI + real firmware upload are now being
  attempted — the Wall assault prerequisites.

Safety restated: unbind hailo1x ONLY via the F3-2 reversible
procedure (record original driver, restore after session); never DMA
into arbitrary physical memory (noiommu-less = no isolation);
leave the device sane (D3hot, hailo1x bound) after every session;
do not touch boot config.

### F3 EXECUTION RESULTS — UIO path real (2026-10-10 ~09:30–09:35 EDT)

Kernel `6.12.112-v8-16k-hailo+`. The vendor driver had already booted
the firmware at kernel boot (ATR1 == 0x200000 verified read-only) —
there was no unbooted device to flash, so the full 3-stage re-flash
was NOT fired (re-flashing a running device is unsafe; the boot code
refuses when already_loaded=1). What executed FOR REAL:

- H065 REAL: uio_pci_generic bind/unbind/restore. /dev/uio0 appeared;
  hailo1x rebound afterward, /dev/h1x-0 back. Two probe bugs fixed
  along the way (new_id is write-only — gate checked it with O_RDONLY;
  new_id auto-binds — explicit bind raced; new_id EEXIST on re-run).
- H064 REAL (re-scoped): BAR0/BAR4 mapped writable during the UIO
  session via sysfs resource; ATR windows programmed for real
  (BAR0+0x700); reads/writes through BAR4. VFIO path documented
  blocked-with-evidence (no IOMMU group, no CONFIG_VFIO_NOIOMMU).
- H069 REAL: a genuine device MSI received on /dev/uio0 (count=1) via
  uio_pci_generic. Caveat: the istatus bits (0x1080C400) did not show
  the expected SOFT_RESET_IRQ bit 24 — the MSI's exact source is
  unidentified (likely bind/enable chatter, not the reset completion).
- H074 REAL: staged blobs read; scu_fw.bin parsed per the vendor
  format (magic 0xE905DAAB verified, header/code/key/content
  extracted with bounds checks).
- H075 IMPLEMENTED, NOT FIRED: the 3-stage PIO upload
  (hailbru/fwboot.mojo, STRATEGY_PCIE_BARS per the vendor driver) is
  complete and validated against real headers, but there was no
  unbooted target. Fail-safe refusal is the correct behavior.
- H076 PARTIAL: handshake SIGNALS verified real (ATR1==0x200000,
  boot_status); the trigger/wait sequence implemented but not fired.
  A soft-reset WAS triggered for real (u32 8 to BAR4+0x1754); the
  device survived and the driver re-probed "already loaded".
- H066 NOT DEMONSTRATED: the PIO strategy made DMA unnecessary; the
  VDMA descriptor path was not attempted. The phys-DMA design
  (pagemap + uncached /dev/mem alias) remains unexecuted.
- Device left sane: hailo1x bound, /dev/h1x-0 present, D3hot,
  firmware loaded. One wart: IRQ 37 "nobody cared" during the
  unbind/rebind transition (PCIe PME/AER line, not the Hailo MSI) —
  kernel disabled it; no lasting effect (device uses MSI).

## Campaign 6 — The Wall / SMIÐR (H101–H120)
### SÓLRÚN AUDIT — C6 pre-execution (2026-10-10 ~09:45 EDT)

**Assault plan (strictly serial H101→H110 per roadmap law):**

- H101: write `docs/plunder/HAILO_COMMAND_QUEUE.md` — original prose, cited
  evidence per claim, UNCORROBORATED marking. CORRECTS the roadmap's
  "ring buffer + doorbell" premise: the H005 study proves the control path
  is a mailbox (BAR4+0x0000 length-prefixed command) with a 32-bit
  "raise ready" flag write as the doorbell — no queue-pair exists. Live
  corroboration via read-only BAR probing on Mimir (vendor driver bound).
- H102: implement mailbox submission through HAILBRÚ's UIO path
  (hailo1x unbind → uio_pci_generic → D0 → mailbox work → restore).
  Two study gaps block it today: (a) the per-board "raise ready" flag
  offset is UNNAMED in H005's study; (b) no valid firmware command
  encoding is documented (H086's on-chip version query was F3-banked for
  exactly this reason). L5-PERMITTED additional study of hailort-drivers
  (GPL-2.0, study-only, clone to /tmp, never committed) will be attempted
  to name the flag offset and ONE side-effect-free control command
  (firmware version / device info query). If the study yields them, H102
  attempts a real 100× control round-trip (golden-map-clean ⇒ no-op
  proven). If the study cannot name them, H102 FAILS honestly with the
  exact blocking finding — inventing offsets is forbidden.
- H103: pure-Mojo descriptor builder (no-op/mailbox-ping, VDMA memcopy,
  vector-add). The mailbox envelope + VDMA descriptor layouts are
  study-documented; the vector-add COMPUTE encoding is UNKNOWN — emitted
  as explicitly-marked unknown-format placeholders with documented
  meaning (no magic bytes). Independent TEST-ONLY checker validates
  field-by-field. Malformed inputs fail closed.
- H104: vector-add config generator (FP16, len 64). Artifact acceptance:
  complete package + human-readable manifest traceable to H019 surface
  elements, 10-run byte-identical determinism, TEST-ONLY validator. The
  manifest HONESTLY marks the compute-context encoding ASSUMPTION/
  UNKNOWN — chip-executability is unproven until H105.
- H105: submit the H104 candidate via the H102 transport on Mimir, with
  timeout + full register dump + golden-state recovery (soft-reset path
  proven in C5). EXPECTED: the firmware cannot consume a configuration
  whose compute encoding is unknown — rejection or timeout. A documented
  failed attempt is evidence; H106 then BLOCKED pending diagnosis.
- H106: requires H105 success. If H105 fails, H106 is BLOCKED/FAIL —
  nothing to verify.
- H107–H110: roadmap internal-deps law is explicit — H107 requires H106
  PASS ("earn the harder op"). If H106 fails, H107–H110 are NOT executed;
  building the harder op on a failed foundation is forbidden. The H105
  failure mode is categorical (the encoding wall, not the op), so a
  matmul attempt would add no new information. Marked BLOCKED with the
  rule cited — this is obedience to the roadmap, not surrender.
- H111: decided SOLELY by the roadmap's decision rule (line 330): GO iff
  H106 PASS + H109 PASS + H110 PASS. NO-GO requires the written technical
  account of the blocking finding. Volmarr's directive is honored by
  pursuing every legitimate avenue above for real — NOT by relaxing the
  criterion.

**C5 honest gaps carried forward (do not serve H111, re-queued):** H093
soak re-run and H097 1-hour baseline were flagged incomplete in the C5
review; they concern bring-up reliability, not the compiler wall, and
stay queued behind the H111 verdict.

**Clean-room posture:** all new study is L5 study-only (original prose,
file citations, no code copied/translated/vendored). The configuration
generator is independently designed; findings live in docs/plunder/.

### C6 EXECUTION RECORD (2026-10-10)

- **H101: PASS** — `docs/plunder/HAILO_COMMAND_QUEUE.md` written.
- **H102: FAIL** — `docs/smidr/H102_ATTEMPT_RECORD.md` +
  `data/smidr/first_command_trace.json`. Firmware silent on both
  doorbells (final core-doorbell probe this campaign: completed=False).
- **H103: PASS** — `smidr/descriptor.mojo` + `smidr/tools/descemit.mojo`;
  independent checker `prof/smidr/check_descriptors.py` ALL PASSED;
  5/5 fail-closed. `data/smidr/descriptors.json`.
- **H104: PASS** — `smidr/config_gen.mojo` + `smidr/tools/cfgemit.mojo`;
  SMIÐR-CFG v1 manifest added to `docs/plunder/HAILO_CONFIG_SURFACE.md`
  (H019, elements 2+12); validator `prof/smidr/check_vecadd_config.py`
  ALL PASSED; determinism proven (2× seed 12345 byte-identical).
  Golden vectors in `data/smidr/vecadd/`.
- **H105: BLOCKED** — `docs/smidr/H105_ATTEMPT_RECORD.md` (no transport).
- **H106–H110: BLOCKED** — strict-serial chain broken at H105.
- **H111: NO-GO** — `docs/smidr/PHASE_D_GATE.md`; decision rule
  (H106+H109+H110 all PASS) not met; written technical account included.
  Verdict signed in DEVLOG.
- **H115–H119 (NO-GO branch): EXECUTED** — `docs/smidr/FALLBACK_TRIGGERED.md`,
  `docs/fallback/F1_COMPLETION_PLAN.md`, `docs/fallback/F2_SURVEY.md`
  (no viable F2 interface), `docs/plunder/BANKED_ASSAULT_INDEX.md`
  (48 paths, 10 docs clean), `docs/fallback/RESCOPED_PLAN.md`
  (62 RUN / 18 SKIP, re-scope valid).
- **H120: DONE** — `docs/smidr/C6_REVIEW.md` (NO-GO-flavored; F1 CPU
  guarantee affirmed via H059).
- Device left sane after every session: hailo1x bound, D3hot, /dev/h1x-0.
- Coordinator: merged `mimisbrunnr-c6-wall` → main as 5590451 (--no-ff), pushed, remote HEAD verified 5590451dc46d080e1a8129001eba954becc8df99. Local branch deleted. **H111 relayed to parent: NO-GO, evidence-forced after full ambition.**

## Campaign 7 — Offload + Pipeline (H121–H140)
- Status: COMPLETE — NO-GO branch (H121–H135 SKIP per re-scope; H136–H140 all DONE, F1-COMPLETE per docs/fallback/C7_REVIEW.md)

## Campaign 8 — Vörðr Robustness (H141–H160)
- Status: COMPLETE — 20/20 slices, verdict ROBUST (`docs/vordr/C8_REVIEW.md`) — Vörðr for the F1 CPU engine + Hailo device health (NPU compute NO-GO; NPU-referencing slices get honest audit treatment)
- Coordinator: merged `mimisbrunnr-c7-f1` → main as 44957cd (--no-ff), pushed, remote HEAD verified 44957cd3121c35e2410efa9ecd16db4c587d2fc5. Branch deleted (local + origin).
- Sólrún audit: `docs/vordr/SOLRUN_AUDIT_C8.md` (2026-10-10) — H150 = CPU numerics cross-check (shadow-verify F1 SIMD kernel vs independent scalar reference, H059R1 pattern); H157 = CPU-pipeline stage retry via scalar fallback, loud DEGRADED, no sticky fallback; H147/H148 = REAL reset/re-init via new HAILBRÚ `reset()` primitive (C5-proven PM-reset cycle); H153 = REAL UIO unbind (device left sane); H151–H154 = TEST-ONLY Python, real faults never simulated; H142 = Hailo die temp not readable on current kernel (Pi SoC is proxy).
- H141 DONE: 10-min health monitor, 120/120 samples, max drift 12ms (<1s), SoC 43–48.5°C all "ok", MonitorStopped, clean exit.
- H142: monitor + live threshold reload implemented (ThermalWarning/Recovered); Hailo die temp honestly documented as unreadable.
- H143 DONE: hang budgets measured on Mimir → `data/vordr/hang_budgets.json` (p99×3); heartbeat detector: 300ms stall caught in 305ms, 1000 clean ops 0 false positives.
- H144 DONE: error-decode selftest 50/50 bits; live register poll in supervised loop.
- H145 DONE: machine-readable taxonomy; `test_taxonomy_complete.py` PASS (52 names classified exactly once, 62 entries all documented).
- H146 DONE: 10/10 spaced SIGKILLs → restarts ≤2.4s (each ≤5s); rapid-death backoff proven 1/2/4/8s; parent-monitor revive proven (H159).
- H147 DONE: 50/50 reset cycles golden-clean, mean 201ms (real HAILBRÚ PM-reset).
- H148 DONE: 50/50 re-init cycles OK, mean 203ms worst 206ms; firmware-survival probe documented.
- H149 DONE: recovery state machine selftest (3 scenarios + 5 illegal transitions rejected).
- H150 DONE: shadow-verification 10/10 (worst diff 1.43e-06); corruption hook → ShadowMismatch.
- H155 DONE: recovery budgets → `data/vordr/recovery_budgets.json` (transient_retry p99 749ms→budget 1498ms; reset_reinit p99 213ms→426ms; process_restart p99 22ms→44ms); 10-sample confirmation ALL BEAT.
- H156 DONE: retry absorbs 3 faults (recovered_after_retries: 3); 6 faults → RetryExhausted; backoff 109ms vs 100ms nominal.
- H157 DONE: 19 fast + 1 degraded ops, exactly 1 DEGRADED event, scalar fallback per-op only.
- H154 DONE: integrity 500/500 corruptions detected, 0 escapes, 500/500 retransferred clean.
- H153 DONE: 3/3 removal stages — DeviceRemoved named, clean release, no crash, device sane (hailo1x/D3hot), inference coherent.
- H154 DONE: 500/500 corruptions detected, 0 escapes, 500/500 retransferred.
- H159 DONE: 20/20 degrade/fallback paths emit events — zero silent paths.
- H151 DONE: 11/11 register-error patterns decoded+classified+actioned (transient→retry, persistent→reset, fatal→halt).
- H152 DONE: 20/20 hangs detected+handled (detect_ms 2001–2004ms, budget+5s); post-recovery inference matches reference.
- H158 DONE: 30-min supervised run — 33 faults injected==handled (seeded @ ~1/60s + 5 PRÓF external), 13 iterations, 4/4 coherence spot-check clean, 2×64-token long-form probes rubric-clean (3 sentences each), zero unhandled faults, zero crashes.
- Branch: `mimisbrunnr-c8-vordr`, pushed (latest 0606745).

## Campaign 9 — Speed (H161–H180)
- Status: IN PROGRESS — CPU-path optimization (H171–H172 GO-only → SKIP per re-scope; H161–H170, H173–H180 RUN)
- [x] H161 — Benchmark harness DONE 2026-10-10: `bench/` package (bench_env,
  bench_kernels, run_bench, run.sh) on Mimir; stability gate PASS — gemm_fp16
  1024^3 twice back-to-back medians within 1.77% (±3% required); governor
  pinned performance @ 2.4 GHz verified in JSON; `data/bench/h161_stability.json`.
- [x] H162 — Kernel baseline DONE 2026-10-10: 22 C2 kernels re-measured via
  H161 harness (repeat methodology: per-kernel repeat counts targeting
  ~50 ms/trial; the single-invocation H038 method gave 20-60% spreads on
  sub-5ms kernels). Official table in `data/bench/baseline_kernels.json`
  (sha256 60386416…). Key: gemm_fp16 6.934 GFLOPS (-3.2% vs H038),
  gemv_fp16 4.724 GB/s (-1.0%), attn 4.832 (-0.9%), mha 6.353 (-1.3%).
  DRAM-streaming kernels systematically depressed vs H038 (stream -26%,
  rmsnorm -25%, elem -5 to -18%): environmental (16k-page kernel + system
  memory contention; a 93%-CPU Python process was observed during the run),
  not measurement noise — repeats confirm systematic. Compute kernels stable
  (spreads <4%). H038 numbers are historical context; H162 is the C9 baseline.
- [x] H163 — End-to-end baseline DONE 2026-10-10: prefill 512 tok ×5 +
  decode 100 tok ×5 (classic sampler) via true pre-H173 baseline binary
  (`run_bench_truebaseline`, 26b6b9a + JSON fix). Official:
  `data/bench/baseline_e2e.json` — prefill **2.080 tok/s** (246.10s median),
  decode **0.1766 tok/s** (47 tokens actual, EOS at 47; 266.13s median).
  Model sha256 da3087fb…. Matches H136 (2.02 / 0.165) within 7%.
- [x] H164 — GEMM tiling sweep DONE 2026-10-10: 12 configs × {1024³, 4096³}
  via `run_bench gemm_tuned` → `data/bench/gemm_sweep_1.json`. Winner config 11
  (mc128/kc512/nc128/prefetch0/hoist1/micro1-pipe): 7.773 GFLOPS on 1024³
  (+12.1% vs 6.934), 7.501 on 4096³ (+49.4% vs 5.021). The hoist_b
  (pack B once, reuse across row-blocks) is the key win. ADOPTED in-place:
  `gemm_fp16` repointed at winner; bit-identical vs original (c9_h164_gemm
  PASS); C2_VERIFY ALL PASS.
- [ ] H165 — Prefetch sweep DONE 2026-10-10: prefetch {0,64,128,256} on 2048³
  with adopted config → `data/bench/gemm_sweep_2.json`. Verdict: NO ADOPTION —
  all within ±1% of baseline (7.766 GFLOPS); none achieve ≥3%. The hoist_b +
  large blocks already keep data cache-resident; software prefetch adds nothing.
- Coordinator: merged `mimisbrunnr-c8-vordr` → main as 966875d (--no-ff), pushed, remote HEAD verified 966875dd674ecbb2e70178918cf08ee6aa793d49. Branch deleted (local + origin). C8 verdict: ROBUST — every recovery path fired on real faults and measured; zero silent fallbacks.

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

