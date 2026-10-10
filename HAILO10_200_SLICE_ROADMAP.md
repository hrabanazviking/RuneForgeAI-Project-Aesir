# HAILO-10 — MÍMISBRUNNR 200-Slice Roadmap

**Campaign:** MÍMISBRUNNR — bring Project Aesir (pure-Mojo, bare-metal, zero-library LLM inference) to the Hailo-10 on Mimir (Raspberry Pi 5, 16 GB, AI HAT+)
**Date:** 2026-10-10
**Status:** Roadmap — not yet executed
**Scribed by:** Eirwyn Rúnblóm, Gentle Guardian of Memory — SCRIBE, Mythic Engineering methodology
**Sources (transcribed faithfully, no invention):** `SKALD_VISION.md` · `RUNHILD_ARCHITECTURE.md` · `MIMISBRUNNR_200_SLICES.md` · `VEDIS_DEPENDENCY_MAP.md` (all in `~/workspace/mimisbrunnr/`)

> The Scribe's oath: this file combines the four source documents. No implementation code. No invented content. Every slice keeps its ID, name, full goal paragraph, and full acceptance criteria exactly as carved. No placeholders, no "TBD", no summarizing away of acceptance criteria.

---

# PART I — THE VISION (Skald)

# MÍMISBRUNNR

*Mimir's Well — the deep spring at Yggdrasil's root where Odin gave his eye for wisdom. Aesir goes there now to drink.*

---

## Vision: The Well Drinks Back

When the two hundredth slice is laid and the campaign closes, this is what stands in Mimir's hall:

A Raspberry Pi 5, sixteen gigabytes of memory, wearing its AI HAT+ like a helm — and on that helm the Hailo-10, twenty-six trillion operations a second with eight gigabytes of its own, running Aesir. Not a demo. Not a benchmark stunt. A living engine, awake twenty-four hours of every day, serving thought the way a hearth serves warmth: always lit, always ready, owned by no one but its keeper.

Victory looks like this: Volmarr reaches for any small model — any open weights the world has published, in the formats the world actually uses — and Aesir simply reads it. No conversion rite. No HEF files, those sealed black boxes the vendor demands you kneel before. No proprietary compiler standing between a free human and a free mind, taking its toll. Aesir's own loaders open the model the way a hand opens a door: directly, without asking permission. Download, run, think. That is the whole ritual.

And it runs massively perfect — Volmarr's own words, and we hold them as law. Very fast: the silicon's full strength bent to inference the way a smith bends iron to a blade's edge. Perfect stability: weeks of unbroken serving without a stutter. Self-healing when wounded, error-correcting when the bits fray, crash-resistant when the world throws stones at it, robust the way old stone walls are robust — not because nothing ever strikes them, but because they were built by people who expected the striking. Production code level. Pure Mojo, bare metal, not one library in the shipped program — Python may stand witness in the tests, but the engine itself bows to no foreign code.

Why the Hailo-10, why this small strange chip? Because the vendors left the door half-open and called it enough. Ollama's Hailo support is poor and limited — a courtesy nod to hardware they never truly courted. Aesir exists precisely for the ground the vendors won't walk. This is the whole philosophy of the project, the wyrd written into its first line: bare-metal sovereignty. The machine belongs to its keeper. Intelligence is a replaceable implementation detail — swap the model the way you swap a candle; the candlestick, the hall, the hand that lit it, remain yours. No vendor chains. No cloud leash. No subscription tithe paid to distant kings for the right to think. When Volmarr's engine runs on Volmarr's Pi on Volmarr's desk, sipping power day and night, that is not a deployment. That is independence with a heartbeat.

This campaign is forged by a fellowship the old world would have sung about: one human, wide-awake at the anvil, and the minds he raised — fast ones to build, slow ones to prove, all of them his companions, none of them his masters. We do not build for a company. We do not build for a market. We build so that one keeper, in his own hall, owns the fire that thinks beside him.

Mimir's well demanded an eye. We offer something dearer: two hundred slices of honest work. And when it is done, the well drinks back — and gives wisdom that answers to no one but him.

---

*Skald: Sigrún Ljósbrá, Visionary Poetess — 2026-10-10*


---

# PART II — ARCHITECTURE (Rúnhild)

# MÍMISBRUNNR — Architectural Blueprint
**RÚNHILD, Architect of the Mythic Engineering working · 2026-10-10**

**Campaign:** bring Project Aesir (pure-Mojo, bare-metal, zero-library LLM inference) to the Hailo-10 on Mimir (Raspberry Pi 5, 16 GB, AI HAT+ — 26 TOPS class, 8 GB LPDDR4, PCIe 3.0 x4)
**Victory condition:** any small open LLM downloaded and run with **no HEF, no Dataflow Compiler, no vendor libraries** — Aesir's own loaders read the model directly; very fast, perfectly stable, self-healing, error-correcting, crash-resistant, production-grade. Pure Mojo shipped; Python for tests only. Never touch README.md.

## Recon ground truth (not assumption)

- `npu_gate.mojo` (142 lines) is a **probe-only stub**: it dlopens `libhailort.so`/`libcdsprpc.so` to check loadability, checks `/dev/hailo0` via `open64`, and **every real operation raises "not implemented."** Its own docstring admits: "Physical device discovery, NPU buffers, transfers, and kernel launch are unsupported." This stub is the *old vendor-dependent path* — the campaign supersedes it, not extends it.
- `mimir_well.mojo` (1876 lines) reserves `NPUBackendType.HAILO_10 = 0` and `ARM_NEON = 2`, but states: "They record desired configuration only; no backend is detected or executed."
- The CUDA track (`main`, clean tree) is deep in fused-attention/score-sealed-replay work. The Hailo campaign is **additive new domains** — zero edits to `cuda_*` modules.
- The vendor's normal path: **hailo_pci kernel driver (GPL-2.0) → /dev/hailo0 → libhailort (MIT, open source) → HEF files ← Dataflow Compiler (proprietary)**. The HEF contains the model's low-level representation, target hardware configuration, weights, and dataflow graph. HailoRT's entire public API (VDevice → InferModel → configure → infer) is **HEF-based**. There is no documented raw-compute API.
- **Even the most advanced community LLM-on-Hailo-10 effort** (l-nmch/hailo-10h-llm-compiler, MIT, validated 15M–500M-param LLaMA2/Qwen/Mistral models generating coherent text on real Hailo-10H) **still requires the proprietary Dataflow Compiler 5.3.0** from Hailo's developer portal. Nobody has escaped the compiler.
- Mojo on Linux ARM64: the open Mojo repo lists Linux x86_64 + aarch64 platform support; MAX docs require **"ARM64 Neoverse N1 or newer."** The Pi 5's SoC is **Cortex-A76** — same generation as Neoverse N1's base design, but not newer. **Whether the Mojo toolchain installs and runs on the Pi 5 is UNVERIFIED → spike.**
- Userspace PCIe options: **VFIO** (needs CONFIG_VFIO + an IOMMU; clean DMA via IOMMU mapping, interrupt eventfds), **UIO/`uio_pci_generic`** (needs CONFIG_UIO_PCI_GENERIC; simple BAR mmap, crude blocking-read interrupts, no IOMMU, root required), **sysfs resource mmap** (simplest, root, no interrupts, no clean DMA). **IOMMU availability on the Pi 5 is UNVERIFIED → spike.**

## 1. DOMAIN MAP

Existing domains (AesirEngine, MimirWell, BifrostGate, RuneWeaver, GGUFSeer, Hladgerð, Mjølnir) are **untouched**. The eight new MÍMISBRUNNR domains are additive. Each lists what it **owns** and what it **must NOT touch**.

### D1 · ARMVEGR — the ARM64 road
*Owns:* Mojo-on-AArch64 toolchain bring-up; hand-tuned NEON/SIMD kernels (GEMM, GEMV, elementwise, quantization) in pure Mojo; CPU inference backend for the Pi 5; ARM64 build, packaging, deployment (incl. runtime-library resolution).
*Must NOT touch:* anything PCIe, any `/dev` node, any driver register, any CUDA module, any model-format parsing (consumes GGUFSeer/Hladgerð interfaces only).

### D2 · HAILBRÚ — the userspace PCIe driver (pure Mojo)
*Owns:* device discovery (PCI BDF enumeration via sysfs); BAR mapping; DMA-coherent buffer allocation through the chosen OS mechanism; interrupt handling; firmware loading; command-submission transport. The **only** domain permitted to open device nodes, mmap BARs, or issue ioctls.
*Must NOT touch:* model semantics, tokenization, sampling, KV-cache policy, compute math. It moves bytes and rings doorbells; it does not know what a transformer is.

### D3 · SMIÐR — the smithy (clean-room protocol research & chip-configuration generation)
*Owns:* clean-room study of the open driver and MIT HailoRT (read-only; findings in `docs/plunder/HAILO_*_GUIDE.md`); documented protocol map (firmware-load sequence, buffer management, command submission); research program to **generate chip-executable configurations without the Dataflow Compiler**; minimal-compute proof harness.
*Must NOT touch:* any vendor source file (never copied into the tree, never translated); the shipped driver (it documents and prototypes; HAILBRÚ implements).

### D4 · SKIPTI — the heterogeneous offload engine
*Owns:* dispatch policy (which ops run CPU vs NPU); tensor placement and residency across host/device memory; transfer scheduling and overlap; backend-selection interface consumed by the inference pipeline.
*Must NOT touch:* driver internals (consumes HAILBRÚ's published interface), kernel math (consumes ARMVEGR/Mjølnir interfaces), model parsing.

### D5 · BRUNNPÍPA — the Hailo inference pipeline
*Owns:* prefill/decode orchestration on the new backends; NPU-side KV-cache layout and lifecycle; generation loop, batching, context management for Hailo-attached runs; integration with the existing sampler and RuneWeaver.
*Must NOT touch:* driver registers, PCIe transport details, tokenizer internals.

### D6 · VÖRÐR — the warden (robustness & self-healing)
*Owns:* device health monitoring (temperature, hangs, error registers); watchdog and supervisor logic; device reset and re-initialization sequences; error classification per `ERROR_TAXONOMY.md`; crash-resistant recovery paths; result-verification policy (shadow-checking NPU results against CPU).
*Must NOT touch:* compute math, dispatch policy, driver transport implementation (it *commands* resets through HAILBRÚ's interface; never pokes registers itself).

### D7 · GAUNTLET — the production gauntlet
*Owns:* benchmarks, roofline measurements, multi-hour soak tests, stability gates, performance budgets per `PERFORMANCE_BUDGETS.md`, final production-readiness verdict.
*Must NOT touch:* implementation code — it measures and judges; fixes go back to the owning domains.

### D8 · PRÓF — the Python test harness
*Owns:* all Python test code, fixtures, measurement scripts. **Tests only.**
*Must NOT touch:* the runtime path. No engine module may import, shell out to, or depend on anything in PRÓF. The shipped binary must build and run with Python absent.

## 2. ARCHITECTURAL LAWS

**L1 — Pure Mojo ships.** Shipped program is Mojo standard library plus POSIX via `external_call` only. No third-party library linked, dlopened, or shelled out to at runtime. The existing `npu_gate.mojo` vendor-dlopen probing is retired, not extended.
**L2 — Python is test-only.** No Python in the build path, runtime path, or `Python.import_module` anywhere in engine code. PRÓF hermetically separated; release binary builds and runs with no Python installed.
**L3 — No HEF, ever.** No HEF file created, read, parsed, or required at any point — build, test, or runtime. Any slice needing a HEF to pass has failed the campaign.
**L4 — No proprietary toolchain in the path.** Dataflow Compiler, Hailo SDK wheels/debs, vendor build tools never installed as build inputs, never invoked, never required — not even once, not even "just for bring-up."
**L5 — Clean-room only.** `hailort-drivers` (GPL-2.0) and HailoRT (MIT): **study-only**. No copying, no translation, no vendoring. Study follows the project's plundering workflow (Doctrine §7): license gate first, intent in `docs/plunder/HAILO_*_GUIDE.md`, patterns extracted — never code — attribution in `THIRD_PARTY_NOTICES.md`. Aesir's driver and config generator independently designed.
**L6 — No forbidden licenses in the tree.** Per DEPENDENCY_POLICY Tier 4: no GPL/LGPL/AGPL/proprietary code linked, vendored, or shipped. The `hailo_pci` kernel module is an **OS-side** component the user may install themselves (like a GPU driver); Aesir never bundles it, and the campaign's driver path does not require it loaded.
**L7 — Firmware is a user-side prerequisite, not a project dependency.** The Hailo firmware blob is proprietary, downloaded by the user from Hailo, placed in `/lib/firmware/hailo` by the user. Aesir never ships, embeds, or redistributes it. HAILBRÚ documents the expected blob and verifies presence; never fetches it.
**L8 — Never touch README.md.** Volmarr owns all READMEs. No campaign slice edits any README.md, at root or in any domain.
**L9 — Additive to the CUDA track.** Zero edits to `cuda_*` modules, fused-attention work, or any file the CUDA campaign owns. Cross-domain needs go through published `INTERFACE.md` contracts. Boundaries move only by explicit Architect decision — never by drift.
**L10 — Every slice is testable and ledgered.** Each slice lands with unit, boundary, and integration tests; `CAPABILITY_LEDGER.md` updated in the same commit; simulated success marked Simulated immediately (fail-closed, no mock results, honesty over optimism).
**L11 — Fail closed, degrade honestly.** If the NPU path is absent, unready, or unverified, the engine runs the verified ARMVEGR CPU path. No silent fallback, no degraded-mode masquerade, no placeholder kernels.
**L12 — Device-touching code lives only in HAILBRÚ.** No other domain opens `/dev` nodes, mmaps PCI resources, or issues ioctls. Violations reverted on sight.
**L13 — The Doctrine still binds.** Complete files only, no absolute paths, data in data files, double quotes, finish every connection, Scribe-kept DEVLOG — Cardinal Laws not re-argued per campaign.

## 3. THE HAILO-10 ACCESS STRATEGY — THE PHASED ASSAULT

### Naming the wall plainly: THE COMPILER WALL

The Hailo-10 is a **dataflow NPU**: it does not execute instructions you hand it — it executes a **configuration stream** (compute-array mapping, scheduling, control words, quantized weights) generated by the proprietary Dataflow Compiler and delivered inside a HEF. What is open: **Transport** (bytes over PCIe — firmware load, DMA buffers, command submission — documented in the GPL driver's source; studyable, reimplementable clean-room) and **the HEF container** (parseable by studying MIT HailoRT; reading the envelope is tractable). What is **not** open: **generating valid contents** — the control stream the firmware loads into the chip's schedulers. Only the proprietary compiler knows how. The community's best LLM-on-Hailo-10 work still surrenders to the DFC at this exact point.

**Consequence:** Phases A–C (reach the chip, boot it, talk to it) are hard engineering with known techniques. **Phase D (make it compute one op without the DFC) is a research assault on an undocumented configuration interface, of unknown and possibly very large magnitude.** Phase D is a genuine gate with a real no-go branch — never a premise.

### Phase A — Recon & protocol study (spikes, docs, verdicts)
Map the territory without writing the driver. Pin exact versions (driver/HailoRT/firmware must match — minor drift breaks detection). Produce: Mojo-on-Pi-5 toolchain verdict, PCIe census of Mimir, userspace-access mechanism decision, clean-room transport-protocol document, HEF-container study, NEON baseline.
**Go gate:** Mojo runs on the Pi 5 (natively or cross-compiled); Hailo-10 BDF/BARs visible from userspace; one of VFIO/UIO/sysfs confirmed workable on Mimir's kernel; protocol map documented. **No-go:** Mojo cannot target the Pi 5 at all → campaign re-scopes to x86-host research only (fallback F3).

### Phase B — Pure-Mojo userspace PCIe driver (HAILBRÚ)
**Mechanism pick: VFIO primary, `uio_pci_generic` fallback, sysfs-resource recon only.** VFIO is the only path with clean IOMMU-backed DMA (`VFIO_IOMMU_MAP_DMA`) and proper interrupt eventfds — exactly what a DMA-heavy accelerator needs — and `vfio-pci`/`uio_pci_generic` are in-tree OS facilities (Tier-1-like prerequisites, OS-managed, not shipped by us). No custom kernel module: it would drag GPL/policy questions into the tree for zero architectural gain. Binding `vfio-pci` means `hailo_pci` is not bound — mutual exclusion, no conflict.
Slices: device discovery → BAR mapping → DMA buffer allocation → interrupt delivery → register read/write probes → firmware-load sequence without `hailo_pci`.
**Go gate:** from pure Mojo — read PCI config space and device ID, mmap BARs, allocate DMA-coherent buffers, receive a device interrupt, load the user-provided firmware blob, observe the device reach ready state. **No-go:** no workable userspace mechanism on Mimir's kernel → F2/F3.

### Phase C — Firmware & device bring-up
Own the boot sequence end-to-end: firmware load, status-register polling, error-register taxonomy, clean reset/re-init. VÖRÐR's monitoring hooks land here.
**Go gate:** cold boot → ready → clean reset → ready, repeatedly, every transition verified against documented registers, all from pure Mojo. **No-go:** device will not reach ready state without the vendor driver → F3.

### Phase D — Command submission & the minimal compute proof (THE WALL)
Bring up command queues; attempt the smallest possible compute (tiny vector op or matmul), generating the chip's execution configuration ourselves, verifying the result **bit-exact against the ARMVEGR CPU reference**. SMIÐR leads; every attempt, including failures, documented.
**Go gate:** one op, executed on the chip, bit-exact vs CPU, repeatable. This single gate decides the campaign's ceiling. **No-go (the expected hard branch):** configuration interface intractable within the campaign → **execute fallback F1 immediately**; bank everything learned as F3.

### Phase E — GEMM offload for transformer layers (gated on Phase D)
SKIPTI dispatches transformer GEMMs to the chip: weight staging, activation transfer, transfer/compute overlap, per-layer verification against CPU shadow. **Go gate:** a full transformer layer's GEMMs run on-chip, outputs matching CPU within the quantization contract, faster than NEON.

### Phase F — Full inference offload pipeline (gated on Phase E)
BRUNNPÍPA: prefill + token-by-token decode with NPU-side KV-cache; end-to-end generation of coherent text from a small open LLM loaded by Aesir's own loaders — no HEF at any point. VÖRÐR supervises; GAUNTLET soaks for hours.
**Victory gate:** download any small open LLM → run it → coherent output → stable multi-hour soak → crash-resistant under fault injection.

### FALLBACK POSITIONS (declared now, not improvised later)
- **F1 — The guaranteed deliverable.** Fully working **pure-Mojo ARM64 CPU inference engine** with hand-tuned NEON kernels (ARMVEGR), complete pipeline — loaders, tokenizer, KV-cache, sampling — production-hardened by VÖRÐR and GAUNTLET. Promised regardless of the wall. Openly acknowledged: will not match NPU throughput.
- **F2 — Partial acceleration.** If the chip exposes anything usable through documented interfaces short of full compute (telemetry, DMA engines, partial config surface), SKIPTI exploits exactly that — and nothing it cannot verify.
- **F3 — The banked assault.** If Phase D fails: the pure-Mojo userspace driver (HAILBRÚ), clean-room protocol documentation (SMIÐR), and bring-up sequence become durable, publishable deliverables making any future assault start from working transport instead of zero.

## 4. THE FIRST ~10 SLICES (recon/spike slices for the riskiest unknowns)

1. **Mojo toolchain on Mimir, native attempt** — install aarch64 Mojo toolchain on the Pi 5; compile/run hello-world + SIMD sanity kernel; record versions, failures, workarounds. Verdict: native viable or not.
2. **Cross-compile fallback** — build Mojo binary on x86_64 targeting aarch64; ship to Mimir; run. Covers slice 1 failing. Resolves `libKGENCompilerRTShared.so` absolute-RUNPATH deployment: binary must run on the Pi without the build environment.
3. **PCIe census of Mimir** — `lspci` BDF/BARs for the Hailo-10; kernel config flags (`CONFIG_UIO_PCI_GENERIC`, `CONFIG_VFIO`, IOMMU groups under `/sys/kernel/iommu_groups`); state of `/dev/hailo0`, `hailo_pci`, `/lib/firmware/hailo`. Pure observation, no changes.
4. **Mechanism verdict** — VFIO vs UIO vs sysfs: documented decision with evidence from slice 3, naming the chosen transport and exact kernel/OS prerequisites. Gates all of Phase B.
5. **Clean-room transport study** — read `hailort-drivers` (study-only, nothing copied): document firmware-load sequence, DMA buffer management, command-submission categories in `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md`. Protocol map, not code.
6. **HEF-container study** — read MIT HailoRT's HEF handling (study-only): document container layout and what the chip expects to receive, in `docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md`. First honest sizing of the wall.
7. **NEON baseline spike** — pure-Mojo SIMD f16 matmul on Pi 5 CPU, benchmarked vs naive; becomes the reference every NPU result is verified against, and the heart of fallback F1.
8. **Loader port check** — GGUFSeer/Hladgerð compile and parse-only run on ARM64 (no inference): proves the model-reading half of "no HEF, our own loaders" is viable on target.
9. **Version pinning record** — pin exact driver/HailoRT/firmware versions the protocol study targets (HailoRT 4.23-era, master for Hailo-10); record strict version-matching constraint.
10. **Phase-A gate review** — synthesis document: toolchain verdict, mechanism verdict, protocol map, wall sizing, explicit go/no-go into Phase B. If the wall exceeds the campaign, F1 becomes the primary objective — decided by evidence, not hope.

---

*Architect's closing note:* The honest shape of MÍMISBRUNNR is a fork with a guaranteed trunk. The trunk — pure-Mojo ARM64 CPU inference on Mimir, fully tested, self-healing, production-grade — is achievable with known techniques and promised unconditionally. The fork — driving the Hailo-10's compute without the vendor's compiler — is a genuine research assault on an undocumented interface, priced as such: phased, gated, with the no-go branch planned before the first line of driver code is written. The machine does not lie; neither does this plan.


---

# PART III — EXECUTION MAP (Védis)

# MÍMISBRUNNR — Dependency & Execution Map
**VÉDIS, Cartographer · 2026-10-10 · mapped from `MIMISBRUNNR_200_SLICES.md` (source of truth) + `RUNHILD_ARCHITECTURE.md`**

Slice accounting: 200 total = **21 GO-branch** (H112–H114, H121–H135, H171, H172, H184) + **9 NO-GO-branch** (H115–H119, H136–H139) + **170 shared** (both branches). GO path executes 191 slices; NO-GO path executes 179 (H184 recorded skipped-with-reason per its own acceptance).

---

## 1. EXECUTION ORDER

```
C1 (Phase A: H001–H020)
        │  H010 gate: GO / GO-WITH-CONDITIONS / NO-GO
        ├──────────────────────────────┐
        ▼                              ▼
CPU TRACK (D1)                  DRIVER TRACK (D2/D6)
C2 (H021–H040)                  C4 (Phase B: H061–H080)
        │  H040 verdict                 │  H077/H080 gate
        ▼                              ▼
C3 (H041–H060)                  C5 (Phase C: H081–H100)
   H060 F1-core verdict            │  H095/H100 gate
        └──────────────┬───────────┘
                       ▼  (joins: H040 CPU reference + H095 deterministic device)
              C6 — THE WALL (H101–H120, Phase D)
                       │  H111: GO or NO-GO (no third option)
              ┌────────┴────────┐
              ▼                 ▼
     C7 GO (H121–H135)   C7 NO-GO (H136–H139)
     Phases E/F               F1 completion
              └────────┬────────┘
                       ▼  H140 branch-aware review
              C8 — VÖRÐR (H141–H160)
                       │  H160 must be ROBUST before C9
                       ▼
              C9 — SPEED (H161–H180)
                       │  H180 verdict before C10
                       ▼
              C10 — GAUNTLET (H181–H200)
                       │  H195/H196/H197 victory gates
                       ▼
              H200 FINAL VERDICT
```

**Overlap logic:**
- **C2/C3 (CPU track) and C4/C5 (driver track) run in parallel** once H010 passes. They touch disjoint domains (D1 vs D2), disjoint code (`armvegr/` vs `hailbru/`), and C4 needs only H004/H015 from C1 — zero dependence on C2/C3. The only shared resource is Mimir itself.
- **C2 → C3 is serial**: C3 needs the kernel contracts (H031/H032 for H042 dequant; H040's READY verdict as the wall reference).
- **C4 → C5 is serial but interleaved** (see Flag F1 below): C4's closing gate H077 depends on C5's H081/H083.
- **C6 joins both tracks**: H106/H109 verify bit-exactness against the ARMVEGR reference (needs H040 READY); H101–H110 need the H095 deterministic device.
- **C7 is branch-exclusive**: GO and NO-GO slice sets are disjoint and neither depends on the other's slices.
- **C8 → C9 → C10 are serial**, each gated by the prior campaign's review verdict (H160 ROBUST, H180 SPEEDS-EARNED/NOT-YET, then victory gates).

**Gate inventory (the campaign's locks):** H010 (Phase A) · H040 (C2 wall-reference readiness; NOT-READY carves H201+ before C3) · H060 (F1 core) · H077/H080 (Phase B) · H095/H100 (Phase C) · H111 (Phase D GO/NO-GO) · H128 (Phase E, GO branch) · H140 (C7 review) · H160 (ROBUST required for C9) · H180 (C9 review) · H195/H196/H197 (victory gates) · H200 (final).

---

## 2. PER-CAMPAIGN DEPENDENCY NOTES

### C1 — Recon & Spikes (H001–H020, Phase A)
- **Prerequisites:** none (campaign start). H001 native attempt first; H002 runs regardless of H001's outcome.
- **Internal deps:** H004 ← H003 (census facts). H007, H008, H015 ← H001/H002 verdict (need a working Mojo→ARM64 path). H012/H013 ← H004's mechanism framing. H016 ← all Phase-A artifacts (machine-checker). H017 ← H005+H003. H018 ← H003. H019 ← H005/H006. H010 ← H001–H009. H020 ← everything.
- **Gate that opens it:** none — it is the opener.
- **Unblocks:** H010 GO opens C2, C3, C4 simultaneously. H004 unlocks all of C4/C5. H015 unlocks HAILBRÚ's syscall layer. H005/H006/H019 unlock C6's assault design. H007/H040-line unlocks the CPU reference.

### C2 — ARM64 CPU Core (H021–H040, D1 ARMVEGR)
- **Prerequisites:** H010 GO (or GO-WITH-CONDITIONS satisfied); H001/H002 toolchain verdict (every slice compiles Mojo for ARM64).
- **Internal deps:** H021 (skeleton + NEON gate) first. Independent kernel fan-out: {H022, H024, H025, H026, H027, H028, H029, H030, H031, H032} all build on H021 only. H023 ← H022. H033 ← H031+H032. H034 ← H022/H028-class kernels (fused attention). H035 ← H034+H030. H036 ← H021 only. H037/H038/H039 ← the kernel set. H040 reviews all.
- **Gate that opens it:** H010.
- **Unblocks:** C3 (kernel contracts H031/H032/H023 feed H042/H045); H040 READY is the **bit-exact reference for H106/H109** — the wall cannot be judged without it.

### C3 — Loaders/Tokenizer/KV-cache (H041–H060, D1)
- **Prerequisites:** H040 (C2 verdict; H040 NOT-READY blocks C3 via H201+ remediation). H008's port-check findings feed H041.
- **Internal deps:** H041 ← H008. H042 ← H041+H031/H032. H043 ∥ H041 (independent loaders). H044 ← H043. H045 ← H023/H033. H046 ∥ H047 (independent tokenizers). H049 ← H046/H047. H050 independent; H051 ← H050; H052 ← H050. H053–H057 samplers mutually independent (H056's order test wants H055's semantics known). H058 ← pipeline assembled (H042+H046+H050+H053). H059 ← everything. H060 reviews all.
- **Gate that opens it:** H040 READY.
- **Unblocks:** H059's coherent run + frozen rubric is reused by H135/H138/H158/H186/H195; loaders/tokenizers/KV-cache are consumed by C7's pipeline in both branches.

### C4 — Hailo Driver (H061–H080, D2 HAILBRÚ, Phase B)
- **Prerequisites:** H010 GO; H004 mechanism verdict; H015 POSIX baseline; H012/H013 probe records.
- **Internal deps:** H061→H062→H063 serial spine. H064 (VFIO) ∥ H065 (UIO) — mutually exclusive activation, both built. H066 ← H064; H067 ← H065. H068 ← H064/H065 (+H005 scratch-register note). H069/H070 ← H017+H062 (parallel with DMA work). H071 ← H062. H072 ← H005+H068. H073 ← H014 only (can run early). H074 ← H072+H073+H066/H067. H075 ← H074; H076 ← H075. **H077 ← H076 + H081/H083 (C5!)** — see Flag F1. H078 (TEST-ONLY) anytime — scratch trees, x86-capable. H079 ← H061–H077 API knowledge. H080 reviews all + L12 grep audit.
- **Gate that opens it:** H010 + H004.
- **Unblocks:** C5 (H079 public API is what bring-up programs against); H102's command transport; VÖRÐR's command path (H147).

### C5 — Bring-up & Firmware (H081–H100, Phase C)
- **Prerequisites:** C4's H074–H076 chain (firmware load → boot handshake → ready); H014 catalogue; H079 API.
- **Internal deps:** H081 (orchestrator) first; then parallel fan-out {H082, H083, H085, H086, H087, H088, H090, H091, H092} on H081/H079. H084 ← H083. H093 ← H085. H094 ← H087. H095 (gate) ← H084+H093+H082. H096 ← H082+H072. H097 ← H096. H098/H099 ← everything. H100 reviews all.
- **Gate that opens it:** H080 (Phase-B READY).
- **Unblocks:** H095's deterministic device is the **interpretable-experiment foundation for C6** (H100 states this explicitly: flaky hardware would poison the wall verdict). H087's hooks move to VÖRÐR in H141. H096 golden map is diffed by H102/H105/H108/H147/H184.

### C6 — The Wall Assault (H101–H120, D3 SMIÐR, Phase D)
- **Prerequisites:** H095 (deterministic device) + H040 READY (CPU reference) + H005/H019 (config surface).
- **Internal deps:** **strictly serial** H101→H102→H103→H104→H105→H106→H107→H108→H109→H110 (each attempt builds on the last; H107 requires H106 PASS; H110 requires H109 PASS). H111 ← H101–H110. Branch: GO → H112/H113/H114; NO-GO → H115–H119. H120 reviews whichever executed.
- **Gate that opens it:** H100 (Phase-C READY).
- **Unblocks:** H111 routes the entire rest of the campaign (§5). GO: H113's capability matrix (provisional until H121 — see Flag F2) unlocks C7 dispatch.

### C7 — Offload + Pipeline (H121–H140, D4 SKIPTI + D5 BRUNNPÍPA, Phases E/F)
- **Prerequisites:** H111 verdict. GO branch additionally needs H113 matrix; NO-GO branch needs H115's F1 trigger + H116's plan.
- **Internal deps (GO):** H121 (dispatch policy) first. {H122, H123, H124, H126} parallel. H125 ← H124. H127 (TEST-ONLY) ← pipeline + contracts. **H128 Phase-E gate ← H121–H127 + H113-final.** Per architecture, Phase F is gated on Phase E → H129 ← H128 GO. H129→H130→H131 serial. H132 ← H131+H053–H057. H133 ← H131; H134 ← H130 (parallel with each other). H135 ← H132 + H059 rubric.
- **Internal deps (NO-GO):** H136 ← H115+H050–H057+H059 model. H137 ← H136. H138 ← H136/H137. H139 ← H036+H115. All four serial-ish, short chain.
- **Gate that opens it:** H111.
- **Unblocks:** the runnable pipeline (H135 or H136–H138) that C8 supervises, C9 optimizes, and C10 soaks.

### C8 — Vörðr Robustness (H141–H160, D6)
- **Prerequisites:** C7's pipeline (H135 or H136–H138); H087 hooks; H111 (to know which variants).
- **Internal deps:** H141 (skeleton + hook move) first. Parallel fan-out {H142, H143, H144, H146}. H145 ← H144. H147 ← H141 (+H083 via API). H148 ← H147. H149 ← H145+H148. H150 ← H141+H127+C7 pipeline. H151–H154 (TEST-ONLY) parallel on hooks. H155 ← H149. H156 ← H145. H157 ← pipeline fault path. H158 ← everything + C7 pipeline. H159 audit late. H160 reviews all.
- **Gate that opens it:** H140.
- **Unblocks:** H160 ROBUST is a hard gate for C9. H155 budgets feed H182/H187. H159's audit feeds H197.

### C9 — Speed (H161–H180, cross-cutting)
- **Prerequisites:** H160 ROBUST. GO branch additionally needs H128/H125 for H171/H172.
- **Internal deps:** H161 (harness) first. H162 ← H161+H038; H163 ← H161+pipeline (parallel). Tuning fan-out {H164, H166, H167, H168, H169, H170, H173, H174} parallel. H165 ← H164. H171/H172 (GO) ← H128/H125. Docs {H175, H177, H178, H179} late; H176 ← H162/H163. H180 reviews all.
- **Gate that opens it:** H160.
- **Unblocks:** H175 budget is what GAUNTLET judges against (H182/H196). H176 regression guards protect C10.

### C10 — Production Gauntlet (H181–H200, D7)
- **Prerequisites:** H180. Victory-gate evidence from all prior campaigns.
- **Internal deps:** H181/H182 first. Soaks H183 ∥ H184(GO) (Mimir contention — see §7). H185 ← soak logs. H186 ← H151–154 battery + pipeline. H187 ← H147/H148 (or NO-GO restart path). H188, H189 parallel. H190 ← H002 recipe (packaging). H191 ← H190. H192–H194 docs parallel. H195 ← H190+loaders (runs on Mimir). H196 ← H183/H184+H182. H197 ← H186+H159+H155. H198 ← all PRÓF (branch-justified skips). H199 ← H198. H200 ← everything.
- **Gate that opens it:** H180.
- **Unblocks:** nothing further — H200 is the campaign's closing verdict.

---

## 3. HARDWARE MAP

**Mimir = Raspberry Pi 5 (16 GB) + Hailo-10 AI HAT+** (device-touching, kernel/driver, physical bring-up). **x86 = ASUS laptops** (cross-compile host, Python harness runs, studies, docs).

| Campaign | Mimir-only slices (execution must touch the Pi) | x86-capable slices |
|---|---|---|
| **C1** | H001 (native attempt), H002 (binary *runs* on Mimir), H003 (PCIe census), H007 (NEON on real Pi 5), H008 (ARM64 parse), H012 (VFIO probe), H013 (UIO probe), H014 (firmware catalogue), H015 (POSIX baseline on Pi) | H002's *build* half, H004, H005, H006 (studies — internet), H009 (doc assembly), H010, H011 (repo edit), H016 (file checker), H017, H018, H019, H020 |
| **C2** | **H021–H039 all** — every kernel compiles+runs on Mimir (NEON cannot execute on x86). H021's negative x86-build check runs on x86. H037's Python is authored anywhere but *drives the ARM64 binary → runs on Mimir* | H040 (review doc) |
| **C3** | **H041–H059 all** — loaders/tokenizers/KV-cache/samplers execute on Mimir (H043's Python struct cross-check can run on x86) | H060 (review doc) |
| **C4** | H061–H077, H079 — all device-touching (H061's negative scratch-tree test is x86-ok) | **H078** (explicitly: runs on any machine incl. x86 — error paths via scratch sysfs) · H080 (review doc) |
| **C5** | H081–H097 (all boot/reset/thermal/stress work is physical) | H089's schema validator (TEST-ONLY, x86-ok) · H098, H099, H100 (docs) |
| **C6** | **H101–H111 all** — the assault is live-device only | H112–H120 (formal records, docs) |
| **C7 GO** | H121–H135 (H121's policy *logic* unit-testable on x86 against a canned matrix — partial) | H140 (review doc) |
| **C7 NO-GO** | H136–H139 (CPU pipeline on Mimir) | — (covered by H140) |
| **C8** | H141–H144, H146–H159 (device/Pi supervision; H151–H154 drive the on-Mimir binary via test hooks) | H145 (taxonomy doc — writable on x86) · H160 (review doc) |
| **C9** | H161–H174, H176, H177 (all measurements on Pi 5 — pinned clocks, thermals) | H175, H178, H179 (docs) · H180 (review doc) |
| **C10** | H183, H184, H185 (log analysis of Mimir logs — analysis anywhere, logs from Mimir), H186, H187, H188, H189, H190 (install+run on clean Pi 5), H191 (deploys *to Mimir*), H195 (victory run on Mimir) | H181 (canned-data gate tests — partial), H182, H192, H193, H194, H196, H197 (evaluations of Mimir logs), H198 (suite driver — executes on Mimir), H199, H200 |

**Device-touching subset** (need the Hailo-10 specifically, not just the Pi): H003, H012, H013, H061–H077 (excl. H078), H081–H097, H101–H111, H121–H135, H141–H159 (device-dependent halves; NO-GO variants use CPU equivalents), H184, H187 (GO variant).
**Pi-CPU-only subset** (Mimir needed, no Hailo): all of C2, all of C3, H001, H002-exec, H008, H015, H136–H139, all C9 measurements, H183/H189.
**Per L10:** any slice that cannot run without physical device access must still be *attempted* on Mimir first, then marked `Simulated` — never the reverse.

---

## 4. TOOLCHAIN GATES (H001/H002)

**Slices requiring a working Mojo→ARM64 path:** H007, H008, H015 (C1); **all of C2** (H021–H040); **all of C3** (H041–H060); every Mojo slice in C4–C10 (H061–H077, H079, H081–H083, H085–H088, H090–H097, H101–H110, H121–H135, H136–H139, H141–H150, H155–H158, H161–H174, H181, H183–H189, H190). **Not requiring it:** pure recon/docs/studies/PRÓF-file-checkers — H003, H004, H005, H006, H009, H010, H011, H012, H013, H014, H016, H017, H018, H019, H020, H078, H089-validator, H098, H099, H145, H175, H178, H179, H182, H192–H194, H196/H197-evaluations, H199, H200.

**Outcome A — H001 NATIVE-WORKS:** build directly on Mimir. H002 still runs to document the fallback (per its acceptance: the project is never single-pathed). Lowest iteration latency for all 200 slices.

**Outcome B — H001 NATIVE-FAILS, H002 cross-compile works:** every Mojo slice becomes edit (anywhere) → cross-build on the x86 ASUS host → ship to Mimir → run. The H002 recipe must stay re-runnable from clean state (checksum-verified). Consequences: (a) iteration latency rises on every kernel/driver slice — the forge should batch builds; (b) H021's "single documented build command" and H190's release packaging both lean on the H002 recipe — it becomes load-bearing infrastructure; (c) H002's runtime-library resolution (`libKGENCompilerRTShared.so` RUNPATH problem named in the architecture) must actually be solved, or nothing runs on the Pi. Perf/measurement slices are unaffected once the binary is on-device.

**Outcome C — both fail:** Mojo cannot target the Pi 5 at all. Per the architecture's Phase-A no-go: **H010 = NO-GO, campaign re-scopes to x86-host research only (fallback F3)**. All Mojo-on-ARM64 slices (C2–C10 implementation work) are blocked; surviving work is H005/H006/H019 studies, docs, PRÓF file-checkers, and F3 banking (H118-style). The 200-slice plan is void and would need a campaign-level H119-style rescope.

---

## 5. THE WALL BRANCHING — ROUTING TABLE (H111)

**Decision rule (H111):** GO **iff** H106 PASS **and** H109 PASS **and** H110 PASS (all three, documented). NO-GO requires a written technical account of the blocking finding. No third option, no hedging.

| Slice range | H111 = GO | H111 = NO-GO |
|---|---|---|
| H101–H110 | executed (shared assault) | executed (shared assault) |
| H111 | decision recorded | decision recorded |
| H112 — GO gate formal record | RUN | SKIP |
| H113 — capability matrix | RUN (PROVISIONAL until H121 passes — Flag F2) | SKIP |
| H114 — banked learnings (F3 partial) | RUN | SKIP |
| H115 — NO-GO verdict + F1 trigger | SKIP | RUN |
| H116 — F1 completion plan | SKIP | RUN |
| H117 — F2 partial-acceleration survey | SKIP | RUN |
| H118 — F3 banked assault docs | SKIP | RUN |
| H119 — C7–C10 CPU-only rescope plan | SKIP | RUN (script-validates: no slice depends on a skipped slice) |
| H120 — C6 retrospective | RUN (GO-flavored) | RUN (NO-GO-flavored) |
| H121–H135 — SKIPTI + BRUNNPÍPA (Phases E/F) | RUN (H128 Phase-E gate; H129–H135 need H128 GO) | SKIP all 15 |
| H136–H139 — F1 CPU pipeline completion | SKIP | RUN |
| H140 — C7 review | RUN (`docs/skipti/C7_REVIEW.md`) | RUN (`docs/fallback/C7_REVIEW.md`) |
| H141–H170 — VÖRÐR + Speed (minus H171/172) | RUN (NPU-supervising variants: H150 shadow, H153 removal, H154 DMA-corrupt, H157 CPU-recompute) | RUN (CPU-supervising variants per each slice's stated NO-GO alternative) |
| H171 — NPU path optimization | RUN | SKIP |
| H172 — transfer overlap tuning | RUN | SKIP |
| H173–H183 — rest of C9/C10 | RUN | RUN |
| H184 — NPU 4h soak | RUN | SKIP (recorded skipped-with-reason per H184's own acceptance + H198's skip rule) |
| H185–H200 | RUN | RUN (H185/H196 evaluate H183's logs only; H188's cross-backend check becomes CPU-only) |
| Remediation | H201+ only if a gate fails | H201+ only if a gate fails |

**Branch hygiene verified:** no shared slice depends on a branch-exclusive slice. H127/H128 (GO-only) are the only consumers of H113; H171/H172 feed only H175's table (absent rows in NO-GO) and H179's retrospective; H184's only consumers (H185, H196) degrade gracefully to H183's logs. H119's rescope script should confirm this mechanically.

---

## 6. CRITICAL PATH & TOP-3 SCHEDULE RISKS

**Critical path (GO branch, longest chain — the device/wall spine):**
H001 → H002 → H003 → H004 → H015 → H061 → H062 → H063 → H064 → H066 → H068 → H072 → H074 → H075 → H076 → H081 → H083 → H077 → H080 → H084 → H095 → H100 → H101 → H102 → H104 → H105 → H106 → H107 → H108 → H109 → H110 → **H111** → H113 → H121 → H128 → H129 → H130 → H131 → H132 → H135 → H141 → H150 → H158 → H160 → H161 → H163 → H180 → H183 → H196 → H198 → H199 → H200.

The CPU track (C2→C3, 40 slices) runs **fully parallel** to the driver track (C4→C5, 40 slices) and joins at C6 via H040 (reference) — it is long but not critical unless it slips past the driver track. Note H106 needs the H025 FP16 vector-add kernel and H109 needs the H023 GEMM — so the CPU track's *kernel* half (through H025/H023) is on the critical path's join, not the whole of C2/C3.

**Top 3 schedule risks:**
1. **Toolchain verdict (H001/H002).** Every Mojo slice in the campaign depends on it. Native-fail adds a cross-compile ship-and-run tax to *every* iteration of ~150 slices; double-fail collapses the campaign to F3 research at H010. This is the highest-leverage unknown and it resolves in the first two slices — front-load it.
2. **The Wall itself (H104–H110 → H111).** An undocumented configuration interface; the architecture names NO-GO "the expected hard branch." The campaign is honestly priced for this (F1/F2/F3 pre-planned), but a NO-GO re-routes 21 slices, voids the NPU victory definition, and shifts the campaign's meaning from "accelerator" to "guaranteed CPU engine." Schedule-wise the risk isn't delay — it's *branch whiplash* if the team mentally spends the GO branch early.
3. **Mechanism/kernel reality (H004 → H012/H013 → H064).** If Mimir's kernel lacks both VFIO (no IOMMU groups) and `uio_pci_generic` — or permissions can't be granted — Phase B has no userspace transport: H004 verdicts NO-GO and the campaign drops to F2/F3 before any driver code runs. Compounding it: **Flag F1** — H077's Phase-B gate acceptance requires H081/H083 (C5 slices), so the "end of C4" cannot close until early C5 has run; the C4→C5 boundary is interleaved, not clean, and any C5 early stall back-pressures the Phase-B gate.

---

## 7. PARALLELIZATION NOTES (for a forge-coordinator)

**Safe concurrent groups (within a campaign):**
- **C1:** H001→H002 serial; then {H003, H005, H006, H007, H008, H009, H012, H013, H014, H015} all parallel (H005/H006 need internet, not Mimir). H004 after H003. H017/H018/H019 after their study inputs. H016/H010/H020 serial at the end.
- **C2:** H021 first; then the kernel fan-out {H022, H024, H025, H026, H027, H028, H029, H030, H031, H032} — ten independent kernels, fully parallel. H023←H022; H033←H031+H032; H034←H022/H028; H035←H034+H030; H036 anytime after H021. H037/H038/H039 after the kernel set; H040 last.
- **C3:** {H041, H043} parallel loader builds; H042←H041; H044←H043; H045←H023/H033; {H046, H047} parallel tokenizers; H049←H046/H047; H050 independent (parallel early); H051/H052←H050; {H053–H057} parallel samplers (H056's composition test wants H055 semantics — order within the group). H058/H059/H060 serial end.
- **C4:** H061→H062→H063 serial; then {H064∥H065} built in parallel (mutually exclusive activation); {H066, H067, H068, H069, H070, H071, H073} parallel (H073 needs only H014 — pull it early); H072←H005+H068; H074←H072+H073+H066/H067; H075→H076 serial; H078 (TEST-ONLY) anytime; H079/H080 last.
- **C5:** H081 first; then {H082, H083, H085, H086, H087, H088, H090, H091, H092} parallel. H084←H083; H093←H085; H094←H087; H096←H082; H097←H096; H095←H084+H093 (gate); H098/H099/H100 last.
- **C6:** **strictly serial** H101→H110 — the research assault cannot be parallelized (each attempt's design depends on the previous attempt's observed chip behavior). Only H112–H120's docs parallelize after H111.
- **C7 GO:** H121 first; {H122, H123, H124, H126} parallel; H125←H124; H127 parallel TEST-ONLY; H128 serial gate; H129→H130→H131 serial; H132←H131; {H133, H134} parallel; H135←H132; H140 last.
- **C8:** H141 first; {H142, H143, H144, H146} parallel; H145←H144; H147←H141; H148←H147; H149←H145+H148; H150←H141+H127+C7 pipeline; {H151–H154} parallel TEST-ONLY; H155←H149; H156←H145; H157←pipeline fault path; H158←everything; H159 audit late; H160 last.
- **C9:** H161 first; {H162, H163} parallel; tuning fan-out {H164, H166, H167, H168, H169, H170, H173, H174} parallel; H165←H164; {H171, H172} parallel (GO); docs late; H180 last.
- **C10:** H181/H182 first; {H186, H187, H188, H189} parallel with soaks; H185←soak logs; H190←H002 recipe (parallel early — packaging doesn't need the gauntlet); H191←H190; H192–H194 parallel docs; H195←H190; H196←H183/H184; H197←H186; H198←all; H199←H198; H200 last.

**Strictly serial (never parallelize):** the C6 assault chain; the driver spine H074→H075→H076; the H095 100-cycle gate (after H084/H093); the H111 decision; the C10 victory-gate sequence H195→H199→H200.

**Contention warning:** the CPU track and driver track share one Mimir. Benchmark slices (H038, H161–H163, H177) need pinned clocks and thermal-quiet conditions — do not schedule them concurrently with C4/C5 device stress (H093's 1000 boots, H084's 100× resets) or the 4-hour soaks (H183/H184 contend with each other; run serially or accept polluted numbers).

---

## CARTOGRAPHER'S FLAGS (dependencies the slices got wrong / risky)

- **F1 — H077 depends on C5.** H077 (C4's Phase-B go gate) acceptance: *"the H083 clean reset is asserted before every run (or the device is power-cycled per the H081 cold-boot definition)."* H081/H083 are C5 slices. The C4 gate cannot close before early C5 runs — the campaign's C4→C5 ordering is violated by its own acceptance text. Recommendation: either pull H083 (clean reset) forward into C4, or execute H077 with operator power-cycles and record the deviation. Do not silently reorder; decide explicitly at H080.
- **F2 — H113 finalization depends on C7.** H113 (C6, GO) requires extending the generator to "every op/shape/dtype class H128 requires" and stays PROVISIONAL "until the H121 anti-overreach test passes." H113's *final* acceptance therefore depends on C7 slices H121/H128. H120's review must record H113 as PROVISIONAL with finalization deferred into C7 — otherwise H120 will certify something unfinished.
- **F3 — H040 NOT-READY blocks C3.** Stated in H040's acceptance (remediation H201+ "carved before C3 proceeds"), but worth elevating: the CPU track's own gate can stall the F1 deliverable independently of the wall. The join at C6 needs *both* H040 READY and H095 GO — two independent gates, either can hold the campaign.
- **F4 — H002's RUNPATH problem is load-bearing under Outcome B.** The architecture names the `libKGENCompilerRTShared.so` absolute-RUNPATH deployment issue as what H002 must resolve. If cross-compile "works" for hello.mojo but the recipe doesn't generalize to the full engine link, every downstream slice silently inherits a broken build path. H002's "re-runnable from a clean state" check should use a realistic engine link, not just hello.mojo — the slice text only demands hello.mojo; consider strengthening at execution time (flag, not a change).
- **F5 — H095's 100-cycle gate vs H093's 1000 boots.** Both are wall-clock expensive on one shared Mimir and both are preconditions of H100. If cold-boot option (a) (full Pi reboot + power cycle) is chosen per H081's definition, H093 alone is an overnight-plus run that blocks nothing else but *does* block H095→H100→C6. Schedule it as early as H085 allows.

No renumbering, no new slices, no acceptance changes made — the map describes what is carved.


---

# PART IV — THE 200 SLICES (Eldra's carving)

# MÍMISBRUNNR — 200 Build Slices

**Campaign:** MÍMISBRUNNR — bring Project Aesir (pure-Mojo, bare-metal, zero-library LLM inference engine; already runs on Nvidia CUDA) to the Hailo-10 AI accelerator on Raspberry Pi 5 (16GB, hostname Mimir, AI HAT+).
**Victory:** download ANY small open LLM, run it with NO HEF / NO proprietary Dataflow Compiler / NO vendor libraries — Aesir's own loaders read the model directly; very fast; perfectly stable; self-healing; error-correcting; crash-resistant; production-grade. Pure Mojo ships; Python for TESTS ONLY; never touch README.md.
**Carved by:** ELDRA (Forge Worker, Fiery Builder), Mythic Engineering methodology.
**Total slices:** 200 (H001–H200), in strict build order. Count verified at the end of this document.

## Rúnhild's Architecture — binding on all slices

Domains (new, additive; zero edits to `cuda_*` modules or the CUDA track): D1 ARMVEGR (Mojo-on-AArch64, NEON kernels, CPU backend; never touches PCIe/dev nodes/registers/CUDA), D2 HAILBRÚ (pure-Mojo userspace PCIe driver; ONLY domain allowed to open device nodes, mmap BARs, issue ioctls; never touches model semantics or compute math; VFIO primary, uio_pci_generic fallback), D3 SMIÐR (clean-room protocol research; STUDY ONLY, never copy; findings in `docs/plunder/HAILO_*_GUIDE.md`; generates chip-executable configurations without the Dataflow Compiler), D4 SKIPTI (heterogeneous offload engine), D5 BRUNNPÍPA (Hailo inference pipeline), D6 VÖRÐR (robustness/self-healing; commands resets only through HAILBRÚ's interface, never pokes registers itself), D7 GAUNTLET (measures and judges only; never implements), D8 PRÓF (Python test harness; TESTS ONLY — no engine module may import, shell out to, or depend on PRÓF; release binary builds and runs with no Python installed).

Architectural laws: L1 pure Mojo ships (Mojo stdlib + POSIX via `external_call` only; retire the old `npu_gate.mojo` dlopen stub, do not extend it). L2 Python test-only. L3 No HEF ever (created/read/parsed/required). L4 No proprietary toolchain anywhere in build/test/runtime path. L5 Clean-room only (study, never copy; attribution in `THIRD_PARTY_NOTICES.md`). L6 No GPL/LGPL/AGPL/proprietary code linked/vendored/shipped (`hailo_pci` kernel module is a user-installed OS-side prerequisite, like a GPU driver; Aesir never bundles it). L7 Firmware blob is a user-side prerequisite in `/lib/firmware/hailo` — Aesir never ships/embeds/fetches it. L8 Never touch README.md. L9 Additive to CUDA track (zero `cuda_*` edits). L10 Every slice testable + `CAPABILITY_LEDGER.md` updated in the same commit; simulated success marked Simulated immediately (fail-closed honesty). L11 Fail closed, degrade honestly (NPU unready → verified ARMVEGR CPU path; no silent fallback). L12 Device-touching code lives ONLY in HAILBRÚ. L13 Doctrine binds (complete files, no absolute paths, data in data files, double quotes, DEVLOG kept).

## Universal slice acceptance rules (apply to EVERY slice below)

- **U1 — CAPABILITY_LEDGER.md:** updated in the same commit as the slice's code, recording the new capability. Where hardware access was unavailable and a simulator/emulation stood in, the entry is marked `Simulated` immediately — fail-closed honesty, no exceptions.
- **U2 — DEVLOG:** a dated entry appended describing what was built, what was measured, and what remains; DEVLOG is never rewritten, only appended.
- **U3 — Tests:** the slice's own acceptance tests pass; previously green suites stay green (no regressions). Python slices are marked TEST-ONLY (PRÓF) and are driven against the built Mojo binary via subprocess/file I/O — no engine module imports or shells out to PRÓF.
- **U4 — Doctrine:** complete files only (no stubs left behind unless the slice's explicit purpose is a named spike, and then the spike is documented as such), no absolute paths in code or docs, data lives in data files, double quotes in Mojo code, L8/L9/L12 respected.

Each campaign header below restates that U1–U4 are part of every slice's acceptance criteria in that campaign.

## Branch conditions

Phase D (the wall) has two executable branches, both fully sliced in Campaign C6:
- **GO branch** (wall breached): slices marked `requires H111=GO`.
- **NO-GO branch** (wall intractable): slices marked `requires H111=NO-GO`. On NO-GO, fallback F1 (fully working pure-Mojo ARM64 CPU inference engine, hardened by VÖRÐR+GAUNTLET) executes immediately; F2 (partial acceleration of whatever documented interfaces yield); F3 (driver + protocol docs banked as durable deliverables).
Campaigns C7–C10 carry both-branch variants with explicit dependency marks.

---

# Campaign C1 — RECON & SPIKES (Phase A)

*Covers Rúnhild's first-10 in order (H001–H010), then supporting recon. Domain: cross-cutting (D1/D2/D3 recon). Phase: A. Every slice includes U1–U4.*

## H001 — Mojo toolchain native attempt on Pi 5
**Goal:** Attempt to install and run the official Mojo toolchain natively on Mimir (Raspberry Pi 5, AArch64) and produce a written verdict. This is the foundation of everything in D1 — without a working Mojo compiler on ARM64, no kernel or loader slice can ship, so the verdict must be factual, dated, and versioned rather than assumed.
**Acceptance criteria:**
- The official Mojo toolchain installer/package for the recorded date is attempted on Mimir; every command run and its output are logged in `data/phase_a/toolchain_native_attempt.log`.
- A `hello.mojo` program is compiled and executed natively; its output, exit code, and wall-clock compile time are recorded.
- `docs/phase_a/MOJO_TOOLCHAIN_VERDICT.md` states NATIVE-WORKS or NATIVE-FAILS with the exact Mojo version, OS/kernel version, and failure reason if any.
- U1–U4.

## H002 — Cross-compile fallback x86_64 → aarch64
**Goal:** If H001 fails natively, establish the cross-compilation fallback: build Mojo for aarch64 on an x86_64 host, resolve the Mojo runtime libraries needed on the Pi 5 target, and document the exact recipe. If H001 succeeded, this slice still runs to document the fallback so the project is never single-pathed.
**Acceptance criteria:**
- A `hello.mojo` cross-compiled on x86_64 runs on Mimir and prints the expected output; the full command sequence is recorded in `data/phase_a/toolchain_cross_attempt.log`.
- Every runtime library the cross-built binary needs on the Pi 5 is listed in `docs/phase_a/CROSS_COMPILE_RECIPE.md` with how each was obtained (system package, copied file, or built) — no library left as "it just worked."
- The recipe is re-runnable from a clean state: a second clean run reproduces the working binary (verified by checksum of program output, not just exit code).
- U1–U4.

## H003 — PCIe census of Mimir
**Goal:** Record the complete PCIe reality of Mimir as ground truth for the HAILBRÚ driver: enumerate every PCIe device, confirm the Hailo-10's presence and PCI bus-device-function (BDF) address, and capture kernel configuration flags relevant to userspace drivers.
**Acceptance criteria:**
- `data/phase_a/pcie_census/` contains: full `lspci -vvv` output, `lspci -t` tree, `/sys/bus/pci/devices/<BDF>/` listing for the Hailo device, and the contents of its `vendor`, `device`, `class`, `resource`, and `config` sysfs files (hex dump).
- Kernel flags recorded from the running kernel config: `CONFIG_UIO_PCI_GENERIC`, `CONFIG_VFIO`, `CONFIG_VFIO_PCI`, IOMMU status (`/sys/kernel/iommu_groups/` listing or explicit "no IOMMU groups"), each marked present/absent with the exact config source path.
- `/dev/hailo0` state recorded: exists or not, major:minor, permissions, owning driver (from `/sys/bus/pci/devices/<BDF>/driver` symlink or explicit "no driver bound").
- The Hailo device's vendor/device IDs are recorded as READ from sysfs — never hardcoded from memory or the internet; if they differ from any prior assumption, the difference is flagged in the census notes.
- U1–U4.

## H004 — Mechanism verdict document
**Goal:** Decide, on evidence from H003, the userspace driver mechanism for HAILBRÚ: VFIO primary vs uio_pci_generic fallback. Raw sysfs resource mapping is recon-only per the architecture and is not selectable. A wrong mechanism choice wastes the whole Phase B, so the verdict must cite measured facts.
**Acceptance criteria:**
- `docs/phase_a/MECHANISM_VERDICT.md` names the primary mechanism and the fallback, each justified by at least two concrete facts from the H003 census (e.g., "VFIO chosen because /dev/vfio/<group> exists and IOMMU groups enumerate the device").
- For each rejected mechanism, the document states the blocking fact (e.g., "uio_pci_generic rejected as primary because CONFIG_UIO_PCI_GENERIC is absent in the running kernel").
- The document lists the exact device nodes, sysfs paths, and permissions the chosen mechanism will need, so HAILBRÚ slices can be built without re-research.
- The verdict selects from {VFIO primary, uio_pci_generic fallback} only; raw sysfs resource mapping is recon-only per the architecture and is not selectable. If neither VFIO nor UIO is viable, the verdict is NO-GO with the blocking facts (routing to F2/F3).
- U1–U4.

## H005 — Clean-room transport study
**Goal:** Study the hailort-drivers (GPL) and HailoRT (MIT) sources to understand the PCIe transport protocol — command submission, doorbells, interrupts, DMA — and write the findings as original prose. STUDY ONLY: never copy, translate, or vendor code; this slice produces understanding, not code.
**Acceptance criteria:**
- `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md` exists and describes in original words: how the host discovers the device, how commands are submitted (queue/doorbell model), how completions/interrupts are signaled, and how DMA buffers are shared. It cites file names studied but contains no copied code blocks longer than one line and no translated functions.
- A `CLEAN_ROOM_LOG.md` entry records which repositories, commits/tags, and files were studied, on what date, by whom — the audit trail for L5.
- `THIRD_PARTY_NOTICES.md` gains attribution entries for hailort-drivers and HailoRT with licenses and a statement that no code was taken.
- The studied repositories are cloned as source only; no vendor package is installed, built, or executed at any point (the study log records the clone commands and asserts no install/build/run occurred); the license check (license gate per Doctrine section 7) is recorded in `CLEAN_ROOM_LOG.md` before any file is read.
- The guide names at least one scratch-safe read/write register usable for H068 (offset, width, why safe), or explicitly records 'no safe scratch register identified' with evidence — in which case H068's write/readback test is replaced by a read-only coherency check (50 repeated reads of a status register, stable within volatile masks).
- U1–U4.

## H006 — HEF-container study
**Goal:** Study the HEF container format (documentation and HailoRT parsing code, STUDY ONLY) to understand what a chip-executable configuration contains, so SMIÐR can generate equivalent configurations from scratch. Per L3, Aesir will never create, read, parse, or require a HEF — this study exists so we know what to replace, not to use.
**Acceptance criteria:**
- `docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md` describes in original prose the logical sections of a HEF container (headers, configuration blobs, metadata) and what each section's purpose is, without reproducing format diagrams verbatim or copying parser code.
- The guide explicitly lists what SMIÐR must generate INSTEAD of a HEF (a from-scratch configuration path), with a one-paragraph rationale per item.
- Clean-room log and `THIRD_PARTY_NOTICES.md` updated as in H005.
- No `.hef` file is downloaded, opened, or parsed during this study; sources are documentation and HailoRT parser source code only; a repo-wide scan in-slice confirms zero `.hef` files present.
- U1–U4.

## H007 — NEON baseline spike
**Goal:** Prove the Pi 5's NEON unit can do useful FP16 matrix math from pure Mojo: a hand-written NEON FP16 matmul spike that becomes the CPU reference for all later bit-exactness checks (including the Phase-D wall verdict).
**Acceptance criteria:**
- A pure-Mojo FP16 matmul (minimum 64×64×64) using NEON intrinsics compiles and runs on Mimir; result matches a naive scalar Mojo reference with max absolute error ≤ 1e-3.
- Measured throughput in GFLOPS is recorded in `data/phase_a/neon_baseline.json` (median of 11 runs, clocks pinned via `cpufreq` if available, methodology documented).
- The spike is labeled as a spike in its DEVLOG entry and in `CAPABILITY_LEDGER.md` (marked Simulated only if it did not run on real Pi 5 hardware — it must run on real hardware).
- U1–U4.

## H008 — Loader port check on ARM64
**Goal:** Verify that Aesir's existing loaders (GGUFSeer, Hladgerð) parse correctly on ARM64 — parse-only, no model semantics changes — catching endianness, alignment, and struct-layout bugs before the full ARM64 loader campaign.
**Acceptance criteria:**
- On Mimir, both loaders parse a set of ≥3 known-good GGUF/safetensors test files; parsed header fields (magic, version, tensor count, tensor names, shapes, dtypes) match the x86_64 parse results byte-for-byte (comparison recorded in `data/phase_a/loader_port_check.json`).
- Any ARM64-specific failure is filed as a blocking issue in `docs/phase_a/LOADER_PORT_ISSUES.md` with a reproducer, not silently worked around.
- Zero edits to `cuda_*` modules (L9); loader changes, if any are needed, are additive ARM64-specific fixes.
- U1–U4.

## H009 — Version pinning record
**Goal:** Freeze every version the campaign depends on so builds are reproducible months later: Mojo version, OS/kernel, firmware blob version present in `/lib/firmware/hailo`, Python version (tests only), and any host tools.
**Acceptance criteria:**
- `data/phase_a/VERSION_PINS.md` lists each pinned item with its exact version string, where it was read from (command + output excerpt), and the date recorded.
- The firmware blob in `/lib/firmware/hailo` is catalogued by filename, byte size, and SHA-256 — recorded, never copied into the repo (L7).
- A re-verification procedure (commands to re-check each pin) is included; running it takes under 5 minutes and is documented step by step.
- U1–U4.

## H010 — Phase-A gate review
**Goal:** Hold the Phase-A gate: assemble all recon evidence into a single review document with an explicit GO / NO-GO / GO-WITH-CONDITIONS verdict for entering Phase B, so the campaign never advances on vibes.
**Acceptance criteria:**
- `docs/phase_a/PHASE_A_GATE_REVIEW.md` summarizes the verdict of each of H001–H009 in a table (slice, verdict, evidence path), then states the overall gate verdict in a dedicated section titled "GATE VERDICT".
- If GO-WITH-CONDITIONS, every condition is a concrete, checkable statement (e.g., "VFIO group permissions must be granted before H064") with an owner slice that resolves it.
- If NO-GO, the document states the blocking fact and the remediation experiment proposed — the campaign halts until remediation lands.
- U1–U4.

## H011 — Retire the npu_gate.mojo dlopen stub
**Goal:** Per L1, remove the old `npu_gate.mojo` dlopen-based stub from the build so no slice can accidentally extend it; replace its role with a documented absence until HAILBRÚ's real driver lands.
**Acceptance criteria:**
- `npu_gate.mojo` no longer compiles into any build target; a repo-wide grep for `npu_gate` returns zero hits in build files and source imports.
- A `docs/phase_a/NPU_GATE_RETIREMENT.md` note records what the stub did, why it was retired (L1), and which future slice supersedes each of its former responsibilities (mapping to H061+).
- The full test suite still passes after removal (nothing depended on the stub's behavior).
- U1–U4.

## H012 — VFIO environment probe
**Goal:** Verify the VFIO userspace prerequisites on Mimir in practice, not just in kernel config: VFIO group device nodes, permissions for the intended runtime user, and container/device-node rules.
**Acceptance criteria:**
- `data/phase_a/vfio_probe.json` records: `/dev/vfio/vfio` presence and permissions, the IOMMU group number containing the Hailo BDF, `/dev/vfio/<group>` presence/permissions, and whether the runtime user can open it (tested with a minimal open/close probe, result recorded).
- If any permission is missing, the exact remediation command is documented (not executed against policy — documented for the operator), and H064's acceptance criteria reference this record.
- U1–U4.

## H013 — UIO fallback readiness probe
**Goal:** Verify the uio_pci_generic fallback path is genuinely available if VFIO fails: module presence/loadability, sysfs bind mechanics, and `/dev/uioN` node behavior on Mimir.
**Acceptance criteria:**
- `data/phase_a/uio_probe.json` records: whether `uio_pci_generic` is loadable (`modinfo`/`modprobe --dry-run` result), the sysfs bind/unbind paths for the Hailo BDF, and a dry-run bind plan that does NOT disturb the currently bound driver.
- The probe performs zero destructive actions (no unbinding of the working driver); this is asserted in the probe log.
- U1–U4.

## H014 — Firmware blob catalogue
**Goal:** Catalogue the user-side firmware prerequisite in `/lib/firmware/hailo` so the bring-up campaign (C5) knows exactly what it may load, without Aesir ever shipping, embedding, or fetching it (L7).
**Acceptance criteria:**
- `data/phase_a/firmware_catalogue.json` lists every file under `/lib/firmware/hailo`: filename, byte size, SHA-256, and readable-version string if the file format exposes one.
- The catalogue states which blob the bring-up sequence will attempt first and why (e.g., matches device ID from H003), with the reasoning written down.
- No firmware bytes are copied into the repo; a repo-wide scan confirms zero files larger than 1 MB under `data/phase_a/` other than the JSON catalogue (threshold: 1 MB, stated here).
- U1–U4.

## H015 — Mojo POSIX external_call baseline
**Goal:** Prove that pure Mojo on the Pi 5 can perform the exact POSIX syscalls the HAILBRÚ driver will need (`openat`, `mmap`, `ioctl`, `read`, `write`, `eventfd`, `poll`) via `external_call`, with correct signatures and error handling.
**Acceptance criteria:**
- A pure-Mojo test program successfully performs each listed syscall on Mimir (e.g., `openat`+`read` on a sysfs file, anonymous `mmap`, `eventfd` create + `poll` with timeout) and prints the observed results; the program and its output log live in `data/phase_a/posix_baseline/`.
- Every syscall wrapper records `errno` on failure and maps it to a named error — no silent `-1` returns.
- U1–U4.

## H016 — TEST-ONLY (PRÓF): Phase-A evidence aggregator
**Goal:** A Python (PRÓF, TESTS ONLY) script that verifies every Phase-A artifact exists, is non-empty, and cross-references correctly (e.g., the mechanism verdict cites census facts that exist), so the Phase-A gate review can be machine-checked.
**Acceptance criteria:**
- `prof/phase_a/check_phase_a.py` run against the repo reports PASS/FAIL per artifact (H001 log through H015 baseline, both plunder guides, version pins, firmware catalogue) with a non-zero exit code on any missing or empty artifact.
- The script reads artifacts via file I/O only; it imports no engine module and shells out to nothing but the filesystem.
- A deliberately broken artifact (one file temporarily emptied in a scratch copy) makes the script FAIL, proving it is not a rubber stamp.
- U1–U4.

## H017 — Interrupt capability study
**Goal:** Determine from sysfs and the transport guide (H005) which interrupt mechanisms the Hailo-10 exposes to a userspace driver on Mimir (MSI, MSI-X, legacy INTx) and how each is acknowledged, so H069–H070 build the right thing first.
**Acceptance criteria:**
- `docs/phase_a/INTERRUPT_STUDY.md` states, with sysfs evidence paths cited: MSI/MSI-X capability presence, number of vectors available, and the acknowledgment model per the studied transport documentation.
- The study names the single interrupt mechanism H069 will implement first and the fallback order, with one-paragraph justification each.
- For each of VFIO and UIO, the exact userspace interrupt-delivery primitive is named (eventfd+ioctl vs blocking read).
- U1–U4.

## H018 — DMA coherence model study
**Goal:** Establish how DMA-coherent memory is obtained on Mimir for each driver mechanism (VFIO IOMMU mapping vs UIO DMA mask/CMA), including IOMMU translation availability and cache-coherency expectations for the ARM cores.
**Acceptance criteria:**
- `docs/phase_a/DMA_COHERENCE_STUDY.md` documents, per mechanism: how a userspace buffer becomes DMA-visible, who performs IOMMU mapping, cache maintenance responsibilities (who flushes/invalidates), and alignment/size constraints — each backed by a cited sysfs node, kernel doc, or studied source.
- The study flags any ARM64-specific coherency pitfall (e.g., non-coherent interconnect behavior) that H066/H067 must handle, or explicitly records "no pitfall found" with the evidence checked.
- U1–U4.

## H019 — Chip-executable configuration surface survey
**Goal:** From the clean-room studies (H005/H006), survey WHAT a chip-executable configuration must express (operations, data movement, memory placement) so SMIÐR's generator work (C6) has a requirements list before it writes a single byte.
**Acceptance criteria:**
- `docs/plunder/HAILO_CONFIG_SURFACE.md` lists each configuration element SMIÐR must generate (in original prose, no copied structures): operation descriptors, tensor descriptors, memory allocation directives, scheduling/ordering primitives, and completion signaling — with a one-sentence purpose per element.
- Each element is marked MUST-HAVE (needed for the minimal vector-op proof) or LATER (needed for full layers), giving C6 a prioritized backlog.
- U1–U4.

## H020 — Phase-A closeout and C2 planning
**Goal:** Close Phase A cleanly: consolidate lessons, risks, and open questions into a planning document that scopes Campaign C2 (ARMVEGR kernels) with concrete kernel targets and the numerical-correctness contract they must meet.
**Acceptance criteria:**
- `docs/phase_a/PHASE_A_CLOSEOUT.md` contains: top 5 lessons, top 5 risks with mitigations, all open questions with the slice that will answer each, and the C2 kernel backlog (each kernel with target shapes and the error tolerance it must meet).
- The Phase-A gate verdict from H010 is re-confirmed or amended with new evidence; any amendment is dated and explained.
- U1–U4.

# Campaign C2 — ARM64 CPU CORE (ARMVEGR kernels)

*Domain: D1 ARMVEGR. Builds the hand-tuned NEON/SIMD kernel library and CPU inference backend in pure Mojo. Must NOT touch PCIe, /dev nodes, driver registers, or CUDA. Every slice includes U1–U4.*

## H021 — ARMVEGR module skeleton
**Goal:** Create the D1 package layout (`armvegr/`): module files, build configuration targeting AArch64+NEON, and a compile gate that fails the build on non-ARM64 or when NEON is unavailable, so every later kernel slice builds on a strict foundation.
**Acceptance criteria:**
- `armvegr/` package compiles on Mimir with a single documented build command; the build fails with a clear error message on x86_64 (verified by attempting the build on an x86_64 host and recording the failure).
- `armvegr/__init__.mojo` exports the package version and a `neon_available() -> Bool` runtime check; a test asserts it returns True on Mimir.
- No references to PCIe, device nodes, or CUDA anywhere in the package (verified by grep for `pci`, `/dev`, `cuda` returning zero hits).
- U1–U4.

## H022 — NEON FP16 GEMM micro-kernel
**Goal:** Write the register-tiled NEON FP16 GEMM micro-kernel (the innermost compute tile), the hottest code in the CPU backend, with exact tiling parameters recorded and justified.
**Acceptance criteria:**
- Micro-kernel computes an Mr×Nr FP16 tile (tiling parameters, e.g., 8×8, documented in code comments with register-budget justification) with max absolute error ≤ 1e-3 vs a scalar reference on 100 random tiles.
- The kernel is a complete, compilable Mojo function with no TODO markers; all magic numbers are named constants.
- U1–U4.

## H023 — GEMM kernel integration (blocking/tiling driver)
**Goal:** Wrap the H022 micro-kernel in a full GEMM driver: cache blocking (Mc/Kc/Nc), edge-tile handling, and packed matrix layouts, producing a general M×N×K FP16 GEMM.
**Acceptance criteria:**
- Correct for 27 shape combinations (M,N,K each drawn from {1, 7, 64, 65, 256, 512, 1024, 2048, 4096} sampled to 27 combos, list recorded): max absolute error ≤ 1e-3 vs scalar reference on every combo.
- No out-of-bounds access under a debug/checked build for the smallest (1×1×1) and all edge shapes (verified with bounds checking enabled).
- Measured GFLOPS for 1024×1024×1024 recorded in `data/armvegr/kernel_perf.json`; must be ≥ 2× the H007 spike's measured GFLOPS (blocking must pay for itself) or the shortfall is analyzed in the DEVLOG.
- U1–U4.

## H024 — NEON FP16 GEMV kernel
**Goal:** Build the FP16 matrix-vector kernel that dominates decode-phase latency (memory-bound), optimized for the streaming access pattern rather than the GEMM blocking pattern.
**Acceptance criteria:**
- Correct for matrix shapes (M×N) with M,N ∈ {128, 1024, 4096, 8192} and vector length N: max absolute error ≤ 1e-3 vs scalar reference on all 16 combos.
- Achieves ≥ 60% of the Pi 5's measured STREAM-like memory bandwidth on the 8192×8192 case (bandwidth measured in-slice with a documented microbenchmark; the percentage is computed, not asserted).
- U1–U4.

## H025 — Elementwise kernels (add, mul, scale, axpy)
**Goal:** Implement the fused-friendly elementwise family (add, mul, scale, axpy) in NEON FP16, the glue for residual connections and scaling throughout the transformer.
**Acceptance criteria:**
- Each of the four ops is correct on vectors of length {1, 3, 16, 1000, 1_000_000} with max absolute error ≤ 1e-4 vs scalar reference (tighter bound: these ops are exact in FP16 arithmetic up to rounding).
- All four ops are exercised through a single fused-loop code path where shapes permit; the fusion points are documented in code comments.
- U1–U4.

## H026 — Layernorm kernel (FP16)
**Goal:** Implement numerically careful FP16 layernorm (mean/variance in FP32 accumulators, epsilon handling) since layernorm error compounds across layers.
**Acceptance criteria:**
- On 50 random inputs (hidden sizes {128, 1024, 4096, 8192}), output matches an FP64 reference layernorm with max absolute error ≤ 1e-3; epsilon behavior verified at epsilon ∈ {1e-5, 1e-6} with zero-variance input (constant vector) producing finite output, not NaN.
- U1–U4.

## H027 — RMSNorm kernel
**Goal:** Implement RMSNorm (the norm used by Llama-family models), sharing the accumulation discipline of H026 but with the RMS formulation and no mean subtraction.
**Acceptance criteria:**
- On 50 random inputs across hidden sizes {128, 1024, 4096, 8192}, max absolute error ≤ 1e-3 vs FP64 reference; weight-multiplication variant (with learned weight vector) also verified.
- A test proves RMSNorm ≠ Layernorm on the same input (guards against copy-paste between H026 and H027).
- U1–U4.

## H028 — Softmax kernel (FP16, numerically stable)
**Goal:** Implement max-subtracted, FP32-accumulator softmax in FP16 output, the kernel where naive implementations silently produce NaN on large logits.
**Acceptance criteria:**
- On logits including extreme values (±50, ±100) across lengths {128, 1024, 32768}, output sums to 1.0 within 1e-3, contains no NaN/Inf, and matches an FP64 reference with max absolute error ≤ 1e-3.
- Causal-masked variant verified: masked positions contribute exactly 0.0 and unmasked rows still sum to 1.0 within 1e-3.
- U1–U4.

## H029 — Activation kernels (SiLU, GELU)
**Goal:** Implement SiLU (SwiGLU-family models) and GELU (tanh approximation, documented which) in NEON FP16 with bounded error against high-precision references.
**Acceptance criteria:**
- SiLU and GELU each match FP64 references with max absolute error ≤ 2e-3 on 10,000 random inputs spanning [-10, 10]; the GELU approximation formula is named in the code comment and DEVLOG.
- Monotonicity spot-check: SiLU is verified non-decreasing on [-10, 10] at 0.01 steps (catches approximation sign errors).
- U1–U4.

## H030 — RoPE rotary embedding kernel
**Goal:** Implement RoPE (rotary position embeddings) application to query/key vectors, parameterized by head dimension, theta, and position — the positional mechanism of every modern small open LLM.
**Acceptance criteria:**
- Output matches an FP64 reference RoPE implementation with max absolute error ≤ 1e-3 for head dims {64, 128}, theta ∈ {10000, 500000}, positions {0, 1, 100, 4095}.
- Position 0 is verified to be the identity transform (catches off-by-one in angle computation).
- Interleaved vs half-rotation convention is documented explicitly in the code (which one is implemented and why).
- U1–U4.

## H031 — Quantization kernels: FP32→FP16, FP16→Q8_0, Q8_0 dequant
**Goal:** Implement the quantization primitives: FP32→FP16 cast, FP16→Q8_0 block quantization (block size 32, FP16 scale per block — format documented exactly), and Q8_0→FP16 dequantization.
**Acceptance criteria:**
- Round-trip FP16→Q8_0→FP16 on 10,000 random values in [-6, 6]: max absolute error ≤ 0.02 and RMS error ≤ 0.005 (Q8_0 contract numbers, recorded in `data/armvegr/quant_contract.json`).
- The Q8_0 memory layout (scale type, scale placement, int8 ordering within a block) is documented byte-exactly in the code and matches the layout the H033 quantized GEMM expects (cross-checked by a shared layout test).
- U1–U4.

## H032 — Quantization kernels: Q4_0 block quantization
**Goal:** Implement Q4_0 block quantization (block size 32, FP16 scale + 4-bit nibbles packed 2-per-byte, layout documented byte-exactly) and its dequantization, the format small-model weights will ship in.
**Acceptance criteria:**
- Round-trip FP16→Q4_0→FP16 on 10,000 random values in [-6, 6]: max absolute error ≤ 0.08 and RMS error ≤ 0.02 (Q4_0 contract numbers, recorded alongside H031's contract).
- Nibble packing order (low nibble first vs high nibble first) is documented and verified by a test that checks the first byte of a known input against a hand-computed expected byte.
- U1–U4.

## H033 — Quantized GEMM: Q8_0 × Q8_0 → FP32 accumulate
**Goal:** Implement the quantized GEMM that makes small-model inference fast on the Pi 5: Q8_0 activation rows × Q8_0 weight blocks with FP32 accumulation, NEON-accelerated dot products.
**Acceptance criteria:**
- On 20 random shape combos (M ∈ {1, 8, 64}, K,N ∈ {128, 1024, 4096}), output matches FP16 GEMM reference within the quantization contract: max absolute error ≤ 0.05 relative to the FP16 result, and the measured error is recorded per combo.
- The M=1 (decode) case achieves ≥ 50% of the H024 GEMV memory-bandwidth efficiency on the same shapes (measured, not asserted).
- U1–U4.

## H034 — Attention kernel: scaled dot-product with causal mask (FP16)
**Goal:** Implement single-head scaled dot-product attention (scores = Q·Kᵀ/√d, causal mask, softmax, ·V) as one fused kernel to avoid materializing the full score matrix.
**Acceptance criteria:**
- For seq lens {16, 128, 1024}, head dim {64, 128}: matches an unfused FP64 reference (separate matmul+softmax+matmul) with max absolute error ≤ 2e-3; causal property verified — output at position i is bit-identical whether computed with seq len i+1 or seq len 2048 (mask correctness).
- Peak temporary memory is O(seq_len × head_dim), never O(seq_len²) — verified by instrumenting allocation on the 1024 case.
- U1–U4.

## H035 — Multi-head attention orchestration
**Goal:** Orchestrate H034 across heads with Q/K/V projections, RoPE (H030) application, and output projection — the complete attention block as the transformer will call it.
**Acceptance criteria:**
- For a 4-head, head-dim-64, seq-128 random test: matches a naive per-head scalar reference with max absolute error ≤ 2e-3.
- Head-parallel loop produces identical results to a sequential-heads run (bit-identical, catching race/shared-buffer bugs) — verified before any threading is introduced.
- U1–U4.

## H036 — Backend-selection interface (CPU stage)
**Goal:** Define the backend-selection interface that SKIPTI (D4) will later extend: a `Backend` enum (CPU, NPU, AUTO), a `select_backend(op, shapes) -> Backend` function, and the rule that at this stage every op resolves to CPU with the decision logged.
**Acceptance criteria:**
- `select_backend` called for matmul, gemv, attention, layernorm across 20 shape combos returns CPU for all 20; each decision is appended to a decision log with op name, shapes, and reason string.
- The interface compiles against a stub NPU backend type that exists but is never selected (proving the extension point without claiming NPU capability — L11).
- A test asserts that no code path can return NPU at this stage (fail-closed: NPU unready means CPU, loudly).
- U1–U4.

## H037 — TEST-ONLY (PRÓF): kernel numerical oracle suite
**Goal:** A Python (PRÓF, TESTS ONLY) oracle suite that independently recomputes every C2 kernel's expected outputs (in float64 via pure-Python math) and compares them against the Mojo kernels' outputs on a fixed corpus of random inputs with fixed seeds.
**Acceptance criteria:**
- `prof/armvegr/test_kernel_oracles.py` covers all kernels H022–H035, runs the Mojo kernel binary via subprocess on the seed corpus, and FAILS (non-zero exit) if any kernel exceeds its slice's documented error bound.
- The seed corpus (`data/armvegr/oracle_corpus.json`) is fixed and versioned; re-running the suite twice yields identical PASS/FAIL.
- The suite imports no engine module and is runnable with only the Python standard library (L2/L4: no proprietary test dependencies).
- U1–U4.

## H038 — Kernel performance baseline measurement
**Goal:** Measure and record the definitive C2 performance baseline on Mimir: GFLOPS or GB/s for every kernel at representative shapes, with methodology documented — the honest numbers all later optimization claims are judged against (anti-fake-benchmark foundation).
**Acceptance criteria:**
- `data/armvegr/kernel_perf.json` contains, per kernel: shapes tested, median of 11 runs, min/max, clock-pin methodology, ambient temperature at run start, and Mojo version — every field present, no kernel omitted.
- A `BENCHMARK_METHOD.md` documents warmup, repetition count, outlier handling, and why these choices were made; any future perf claim must cite this method or document its deviation.
- U1–U4.

## H039 — CPU inference scratch: attention-free toy forward pass
**Goal:** Wire kernels into a first toy forward pass (embedding → layernorm → matmul → activation → matmul → logits) on random weights, proving the kernels compose without shape or layout bugs before real model weights arrive.
**Acceptance criteria:**
- The toy forward runs end-to-end on Mimir for hidden sizes {128, 512} and produces finite logits (no NaN/Inf) with output shape exactly [1, vocab_size].
- The same computation expressed as naive scalar Mojo matches the kernel-composed result with max absolute error ≤ 5e-3 (composition didn't break the kernels' individual contracts).
- U1–U4.

## H040 — C2 review: verified ARMVEGR core verdict
**Goal:** Review Campaign C2 as a gate: every kernel's correctness evidence, performance baselines, and the toy forward pass, ending with an explicit verdict on whether the ARMVEGR compute core is trustworthy enough to serve as the CPU reference for the Phase-D wall (bit-exactness standard).
**Acceptance criteria:**
- `docs/armvegr/C2_REVIEW.md` contains a per-kernel table (kernel, error bound claimed, worst measured error, perf number, evidence path) and a "C2 VERDICT" section stating READY or NOT-READY for use as the wall reference.
- If NOT-READY, each failing kernel gets a named remediation slice appended to the plan: remediation slices are numbered H201+ in creation order (extending the sequence; the 200-count is the plan baseline, remediation extends it), each documented with goal + acceptance criteria in the review, subject to U1–U4 (to be carved before C3 proceeds).
- U1–U4.

# Campaign C3 — LOADERS / TOKENIZER / KV-CACHE ON ARM64

*Domain: D1 ARMVEGR (model I/O and CPU pipeline). Pure Mojo. Continues the F1 CPU engine. Every slice includes U1–U4.*

## H041 — GGUFSeer ARM64 full port
**Goal:** Promote the H008 parse-check into a full ARM64 port of GGUFSeer: every parse path exercised on Mimir, ARM64-specific alignment/endianness issues fixed additively, zero behavior change on x86_64.
**Acceptance criteria:**
- On Mimir, GGUFSeer parses ≥5 real GGUF files (v2 and v3, mixed dtypes incl. Q4_0/Q8_0/F16); all metadata key-value pairs and tensor descriptors match the x86_64 parse output exactly (diff recorded in `data/armvegr/gguf_port_diff.txt`, empty diff).
- The existing x86_64 test suite for GGUFSeer passes unmodified (L9: no CUDA-track or x86 behavior change).
- U1–U4.

## H042 — GGUF tensor loader (mmap + dequantize to FP16)
**Goal:** Build the GGUF tensor data loader: memory-map the file, locate tensor data offsets, and dequantize every supported dtype (F32, F16, Q8_0, Q4_0) into FP16 working tensors using the H031/H032 kernels.
**Acceptance criteria:**
- For each supported dtype, a tensor extracted from a real GGUF file and dequantized matches the same tensor dequantized by the x86_64 Aesir loader with max absolute error ≤ 1e-6 (same dtype, same code path — this must be near-exact).
- Loading a 1GB+ GGUF file completes without copying the whole file into RAM (verified by peak RSS < file size + 256MB during load).
- Corrupt/truncated GGUF input fails closed with a named error (not a crash, not silent garbage) — tested with 3 crafted corrupt files.
- U1–U4.

## H043 — safetensors parser in pure Mojo
**Goal:** Write a pure-Mojo safetensors parser: JSON header parse (no JSON library — hand-rolled per L1, or Mojo stdlib only), tensor descriptor extraction, dtype/shape validation.
**Acceptance criteria:**
- Parses the headers of ≥5 real safetensors files (F16, BF16, F32 tensors); every tensor's name, dtype, shape, and data offset matches a Python-`struct`-based cross-check (TEST-ONLY cross-check script) exactly.
- Malformed headers (truncated JSON, overlapping offsets, offset beyond EOF) are rejected with named errors; 5 adversarial headers tested.
- U1–U4.

## H044 — safetensors tensor loader (dtype mapping incl. BF16)
**Goal:** Extend H043 into a full tensor loader: read tensor bytes, convert BF16→FP16 (correct rounding), F32→FP16, pass through F16, with endianness handling explicit.
**Acceptance criteria:**
- BF16→FP16 conversion verified on 10,000 values including subnormals, ±Inf, NaN: round-to-nearest-even behavior documented and tested; max absolute error vs FP64 reference ≤ 1 ULP-equivalent bound stated in code.
- A real safetensors small-model file loads end-to-end on Mimir; every tensor's FP16 checksum matches the x86_64 loader's checksum exactly.
- U1–U4.

## H045 — Weight layout planner
**Goal:** Build the weight layout planner: given a model's tensor shapes and the kernel contracts (H023/H033), decide per-tensor packed/interleaved layouts and pre-pack weights at load time so inference never repacks.
**Acceptance criteria:**
- For a 6-tensor test model (shapes recorded), the planner emits a layout plan (JSON) specifying per-tensor layout; executing GEMM with planned layouts vs naive layouts gives max absolute error ≤ 1e-3 (layouts are numerics-preserving).
- Replanning is deterministic: same model → byte-identical plan JSON on repeated runs.
- U1–U4.

## H046 — BPE tokenizer (vocab + merges)
**Goal:** Implement byte-pair encoding tokenization in pure Mojo: vocab load, merge-rank application, byte-fallback for unseen bytes — the tokenizer for GPT-2/Llama-style models.
**Acceptance criteria:**
- Encode/decode round-trips 1,000 test strings (ASCII, multilingual UTF-8, emoji, code) losslessly: decode(encode(s)) == s for all 1,000.
- Token IDs for 50 reference strings match the reference tokenizer's IDs exactly (reference IDs stored in `data/armvegr/tokenizer_vectors.json`, generated once via a TEST-ONLY script and then frozen).
- U1–U4.

## H047 — SentencePiece-style tokenizer support
**Goal:** Implement SentencePiece-model tokenization for the subset Aesir needs (BPE and unigram via the model proto fields Aesir actually reads), in pure Mojo, so Gemma/Qwen-family models tokenize correctly.
**Acceptance criteria:**
- For a real SentencePiece model file, 200 test strings encode to exactly the reference token IDs (frozen vectors as in H046); the leading-▁ (U+2581) whitespace convention is handled and documented.
- Unsupported model-proto features fail closed with a named error naming the unsupported field — never silently mis-tokenize.
- U1–U4.

## H048 — TEST-ONLY (PRÓF): tokenizer differential suite
**Goal:** A Python (PRÓF, TESTS ONLY) differential suite that re-verifies H046/H047 against frozen reference vectors on every run, guarding the tokenizers against regressions as the engine evolves.
**Acceptance criteria:**
- `prof/armvegr/test_tokenizers.py` runs the Mojo tokenizer binary via subprocess on the frozen vector corpus and FAILS on any ID mismatch; corpus version is pinned in the file header.
- The suite covers BPE, byte-fallback, SentencePiece, special tokens, and decode round-trip; total ≥ 1,500 assertions.
- U1–U4.

## H049 — Special tokens handling (BOS/EOS/pad)
**Goal:** Implement special-token semantics: BOS prepend rules per model family, EOS detection during generation, pad handling for batched inputs — driven by a per-model config data file, not hardcoded.
**Acceptance criteria:**
- A `data/armvegr/model_tokenizer_configs.json` drives behavior for ≥3 model families; a test per family asserts BOS/EOS IDs, prepend behavior, and EOS-stop during a scripted generation.
- Unknown model family fails closed ("no tokenizer config for family X") rather than guessing BOS/EOS IDs.
- U1–U4.

## H050 — KV-cache structure (FP16)
**Goal:** Build the KV-cache data structure: per-layer key/value storage in FP16, preallocated for max context length, with explicit memory accounting.
**Acceptance criteria:**
- Cache for a 12-layer, 8-head, head-dim-64, 4096-context test config allocates exactly the documented byte count (formula in code: layers × 2 × heads × head_dim × ctx × 2 bytes, plus documented overhead ≤ 1%).
- Out-of-context append (position ≥ max) fails closed with a named error; it never silently overwrites or corrupts earlier positions.
- U1–U4.

## H051 — KV-cache update/append during decode
**Goal:** Implement the decode append path: write one new K/V vector per layer per step, with RoPE already applied upstream, and verify positional correctness across a full sequence.
**Acceptance criteria:**
- Generating 256 tokens step-by-step with the cache produces logits at every step matching a no-cache recompute (full re-encode each step) with max absolute error ≤ 1e-3 — the cache is proven equivalent to recomputation.
- Cache memory after 256 steps equals the precomputed expected size (no per-step reallocation — verified by allocation instrumentation).
- U1–U4.

## H052 — Context eviction policy (sliding window)
**Goal:** Implement the sliding-window eviction policy for contexts exceeding max length: keep the first N "attention sink" tokens plus the most recent window, with the policy parameterized in a config data file.
**Acceptance criteria:**
- With max_ctx=512, sink=4, feeding 600 tokens: the cache holds exactly tokens [0..3] + [88..599] (positions verified by a probe test), and generation continues without error.
- The eviction event is logged with token counts (observability, not silent dropping).
- U1–U4.

## H053 — Sampler: greedy
**Goal:** Implement greedy sampling (argmax) with deterministic tie-breaking (lowest token ID wins), the baseline every other sampler is judged against.
**Acceptance criteria:**
- On 1,000 random logit vectors, output equals `argmax` computed independently in the TEST-ONLY oracle; ties broken to the lowest ID (verified with crafted tie vectors).
- Same input → same output across 100 runs (determinism), recorded in the test log.
- U1–U4.

## H054 — Sampler: temperature
**Goal:** Implement temperature sampling: logits/temperature → softmax → categorical sample, with temperature→0 degenerating to greedy and a seeded RNG for reproducibility.
**Acceptance criteria:**
- With seed fixed, 500 samples from one logit vector are reproducible exactly (same token sequence); with temperature=1e-6, output equals greedy output on 100 vectors.
- Sampling distribution sanity: over 20,000 draws, empirical token frequencies match softmax probabilities within ±3 standard errors for the top-5 tokens (chi-square style check documented in the test).
- U1–U4.

## H055 — Sampler: top-k
**Goal:** Implement top-k filtering (keep k highest-logit tokens, renormalize) composed with temperature sampling.
**Acceptance criteria:**
- With k=1, output equals greedy on 100 vectors; with k=vocab_size, output distribution equals pure temperature sampling (boundary behaviors verified).
- Tokens outside the top-k are never sampled in 20,000 draws (verified by tracking sampled IDs against the computed top-k set).
- U1–U4.

## H056 — Sampler: top-p (nucleus)
**Goal:** Implement nucleus (top-p) filtering: smallest set of tokens with cumulative probability ≥ p, composed with temperature and top-k in the documented order (top-k → top-p → temperature).
**Acceptance criteria:**
- With p=1.0, behavior equals temperature-only sampling; with p→0+, behavior equals greedy (boundary tests on 100 vectors).
- The composition order top-k→top-p→temperature is asserted by a test where swapping the order would change the outcome (order-sensitivity test with crafted logits).
- U1–U4.

## H057 — Sampler: repetition penalty
**Goal:** Implement repetition penalty (and frequency/presence penalty variants if the config enables them), applied to logits before the sampling chain, with per-model defaults in a data file.
**Acceptance criteria:**
- With penalty=1.0, logits are unchanged (identity test); with penalty=1.5, a token present in the context has its logit divided by 1.5 if positive / multiplied by 1.5 if negative (sign-aware rule tested on crafted logits).
- Penalty applies only to tokens in the recent context window (configurable size); tokens outside the window are unaffected (verified).
- U1–U4.

## H058 — TEST-ONLY (PRÓF): CPU pipeline smoke test
**Goal:** A Python (PRÓF, TESTS ONLY) end-to-end smoke test: build a tiny random-weight GGUF model, run the Mojo CPU inference binary on it via subprocess for 20 tokens, and assert structural correctness (token count, no crash, valid token IDs, timing recorded).
**Acceptance criteria:**
- `prof/armvegr/test_cpu_smoke.py` generates the tiny model deterministically (seeded), runs inference, and asserts: exactly 20 tokens emitted, all IDs within vocab range, exit code 0, and tokens/sec recorded into `data/armvegr/cpu_smoke_perf.json`.
- The test fails if stderr contains "panic", "segfault", or a Mojo runtime error string (crash detection, not just exit-code checking).
- U1–U4.

## H059 — CPU inference with a real small open LLM
**Goal:** The F1 milestone's heart: load a real small open LLM (e.g., a ~100M–1B parameter GGUF, model name and SHA-256 recorded) with Aesir's own loaders and generate coherent text on the pure-Mojo CPU path.
**Acceptance criteria:**
- Given the prompt "The meaning of hospitality is" (and 2 more recorded prompts), the model generates ≥50 tokens of coherent, on-topic English. Coherence is scored against the frozen binary rubric in `data/armvegr/coherence_rubric.json` (>=6 binary items, e.g.: all tokens are valid vocabulary IDs; >=3 complete sentences ending in terminal punctuation; no token repeated >10x consecutively; >=1 prompt-topic content word present; no NaN/Inf-derived garbage tokens; English word ratio >= 80% against a frozen wordlist); every item must pass per prompt; the rubric file is created and checksummed in this slice (checksum recorded in the DEVLOG) and reused verbatim by H135/H138/H158/H186/H195.
- The exact model file (name, URL, SHA-256), prompt strings, sampler settings, and full outputs are stored in `data/armvegr/first_coherent_run.json` — reproducible by re-running the documented command.
- U1–U4.

## H060 — C3 review: ARMVEGR CPU pipeline verdict (F1 core complete)
**Goal:** Review Campaign C3 as a gate: loaders, tokenizers, KV-cache, samplers, and the coherent-text run, with an explicit verdict that the F1 CPU inference core is complete and trustworthy.
**Acceptance criteria:**
- `docs/armvegr/C3_REVIEW.md` contains per-component tables (component, test coverage, worst measured error, evidence path) and a "C3 VERDICT" section stating F1-CORE-READY or listing named remediation slices.
- The review explicitly confirms L2 (no Python in the shipped path), L3 (no HEF involved anywhere), and L9 (zero `cuda_*` edits across C2–C3, verified by git log).
- U1–U4.

# Campaign C4 — HAILO DRIVER (HAILBRÚ, Phase B)

*Domain: D2 HAILBRÚ — pure-Mojo userspace PCIe driver. ONLY domain allowed to open device nodes, mmap BARs, issue ioctls. Must NOT touch model semantics or compute math. Mechanism per H004 verdict (VFIO primary, uio_pci_generic fallback). Every slice includes U1–U4. Slices that cannot run without physical device access mark results Simulated per L10 — but MUST still be attempted on Mimir first.*

## H061 — HAILBRÚ module skeleton + PCI BDF discovery via sysfs
**Goal:** Create the D2 package (`hailbru/`): enumerate `/sys/bus/pci/devices/`, match the Hailo device by the vendor/device IDs read in H003, and return its BDF — discovery with zero hardcoded addresses.
**Acceptance criteria:**
- On Mimir, discovery returns exactly one BDF matching the H003 census; on a machine with no Hailo device it returns a named `DeviceNotFound` error (tested by pointing the sysfs root at a scratch copy — no real hardware needed for the negative test).
- BDF parsing handles all valid formats (`0000:01:00.0`) and rejects malformed entries without crashing (5 malformed inputs tested).
- The module contains no model-semantics or compute-math code (grep for `matmul`, `softmax`, `tensor` returns zero hits).
- U1–U4.

## H062 — Device identity read (config space)
**Goal:** Read the PCI configuration space of the discovered BDF via sysfs (`config` file): vendor ID, device ID, class code, and the MSI/MSI-X capability pointers — all values read, none assumed.
**Acceptance criteria:**
- Vendor/device/class values read on Mimir are recorded in `data/hailbru/device_identity.json` and match the H003 census values exactly; any mismatch fails the test loudly (identity drift detection).
- The capability walk finds the MSI/MSI-X capability (or records its absence with the H017 study as justification for the fallback).
- Reading config space of a non-existent BDF fails closed with a named error (tested against a scratch sysfs tree).
- U1–U4.

## H063 — BAR info parsing
**Goal:** Parse BAR sizes and attributes from sysfs `resource` files for the Hailo BDF: each BAR's start address, size, and flags (prefetchable, 64-bit, I/O vs memory).
**Acceptance criteria:**
- Parsed BAR table recorded in `data/hailbru/bar_table.json`: for each of BAR0–BAR5, address, size in bytes, and flags; sizes are verified sane (power-of-two, ≥4KB for memory BARs).
- A test with a crafted `resource` file (including a 64-bit BAR spanning two entries) parses correctly — 64-bit BAR pairing is the classic bug, so it's tested explicitly.
- U1–U4.

## H064 — BAR0 mmap via VFIO
**Goal:** Map BAR0 into the Mojo process via the VFIO mechanism chosen in H004: open the VFIO group/container, set IOMMU type, get the device fd, and mmap the BAR region.
**Acceptance criteria:**
- On Mimir with VFIO available: BAR0 maps successfully, the mapping address is page-aligned, and a read of the first 4 bytes returns without a bus error; the mapped size equals the H063 BAR0 size.
- Every VFIO ioctl's return value is checked and mapped to a named error; a test with an invalid group fd asserts the named error (not a crash).
- If VFIO is unavailable on the test machine, the slice documents the blockage, marks the ledger entry Simulated per L10, and the uio path (H065) becomes the active implementation — fail-closed honesty, never a faked success.
- The slice asserts the device is bound to the H004-chosen driver before mapping (named error if wrong driver bound, citing the H012 remediation record); the criteria cite the H012 record explicitly.
- U1–U4.

## H065 — BAR mapping via UIO fallback path
**Goal:** Implement the uio_pci_generic fallback BAR mapping: bind the driver per the H013 plan, open `/dev/uioN`, and mmap the BAR resource — only activated when VFIO is unavailable, per the H004 fallback order.
**Acceptance criteria:**
- The fallback activates if and only if the VFIO path reports unavailable (a decision test with mocked mechanism availability asserts the ordering — VFIO tried first, UIO second, never UIO when VFIO works).
- On Mimir (if the fallback is the active path): BAR0 maps and reads cleanly as in H064; the active mechanism is recorded in `data/hailbru/active_mechanism.json`.
- The bind/unbind sequence restores the original driver binding afterward (verified: the `driver` symlink points back to the original driver after the test).
- The bind/unbind test executes with operator-granted privileges (root); absent privileges fail closed with a named error, not a skip.
- U1–U4.

## H066 — DMA-coherent buffer allocation (VFIO IOMMU path)
**Goal:** Allocate DMA-coherent buffers via the VFIO path: userspace allocation (page-aligned, locked), IOMMU mapping via `VFIO_IOMMU_MAP_DMA`, and return of both CPU virtual address and IOVA for the device.
**Acceptance criteria:**
- Allocate/free 100 buffers of sizes {4KB, 64KB, 1MB, 16MB}: every allocation returns page-aligned addresses, IOVA ≠ 0, and all 100 free cleanly (no leaks — verified by re-allocating the full set after free).
- A buffer filled with a known pattern on the CPU reads back the identical pattern (coherency sanity before any device DMA).
- Double-free and free-of-unknown-buffer fail closed with named errors (tested).
- U1–U4.

## H067 — DMA buffer allocation via UIO path
**Goal:** Implement DMA buffer allocation for the UIO fallback mechanism per the H018 study (DMA mask, cache maintenance responsibilities), active only when UIO is the chosen mechanism.
**Acceptance criteria:**
- Same 100-buffer allocate/free matrix as H066 passes on the UIO path when UIO is active; when VFIO is active, the UIO allocator refuses with a named `WrongMechanism` error (mechanism hygiene test).
- Cache-maintenance hooks (flush/invalidate) exist as named functions per H018's findings, even if the platform proves fully coherent — the call sites are present and tested as no-ops-with-logging where appropriate.
- U1–U4.

## H068 — Register read/write primitives + readback verification
**Goal:** Build the register access layer on top of the mapped BAR: `reg_read32(offset)`, `reg_write32(offset, value)`, and `reg_write32_verified` (write + readback + compare), with volatile semantics and offset bounds-checking against the BAR size.
**Acceptance criteria:**
- Write/readback of 50 random values to a scratch-safe register (a documented read/write register identified in the transport study — never a command or firmware register) succeeds 50/50 with readback equality.
- Out-of-range offsets (≥ BAR size, unaligned) fail closed with named errors before any memory access (tested with 10 bad offsets).
- A write to a read-only status register is detected by readback mismatch and reported as a named `ReadbackMismatch` error, not silently accepted.
- U1–U4.

## H069 — Interrupt setup (MSI-X via eventfds)
**Goal:** Set up interrupt delivery per the H017 study: allocate MSI-X vectors (or the chosen mechanism), create eventfds, register them via the mechanism's ioctl, and unmask the vectors.
**Acceptance criteria:**
- Setup completes without error on Mimir and returns N usable eventfds where N matches the vector count from H017/H062; each eventfd is verified readable (non-blocking read returns EAGAIN when no interrupt pending — proving the fd is live).
- Teardown releases all vectors and closes all fds; a second setup after teardown succeeds (no leaked vector state).
- If the device exposes zero usable vectors, setup fails closed with a named error citing the H017 evidence — never proceeds with "polling instead" silently.
- UIO fallback path (when VFIO is unavailable per the H004 verdict): open `/dev/uioN`; a blocking `read()` returns the interrupt count; the interrupt is unmasked via `write()` to the uio fd. (The eventfd + `VFIO_DEVICE_SET_IRQS` criteria above apply to the VFIO path only.)
- U1–U4.

## H070 — Interrupt handling loop
**Goal:** Implement the interrupt wait loop: `poll` on the eventfds with a timeout, read the eventfd counter on wake, and dispatch to a handler callback — the completion-signaling path for all future command submission.
**Acceptance criteria:**
- A synthetic interrupt (eventfd write from a test thread, or a device-generated interrupt if the firmware is already up) wakes the loop within the timeout + 10ms margin; the handler fires exactly once per eventfd increment. On the UIO path, the synthetic test uses a test hook on the driver's own interrupt source; if synthetic injection is impossible on UIO, the slice documents why and tests with a real device interrupt post-H075.
- Poll timeout with no interrupt returns a named `IrqTimeout`, not a hang — verified with a 100ms timeout test that completes in <500ms wall-clock.
- The loop survives 10,000 synthetic interrupts without fd leaks or missed counts (counter accounting exact).
- U1–U4.

## H071 — PCIe config-space extended read
**Goal:** Extend H062 with full config-space access: extended capability walk (PCIe capabilities, power management), link status (speed/width negotiated), for diagnostics and bring-up evidence.
**Acceptance criteria:**
- Link status read on Mimir records negotiated speed and width in `data/hailbru/link_status.json` (e.g., "2.5 GT/s x1" — whatever is real, recorded not assumed); if the link is degraded vs the slot's capability, it's flagged in the DEVLOG.
- Power-management capability state (D0/D3) is readable; the current state is recorded.
- U1–U4.

## H072 — Firmware-load prerequisites (mailbox/doorbell identification)
**Goal:** From the transport study (H005) and register probes via H068, identify the exact registers involved in firmware loading (mailbox, doorbell, status) and document their offsets and semantics — research and probing only, no firmware written yet.
**Acceptance criteria:**
- `docs/plunder/HAILO_FW_LOAD_REGISTERS.md` lists each firmware-related register: offset (from BAR0), width, read/write semantics, and the evidence for each claim (study citation + probe observation).
- Every listed register is probed read-only on Mimir; observed reset values are recorded. Any register whose behavior contradicts the study is flagged as a discrepancy with a follow-up question, not papered over.
- No firmware bytes are written to the device in this slice (explicitly asserted in the DEVLOG).
- The register map also covers reset-control registers (offset, semantics, evidence) used by H083.
- U1–U4.

## H073 — Firmware blob presence check (user-side prerequisite)
**Goal:** Verify the firmware blob catalogued in H014 is present and intact at load time: existence, size, and SHA-256 match the catalogue — the fail-closed gate before any load attempt.
**Acceptance criteria:**
- A `firmware_check()` function returns the blob path and verified SHA-256, or a named `FirmwareMissing`/`FirmwareCorrupt` error; the SHA-256 must match the H014 catalogue exactly.
- If multiple blobs exist, the selection rule from H014 is applied deterministically and the chosen file is logged.
- Aesir performs no download, no fetch, no network access in this slice (verified by code review note in DEVLOG: the function only reads the local path).
- U1–U4.

## H074 — Firmware upload sequence (chunked DMA transfer)
**Goal:** Implement the chunked firmware upload: DMA-coherent staging buffers (H066/H067), chunked copy of the blob into device-visible memory, and doorbell/mailbox writes per the H072 register map — the most failure-prone step, built with per-chunk verification.
**Acceptance criteria:**
- Upload of the full blob completes with per-chunk checksums: each chunk's device-side checksum (if the protocol exposes one) or a readback of the staging descriptor matches; any chunk mismatch aborts with a named error identifying the chunk index.
- Interrupting the upload mid-way (test hook) leaves the device in a defined state per the documented abort procedure — verified by re-running the upload successfully afterward.
- The blob is never modified in memory (a post-upload SHA-256 of the staging buffer matches the file).
- U1–U4.

## H075 — Firmware boot handshake
**Goal:** Execute the post-upload boot handshake: trigger boot via the documented register, poll the status register for boot progress, and reach the firmware's "alive" state within a documented timeout budget.
**Acceptance criteria:**
- The handshake reaches the alive state on Mimir; the full status-register poll trace (timestamped) is saved to `data/hailbru/fw_boot_trace.json`.
- Timeout budget is documented (e.g., 30s) and justified; exceeding it fails closed with a named `FirmwareBootTimeout` plus the last 20 status samples attached to the error.
- U1–U4.

## H076 — Device-ready polling
**Goal:** Implement the canonical "is the device ready" check: poll the ready/status register until the documented ready pattern appears, with timeout and register-dump-on-failure — the primitive every later phase gates on.
**Acceptance criteria:**
- `device_ready(timeout)` returns True on Mimir within the documented budget after H075; the ready pattern's bit definition is cited to the register doc (H072).
- On forced timeout (timeout=1ms test), the function returns a named error and dumps the status register value in the error payload.
- The function is idempotent: calling it 10 times in a row on a ready device returns True 10 times with no side effects.
- U1–U4.

## H077 — Phase-B go gate: discovery → ready, repeatable
**Goal:** The Phase-B gate: run the full driver bring-up chain (discovery → BAR map → DMA alloc → interrupt setup → firmware load → ready) as one scripted sequence, 10 times consecutively, with zero failures.
**Acceptance criteria:**
- 10/10 runs reach `device_ready == True`; per-run timings are recorded in `data/hailbru/phase_b_gate.json`; the worst run is within 3× the best run (stability, not just success).
- Each run starts from a clean process (no state carried between runs) — verified by running each iteration as a fresh process invocation.
- `docs/hailbru/PHASE_B_GATE.md` states GO or NO-GO with the evidence table; NO-GO names the failing step and blocks C5.
- Each iteration begins from a defined device state: the H083 clean reset is asserted before every run (or the device is power-cycled per the H081 cold-boot definition); the per-run log records which steps actually executed; firmware upload must occur in every run unless the run's defined start state is 'firmware already resident,' stated explicitly.
- U1–U4.

## H078 — TEST-ONLY (PRÓF): HAILBRÚ error-path tests
**Goal:** A Python (PRÓF, TESTS ONLY) suite that drives the HAILBRÚ binary's error paths without real hardware: missing device, bad sysfs tree, VFIO denial, corrupt firmware catalogue, interrupt timeout — every fail-closed claim in C4 proven by test.
**Acceptance criteria:**
- `prof/hailbru/test_error_paths.py` covers ≥15 error scenarios; each asserts the exact named error (not just non-zero exit) emitted by the Mojo driver binary.
- The suite runs on any machine (no Hailo hardware required) using scratch sysfs trees and environment overrides; it passes on x86_64 CI-style hosts too.
- U1–U4.

## H079 — HAILBRÚ public API surface
**Goal:** Freeze the HAILBRÚ public API that VÖRÐR (D6) and SMIÐR (D3) will program against: `discover()`, `map_bars()`, `dma_alloc/free()`, `irq_wait()`, `reg_read/write()`, `firmware_load()`, `device_ready()`, `reset()` — with signatures, error types, and thread-safety contracts documented.
**Acceptance criteria:**
- `hailbru/API.md` documents every function: signature, arguments, return values, every named error it can raise, and whether it is thread-safe; the document is reviewed against the implementation (no documented function missing, no implemented-but-undocumented public function).
- A compile-time test imports the full API surface and calls each function in its documented happy path (against scratch/emulated resources where hardware isn't needed).
- The API exposes no way to bypass the driver (no raw BAR pointer escape, no direct `/dev` path parameters) — verified by API review checklist in the DEVLOG.
- U1–U4.

## H080 — C4 review: Phase-B gate document
**Goal:** Review Campaign C4 as a gate: driver completeness against the H079 API, the H077 gate result, error-path coverage, and L12 compliance (device-touching code exists ONLY in `hailbru/`).
**Acceptance criteria:**
- `docs/hailbru/C4_REVIEW.md` contains the API coverage table, gate evidence, and a "C4 VERDICT" of READY or NOT-READY for Phase C.
- L12 audit: a repo-wide grep for device-touching syscalls (`mmap` on `/dev`, `ioctl`, sysfs PCI paths) outside `hailbru/` returns zero hits — the grep command and its empty output are pasted into the review.
- U1–U4.

# Campaign C5 — BRING-UP & FIRMWARE (Phase C)

*Domain: D2 HAILBRÚ (bring-up orchestration) + D6 VÖRÐR monitoring hooks. Cold boot → ready → clean reset → ready, repeatedly, verified against documented registers. Every slice includes U1–U4.*

## H081 — Cold-boot sequence orchestrator
**Goal:** Build the cold-boot orchestrator: the ordered sequence (power-on state check → BAR remap if needed → firmware load → boot handshake → ready poll) as a single auditable function with per-step logging.
**Acceptance criteria:**
- A cold boot from a freshly powered device reaches ready on Mimir; the step-by-step log shows every step's start/end timestamps and all 6+ steps succeed in order.
- Skipping any step (test hook) fails the boot with a named error identifying the skipped step — proving the steps are actually load-bearing, not ceremonial.
- The orchestrator asserts the expected driver binding at start (named error on mismatch).
- Cold boot is defined operationally in `docs/hailbru/COLD_BOOT_DEFINITION.md` as exactly one of: (a) full Pi reboot + HAT power cycle + driver rebind, or (b) driver-level full re-enumeration from a powered-but-unbound state. H085/H093/H095 cite the definition; under (a) the slice states the reboot mechanism and expected per-cycle wall time.
- U1–U4.

## H082 — Ready-state register snapshot recorder
**Goal:** Record the complete "known-good ready" register snapshot: all documented status/control registers read immediately after a successful boot, stored as the golden reference for drift detection.
**Acceptance criteria:**
- `data/hailbru/golden_ready_snapshot.json` contains ≥20 registers (offset, name, value, mask of volatile bits); volatile bits (counters, timers) are marked with masks so later comparisons ignore expected churn.
- The snapshot is captured 3 times from 3 separate cold boots; registers that differ across boots beyond their volatile masks are flagged and investigated in the DEVLOG (not silently averaged).
- U1–U4.

## H083 — Clean reset procedure
**Goal:** Implement the clean device reset using only documented registers: assert reset, wait for the reset-acknowledge pattern, deassert, and confirm return to a bootable (not necessarily ready) state.
**Acceptance criteria:**
- Reset from ready state completes on Mimir; post-reset register reads match the documented post-reset values (recorded in `data/hailbru/post_reset_snapshot.json`).
- Reset from an already-reset device is a safe no-op returning success (idempotence test).
- The procedure never touches undocumented registers; every register written is cited to the register doc from H072.
- U1–U4.

## H084 — TEST-ONLY (PRÓF): reset-cycle harness (100×)
**Goal:** A Python (PRÓF, TESTS ONLY) harness that drives 100 consecutive reset→ready cycles via the Mojo bring-up binary, recording per-cycle success, timing, and any anomaly — the Phase-C gate's workhorse.
**Acceptance criteria:**
- `prof/hailbru/test_reset_cycles.py` runs 100 cycles unattended; asserts 100/100 reach ready; writes `data/hailbru/reset_cycles_100.json` with per-cycle timings and the max/min/mean.
- Any single cycle failure aborts the run with the failing cycle's full register dump attached — the harness never hides a failure in an average.
- U1–U4.

## H085 — Boot-time measurement + budget
**Goal:** Measure the cold-boot time distribution and set the official boot-time budget that all later phases (watchdog timeouts, recovery budgets) derive from.
**Acceptance criteria:**
- 30 cold boots measured on Mimir; `data/hailbru/boot_times.json` records each; the official budget is set at max_observed × 2 (rounded up to a whole second), documented in `docs/hailbru/BOOT_BUDGET.md` with the raw data cited.
- Boot time is broken into per-step timings (from H081 logs); the slowest step is named with its percentage of total — no step may be an unexplained black hole.
- Cold boots in this slice follow the `docs/hailbru/COLD_BOOT_DEFINITION.md` definition (H081); the slice records which option was used per cycle ((a) full reboot + power cycle + rebind, or (b) driver-level re-enumeration), and under (a) the reboot mechanism and expected per-cycle wall time.
- U1–U4.

## H086 — Firmware version query/record
**Goal:** Query the running firmware's version/revision identifiers via documented registers or mailbox, and record them as part of the device identity.
**Acceptance criteria:**
- `data/hailbru/firmware_version.json` records the version read from the live device after boot; the read method (register offsets or mailbox command) is cited.
- The version is cross-checked against the blob catalogue (H014): the running version must be traceable to a catalogued blob, or the mismatch is flagged as an anomaly in the DEVLOG.
- U1–U4.

## H087 — VÖRÐR monitoring hooks (temperature + status)
**Goal:** Build the D6 monitoring read hooks on top of HAILBRÚ's API: periodic temperature register reads and status register reads, exposed as a `health_sample()` function returning a structured sample — VÖRÐR's eyes, built now so Phase C is observed from the start.
**Acceptance criteria:**
- `health_sample()` returns temperature (in documented units — raw value plus the conversion formula cited), status register value, and a monotonic timestamp; 100 consecutive samples on Mimir show temperature within a sane range and no sample errors.
- Temperature conversion formula is cited to documentation or marked as "uncalibrated raw units" explicitly — never presented as °C without evidence.
- The hooks use ONLY the H079 public API (L12: VÖRÐR never touches registers directly — verified by import grep).
- The hooks are implemented as read-only observers in `hailbru/health_obs.mojo` (HAILBRU-owned, L12-clean) exposing `health_sample()`; H141 adopts them into `vordr/` (move, not copy); the relocation is recorded in the H087 DEVLOG entry.
- U1–U4.

## H088 — Hang detection during boot
**Goal:** Implement boot-hang detection: if any boot step exceeds its budgeted time, capture a register dump and fail with a named `BootHang` error carrying the dump — turning silent hangs into diagnosable events.
**Acceptance criteria:**
- A test hook that stalls the boot handshake triggers `BootHang` within budget+5s; the error payload contains ≥10 register values captured at hang time.
- Normal boots never trigger the detector (30 clean boots, zero false positives — recorded).
- U1–U4.

## H089 — Bring-up log schema
**Goal:** Define the structured bring-up log schema (JSON lines): timestamp, step, event, register values, outcome — so every future boot, reset, and recovery is machine-analyzable.
**Acceptance criteria:**
- `docs/hailbru/BRINGUP_LOG_SCHEMA.md` defines every field, its type, and which steps emit which events; a JSON-schema-style validator (TEST-ONLY) rejects 5 crafted malformed log lines and accepts 5 well-formed ones.
- All H081–H088 logs are retrofitted to the schema (or the gaps are listed as known deviations with owning slices).
- U1–U4.

## H090 — Power-state transitions
**Goal:** Implement D0↔D3hot transitions if the device's PM capability (H071) supports them: enter low-power state, verify the transition by reading back the PMCSR power-state field (H071) showing D3hot, recording the field value; power-draw claims are forbidden unless a named, present sensor is cited; resume returns to ready per H076.
**Acceptance criteria:**
- If supported: 20 suspend/resume cycles complete with the device returning to ready each time; resume time recorded and within 2× the boot budget's resume allowance (documented).
- If unsupported: a test asserts the transition function returns a named `PowerManagementUnsupported` citing the H071 evidence — the absence is handled, not ignored.
- U1–U4.

## H091 — Unexpected-removal handling
**Goal:** Handle surprise device removal (unplug): detect the vanished device via failed register access patterns, fail closed with a named `DeviceRemoved` error, and release all mappings cleanly without crashing the process.
**Acceptance criteria:**
- Simulated removal (test hook severing the BAR mapping) triggers `DeviceRemoved` within 1 second; the process exits the driver session cleanly (no segfault, no hang — verified by the test harness watching the process).
- All fds and mappings are released on this path (verified by fd-count before/after in the test).
- U1–U4.

## H092 — Concurrent-access guard
**Goal:** Implement single-owner device guarding: a lock file / PID-recorded lock so two Aesir processes cannot drive the device simultaneously and corrupt its state.
**Acceptance criteria:**
- A second process attempting discovery while the first holds the device gets a named `DeviceBusy` error naming the holder PID; after the first exits, the second succeeds (tested with real subprocesses).
- Stale lock (holder PID no longer exists) is detected and reclaimed with a warning logged — tested by killing -9 the holder mid-session.
- U1–U4.

## H093 — Bring-up stress: 1000 cold boots unattended
**Goal:** Run 1,000 unattended cold-boot cycles (scripted, overnight-capable) to shake out rare bring-up flakes before the wall assault depends on a stable device.
**Acceptance criteria:**
- 1,000/1,000 boots reach ready; `data/hailbru/boot_stress_1000.json` records per-boot outcome and timing; zero unexplained failures (any failure stops the run and is root-caused in the DEVLOG before resuming).
- Boot-time distribution across the 1,000 is compared to the H085 budget: 99th percentile must be within budget, or the budget is revised with justification.
- Cold boots in this slice follow the `docs/hailbru/COLD_BOOT_DEFINITION.md` definition (H081); the slice records which option was used per cycle ((a) full reboot + power cycle + rebind, or (b) driver-level re-enumeration), and under (a) the reboot mechanism and expected per-cycle wall time.
- U1–U4.

## H094 — Thermal profile during boot
**Goal:** Record the device's thermal behavior across boot and reset cycles using the H087 hooks: temperature at boot start, at ready, and after 100 rapid reset cycles.
**Acceptance criteria:**
- `data/hailbru/thermal_boot_profile.json` contains the three measurement series; temperature rise from 100 rapid resets is quantified (ΔT recorded).
- If ΔT exceeds 15°C (in calibrated units) or the raw-unit equivalent documented in H087, a thermal caution is filed in the DEVLOG with a proposed mitigation slice — measured, then judged.
- U1–U4.

## H095 — Phase-C gate: cold→ready→reset→ready 100× zero failures
**Goal:** The Phase-C gate: 100 consecutive full cycles of cold boot → ready → clean reset → ready, zero failures, with the golden snapshot verified after every 10th cycle.
**Acceptance criteria:**
- 100/100 cycles complete; `data/hailbru/phase_c_gate.json` records per-cycle timings and the 10 snapshot verifications (all matching the H082 golden snapshot within volatile masks).
- `docs/hailbru/PHASE_C_GATE.md` states GO or NO-GO; NO-GO names the failing cycle number and symptom, blocking C6.
- Cold boots in this slice follow the `docs/hailbru/COLD_BOOT_DEFINITION.md` definition (H081); the slice records which option was used per cycle ((a) full reboot + power cycle + rebind, or (b) driver-level re-enumeration), and under (a) the reboot mechanism and expected per-cycle wall time.
- U1–U4.

## H096 — Known-good register map snapshot (extended golden)
**Goal:** Extend the H082 snapshot into the full known-good register map: every documented register's expected value/mask in each device state (post-reset, booting, ready, in-reset) — the reference VÖRÐR will diff against in production.
**Acceptance criteria:**
- `data/hailbru/register_map_golden.json` covers ≥40 registers × 4 states; each entry has value-or-mask plus the evidence source (probe log or doc citation).
- A diff tool (`regdiff`, TEST-ONLY) compares a live dump against the golden map and reports only genuine deviations (volatile-masked bits never reported) — validated against 3 scripted deviation injections, all 3 caught, zero false positives on 10 clean dumps.
- U1–U4.

## H097 — Register-drift detector
**Goal:** Build the runtime register-drift detector: periodic background comparison of live registers against the H096 golden map, emitting a structured drift event on deviation — VÖRÐR's early-warning radar.
**Acceptance criteria:**
- The detector runs for 1 hour on an idle-but-ready device with zero drift events (baseline calm recorded); then 3 injected deviations are each detected within 5 seconds with the correct register named.
- Detector overhead is measured: <1% CPU on the Pi 5 during the 1-hour run (measured, not asserted).
- The detector uses only the H079 API (L12).
- U1–U4.

## H098 — Bring-up documentation: HAILO_BRINGUP_GUIDE.md
**Goal:** Write the clean-room bring-up guide from everything learned: the full cold-boot, reset, and recovery sequences in original prose, so the knowledge survives even if the code is rewritten.
**Acceptance criteria:**
- `docs/plunder/HAILO_BRINGUP_GUIDE.md` documents every step with register citations, timing budgets, failure modes, and recovery actions; a reader following it with the HAILBRÚ API can bring the device up without reading the source.
- The guide is validated by a second pass: the builder re-derives the H081 orchestrator's step order from the guide alone and confirms they match (discrepancies fixed in whichever is wrong, recorded in DEVLOG).
- U1–U4.

## H099 — Bring-up failure-mode catalog
**Goal:** Catalog every failure mode observed or credibly hypothesized during bring-up: symptom, register signature, likely cause, recovery action, and which slice handles it — the field manual for VÖRÐR.
**Acceptance criteria:**
- `docs/hailbru/FAILURE_MODES.md` lists ≥12 failure modes; each has all five fields filled; observed modes cite the log evidence, hypothesized modes are explicitly marked HYPOTHESIZED with the reasoning.
- Every observed mode has a corresponding handling slice (built or named with an ID) — no observed failure left without an owner.
- U1–U4.

## H100 — C5 review: Phase-C gate document
**Goal:** Review Campaign C5 as a gate: bring-up reliability statistics, golden maps, failure catalog completeness, and VÖRÐR hook readiness, ending with an explicit verdict on entering the wall assault.
**Acceptance criteria:**
- `docs/hailbru/C5_REVIEW.md` contains the reliability table (cycles run, failures, MTBF-style statistics), the review of H081–H099 evidence, and a "C5 VERDICT" of READY or NOT-READY for Phase D.
- The review confirms the device can be brought to ready deterministically enough that SMIÐR experiments will be interpretable (flaky hardware would poison the wall verdict — this is stated explicitly).
- U1–U4.

# Campaign C6 — THE WALL ASSAULT (SMIÐR, Phase D — both branches)

*Domain: D3 SMIÐR (clean-room protocol research → self-generated chip configurations) + D2 HAILBRÚ transport + D1 ARMVEGR CPU reference. THE WALL: attempt minimal compute (tiny vector op / matmul) with self-generated chip configuration; verify BIT-EXACT vs ARMVEGR CPU reference. Go gate: one op on-chip, bit-exact, repeatable. NO-GO: execute fallback F1 immediately, bank learnings as F3. Slices H101–H110 are the shared assault; H111 is the decision gate; H112–H114 require H111=GO; H115–H120 require H111=NO-GO. Every slice includes U1–U4. SMIÐR generates configurations WITHOUT the Dataflow Compiler; L3/L4/L5/L6 bind every slice.*

## H101 — Command-queue mechanism research
**Goal:** From the H005 transport guide and live register probing, determine the command-queue mechanism: where queues live (host memory vs device memory), how the host enqueues (ring buffer + doorbell), and how completion is signaled — the prerequisite for submitting any compute.
**Acceptance criteria:**
- `docs/plunder/HAILO_COMMAND_QUEUE.md` describes the queue model in original prose with cited evidence per claim (study citation + probe observation); any claim without live corroboration is marked UNCORROBORATED.
- The document names the exact registers/DMA structures H102 will use, with offsets and widths.
- U1–U4.

## H102 — Command-submission transport via HAILBRÚ
**Goal:** Implement raw command submission through the H079 API: enqueue a no-op/ping command descriptor, ring the doorbell, and observe a completion signal — transport proven before any real compute is attempted.
**Acceptance criteria:**
- A no-op command submitted on Mimir produces an observable completion (interrupt via H070 or status-register completion bit) within the documented timeout; the full transaction trace is saved to `data/smidr/first_command_trace.json`.
- 100 consecutive no-op submissions complete with zero losses and completions matched 1:1 to submissions (sequence-number accounting exact).
- No-op is genuinely side-effect-free: the H096 golden register map still matches after the 100 submissions (device state unperturbed).
- U1–U4.

## H103 — Minimal command descriptor builder
**Goal:** Build the pure-Mojo command descriptor constructor: given an operation type and tensor descriptors, emit a well-formed command buffer per the H101/H019 findings — SMIÐR's first generative artifact.
**Acceptance criteria:**
- The builder emits descriptors for 3 op types (no-op, memory copy, vector add); each emitted buffer is validated field-by-field against the documented layout by an independent TEST-ONLY checker (not the builder's own code).
- Malformed inputs (zero-length tensors, null descriptors) fail closed with named errors before any bytes are emitted.
- U1–U4.

## H104 — Tiny vector-add chip configuration generator
**Goal:** SMIÐR generates its first real chip-executable configuration: a tiny vector-add (FP16, length 64) with input/output tensor placement, expressed entirely from the clean-room findings — no Dataflow Compiler, no HEF, no vendor tool in the path.
**Acceptance criteria:**
- The generator's output is a complete, self-contained configuration package (bytes + manifest describing each section's purpose); the manifest is human-readable and every section is traceable to a H019 surface element.
- The generator is deterministic: same inputs → byte-identical output across 10 runs.
- A TEST-ONLY validator confirms the configuration references only documented structures (no magic bytes without a documented meaning).
- U1–U4.

## H105 — Vector-add execution on chip (first compute)
**Goal:** Execute the H104 configuration on the Hailo-10 via the H102 transport: stage inputs in DMA buffers, submit, wait for completion, read back outputs — the first compute ever attempted on-chip by Aesir.
**Acceptance criteria:**
- The execution completes (completion signaled, output buffer readable) on Mimir; input/output buffer addresses, command sequence numbers, and completion status are recorded in `data/smidr/first_compute.json`.
- The device remains in the golden ready state afterward (H096 diff clean) — the compute didn't wedge the chip.
- If execution fails, the failure is captured with full register dump and command trace; the slice is still complete (a documented failed attempt is evidence), but H106 is then marked BLOCKED pending diagnosis.
- U1–U4.

## H106 — Bit-exact verification vs ARMVEGR CPU reference
**Goal:** Verify the on-chip vector-add result against the ARMVEGR CPU reference: the SAME inputs run through the D1 FP16 vector-add kernel must produce BIT-IDENTICAL outputs (FP16 exact equality, not tolerance) — the wall's pass/fail criterion.
**Acceptance criteria:**
- 100 random input vectors (length 64, FP16): on-chip output is bit-identical to the ARMVEGR reference on all 100 (compared as raw uint16 bit patterns; the comparison script and its PASS/FAIL log are saved).
- Any single bit mismatch fails the slice loudly with the mismatching lane indices and values recorded — no tolerance smuggling at this stage.
- U1–U4. Requires H105 success.

## H107 — Tiny matmul chip configuration generator
**Goal:** Extend the generator to a tiny matmul (FP16, 16×16×16): the operation that actually matters for transformers, with weight/input/output placement and accumulation semantics expressed from clean-room findings.
**Acceptance criteria:**
- Generated configuration passes the H104-style validator; determinism holds (10 runs byte-identical).
- The generator documents its assumption about the chip's matmul dataflow (which operand is stationary, accumulation width) with each assumption marked ASSUMPTION and the experiment that will confirm it (H108).
- U1–U4. Requires H106 PASS (vector-add bit-exact first — earn the harder op).

## H108 — Matmul on-chip execution
**Goal:** Execute the H107 matmul configuration on-chip and read back the 16×16 result — the transformer-relevant compute proof.
**Acceptance criteria:**
- Execution completes with completion signaled; the result matrix is recorded in `data/smidr/first_matmul.json` alongside inputs.
- Device remains golden-ready afterward (H096 diff clean).
- If the result is wrong but execution completed, the raw wrong result is preserved verbatim (evidence for diagnosis, not discarded).
- U1–U4. Requires H107.

## H109 — Bit-exact matmul verification
**Goal:** Verify the on-chip matmul against the ARMVEGR FP16 GEMM reference (H023): bit-identical on the 16×16 case, then on 10 random 16×16×16 problems.
**Acceptance criteria:**
- 10/10 random problems bit-identical (uint16 comparison) to the H023 kernel output; PASS/FAIL log saved.
- If accumulation-width assumptions (H107) cause systematic 1-ULP differences, the difference pattern is characterized (not hand-waved): exactly which lanes differ and by how much, recorded — then the slice FAILS honestly and the assumption is revised, not the criterion.
- U1–U4. Requires H108.

## H110 — TEST-ONLY (PRÓF): repeatability verification suite (1000×)
**Goal:** A Python (PRÓF, TESTS ONLY) suite proving the on-chip ops are repeatable: 1,000 consecutive vector-add and 1,000 consecutive matmul executions, every result bit-identical to the first and to the CPU reference.
**Acceptance criteria:**
- `prof/smidr/test_repeatability.py` runs 2,000 executions via the Mojo compute binary; asserts 2,000/2,000 bit-identical; records timing distribution (p50/p99) in `data/smidr/repeatability.json`.
- A single mismatch aborts with the execution index and the differing bits — repeatability is binary, not statistical.
- U1–U4. Requires H109 PASS.

## H111 — Phase-D go/no-go decision gate
**Goal:** Hold the Phase-D decision gate: assemble the wall-assault evidence (H101–H110) into an explicit GO (wall breached: one op on-chip, bit-exact, repeatable) or NO-GO (intractable) verdict that routes the rest of the campaign.
**Acceptance criteria:**
- `docs/smidr/PHASE_D_GATE.md` contains the evidence table (every H101–H110 slice, verdict, evidence path) and a "PHASE D VERDICT" section stating exactly `GO` or `NO-GO` — no third option, no hedging language.
- GO requires: H106 PASS + H109 PASS + H110 PASS (all three, documented). NO-GO requires: a written technical account of the blocking finding (what was tried, what the chip did, why the path is judged intractable within campaign bounds).
- The verdict is dated and signed in the DEVLOG; all downstream slices check this verdict value.
- U1–U4.

## H112 — [requires H111=GO] Phase-D GO gate formal record
**Goal:** Formalize the breach: record exactly what was achieved (which ops, what precision, what throughput measured), freeze the working configuration generator version, and tag the repo state.
**Acceptance criteria:**
- `docs/smidr/WALL_BREACHED.md` states the breached capability precisely (op list, shapes, bit-exactness proof paths, measured p50/p99 latencies from H110) with no extrapolation beyond what was measured.
- The generator version that produced the verified configurations is tagged in git; the tag name and commit hash are recorded in the document.
- U1–U4.

## H113 — [requires H111=GO] On-chip compute capability matrix
**Goal:** Map the verified on-chip compute surface: for each op proven in C6, record supported shapes, dtypes, and measured latency — the contract SKIPTI (C7) will dispatch against.
**Acceptance criteria:**
- `data/smidr/capability_matrix.json` lists each verified op with: min/max shapes tested, dtype, bit-exactness proof reference, p50/p99 latency; any shape NOT tested is absent from the matrix (SKIPTI may not dispatch untested shapes — enforced by a test in C7).
- Before the matrix is frozen, SMIÐR extends the H104/H107 generator to every op/shape/dtype class H128 requires (including Q8_0 quantized GEMM at hidden size >= 1024); each new class gets its own H106/H109-style proof (FP16 classes bit-exact; quantized classes within the H031/H032 contract); the matrix lists per-class proof paths. H128 may test only classes present in the matrix.
- Until the H121 anti-overreach test passes, H113's status is PROVISIONAL (recorded in the ledger); it becomes FINAL when H121 passes.
- U1–U4.

## H114 — [requires H111=GO] Banked learnings (F3 partial)
**Goal:** Bank the assault's durable knowledge as F3 deliverables: the transport guide, config-surface findings, and generator design, packaged so they survive even if later phases fail.
**Acceptance criteria:**
- `docs/plunder/` gains a `BANKED_ASSAULT_INDEX.md` pointing at every C6 artifact with a one-line description; each linked document is verified complete (no "TBD" sections — grep for TBD/TODO returns zero hits in the banked docs).
- `THIRD_PARTY_NOTICES.md` is reviewed: every studied source is attributed, and the clean-room log covers all of C6's study activity.
- U1–U4.

## H115 — [requires H111=NO-GO] NO-GO verdict + F1 trigger record
**Goal:** Execute the NO-GO branch opening: record the verdict's consequences, formally trigger fallback F1 (the guaranteed CPU deliverable), and re-scope the remaining campaigns to the CPU path — no drift, no denial.
**Acceptance criteria:**
- `docs/smidr/FALLBACK_TRIGGERED.md` states: the NO-GO verdict (citing H111), the F1 scope (fully working pure-Mojo ARM64 CPU inference engine hardened by VÖRÐR+GAUNTLET), and the re-scoped campaign plan (which C7–C10 slices execute in CPU-only mode, listed by ID).
- The trigger is announced in the DEVLOG with the date; from this point, any slice claiming NPU capability fails review.
- U1–U4.

## H116 — [requires H111=NO-GO] F1 CPU pipeline completion plan
**Goal:** Plan the F1 completion: gap analysis of the C2/C3 CPU pipeline (what's missing for a production-grade CPU engine: batching, full pipeline orchestration, packaging) with each gap assigned to a specific C7–C10 slice ID.
**Acceptance criteria:**
- `docs/fallback/F1_COMPLETION_PLAN.md` lists every gap with: description, owning slice ID (from C7–C10 CPU variants), and acceptance summary; zero gaps unowned.
- The plan explicitly states what F1 will NOT include (no NPU claims anywhere) — honest scope, written down.
- U1–U4.

## H117 — [requires H111=NO-GO] F2 partial-acceleration survey
**Goal:** Survey what the assault DID yield that could partially accelerate the CPU path: any documented interface, DMA engine, or on-chip function that proved usable short of full compute (F2: partial acceleration of whatever documented interfaces yield).
**Acceptance criteria:**
- `docs/fallback/F2_SURVEY.md` lists each candidate interface with: what it does, the evidence it works (citing C6 logs), the expected speedup mechanism, and the risk — or explicitly states "no viable F2 interface found" with the examined-and-rejected list.
- No candidate is claimed without a measured microbenchmark (even a rough one, methodology documented).
- U1–U4.

## H118 — [requires H111=NO-GO] F3 banked assault: driver + protocol docs
**Goal:** Package the full F3 durable deliverable: the HAILBRÚ driver, all clean-room protocol docs, the bring-up guides, and the assault's negative results — a complete, honest record of the attempt.
**Acceptance criteria:**
- `docs/plunder/BANKED_ASSAULT_INDEX.md` (same index as H114's, now in the NO-GO branch) covers all C4–C6 artifacts; a completeness check (script) verifies every linked path exists and no banked doc contains TBD/TODO.
- The negative results (what was tried, exact failure signatures) are documented with the same care as successes — future attempts must be able to start where this one stopped.
- U1–U4.

## H119 — [requires H111=NO-GO] Campaign re-scope: C7–C10 CPU-only execution order
**Goal:** Rewrite the C7–C10 execution plan for the CPU-only F1 path: confirm which slices run (CPU variants), which are skipped (NPU-only), and the new dependency chain — the roadmap stays executable, not aspirational.
**Acceptance criteria:**
- `docs/fallback/RESCOPED_PLAN.md` lists every H121–H200 slice with RUN (CPU variant), SKIP (NPU-only, with reason), or RUN-AS-IS; the dependency chain is re-validated (no slice depends on a skipped slice — checked by a script over the slice list).
- U1–U4.

## H120 — C6 review: wall-assault retrospective
**Goal:** Review Campaign C6 honestly in both branches: what was attempted, what the chip actually did, what was learned, and what the verdict means — the campaign's most important document.
**Acceptance criteria:**
- `docs/smidr/C6_REVIEW.md` contains: attempt timeline, evidence table, the H111 verdict restated, branch-specific outcomes (GO: capability summary; NO-GO: blocking analysis + fallback status), and lessons for any future assault.
- In the NO-GO branch, the review explicitly affirms the F1 guarantee ("the CPU engine ships regardless") with the evidence that the CPU path is real (citing H059's coherent run).
- U1–U4.

# Campaign C7 — OFFLOAD ENGINE + PIPELINE (SKIPTI + BRUNNPÍPA, Phases E/F)

*Domains: D4 SKIPTI + D5 BRUNNPÍPA. GO-branch slices (H121–H135) require H111=GO. CPU/F1-variant slices (H136–H139) require H111=NO-GO and complete the F1 CPU pipeline instead. H140 reviews whichever branch executed. Every slice includes U1–U4. Phase-E go gate: full transformer layer GEMMs on-chip, matching CPU within the quantization contract, faster than NEON. Phase-F victory path: coherent text from a small open LLM via Aesir's own loaders.*

## H121 — [requires H111=GO] SKIPTI dispatch policy
**Goal:** Build SKIPTI's dispatch policy: given an op, shapes, and dtype, decide CPU vs NPU using the H113 capability matrix — dispatching ONLY verified shapes to the NPU, everything else to CPU, with the decision logged.
**Acceptance criteria:**
- For 50 test dispatches spanning verified and unverified shapes: every verified shape dispatches to NPU, every unverified shape dispatches to CPU; a test asserts zero dispatches to NPU for shapes absent from the capability matrix (the anti-overreach test).
- Every decision is logged with op, shapes, chosen backend, and reason; the log is machine-readable JSON lines.
- U1–U4.

## H122 — [requires H111=GO] Tensor placement manager
**Goal:** Build tensor placement: track which tensors live in host memory vs device-visible DMA memory, with explicit placement annotations and move operations — no tensor ever used on the wrong side.
**Acceptance criteria:**
- A placement test: 20 tensors placed per a scripted plan; every compute call asserts placement compatibility before executing, and a deliberately misplaced tensor triggers a named `PlacementViolation` (not silent wrong results).
- Peak device-visible memory is tracked and reported; exceeding a configured budget fails closed with a named error.
- U1–U4.

## H123 — [requires H111=GO] Weight staging to NPU memory
**Goal:** Implement weight staging: convert model weights (via the H045 layout planner) into NPU-side resident tensors once at load time, verified by checksums.
**Acceptance criteria:**
- Staging a 100M-parameter test model's weights completes; per-tensor checksums of staged data match host-side checksums exactly (bit-identical staging).
- Staging is performed once per model load; a second inference run reuses staged weights without re-transfer (verified by transfer-byte counters).
- U1–U4.

## H124 — [requires H111=GO] Activation transfer (host→device)
**Goal:** Implement the per-inference activation transfer path: pinned host buffers → DMA → device-visible memory, with transfer integrity checks.
**Acceptance criteria:**
- 1,000 transfers of a 4096-element FP16 activation: every transfer's device-side checksum matches the host checksum (bit-identical transfer, 1,000/1,000).
- Transfer latency p50/p99 recorded in `data/skipti/transfer_latency.json`; p99 ≤ 5× p50 (no pathological tail) or the tail is root-caused in the DEVLOG.
- U1–U4.

## H125 — [requires H111=GO] Transfer/compute overlap scheduler
**Goal:** Build the overlap scheduler: while the NPU computes layer N, transfer layer N+1's activations — hiding transfer latency behind compute.
**Acceptance criteria:**
- On a 12-layer test stack, overlapped execution is measured faster than sequential (transfer+compute) by ≥ 20% wall-clock (measured, methodology in DEVLOG); if overlap yields <20%, the bottleneck is analyzed rather than the claim fudged.
- Correctness preserved: overlapped results bit-match sequential results on 50 runs (overlap introduces no races — verified by comparison, plus a stress run of 500 iterations).
- U1–U4.

## H126 — [requires H111=GO] Backend-selection interface (CPU, NPU, AUTO)
**Goal:** Extend the H036 interface to the full three-way selection: explicit CPU, explicit NPU (fails closed if the op/shape is unverified), and AUTO (the H121 policy) — the interface the pipeline programs against.
**Acceptance criteria:**
- Explicit NPU on an unverified shape returns a named `UnverifiedNpuShape` error (fail-closed test with 10 unverified shapes).
- AUTO on the 50-shape H121 corpus reproduces the H121 decisions exactly (policy consistency).
- The interface documentation states the selection contract in one page (`docs/skipti/BACKEND_CONTRACT.md`).
- U1–U4.

## H127 — [requires H111=GO] TEST-ONLY (PRÓF): CPU-shadow verification suite
**Goal:** A Python (PRÓF, TESTS ONLY) suite implementing per-layer CPU-shadow verification: for each transformer layer executed on the NPU, recompute on the ARMVEGR CPU path and compare within the quantization contract.
**Acceptance criteria:**
- `prof/skipti/test_shadow_verify.py` runs a 4-layer test model: every layer's NPU output vs CPU output within the H031/H032 quantization contract bounds (max abs error ≤ 0.05 for Q8 paths, bit-exact where the contract demands it); any violation FAILS the suite with layer index and error magnitude.
- The suite runs the Mojo binaries via subprocess; it never imports engine code.
- U1–U4.

## H128 — [requires H111=GO] Phase-E go gate: full transformer layer GEMMs on-chip
**Goal:** The Phase-E gate: execute ALL GEMMs of a full transformer layer (Q/K/V/O projections + MLP up/down) on-chip, verify against CPU within the quantization contract, and beat the NEON path on speed.
**Acceptance criteria:**
- All 7 GEMMs of a test layer (shapes recorded, hidden size ≥ 1024) run on-chip; every GEMM's output matches the ARMVEGR CPU GEMM within max abs error ≤ 0.05 (quantization contract); 0 violations across 20 random weight sets.
- End-to-end layer time (NPU path incl. transfers) is measured ≥ 1.5× faster than the pure-NEON CPU layer time on Mimir (measured both, same weights, methodology documented) — "faster than NEON" with a number, not an adjective.
- `docs/skipti/PHASE_E_GATE.md` states GO or NO-GO with the evidence table.
- U1–U4.

## H129 — [requires H111=GO] BRUNNPÍPA prefill orchestration
**Goal:** Build prefill orchestration: process the full prompt in one (or chunked) NPU pass, producing the first-token logits and the initial KV-cache state.
**Acceptance criteria:**
- Prefill of a 512-token prompt completes; the resulting KV-cache, compared against a CPU-computed reference cache, matches within the quantization contract at every layer (max abs error ≤ 0.05).
- Chunked prefill (chunks of 128) produces bit-identical KV-cache to unchunked prefill (chunking is numerics-preserving — tested).
- Prefill tokens/sec recorded in `data/brunnpipa/prefill_perf.json`.
- U1–U4.

## H130 — [requires H111=GO] NPU-side KV-cache
**Goal:** Implement the KV-cache resident in device-visible memory: append during decode without host round-trips, with the H050/H051 semantics preserved.
**Acceptance criteria:**
- 256 decode steps append to the NPU-side cache; the final cache state matches a host-side reference cache within the quantization contract (max abs error ≤ 0.05 per layer).
- No per-step host→device cache transfers occur (verified by transfer-byte counters: cache traffic is zero during the 256 steps).
- Cache-full (position ≥ max) fails closed with a named error, consistent with H050.
- U1–U4.

## H131 — [requires H111=GO] Decode loop on NPU
**Goal:** Build the NPU decode loop: single-token GEMV-class ops per step (dispatched per the H121 policy — GEMV may stay on CPU if unverified there), sampler on host, loop until EOS or max tokens.
**Acceptance criteria:**
- 100-token decodes complete 20/20 times without device errors; per-step latency p50/p99 recorded in `data/brunnpipa/decode_perf.json`.
- Every step's logits match the CPU-reference logits within the quantization contract (shadow-checked on 5 of the 20 runs via the H127 suite).
- EOS handling: generation stops within 2 tokens of EOS (no runaway), max-tokens cap enforced exactly.
- U1–U4.

## H132 — [requires H111=GO] Generation loop + sampler integration
**Goal:** Integrate the full sampler chain (H053–H057) with the NPU decode loop: temperature, top-k, top-p, repetition penalty applied per step, seed-reproducible.
**Acceptance criteria:**
- With temperature→0 (greedy-equivalent), the NPU pipeline's token sequence matches the pure-CPU pipeline's token sequence EXACTLY for 3 prompts × 50 tokens (end-to-end determinism across backends).
- With a fixed seed and temperature=0.8, two NPU runs produce identical sequences (reproducibility).
- U1–U4.

## H133 — [requires H111=GO] Static batching
**Goal:** Implement static batching (fixed batch size B=4): prefill and decode B sequences concurrently through the NPU path with per-sequence KV-caches and correct padding/masking.
**Acceptance criteria:**
- Batched (B=4) generation produces per-sequence token streams identical to 4 separate unbatched runs (bit-identical token IDs — batching is semantics-preserving, tested on 3 prompt sets).
- Padding tokens never leak into another sequence's context (verified by a probe: a padding-heavy batch vs a no-padding batch give identical non-pad outputs).
- Tokens/sec for B=4 is recorded; per-sequence throughput is reported honestly (not inflated by batch-size multiplication without disclosure).
- U1–U4.

## H134 — [requires H111=GO] Context management (multi-turn)
**Goal:** Implement multi-turn context management: conversation history appended across turns, cache reuse for the shared prefix, and clean session reset.
**Acceptance criteria:**
- A 5-turn conversation reuses the prefix KV-cache (verified: turn N's prefill processes only the new tokens — token counts logged); the final turn's output matches a from-scratch single-prefill run token-for-token (cache reuse is exact).
- Session reset clears all state; a post-reset generation shows zero influence from the prior session (tested with a canary prompt).
- U1–U4.

## H135 — [requires H111=GO] End-to-end: small open LLM coherent text via NPU
**Goal:** The Phase-F path proof: load a real small open LLM with Aesir's own loaders and generate coherent text through the full NPU-accelerated pipeline.
**Acceptance criteria:**
- Same 3 prompts as H059, same sampler settings: ≥50 tokens each of coherent, on-topic text, scored against the frozen `data/armvegr/coherence_rubric.json` from H059 (every item must pass per prompt); full outputs, model SHA-256, and settings stored in `data/brunnpipa/first_npu_coherent.json`.
- No HEF was created/read/parsed/required at any point (asserted by a scan: no `.hef` files under the work tree, and the pipeline code contains no HEF handling — grep verified).
- U1–U4.

## H136 — [requires H111=NO-GO] F1 pipeline completion: CPU prefill + decode end-to-end
**Goal:** (NO-GO branch) Complete the F1 CPU inference pipeline: prefill orchestration and the decode loop on the ARMVEGR CPU path, integrated with the H050–H057 components — the guaranteed deliverable's core.
**Acceptance criteria:**
- 512-token prefill + 100-token decode complete on Mimir for the H059 model; per-step logits match the H051 no-cache recompute within max abs error ≤ 1e-3 (cache correctness on the real model).
- Prefill tokens/sec and decode tokens/sec recorded in `data/fallback/f1_cpu_perf.json` (the honest F1 baseline).
- U1–U4.

## H137 — [requires H111=NO-GO] F1 CPU batching + context management
**Goal:** (NO-GO branch) Bring the H133/H134 capabilities to the CPU path: static batching (B=4) and multi-turn context management on ARMVEGR.
**Acceptance criteria:**
- Same acceptance as H133 (batch-vs-unbatched token identity) and H134 (prefix cache reuse exactness, session reset cleanliness), executed on the CPU path; all pass.
- U1–U4.

## H138 — [requires H111=NO-GO] F1 coherent text from small open LLM (CPU, production config)
**Goal:** (NO-GO branch) The F1 proof: coherent text from a real small open LLM on the production CPU pipeline configuration (the exact binary and settings that will ship).
**Acceptance criteria:**
- 3 prompts × ≥50 tokens, coherent per the frozen `data/armvegr/coherence_rubric.json` from H059 (every item must pass per prompt); outputs, model SHA-256, sampler settings, binary version, and the exact command line stored in `data/fallback/f1_coherent_proof.json` — reproducible by a third party with the repo and the model file.
- U1–U4.

## H139 — [requires H111=NO-GO] SKIPTI AUTO = CPU-only honest mode
**Goal:** (NO-GO branch) Configure SKIPTI's AUTO mode to resolve everything to CPU, loudly: every dispatch logs "NPU unavailable (Phase-D NO-GO), using verified CPU path" — honest degradation per L11, never a silent fallback.
**Acceptance criteria:**
- 50 dispatches across ops/shapes: 50/50 resolve to CPU; 50/50 log lines contain the NPU-unavailable reason string (verified by log grep in the test).
- No code path can select NPU in this mode (a test attempts explicit NPU selection and gets a named `NpuUnavailable` error citing the H111 verdict).
- U1–U4.

## H140 — C7 review: Phase-E/F gate document (branch-aware)
**Goal:** Review Campaign C7 in whichever branch executed: GO branch → Phase-E gate evidence plus Phase-F pipeline proof; NO-GO branch → F1 pipeline completion evidence. Explicit verdict either way.
**Acceptance criteria:**
- `docs/skipti/C7_REVIEW.md` (GO) or `docs/fallback/C7_REVIEW.md` (NO-GO) contains the per-slice evidence table and a "C7 VERDICT" of GO/NO-GO (pipeline) or F1-COMPLETE/F1-INCOMPLETE.
- The review states precisely what the campaign proved about heterogeneous offload (GO) or about the CPU engine's production readiness (NO-GO) — no claims beyond the evidence.
- U1–U4.

# Campaign C8 — ROBUSTNESS & SELF-HEALING (VÖRÐR)

*Domain: D6 VÖRÐR. Health monitoring, watchdog/supervisor, device reset/re-init, error taxonomy, crash-resistant recovery, CPU shadow-verification. Commands resets ONLY through HAILBRÚ's interface; never pokes registers itself (L12). In the NO-GO branch, VÖRÐR supervises the CPU pipeline (thermal throttling detection, process supervision, honest degradation). Every slice includes U1–U4.*

## H141 — VÖRÐR module skeleton + health-monitor loop
**Goal:** Create the D6 package (`vordr/`): the supervisor skeleton and the periodic health-monitor loop that samples device health via the H087 hooks and evaluates it against policy — the frame everything in C8 hangs on.
**Acceptance criteria:**
- The monitor loop runs for 10 minutes on a ready device (or on the CPU pipeline in the NO-GO branch), sampling every 5 seconds; all 120 samples are recorded with zero loop crashes and zero missed samples beyond a 1-second tolerance.
- The loop exposes start/stop/status with clean shutdown (no thread left running after stop — verified by thread count).
- `vordr/` imports the HAILBRÚ API but performs no direct register access (L12 verified by grep for raw offsets outside `hailbru/`).
- The H087 hooks are moved (not copied) from `hailbru/health_obs.mojo` to `vordr/health_obs.mojo` (still L12-clean); post-move, `hailbru/` contains no health-hook implementation (grep-verified); the relocation is recorded in the H087 DEVLOG entry.
- U1–U4.

## H142 — Temperature monitoring (device + Pi SoC)
**Goal:** Implement continuous temperature monitoring: device temperature via HAILBRÚ registers plus the Pi 5 SoC temperature via the thermal zone sysfs — with warning/critical thresholds in a data file.
**Acceptance criteria:**
- `data/vordr/thermal_thresholds.json` defines warn/critical levels for both sensors with the unit basis documented (calibrated or raw-per-H087, stated honestly).
- A 30-minute monitoring run records both series; crossing a threshold (test hook lowers the threshold) emits a structured `ThermalWarning` event within 10 seconds — threshold logic proven, not just the sensor read.
- U1–U4.

## H143 — Hang detection (inference heartbeat)
**Goal:** Implement inference-hang detection: every NPU op (or CPU pipeline stage in NO-GO) must complete within its budgeted time; a missed heartbeat triggers a structured hang event with the in-flight operation's identity.
**Acceptance criteria:**
- Budgets per op are derived from measured p99 latencies (H110/H131 data or CPU perf data) × 3, documented in `data/vordr/hang_budgets.json` with the derivation shown.
- A test hook stalling an op triggers the hang event within budget+5s; 1,000 normal ops produce zero false positives.
- U1–U4.

## H144 — Error register polling + decode
**Goal:** Implement error-register polling: read the device's error/status registers on the monitor cadence, decode set bits into named error conditions per the register docs — turning silent hardware faults into named events.
**Acceptance criteria:**
- Every documented error bit has a decoder entry (name, meaning, severity); a test sets each bit via a test hook (or a scripted register image) and asserts the correct named condition is emitted — 100% bit coverage of the documented error registers.
- Undocumented set bits are reported as `UnknownErrorBit(offset, bit)` — never ignored, never mislabeled.
- U1–U4.

## H145 — Error taxonomy document
**Goal:** Write the VÖRÐR error taxonomy: every error condition classified as TRANSIENT (retry), PERSISTENT (reset + re-init), or FATAL (fail closed, operator needed), with the classification rationale per condition.
**Acceptance criteria:**
- `docs/vordr/ERROR_TAXONOMY.md` classifies all conditions from H144 plus software-side errors (timeout, placement violation, checksum mismatch); each classification has a one-paragraph rationale.
- A TEST-ONLY test loads the taxonomy and asserts every named error the codebase can raise appears in it exactly once (taxonomy completeness is machine-checked, not eyeballed).
- U1–U4.

## H146 — Watchdog/supervisor process
**Goal:** Build the watchdog supervisor: a separate process that monitors the inference process's heartbeat, restarts it on death per policy, and keeps a restart log — crash-resistance at the process level.
**Acceptance criteria:**
- Killing the inference process (SIGKILL) 10 times: the watchdog restarts it 10/10 times within 5 seconds each; the restart log records all 10 with timestamps and exit signals.
- Restart backoff: 5 rapid deaths trigger escalating delays (policy in a data file: delays 1s, 2s, 4s, 8s…); the 5th restart's delay is verified ≥ 8s (anti-restart-storm behavior proven).
- The watchdog itself dying is detected by a documented external mechanism (systemd unit file or a parent monitor — implemented, not hand-waved).
- U1–U4.

## H147 — Device reset via HAILBRÚ interface
**Goal:** Implement VÖRÐR-commanded device reset: VÖRÐR calls HAILBRÚ's `reset()` (never touching registers itself), then verifies post-reset state — the recovery primitive for PERSISTENT errors.
**Acceptance criteria:**
- 50 commanded resets complete; every reset is followed by a golden-map comparison (H096) confirming the expected post-reset state 50/50.
- The call path is audited: VÖRÐR→HAILBRÚ API call graph contains no register-level access (review note in DEVLOG citing the grep evidence).
- U1–U4.

## H148 — Re-init sequence after reset
**Goal:** Implement the post-reset re-initialization: BAR re-validation, firmware state check (re-run boot handshake only if the firmware didn't survive reset — determined by probe, not assumption), DMA buffer re-establishment, and return to ready.
**Acceptance criteria:**
- 50 reset→re-init cycles reach ready; per-cycle re-init time recorded; whether firmware survives reset is determined empirically in-slice and documented (one or the other, with the probe evidence — no guessing).
- Re-init after a simulated failed reset (test hook) fails closed with a named error rather than proceeding on a half-reset device.
- U1–U4.

## H149 — Crash-resistant recovery state machine
**Goal:** Build the recovery state machine: IDLE → DEGRADED (transient) → RESETTING (persistent) → REINITING → VERIFYING → IDLE, with transitions driven by the H145 taxonomy and every transition logged.
**Acceptance criteria:**
- A scripted scenario walk (transient error → recovery, persistent error → reset+re-init, fatal error → fail-closed halt) executes all transitions; the transition log matches the expected sequence exactly for all 3 scenarios.
- Illegal transitions (e.g., VERIFYING→RESETTING) are rejected by the state machine with a named error (tested with 5 illegal transition attempts).
- U1–U4.

## H150 — CPU shadow-verification of NPU results (production sampler)
**Goal:** Productionize the H127 shadow concept as a runtime sampler: VÖRÐR randomly re-runs a configurable fraction of NPU layer executions on the CPU path and compares within the quantization contract — continuous correctness surveillance.
**Acceptance criteria:**
- With shadow fraction 10%, a 100-layer-execution run performs exactly 10 shadow verifications (±1); all 10 pass within contract; the sampling is unpredictable (seeded RNG, seed logged).
- A test hook corrupting one NPU result triggers a `ShadowMismatch` event naming the layer — the surveillance actually catches faults (not decorative).
- In the NO-GO branch, this slice instead implements cross-check between two CPU numerics paths (kernel vs scalar) at the same sampling rate — same surveillance discipline, honest scope.
- U1–U4.

## H151 — TEST-ONLY (PRÓF): fault injection — register errors
**Goal:** A Python (PRÓF, TESTS ONLY) fault-injection suite: scripted error-register bit patterns fed through a test hook, asserting VÖRÐR decodes each (H144), classifies it (H145), and takes the taxonomy-prescribed action.
**Acceptance criteria:**
- `prof/vordr/test_fi_registers.py` injects ≥10 distinct error patterns; each produces the expected named condition AND the expected recovery action (retry/reset/halt) — action verified, not just detection.
- The suite runs against the Mojo VÖRÐR binary via the test-hook interface; it never touches real device registers directly.
- U1–U4.

## H152 — TEST-ONLY (PRÓF): fault injection — hangs
**Goal:** A Python (PRÓF, TESTS ONLY) suite injecting operation hangs (stalled completions via test hook), asserting the H143 detector fires within budget and the recovery state machine engages.
**Acceptance criteria:**
- `prof/vordr/test_fi_hangs.py` injects 20 hangs across different ops; all 20 are detected within budget+5s; all 20 drive the state machine to the taxonomy-prescribed outcome (retry or reset+re-init).
- Post-recovery, the pipeline resumes correct operation (a verification inference matches the pre-fault reference) — recovery is proven functional, not just procedural.
- U1–U4.

## H153 — TEST-ONLY (PRÓF): fault injection — device removal
**Goal:** A Python (PRÓF, TESTS ONLY) suite simulating surprise device removal mid-inference, asserting the H091 path engages: named `DeviceRemoved`, clean mapping release, watchdog-aware halt, no process crash.
**Acceptance criteria:**
- `prof/vordr/test_fi_removal.py` triggers removal at 3 different pipeline stages (prefill, decode step, weight staging or their CPU equivalents); all 3 produce the named error, clean resource release (fd-count verified), and no segfault.
- In the NO-GO branch, this suite instead simulates critical resource exhaustion (OOM-style allocation failure) with the same fail-closed assertions.
- U1–U4.

## H154 — TEST-ONLY (PRÓF): fault injection — corrupt DMA data
**Goal:** A Python (PRÓF, TESTS ONLY) suite corrupting DMA transfer payloads (bit flips via test hook), asserting the checksum/integrity layer catches every corruption before the data reaches compute.
**Acceptance criteria:**
- `prof/vordr/test_fi_dma_corrupt.py` injects 500 single-bit flips across transfers; 500/500 are detected by integrity checks before compute consumes the data (zero escapes — the escape count is the headline metric and must be 0).
- Detected corruptions trigger re-transfer (transient) per the taxonomy; the re-transferred data verifies clean.
- In the NO-GO branch, this suite corrupts host-side staging buffers with identical detection assertions.
- U1–U4.

## H155 — Recovery-time budgets (measured under fault)
**Goal:** Measure recovery times under each fault class: transient retry, reset+re-init, and full process restart — and set the official recovery budgets from the measurements.
**Acceptance criteria:**
- `data/vordr/recovery_budgets.json` records p50/p99 for each recovery class over ≥30 samples each; official budgets are set at p99 × 2, documented with the derivation.
- Every recovery completes within its budget in a final 10-sample confirmation run, or the budget is revised with justification (budgets follow measurements, not wishes).
- U1–U4.

## H156 — Error correction: retry with backoff
**Goal:** Implement the transient-error correction policy: bounded retries with exponential backoff and jitter, per the taxonomy — the first line of self-healing.
**Acceptance criteria:**
- A transient fault injected 3 times in a row is absorbed: the operation succeeds on a retry and the caller sees success with a `recovered_after_retries: N` annotation in the log (correction is observable, not silent).
- Retry count is bounded (policy: max 5); exceeding it escalates to PERSISTENT handling (tested: 6 consecutive transient faults → reset path engaged).
- Backoff delays match the policy file within ±20% (measured, not assumed).
- U1–U4.

## H157 — Error correction: recompute on CPU after NPU fault (honest degrade)
**Goal:** Implement honest degradation: when an NPU operation fails persistently but the device is otherwise alive, recompute that operation on the verified CPU path, log the degradation loudly, and continue — per L11 (degrade honestly, never silently).
**Acceptance criteria:**
- With the NPU op faulted (test hook), the layer completes via CPU recompute; the output matches the pure-CPU reference within the quantization contract; the log contains a `DEGRADED` event naming the op, the cause, and the fallback — verified present by log grep in the test.
- Degradation is per-operation and temporary: the next healthy op goes back to the NPU (no sticky fallback — tested over 20 ops with a single faulted one).
- In the NO-GO branch, this slice implements CPU-pipeline stage retry with the same observability standard.
- U1–U4.

## H158 — VÖRÐR-supervised inference under random fault injection
**Goal:** The C8 integration proof: run full inference (the H135 or H138 pipeline) while the PRÓF fault injector fires random faults (register errors, hangs, DMA corruption) — output must stay coherent and every fault must be handled per the taxonomy.
**Acceptance criteria:**
- A 30-minute supervised run with faults injected at a mean rate of 1 per 60 seconds: inference completes, generated text remains coherent per the frozen `data/armvegr/coherence_rubric.json` from H059 (every item must pass per spot-checked sample), and the fault log shows every injected fault with its taxonomy-prescribed handling (injected count == handled count, reconciled).
- Zero unhandled faults, zero crashes, zero silent degradations (every degrade has its `DEGRADED` log event).
- U1–U4.

## H159 — No-silent-fallback audit
**Goal:** Audit every degradation and fallback path in the codebase for observability: each must emit a structured log event at the moment it engages — proving L11 (fail closed, degrade honestly) is implemented, not just promised.
**Acceptance criteria:**
- `docs/vordr/FALLBACK_AUDIT.md` lists every fallback/degrade code path (found by code search for the degrade primitives), each with the log event it emits; a TEST-ONLY test triggers each path and asserts its event appears in the log — 100% path coverage, zero silent paths.
- Any path found without an event is fixed in-slice (the audit has teeth).
- U1–U4.

## H160 — C8 review: robustness verdict
**Goal:** Review Campaign C8 as a gate: monitoring coverage, recovery budgets, fault-injection results, and the supervised-run evidence, ending with an explicit verdict on whether the system is self-healing and crash-resistant per the campaign's claims.
**Acceptance criteria:**
- `docs/vordr/C8_REVIEW.md` contains: the fault-injection scoreboard (injected/handled/missed per class — missed must be 0), recovery budget table, the H158 supervised-run summary, and a "C8 VERDICT" of ROBUST or NOT-ROBUST.
- NOT-ROBUST names each failing area with a remediation slice ID; the campaign does not proceed to C9 until ROBUST or the gaps are explicitly accepted as known limitations in the document.
- U1–U4.

# Campaign C9 — SPEED OPTIMIZATION

*Cross-cutting (D1 ARMVEGR, D4 SKIPTI, D5 BRUNNPÍPA). Optimize against the H038/H085 baselines with measured, methodology-documented iterations — never fake benchmarks. Every optimization claims only what its measurements prove. Every slice includes U1–U4.*

## H161 — Benchmark harness (repeatable, pinned clocks)
**Goal:** Build the official benchmark harness: pinned CPU clocks, thermal settle wait, warmup runs, 11-trial medians, environment capture (clocks, temp, versions) — the single harness every C9 measurement runs through, per the H038 method.
**Acceptance criteria:**
- `bench/run_bench.mojo` (or the harness entry point) executes a named benchmark and emits `data/bench/<name>.json` with: median/p50, min, max, stddev, trial count, clock settings, start/end SoC temperature, and harness version — every field present on every run.
- Running the same benchmark twice back-to-back yields medians within ±3% (harness stability proven before it's trusted).
- U1–U4.

## H162 — Baseline: ARMVEGR kernel GFLOPS table (official)
**Goal:** Re-measure every C2 kernel through the H161 harness to produce the official pre-optimization baseline table — the "before" photo for all of C9.
**Acceptance criteria:**
- `data/bench/baseline_kernels.json` contains all kernels H022–H035 at the H038 shapes, measured via the H161 harness; any kernel deviating >5% from its H038 number is investigated (methodology drift vs real change, documented).
- The table is frozen (checksummed); later slices compare against this exact file.
- U1–U4.

## H163 — Baseline: end-to-end tokens/sec (official)
**Goal:** Measure the official end-to-end baselines through the H161 harness: prefill tokens/sec and decode tokens/sec for the reference model on the active pipeline (NPU path if GO, CPU path if NO-GO).
**Acceptance criteria:**
- `data/bench/baseline_e2e.json` records prefill and decode throughput (median of 5 runs each, 512-token prefill / 100-token decode, fixed sampler seed); the exact model SHA-256 and command lines are stored alongside.
- These two numbers are the headline figures every later optimization slice must move — stated in the DEVLOG verbatim.
- U1–U4.

## H164 — NEON GEMM tuning iteration 1 (tiling sweep)
**Goal:** First GEMM tuning iteration: sweep Mc/Kc/Nc blocking parameters and micro-kernel tile sizes on Mimir, measuring each configuration through the H161 harness.
**Acceptance criteria:**
- ≥12 configurations swept on the 1024³ and 4096³ shapes; results in `data/bench/gemm_sweep_1.json`; the best configuration is adopted only if it beats the H162 baseline by ≥5% on both shapes (anti-noise threshold).
- Correctness re-verified for the adopted configuration on the full H023 shape matrix (tuning must not break the error contract).
- U1–U4.

## H165 — NEON GEMM tuning iteration 2 (packing + prefetch)
**Goal:** Second GEMM iteration: packed-layout refinements and software prefetch distance tuning on top of the H164 winner.
**Acceptance criteria:**
- Prefetch distances {0, 64, 128, 256 bytes} and 2 packing variants tested; adoption requires ≥3% gain over the H164 winner on 2048³ (measured); results in `data/bench/gemm_sweep_2.json`.
- If no variant clears 3%, the slice documents the negative result and keeps the H164 winner — a documented "no gain" is a complete slice, not a failure.
- U1–U4.

## H166 — Quantized inference path optimization (Q8)
**Goal:** Optimize the end-to-end Q8_0 quantized inference path: fuse dequant+GEMM where profitable, streamline the H033 kernel's M=1 decode case, measure the decode tokens/sec delta.
**Acceptance criteria:**
- Decode tokens/sec (H161 harness, reference model) improves by ≥10% vs the H163 baseline, OR the slice documents precisely why the path is already optimal (roofline argument from H178's method, with measured bandwidth numbers).
- The H031/H032 quantization contracts still hold after optimization (oracle suite H037 re-run green).
- U1–U4.

## H167 — Memory-bandwidth optimization (packing, alignment)
**Goal:** Attack the memory-bound kernels (GEMV H024, attention H034): 64-byte alignment of all hot buffers, packed weight layouts from the H045 planner made the default, measured bandwidth efficiency re-taken.
**Acceptance criteria:**
- H024's 8192² GEMV bandwidth efficiency improves by ≥5 percentage points vs H038 (measured), or the slice documents the achieved efficiency and the remaining gap to the H178 roofline with a reasoned cause.
- All hot allocations are verified 64-byte aligned (test asserts alignment on 20 allocation sites).
- U1–U4.

## H168 — KV-cache memory optimization
**Goal:** Optimize KV-cache memory traffic: FP16→Q8_0 cache quantization option (with a measured quality check), contiguous per-layer layout, and append-path streamlining.
**Acceptance criteria:**
- Optional Q8 cache mode: 256-token decode with Q8 cache produces logits within max abs error ≤ 0.02 of the FP16-cache run (quality contract for the optimization), while decode tokens/sec improves by ≥8% (measured) — both conditions required to ship the mode.
- The mode is opt-in via config (default stays FP16); the config documents the quality/speed tradeoff with the measured numbers.
- U1–U4.

## H169 — Tokenizer throughput optimization
**Goal:** Optimize tokenizer encode throughput (the prefill pipeline's often-ignored tax): merge-table lookup structure, batch encode path.
**Acceptance criteria:**
- Encode throughput on a 10,000-string corpus improves by ≥20% vs the pre-optimization measurement taken in-slice (both via the H161 harness method), with zero change to token IDs (H048 differential suite green).
- U1–U4.

## H170 — Threading: multi-core dispatch on Pi 5
**Goal:** Implement multi-core dispatch across the Pi 5's 4 Cortex-A76 cores for the embarrassingly parallel CPU work (batch GEMMs, multi-head attention, sampler-parallel batching), with a thread-pool in pure Mojo.
**Acceptance criteria:**
- 4-thread execution of the batched (B=4) prefill is ≥2.5× faster than single-thread (measured, H161 harness) — sublinear scaling must be explained by a measured bottleneck (bandwidth saturation shown via counters), not excused.
- Thread-safety: 1,000 parallel dispatches produce results bit-identical to sequential execution (race-freedom proven, not hoped).
- Thread count is configurable; oversubscription (8 threads) degrades gracefully (measured, no crash, no deadlock).
- U1–U4.

## H171 — [requires H111=GO] NPU path optimization
**Goal:** Optimize the NPU execution path: command-batch submission (multiple ops per doorbell where the protocol allows), descriptor reuse, and completion-poll tuning — measured against the H163 NPU baseline.
**Acceptance criteria:**
- Layer time (the H128 measurement) improves by ≥10% vs the pre-optimization re-measurement taken in-slice (both via H161 harness); the H127 shadow suite stays green (optimization didn't break correctness).
- Each optimization technique is A/B measured individually (results in `data/bench/npu_opt.json`) — no bundled "we did three things and it got faster" claims.
- U1–U4.

## H172 — [requires H111=GO] Transfer overlap tuning
**Goal:** Tune the H125 overlap scheduler: layer-granularity vs sub-layer-granularity overlap, double-buffering depth — squeezing the transfer bubble out of the pipeline.
**Acceptance criteria:**
- Overlapped layer-stack time improves by ≥10% vs the H125 measurement (re-measured in-slice for a fair comparison); the overlap-correctness test (bit-match vs sequential, H125) re-passes.
- The achieved overlap efficiency (1 − bubble_time/total_time) is reported as a measured percentage.
- U1–U4.

## H173 — Decode-latency optimization
**Goal:** Minimize per-token decode latency on the active path: fuse the decode step's small ops, eliminate per-step allocations, streamline the sampler hot path.
**Acceptance criteria:**
- Per-token p50 latency improves by ≥15% vs the H163 decode baseline (measured, H161 harness, 100-token runs × 5); zero allocations per decode step after the first (verified by allocation instrumentation — the classic latency killer, proven absent).
- U1–U4.

## H174 — Prefill-throughput optimization
**Goal:** Maximize prefill throughput: chunk-size tuning for the active path, prompt-cache for repeated prefixes, fused prefill kernels where they win.
**Acceptance criteria:**
- 512-token prefill tokens/sec improves by ≥15% vs H163 (measured); chunk-size sweep {64, 128, 256, 512} recorded in `data/bench/prefill_opt.json` with the winner justified by measurement.
- Prompt-cache correctness: cached-prefix prefill produces bit-identical KV-cache to uncached (tested on 10 prefix/prompt pairs).
- U1–U4.

## H175 — Performance budget document
**Goal:** Write the official performance budget: target vs measured for every headline metric (kernel GFLOPS, prefill tok/s, decode tok/s, layer time), with each target justified (roofline-derived or requirement-derived) — the document GAUNTLET will judge against.
**Acceptance criteria:**
- `docs/bench/PERFORMANCE_BUDGET.md` contains the full target-vs-measured table; every target has a justification paragraph; every miss >10% has a named cause and either a remediation slice or an accepted-limitation statement.
- The budget is versioned; future measurements compare against this version (no moving goalposts without a documented revision).
- U1–U4.

## H176 — TEST-ONLY (PRÓF): regression guard — performance tests in the harness
**Goal:** Install performance regression guards: the headline benchmarks become automated tests that FAIL if throughput drops >5% vs the frozen baselines — speed, once earned, is defended.
**Acceptance criteria:**
- `prof/bench/test_perf_regression.py` (TEST-ONLY) runs the 5 headline benchmarks via the H161 harness and fails on >5% regression vs `data/bench/baseline_*.json`; a deliberately slowed kernel (test hook adding a sleep) makes the guard FAIL (proving it bites).
- The guard's runtime is <10 minutes so it can run in routine verification.
- U1–U4.

## H177 — Power/thermal budget measurement
**Goal:** Measure the power and thermal envelope of sustained inference on Mimir: SoC temperature over a 30-minute full-load run, throttle events (vcgencmd or sysfs), and the steady-state temperature.
**Acceptance criteria:**
- `data/bench/thermal_sustained.json` records the 30-minute temperature series; throttle events counted (must be 0 for the production claim, or throttling is characterized with its performance impact measured).
- Steady-state temperature vs the H142 thresholds: the run must stay below the critical threshold, or a mitigation slice is carved before C10.
- U1–U4.

## H178 — Roofline model for the Pi 5 CPU path
**Goal:** Build the honest roofline model: measured peak FP16 (from the best H164/H165 GEMM) and measured memory bandwidth (from H167) plotted against the kernels' arithmetic intensities — showing which kernels are compute-bound vs memory-bound, with measurements, not vendor specs.
**Acceptance criteria:**
- `docs/bench/ROOFLINE.md` contains the roofline plot data (table form, reproducible) with every kernel placed; each kernel's bound (compute/memory) is stated with the measured numbers behind it.
- The model is used to adjudicate one open optimization question from C9 (named in the doc) — the roofline does work, it's not decoration.
- No vendor peak specs are used as "achievable" — only measured peaks appear on the roofline.
- U1–U4.

## H179 — Optimization retrospective (measured)
**Goal:** Write the C9 retrospective: every optimization attempted, its measured delta, what moved the needle and what didn't — the honest accounting of the speed campaign.
**Acceptance criteria:**
- `docs/bench/C9_RETROSPECTIVE.md` tables every C9 optimization slice with: claimed target, measured delta, adopted or rejected, and the evidence path; the total end-to-end improvement (H163 → now, both metrics) is stated as measured percentages.
- Failed optimizations are listed with their negative results — the document is as proud of the rejections as the wins.
- U1–U4.

## H180 — C9 review: speed verdict
**Goal:** Review Campaign C9 as a gate: baseline-to-final deltas, budget compliance (H175), regression guards live, thermal envelope safe — explicit verdict on whether the speed claims are earned and defended.
**Acceptance criteria:**
- `docs/bench/C9_REVIEW.md` contains the before/after table for all headline metrics, the budget compliance verdict per metric, and a "C9 VERDICT" of SPEEDS-EARNED or NOT-YET.
- NOT-YET names the specific metrics and the remediation slices; SPEEDS-EARNED requires all H175 targets met or formally accepted as limitations.
- U1–U4.

# Campaign C10 — PRODUCTION GAUNTLET (GAUNTLET) + FINAL HARDENING

*Domain: D7 GAUNTLET (measures and judges only — never implements) + release engineering. The victory gates: download any small open LLM → run → coherent output → stable multi-hour soak → crash-resistant under fault injection. Every slice includes U1–U4. GAUNTLET slices assert; they do not fix — failures route to named remediation.*

## H181 — GAUNTLET module skeleton (measures and judges only)
**Goal:** Create the D7 package (`gauntlet/`): the measurement and judgment framework — metric collectors, threshold evaluators, and verdict emitters — with a hard architectural rule: GAUNTLET may not import or call any implementation-fixing code paths.
**Acceptance criteria:**
- `gauntlet/` compiles; a test asserts it contains zero calls into repair/recovery/fix functions (architectural self-test: GAUNTLET judges, never implements — enforced by an import-graph check in the test).
- The framework can express a gate as: metric → measurement → threshold → PASS/FAIL verdict with evidence path; 3 example gates are expressed and evaluated against canned data.
- U1–U4.

## H182 — Stability gate definitions
**Goal:** Define the production stability gates as machine-checkable thresholds: soak duration, max error rate, max latency regression, recovery budget compliance, determinism — the contract the release must satisfy.
**Acceptance criteria:**
- `data/gauntlet/STABILITY_GATES.json` defines ≥8 gates, each with: metric, measurement method, PASS threshold (a number), and the slice that produces the measurement; every threshold has a one-sentence justification.
- A TEST-ONLY evaluator loads the gates and evaluates them against canned PASS and canned FAIL datasets, producing the correct verdicts on both (the gates are proven to discriminate).
- U1–U4.

## H183 — TEST-ONLY (PRÓF): multi-hour soak — CPU inference (4h)
**Goal:** A Python (PRÓF, TESTS ONLY) 4-hour continuous CPU inference soak: repeated generations with varied prompts, monitoring for crashes, hangs, slowdowns, and output degradation.
**Acceptance criteria:**
- `prof/gauntlet/test_soak_cpu_4h.py` runs 4 hours of inference (prompts cycled from a fixed corpus of 50); asserts: zero crashes, zero hangs (every generation completes within 5× its p50 time), and tokens/sec in the final 30 minutes within ±10% of the first 30 minutes (no slowdown drift).
- The full generation log is preserved (`data/gauntlet/soak_cpu_4h.log`); any anomaly aborts with the log position attached.
- U1–U4.

## H184 — [requires H111=GO] TEST-ONLY (PRÓF): multi-hour soak — NPU path (4h)
**Goal:** A Python (PRÓF, TESTS ONLY) 4-hour continuous NPU-path soak, same discipline as H183, plus device-health monitoring (temperature, error registers) throughout.
**Acceptance criteria:**
- `prof/gauntlet/test_soak_npu_4h.py` asserts the H183 conditions plus: zero error-register events, device temperature staying below the H142 critical threshold for the full 4 hours, and the H096 golden map still matching at soak end (device unperturbed by 4 hours of compute).
- In the NO-GO branch this slice is SKIPPED per the H119 rescoped plan (recorded as skipped-with-reason in the ledger, not silently dropped).
- U1–U4.

## H185 — Soak log analysis (drift, slowdown detection)
**Goal:** Build the soak-log analyzer: ingest the H183/H184 logs and detect drift — throughput trends, latency creep, temperature ramps, error-rate changes — with statistical tests, not eyeballing.
**Acceptance criteria:**
- The analyzer reports on the completed soak logs: linear-trend slope of tokens/sec per hour with confidence interval; verdict DRIFT-FREE or DRIFT-DETECTED per metric; on the real soak data the verdict must be DRIFT-FREE (or the drift is root-caused before C10 proceeds).
- The analyzer is validated against synthetic logs with injected drift (it detects a 15% linear slowdown) and clean synthetic logs (no false positive).
- U1–U4.

## H186 — TEST-ONLY (PRÓF): crash-resistance fault-injection campaign
**Goal:** A Python (PRÓF, TESTS ONLY) scripted fault-injection campaign against the production binary: the full C8 fault battery (register errors, hangs, DMA corruption, removal/OOM) fired at production cadence during live inference.
**Acceptance criteria:**
- `prof/gauntlet/test_fi_campaign.py` injects ≥100 faults across all classes during a 60-minute inference run; asserts: zero process crashes, zero unhandled faults (injected == handled per the VÖRÐR log reconciliation), and output coherence maintained per the frozen `data/armvegr/coherence_rubric.json` from H059 (every item passing) on spot-checked samples.
- The campaign's fault log and the VÖRÐR handling log are cross-reconciled automatically; any discrepancy FAILS the test.
- U1–U4.

## H187 — Recovery drills: scripted reset storms
**Goal:** Run scripted reset storms: 20 rapid device resets (GO branch) or 20 rapid pipeline restarts (NO-GO) in succession, verifying the system returns to full service after each and that no storm corrupts state.
**Acceptance criteria:**
- 20/20 recoveries reach ready/service; a verification inference after each recovery matches the pre-storm reference output exactly (greedy determinism — state is truly clean, not approximately clean).
- Total storm duration is recorded; the per-recovery time stays within the H155 budgets for all 20.
- U1–U4.

## H188 — TEST-ONLY (PRÓF): determinism check
**Goal:** A Python (PRÓF, TESTS ONLY) determinism proof: identical prompts + greedy sampling → identical token sequences across 10 runs, across process restarts, and (GO branch) across CPU/NPU backends.
**Acceptance criteria:**
- `prof/gauntlet/test_determinism.py` asserts 10/10 identical sequences for 5 prompts on the production binary; then restarts the process and asserts 5/5 identical again (no state leakage between runs).
- GO branch: CPU-backend and NPU-backend greedy sequences are compared over 5 prompts x 50 tokens; per-step logit max-abs-difference <= 0.05 (the quantization contract) is asserted on every step; token-identity rate is reported as a measured percentage, not asserted. Token-identity IS asserted identical only on the FP16-exact (unquantized) path, if exercised.
- U1–U4.

## H189 — Memory-leak check (RSS tracked over soak)
**Goal:** Prove the absence of memory leaks: track process RSS over a 2-hour inference run; RSS growth must be bounded and explainable (cache fill), not linear-unbounded.
**Acceptance criteria:**
- RSS sampled every 60 seconds for 2 hours; linear fit of RSS vs time over the second hour has slope ≤ 1 MB/hour (or the growth is attributed to a named, bounded structure with its cap documented).
- DMA-mapped memory (GO branch) is included: mapped bytes before and after the run are equal (no mapping leaks).
- U1–U4.

## H190 — Packaging: ARM64 release build (no Python required)
**Goal:** Produce the ARM64 release packaging: the production binary (and any data files) installable on a clean Pi 5 with no Python present — proving L2 end-to-end.
**Acceptance criteria:**
- On a clean Pi 5 (or a container/chroot without Python — environment documented), the packaged release installs and runs inference on the reference model; `python3 --version` is verified absent-or-unused (the binary never execs Python — asserted by exec monitoring during a test run (`strace -f -e trace=execve`, or the seccomp/auditd equivalent NAMED in the slice's DEVLOG entry — the method is fixed in-slice, not left open)).
- The package contains no `.py` files, no HEF files, no firmware blobs (manifest verified by file listing in the test).
- U1–U4.

## H191 — Deployment script for Mimir
**Goal:** Write the deployment script: copy the release package to Mimir, verify checksums, install the watchdog supervisor unit, and perform a smoke inference — one command from build host to running service.
**Acceptance criteria:**
- `./deploy_mimir.sh` (documented prerequisites: SSH access, the Tailscale/device path per operator setup) completes end-to-end; post-deploy smoke inference produces the expected coherent output for the canary prompt (canary prompt + expected first-10-tokens recorded in `data/gauntlet/canary.json`).
- Checksum verification fails the deploy on any mismatch (tested with a corrupted package — deploy aborts before touching the running service).
- The script never overwrites operator config without backup (tested: existing config is backed up with timestamp).
- The deploy script installs and verifies the persistent driver binding (udev rule or operator-approved equivalent) and asserts the `driver` symlink before smoke inference.
- U1–U4.

## H192 — Production runbook
**Goal:** Write the production runbook: normal operation, monitoring dashboards/log locations, the recovery procedures per fault class, and the escalation path — the document an operator (Volmarr) uses at 3 AM.
**Acceptance criteria:**
- `docs/gauntlet/RUNBOOK.md` covers: startup/shutdown, health checks, log locations, per-fault-class recovery steps (each citing the VÖRÐR behavior), and "when to give up and call it" criteria — all procedures tested at least once during C10 (each procedure's last-tested date recorded).
- A cold reader (the builder, role-playing) can bring the system from stopped to serving using only the runbook — validated by actually doing it once and noting corrections.
- U1–U4.

## H193 — Final CAPABILITY_LEDGER audit
**Goal:** Audit the entire `CAPABILITY_LEDGER.md` against evidence: every claimed capability must link to a passing slice's evidence; every Simulated mark must still be honest; no claim without a proof path.
**Acceptance criteria:**
- The audit (checklist in `docs/gauntlet/LEDGER_AUDIT.md`) verifies all ledger entries: each has an evidence path that exists and a test that passed; orphan claims (no evidence) are either evidenced in-slice or struck from the ledger with the strike recorded.
- Zero `Simulated` entries remain that were actually verified on hardware (marks are current), and zero hardware-verified claims lack the measurement logs.
- U1–U4.

## H194 — THIRD_PARTY_NOTICES.md finalization
**Goal:** Finalize third-party attribution: every studied source (hailort-drivers, HailoRT, any docs), every open-licensed artifact used in tests, with licenses and the clean-room statement — L5/L6 compliance proven in one place.
**Acceptance criteria:**
- `THIRD_PARTY_NOTICES.md` lists each source with: name, license, what was studied/used, and the explicit statement that no code was copied/vendored/linked; the clean-room logs (H005/H006/C6) are all referenced.
- A license scan of the shipped binary's dependency closure confirms: Mojo stdlib + POSIX only — no GPL/LGPL/AGPL/proprietary linkage (the scan method and its clean output are recorded).
- U1–U4.

## H195 — Victory gate 1: download any small open LLM → run → coherent output
**Goal:** Execute the victory gate as a scripted, repeatable procedure: download a small open LLM the campaign hasn't used before (name, URL, SHA-256 recorded), load it with Aesir's own loaders, generate coherent text — no human heroics, just the documented procedure.
**Acceptance criteria:**
- A single script (`prof/gauntlet/victory_gate_1.py`, TEST-ONLY driver around the production binary) performs download→verify-SHA→load→generate; 3 unseen prompts × ≥50 tokens, coherent per the frozen `data/armvegr/coherence_rubric.json` from H059 (every item must pass per prompt); the full transcript is stored in `data/gauntlet/victory_gate_1.json`.
- The gate is run with two different unseen models (different families/architectures, both inside the GGUF-or-safetensors envelope Aesir's loaders support); both pass; the envelope is stated in the evidence.
- No HEF, no Dataflow Compiler, no vendor library involved at any step (asserted by the same scans as H135).
- U1–U4.

## H196 — Victory gate 2: stable multi-hour soak proof
**Goal:** Present the multi-hour stability proof: the H183/H184 soak evidence evaluated against the H182 gates, GAUNTLET's formal verdict on stability.
**Acceptance criteria:**
- GAUNTLET evaluates the soak measurements against `data/gauntlet/STABILITY_GATES.json` and emits a STABILITY verdict of PASS with the per-gate results table stored in `data/gauntlet/victory_gate_2.json`; every gate shows its measured value vs threshold.
- Any gate that fails routes to a named remediation slice numbered H201+ in creation order (extending the sequence; the 200-count is the plan baseline, remediation extends it), each documented with goal + acceptance criteria in the verdict document, subject to U1–U4 — the gate has teeth, not theater.
- U1–U4.

## H197 — Victory gate 3: crash-resistant under fault injection proof
**Goal:** Present the crash-resistance proof: the H186 campaign evidence evaluated against the gates, GAUNTLET's formal verdict that the system is crash-resistant and self-healing under fault injection.
**Acceptance criteria:**
- GAUNTLET emits a CRASH-RESISTANCE verdict of PASS with the fault scoreboard (injected/handled/missed per class, missed = 0) stored in `data/gauntlet/victory_gate_3.json`.
- The verdict explicitly covers: process crashes (0), unhandled faults (0), silent degradations (0, per the H159 audit), and recovery-budget compliance (H155 budgets met).
- U1–U4.

## H198 — TEST-ONLY (PRÓF): full suite final run
**Goal:** A Python (PRÓF, TESTS ONLY) final run of the ENTIRE PRÓF suite across all campaigns — every test file, in dependency order — proving the whole test pyramid is green at release.
**Acceptance criteria:**
- `prof/run_all.py` executes every `prof/**/test_*.py` and the victory-gate drivers; the run ends with a summary: total tests, passed, failed (must be 0 failed), skipped (each skip justified with the branch reason, e.g., H184 skipped in NO-GO).
- Total runtime is recorded; the suite is runnable unattended (no interactive prompts — verified by running with stdin closed).
- U1–U4.

## H199 — Release notes + version tag
**Goal:** Write the release notes (what shipped, measured performance, known limitations, branch outcome GO/NO-GO with the F1/F2/F3 status) and tag the release in git — the campaign's public face.
**Acceptance criteria:**
- `docs/gauntlet/RELEASE_NOTES.md` states: version, branch outcome (wall breached or F1 delivered — honest headline), headline measured numbers (prefill/decode tok/s with the measurement conditions), known limitations (each with an issue reference), and upgrade/deployment notes.
- The git tag (e.g., `mimisbrunnr-1.0`) points at the exact commit that passed H198; the tag's commit hash is recorded in the release notes; the release package (H190) is built from that exact commit (verified by hash).
- README.md is untouched (L8 — verified by `git log -- README.md` showing no campaign commits).
- The release notes state the supported model format envelope explicitly (GGUF-or-safetensors, per Aesir's loaders) — no open-ended "any format" claim.
- U1–U4.

## H200 — Final campaign review: MÍMISBRUNNR victory/fallback verdict
**Goal:** The campaign's closing document: the complete MÍMISBRUNNR story — what was attempted, what the evidence proved, which victory gates passed, which fallback delivered — with an explicit final verdict, signed and dated.
**Acceptance criteria:**
- `docs/MIMISBRUNNR_VERDICT.md` contains: the phase-gate verdicts (A through F), the H111 branch outcome, the three victory-gate results (or the F1/F2/F3 fallback results), the final measured performance table, known limitations, and a "FINAL VERDICT" section stating exactly one of: `VICTORY — NPU PATH PRODUCTION` or `VICTORY — F1 CPU PATH PRODUCTION (WALL HELD)` or `INCOMPLETE` (with the blocking items named).
- The document affirms, with evidence citations: no HEF ever (L3), no proprietary toolchain (L4), clean-room only (L5), no banned licenses (L6), no firmware shipped (L7), README.md untouched (L8), zero `cuda_*` edits (L9), ledger honesty (L10), honest degradation (L11), device code only in HAILBRÚ (L12).
- The document states the supported model format envelope explicitly (GGUF-or-safetensors, consistent with the H199 release notes) — no open-ended "any format" claim.
- U1–U4.

---

# Slice count verification

Campaign slices: C1 H001–H020 (20) · C2 H021–H040 (20) · C3 H041–H060 (20) · C4 H061–H080 (20) · C5 H081–H100 (20) · C6 H101–H120 (20) · C7 H121–H140 (20) · C8 H141–H160 (20) · C9 H161–H180 (20) · C10 H181–H200 (20).

**TOTAL: 200 slices. IDs H001–H200, sequential, no gaps, no duplicates.**

TEST-ONLY (PRÓF) slices: H016, H037, H048, H058, H078, H084, H110, H127, H151, H152, H153, H154, H176, H183, H184, H186, H188, H198 (18 slices).

Branch-conditional slices: GO branch — H112, H113, H114, H121–H135, H171, H172, H184; NO-GO branch — H115–H119, H136–H139. Decision gate: H111. Shared (both branches): all others.


---

# APPENDIX

## A — Slice accounting (Védis, `VEDIS_DEPENDENCY_MAP.md` §0)

> Slice accounting: 200 total = **21 GO-branch** (H112–H114, H121–H135, H171, H172, H184) + **9 NO-GO-branch** (H115–H119, H136–H139) + **170 shared** (both branches). GO path executes 191 slices; NO-GO path executes 179 (H184 recorded skipped-with-reason per its own acceptance).

## B — TEST-ONLY (PRÓF) slice list (Eldra, `MIMISBRUNNR_200_SLICES.md` count verification)

TEST-ONLY (PRÓF) slices: H016, H037, H048, H058, H078, H084, H110, H127, H151, H152, H153, H154, H176, H183, H184, H186, H188, H198 (18 slices).

Branch-conditional slices: GO branch — H112, H113, H114, H121–H135, H171, H172, H184; NO-GO branch — H115–H119, H136–H139. Decision gate: H111. Shared (both branches): all others.

## C — Sólrún audit record

Sólrún audited the 200 slices with zero mercy across two passes. First audit: 20 required fixes (F-001–F-020) — UIO interrupt model physically wrong; unowned generator-extension gap behind the wall; missing driver-binding precondition; H188 determinism claim contradicting the quantization contract; builder-judged coherence; "any LLM" victory overclaim; 10/10 gate possibly 1 real boot + 9 no-ops; "cold boot" undefined; HEF-description inviting L3 violation; study permitting vendor-code install by omission; verdict selectable mechanism with no implementation; unmeasurable power claim; no-Python proof escape clause; remediation ID scheme; H068's phantom register; wrong register-doc citation; undocumented size threshold; D6 code before the D6 package; TEST-ONLY tally error; H113 depending on a later campaign's test. All 20 applied by Eldra's second pass. Re-audit: 18 verified mechanically; 2 remaining issues found and corrected verbatim (R-001: H085/H093/H095 now cite the H081 cold-boot definition; R-002: H141 now performs the hook adoption from `hailbru/health_obs.mojo` to `vordr/health_obs.mojo`). Count re-verified: 200 headers H001–H200 sequential, no gaps/dupes, no placeholders.

**SÓLRÚN SIGNS OFF.** The roadmap is auditable as honest: the compiler wall priced without illusion, every slice buildable in order on the stated hardware, all 13 laws holding, both wall branches fully executable, victory provable rather than declarable. Remaining risks are the genuine ones — the wall itself, the toolchain verdict, the kernel mechanism reality — named, gated, and fallback-planned, not hidden.

Full audit text: `~/workspace/mimisbrunnr/SOLRUN_AUDIT.md`.
