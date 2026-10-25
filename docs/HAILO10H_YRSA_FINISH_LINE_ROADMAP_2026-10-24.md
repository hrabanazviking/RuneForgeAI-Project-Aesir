# HAILO-10H NATIVE EXECUTION — FINISH-LINE ROADMAP

**Project:** Project Aesir (`hrabanazviking/RuneForgeAI-Project-Aesir`)
**Owner:** Volmarr Wyrd
**Roadmap keeper:** Yrsa (branch `yrsa/finish-line-roadmap`)
**Authority:** *The Yrsa Codex — Hailo-10H Native Execution for Project Aesir* (snapshot 2026-10-24) and `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`
**Status date:** 2026-10-24
**Target hardware profile:** Hailo-10H on Raspberry Pi 5 — kernel `6.12.112-v8-16k-hailo+`, Hailo driver/runtime family **5.3.0** (physical evidence profile). Public 5.4.x material is research-only until a fresh physical profile is qualified.

---

## 1. Mission

A user hands Aesir an **ordinary, unmodified source-model file** (GGUF or Safetensors) of a size compatible with the Hailo-10H. Aesir — in Mojo, owning every stage itself — parses the source, lowers the model's semantics, generates the Hailo-10H numerical program from qualified facts, transports and activates it, and the **Hailo-10H executes the LLM inference**. No Hailo Dataflow Compiler. No vendor-precompiled HEF prerequisite. No CPU, CUDA, or cloud path performing the model's forward pass as fallback.

This roadmap covers **Route B only** (Aesir-owned source model → native Hailo-10H execution). Route A (HailoRT + a compatible compiled model) already stands PHYSICALLY VERIFIED — a Qwen2.5-1.5B-Instruct compiled artifact run on the physical device through Aesir's Mojo session layer, 12/12 boundary/lifecycle checks — and serves this roadmap as a **behavioral oracle and device baseline**, never as a dependency of the native route.

### Non-negotiable scope (owner, 2026-10-20 — restated, not reinterpreted)

1. Broad model support is the target. Missing formats, architectures, operators, quantization schemes, or backend encodings are implementation work, not permanent exclusions.
2. Users provide ordinary, unmodified source-model files of compatible size.
3. Users are never required to run DFC, use another compiler host, or obtain a vendor-precompiled HEF.
4. Aesir owns source loading, representation conversion, model semantics, operation lowering, device program/configuration generation, orchestration, and hardware execution.
5. The native implementation language is Mojo, with narrow system seams only where necessary.
6. CPU/CUDA/cloud/proxy LLM inference does not count as completion of the Hailo path.
7. HailoRT, DFC, other open projects, patents, and public schemas may be studied as evidence or isolated oracles. External implementations are not copied or translated into Aesir.
8. Current capability is always reported honestly. A stated goal is not a capability.
9. HEF knowledge is used to learn what functional content must be replaced. The final source-model route does not require users to create or supply HEFs.

---

## 2. Evidence discipline (binding on every slice in this roadmap)

### 2.1 Evidence tags

Every claim produced under this roadmap carries one tag:

| Tag | Meaning |
|---|---|
| **PHYSICALLY VERIFIED** | Observed on Volmarr's actual Hailo-10H under a recorded hardware/software profile. |
| **HOST VERIFIED** | Native Mojo/C/C++ host behavior is tested; no physical NPU effect is established. |
| **PUBLIC INTERFACE FACT** | Present in Hailo's public MIT/GPL source or official documentation. Describes an interface, not necessarily hidden silicon semantics. |
| **OFFICIAL PRODUCT FACT** | Stated in Hailo's official product documentation. |
| **EXTERNAL EXPERIMENTAL** | Measured or reverse-documented by another open project. Valuable evidence; not automatically Aesir truth. |
| **PATENT ARCHITECTURAL LEAD** | Hailo patent material. May reveal design concepts; never an H10H programming manual. |
| **INFERENCE** | A reasoned interpretation supported by facts but not directly measured. |
| **UNKNOWN** | Not established. Never filled with intuition. |

**The gate rule:** any statement that would allow a new physical write, a new program submission, a new descriptor-use formula, a new numerical encoding, or a new claim of model execution requires PHYSICALLY VERIFIED evidence or a separately contracted experiment.

### 2.2 Do Not Infer (law until stronger evidence supersedes an entry)

- A successful USERPTR map does **not** imply DMA coherence, correct descriptors, or an executable program.
- A positive launch/count return does **not** imply a universal descriptor-count formula or device capacity.
- An IRQ does **not** imply correct model semantics, correct returned data, or program completion, unless direction/channel and protocol state correlate exactly.
- A closed device file does **not** imply remote logical destruction, stopped DMA under every failure path, or hardware idle.
- An hRPC action ID is **not** an arithmetic opcode or LCU instruction.
- An `active_l2` bitmap's bits do **not** have known physical meanings or a known legal H10H resource count.
- HEF metadata naming a shape/layout does **not** imply the numerical hardware instruction encoding is known.
- HailoRT parsing a HEF field does **not** imply Aesir knows how DFC generated the corresponding CCW payload.
- Weights fitting in LPDDR does **not** imply placeable contexts, supported operators, or a fitting working set.
- A parsed source model is **not** an executable one. A correct mathematical graph is **not** a correct quantization, packing, placement, or schedule.
- A DFC emulator's good cosine does **not** imply silicon agreement (an external project found a multi-head softmax emulation defect) — and a bad emulator cosine does **not** imply bad silicon.
- A valid outer XXH3 checksum does **not** imply LCU microcode CRC validity, hardware safety checks, target compatibility, or arithmetic correctness.
- Runtime device enum `6` is **not** the program architecture enum (program-side `HAILO1XH` = 103). Namespaces convert through qualified mappings only.
- A compatible-family mapping including Hailo-10H does **not** imply arbitrary HAILO1XH programs are physically valid on the exact device.
- A patent field/block/illustrative opcode is **not** the exact H10H register/bit encoding.
- A community compiler working *with* DFC is **not** an independent Hailo compiler and does not satisfy Aesir's no-DFC target.

### 2.3 Working agreements

- **Contract first.** Every slice publishes its exact contract (capability added, what it explicitly does NOT prove, files touched, reused owners, host tests, independent oracle, the one bounded physical action if any, cleanup-on-uncertainty behavior, evidence retained) *before* implementation.
- **Host-qualify before hardware.** All pure logic is proven host-side first.
- **One bounded physical action per contract.** Never repeat an uncertain side effect because the result was inconvenient.
- **PROVEN / NOT PROVEN.** Every physical run is reported in those two sections. Capability inflation is a defect.
- **Poison on uncertain failure.** A client/session that may have partially affected the device is never reused; recovery requires a fresh owner.
- **Local cleanup ≠ remote quiescence.** These are recorded separately, always.
- **Deadlines are plural.** Admission deadline, completion evidence, outer process watchdog, and cleanup deadline are distinct concepts; userspace checks do not preempt a synchronous kernel call already in progress.
- **Version discipline.** Physical claims pin to the recorded 5.3.0 profile. 5.4 public declarations + 5.3 firmware + old offsets never combine into "probably compatible." An upgrade means a fresh `HailoProfile` and re-qualification.
- **Unknown stays `Unknown`.** In PlacedIR/ContextIR, unqualified physical fields are never zero-filled or defaulted into plausibility.

---

## 3. Where we stand (2026-10-24, per the Codex)

### 3.1 The two bodies of work and the gap

```text
SOURCE COMPILER SIDE                     DEVICE SIDE (HAILBRÚ)
--------------------                     ---------------------
GGUF / Safetensors ownership      ✅     driver discovery            ✅
sealed source identity            ✅     device properties           ✅
tensor inventory                  ✅     descriptor lists            ✅
quant readers (Q2–Q8, IQ4 fam.)   ✅     channel allocation          ✅
transformer semantics IR          ✅     USERPTR mapping             ✅
rotary / activation / cache IR    ✅     IRQ completion model        ✅
matrix scheduling (host math)     ✅     hRPC framing                ✅
                                         typed device RPC            ✅
                                         deadlines / cleanup         ✅
                                         sealed program buffers      ✅

                    THE GAP (unbuilt, unproven)
   numerical device configuration · precision choice & device
   representation · tensor packing · physical resource placement ·
   exact CCW / context / LCU programming values · original program
   delivery & activation · result retrieval · broad coverage
```

### 3.2 Current frontier (updated to `main` be9db5d6, 2026-10-24)

The AES-CONTROL line stands at **-018** (aligned grouped lifecycle, one bounded physical attempt — PARTIAL: CREATE completed physically, IDENTIFY launched but did not complete, batch closed; -017 is the aligned grouped backing — HOST VERIFIED, host scope only; -016 is the closed physical offset-rejection attempt, -015 the typed grouped lifecycle — HOST VERIFIED). **-013** (same-file physical session maps: six real mappings, device/session cleanup) is PHYSICALLY VERIFIED. -009's sealed two-part driver mappings are verified including physical children; -010/-011/-012/-014 are HOST VERIFIED.

**The first physical grouped lifecycle has already been attempted — and rejected on span alignment** (2026-10-24, one child, `docs/HAILO10H_GROUPED_DEVICE_PROBE_2026-10-24.md`, HEAD commit be9db5d6). Proven by that attempt: D2H scalar 2068 launch admitted (return 5, one observed return only); **the H2D two-span launch (20-byte header at map offset 0, 2048-byte body at map offset 20) failed EINVAL** — kernel diagnostic: invalid buffer offset 20 against descriptor page 512; the qualified public driver source confirms a USERPTR span's mapping-relative offset must be divisible by the list's descriptor page size. Local cleanup was exact and fully accounted; no handle was accepted, no identify/destroy was sent, and **that batch is CLOSED — it is never rerun.**

**The aligned host contract is now HOST-QUALIFIED** (2026-10-24, AES-CONTROL-017, `docs/HAILO10H_ALIGNED_GROUPED_CONTROL_2026-10-24.md`): `TASK_hailo10h_aligned_grouped_control.md` (published at be9db5d6) added the **host-only** aligned backing path to the grouped control owner — logical wire unchanged (20 header + 2048 padded body = 2068 bytes), physical backing placing header at map offset 0 and body at offset 512 under the observed policy (map extent 2560), explicit CPU-owned scatter/gather, scoped changes in `hailbru/soc_storage.mojo`, `soc_session.mojo`, `soc_group_rpc.mojo`, `soc_group_device.mojo` behind new explicit entry points, legacy defaults preserved. Aligned storage/control/lifecycle suites pass in full (6/10/12) and legacy behavior is byte-identical across 574 + 784 baseline scenarios. **No physical child was authorized or run under that contract** — the physical lifecycle retry requires its **own** new one-shot contract (Campaign 1, slice 1.4 below), taken only at the owner's word.

**That one-shot contract has now run — PARTIAL (2026-10-24, AES-CONTROL-018, `docs/HAILO10H_ALIGNED_GROUPED_PHYSICAL_2026-10-24.md`).** At the owner's word (real physical Hailo proof, slices advancing automatically), exactly one child ran on Mimir: CREATE completed physically end-to-end over aligned backing (both launches returned 5; the -016 EINVAL is gone), and IDENTIFY's launches were also accepted (5/5) — but identify's directional completions were not established, no reply became CPU-visible, the client poisoned the transport and attempted no destroy, and acceptance failed. The batch is CLOSED; Campaign 1's exit is not met; the next host step is Campaign 2's semantics extraction on this evidence, and any further physical attempt takes a fresh contract.

**The most important sentence in the Codex still stands:** Aesir can now create the host-side ownership and control machinery needed to talk safely to the device, but it still lacks a proven Aesir-generated numerical program that the Hailo-10H accepts and executes. This roadmap exists to close exactly that.

### 3.3 Capability ledger (seed state — maintained as slices land)

| Capability | Host | Physical transport | Physical numerical | Full model |
|---|---|---|---|---|
| Source tensor ownership | ✅ | n/a | n/a | partial/broadening |
| Mathematical decoder IR | ✅ | n/a | n/a | broadening |
| Numerical policy IR | partial | n/a | ❌ | ❌ |
| Tile planning | partial | n/a | ❌ | ❌ |
| Physical placement | ❌ | n/a | ❌ | ❌ |
| Context record codecs | ✅ | partial | ❌ numerical | ❌ |
| Grouped control transport | ✅ | **attempted twice — span-offset rejection (negative boundary ✅, -016); aligned attempt (-018): CREATE completed physically, IDENTIFY launched (5/5) but completions not established, acceptance FAILED, batch closed** | n/a | ❌ |
| Program payload staging | ✅ | partial | ❌ | ❌ |
| Program activation | ❌ | ❌ | ❌ | ❌ |
| First numerical primitive | design/research | transport prerequisites | ❌ | n/a |
| GEMM | mathematical only | prerequisites | ❌ | ❌ |
| RMSNorm | mathematical only | prerequisites | ❌ | ❌ |
| RoPE | mathematical only | prerequisites | ❌ | ❌ |
| Attention | mathematical only | prerequisites | ❌ | ❌ |
| MLP | mathematical only | prerequisites | ❌ | ❌ |
| One decoder layer | mathematical IR | prerequisites | ❌ | ❌ |
| Prefill | runtime behavior understood | prerequisites | ❌ native | ❌ native |
| TBT + KV cache | runtime behavior understood | prerequisites | ❌ native | ❌ native |
| Ordinary model end-to-end | source side strong | partial | ❌ | ❌ |

---

## 4. The acceptance spine — numerical verification ladder

No stage of this roadmap is accepted by skipping rungs. Language quality is the **last** rung, never the first.

| Level | Gate |
|---|---|
| 0 | Source byte identity — tensor components reaching the compiler equal the intended source bytes/components. *(Largely in hand.)* |
| 1 | Source mathematical value identity — independent test oracle reconstructs selected source values; comparison passes. |
| 2 | Numerical-plan identity — the exact quantized representation the lowering intends (scale, codes, grouping, padding, packing order) is independently calculated and matches. |
| 3 | First device primitive — smallest hardware operation whose output is exhaustively predictable, chosen only once its real Hailo encoding is known. No invented "safe" opcodes. |
| 4 | Transformer primitives — RMSNorm, linear projection, RoPE, QKᵀ, scale, mask addition, softmax, attention×V, gated MLP, residual add — each validated individually. |
| 5 | One decoder block — synthetic hidden state + cache tensors in; complete outputs compared against an independent test oracle. |
| 6 | Multi-layer decoder without tokenization ambiguity — explicit token IDs, fixed positions; final logits compared. |
| 7 | Prefill — short real prompt, explicit token IDs; final logits, argmax, top-k compared. |
| 8 | One TBT step — known cache populated; advance exactly once; next-token logits compared. |
| 9 | Repeated TBT — 8, then 32, then context-boundary sequences; cache offset and numerical drift checked. |
| 10 | Normal chat — only now is coherent language behavior judged. |

**Metrics discipline:** record max/mean absolute error, relative error where defined, cosine, Pearson correlation, argmax agreement, top-k overlap, and KL divergence for distributions. Cosine alone is never sufficient — two vectors can agree in cosine and disagree in the few logits that choose the next token. For deterministic primitive tests, exact integer equality is preferred wherever the device representation allows it. A host oracle is verification machinery only; it never becomes the product's inference route.

---

## 5. The campaigns

Campaigns run in order; a campaign's exit condition is the next campaign's entry condition. Research Track R (§6) runs in parallel and feeds Campaigns 3–5. Slice IDs are stable references for contracts, commits, and the ledger.

### Campaign 1 — Close the grouped physical control gap

**Goal:** one real CREATE → IDENTIFY → DESTROY through the grouped Mojo owner, on the physical device, under the recorded 5.3.0 profile.

- **1.1 Grouped owner, host-qualified — DONE.** AES-CONTROL-015 typed grouped lifecycle (codecs, deadline law, poisoning, ownership) HOST VERIFIED (f8274175).
- **1.2 First physical attempt — DONE, REJECTED ON ALIGNMENT.** One bounded child (2026-10-24): D2H scalar admitted; H2D two-span launch EINVAL — second span at map offset 20 vs descriptor page 512 (offset must be page-divisible, per kernel diagnostic + qualified public driver source). Cleanup exact; no handle accepted; batch CLOSED, never rerun. Evidence: `docs/HAILO10H_GROUPED_DEVICE_PROBE_2026-10-24.md`. This is a PHYSICALLY VERIFIED negative boundary, and it is *not* numerical execution.
- **1.3 Aligned backing, host-only — ✅ HOST-QUALIFIED 2026-10-24** (AES-CONTROL-017, `docs/HAILO10H_ALIGNED_GROUPED_CONTROL_2026-10-24.md`). Add the explicit aligned backing path to the grouped owner: logical wire stays 20 + 2048 = 2068 bytes; physical spans at separately aligned map-relative offsets (policy 512: header @0, body @512, map extent 2560); CPU-owned scatter/gather with deterministic gap clearing and exact 2068-byte oracle projection; scoped changes in `hailbru/soc_storage.mojo` / `soc_session.mojo` / `soc_group_rpc.mojo` / `soc_group_device.mojo` behind new explicit entry points, legacy behavior preserved; host-mock aligned diagnostic; full host qualification battery (page policies 0/1/max/512/boundary, disjointness/containment/overflow, sync and launch faults, IRQ correlation cases, typed reply failures, uncertain cleanup, all old compatibility tests). **No physical child under this contract.**
- **1.4 New one-shot physical contract — DONE 2026-10-24, PARTIAL (AES-CONTROL-018).** Contract published at 7bcfd81c before code; host qualification ran on Mimir (7 tests OK with a new test-only aligned observer variant; the -016 observer captured replies only over aligned backing). Exactly one physical child: **CREATE completed end-to-end on the real chip** (both launches returned 5 — the -016 EINVAL is gone; exact typed reply; real handle); **IDENTIFY launched in both directions (5/5, spans @0/512) but its distinct directional completions were not established**, no reply became CPU-visible, the client poisoned the transport and — correctly — attempted no destroy; retained views 0, local finalization confirmed. Acceptance FAILED (attempts 2, identity unmatched); the device-side handle was not logically destroyed. Batch CLOSED, never rerun. Evidence: `docs/HAILO10H_ALIGNED_GROUPED_PHYSICAL_2026-10-24.md`.
- **1.5 Report — DONE 2026-10-24.** The -018 evidence document is the PROVEN / NOT PROVEN write-up for this attempt; ledger, TODO, progress and this roadmap updated in the same commit. A completed create exchange is **not** numerical execution and is not described as such.

**Exit condition:** the grouped lifecycle completes physically on aligned backing with exact typed replies, completion correlation, cleanup, and target profile all recorded from one bounded run under its own contract. **NOT MET as of -018** (identify completion + destroy outstanding); a further attempt requires a NEW one-shot contract, taken as its own roadmap step under the owner's standing orders — never a rerun of the closed -018 batch.

### Campaign 2 — Generalize the physically proven grouped exchange

**Goal:** extract from Campaign 1 a rigorously owned general transfer primitive that later numerical/program messages reuse.

- **2.1 Semantics extraction — ✅ DONE 2026-10-24** (AES-TRANSFER-001, `docs/HAILO10H_GROUPED_TRANSFER_SEMANTICS_2026-10-24.md`). Six sections (S1–S6) traced to the grouped owner sources and the -015/-016/-017/-018 evidence: span description + the physical offset-admission rule; launch return = descriptor count under the observed-return policy (all four -018 launches returned 5); IRQ completion records against the pinned UAPI (data 1 = completed, 0 = none yet, 0xFE/0xFF = failure indications, never counts; correlation by channel + one-outstanding law, not timestamp); the exact cache-sync sequence; ownership until validated completion; late-completion quarantine under one total deadline. Decoded during extraction: -018 identify's second wait reported 0xFF CHANNEL_NOT_ACTIVE for both owned channels — whether its transfers completed device-side first is NOT established, and the 2.2 primitive must specify that presentation explicitly without crediting it as success.
- **2.2 Primitive implementation — ✅ DONE 2026-10-24** (AES-TRANSFER-002, `docs/HAILO10H_GROUPED_TRANSFER_PRIMITIVE_2026-10-24.md`). `hailbru/soc_transfer.mojo` implements `SocGroupedTransfer`: one outstanding **raw** grouped exchange (caller owns framing; `exchange_raw` moves logical packets ≤2068 bytes and returns the raw reply extent) embodying S1–S6, sharing all lower owners with the RPC client. The qualified `soc_group_rpc`/`soc_group_device` sources are deliberately untouched, so the -015/-017/-018 evidence stands on its exact sources. Host-mock diagnostic builds clean; full qualification is 2.3.
- **2.3 Host qualification — ✅ DONE 2026-10-24** (AES-TRANSFER-003, `docs/HAILO10H_GROUPED_TRANSFER_QUALIFICATION_2026-10-24.md`). Derived suite against the unchanged -017 oracle/fault battery: **11 tests OK, 574 runs**, byte-identical comparisons throughout; deadline faulted at every clock stage, poison-on-uncertainty, ownership lifetimes, IRQ quarantine cases all pass; test_11 proves the primitive's diagnostic output byte-identical to the RPC client's on identical scenarios. Two iterations failed only on reply-framing faults — resolved as a qualified **consumer-layer** poison contract (the primitive stays framing-free by design); the layering boundary is now exercised and recorded.
- **2.4 Bounded physical confirmation — ✅ DONE 2026-10-24** (AES-TRANSFER-004, `docs/HAILO10H_GROUPED_TRANSFER_PHYSICAL_2026-10-24.md`). Contract published at 55a4b9ba before code; diagnostic host-qualified on the Pi (7 tests OK); exactly one physical child: **ACCEPTED** — one CREATE exchange through the primitive completed on the real Hailo-10H (descriptor returns exactly 5/5 as S2 predicts, completions 1/1 across 3 snapshots, typed reply validated at the consumer layer, retained 0, finalization confirmed). The created handle was not logically destroyed (residue stated in the contract up front); Campaign 1's exit remains unmet and unchanged.

**Exit condition:** returned-count, completion, cache-sync, and lifetime semantics observed physically and embodied in a tested primitive. **✅ MET** (AES-TRANSFER-001..004).

### Campaign 3 — Program resource lifecycle

**Goal:** create, transfer, finalize, identify/readiness-check, and destroy a structurally valid program/resource object — without claiming arithmetic execution.

- **3.1 Interface qualification — ✅ DONE 2026-10-24** (AES-PROG-001, `docs/HAILO10H_PROGRAM_LIFECYCLE_INTERFACE_2026-10-24.md`). Creation = hRPC action 2 (vdevice handle + declared byte count + name → infer handle) ESTABLISHED; program bytes form a separate phase of exactly the declared count (its transport mechanics and chunk/offset representation NOT ESTABLISHED — no assumptions admitted); completion = typed replies under the Campaign 2 law, readiness/finalization = action 4 configure → configured handle + queue size ESTABLISHED; teardown actions 3/5/10/11/12 exist as qualified codecs (ordering/preconditions for partial states NOT ESTABLISHED); the two handle tiers (infer vs configured) are never interchangeable.
- **3.2 Host implementation — ✅ DONE 2026-10-24** (AES-PROG-002, `docs/HAILO10H_PROGRAM_LIFECYCLE_HOST_2026-10-24.md`). `hailbru/soc_program.mojo` implements the seven-stage lifecycle over the Campaign 2 primitive with consumer-layer validation, the printable `ProgramIdentity` record, and the two AES-PROG-001 unknowns as fail-closed laws (payload-attestation gate; conservative client-side teardown order). Host-qualified on Mimir: 8 tests OK, 116 runs, against a new dedicated program-action oracle (the -018 device oracle is hardcoded to the device lifecycle sequence and cannot serve program actions — recorded in the evidence doc).
- **3.3 Bounded physical lifecycle — ✅ OBSERVATION COMPLETE 2026-10-24, branch B2** (AES-PROG-003, `docs/HAILO10H_PROGRAM_LIFECYCLE_PHYSICAL_2026-10-24.md`). The contracted run was redesigned around the AES-PROG-001 Q2 unknown (contract `TASK_hailo10h_program_lifecycle_physical.md`, b34e11e1): Phase A device CREATE completed physically; the action-2 metadata exchange earned **no reply and did not complete** — the receiver does not answer metadata alone on this channel, consistent with reading the separate payload phase first. No payload was sent (its mechanics remain unestablished), no infer handle was obtained, and this run's device handle is recorded residue. The full lifecycle (create → payload → finalize → destroy) remains open and now requires the payload phase to be *specified* from the receiver's pinned sources (Track R) before a successor contract can admit sending bytes.
- **3.4 Failure teardown — ✅ DONE 2026-10-24** (AES-PROG-004, `docs/HAILO10H_PROGRAM_FAILURE_TEARDOWN_2026-10-24.md`). Partial-creation failure paths contracted and host-tested (10 tests OK, 148 runs): corrupting each stage's reply yields the exact residue accounting, with create-failure the worst class (object possibly created, handle never learned) and recovery-by-adoption deliberately not implemented. The companion Track R study of the pinned receiver **established the payload phase's shape** (`read_buffer` of exactly the declared size between metadata and reply — matching the B2 observation), answered Q6 at source level (destroy-configured performs shutdown receiver-side), and found the disconnect-cleanup mechanism that reclaims client resources. Still NOT ESTABLISHED: the SoC connection layer's realization of the read/write (chunking, pairing, who launches) — the gate for any payload-sending successor contract. Campaign 3's exit condition remains unmet (no program object created on the device).

**Exit condition:** remote lifecycle proven, no leaked resources, exact payload identity recorded. **Not proven at exit:** numerical validity or execution.

### Campaign 4 — Numerical interface specification

**Goal:** close enough CCW/config/placement unknowns to describe **one tiny operation completely** before encoding it. This is a reverse-*specification* campaign: a written spec precedes any emitter.

- **4.1 Field-table discipline — ✅ DONE 2026-10-24** (AES-NUM-001, `docs/HAILO10H_NUMERICAL_FIELD_TABLE_2026-10-24.md`). Five evidence-graded groups: container metadata admitted as references/carriers only; context-action packed layouts admitted with the ID 35 typed-write's *address values* excluded (no safe address in evidence); the CCW words themselves OUT entirely (no public bit layout found); the entire numerical-semantics group OUT (quantization, accumulator, tiling, assignment, weight packing); and the transport group standing as the physically corroborated minority. The slice records its prediction in advance: no operation clears all eight layers until a CCW word layout or equivalent device-consumed encoding is established — 4.2 selects by evidence strength knowing this, and the iteration loop runs through Track R (whose connection study this slice narrowed to the session readiness protocol), not around it.
- **4.2 Operation selection — ✅ DONE 2026-10-24** (AES-NUM-002, `docs/HAILO10H_FIRST_OPERATION_SELECTION_2026-10-24.md`). Winner by the stated criteria: the **elementwise identity copy** of a single tensor — exactly calculable (byte equality), no persistent state, tiny buffers, one context, no KV cache, no scheduling, no model ambiguity, and the only candidate whose correctness depends on no OUT field. The roadmap's parenthetical expectation of a matrix/vector primitive was scored honestly and overruled by the evidence clause in the same sentence: GEMV carries the most OUT rows of any candidate (weights layout, tiling, accumulation, representation) and waits. ReLU is alternate #1. The selection records its 4.3 prediction in advance (layers 1–4, 7, 8 completable at source level; 5–6 blocked on CCW content and action sequencing; Campaign 4 does not exit this pass).
- **4.3 The eight-layer description — ✅ DONE 2026-10-24** (AES-NUM-003, `docs/HAILO10H_IDENTITY_COPY_EIGHT_LAYER_SPEC_2026-10-24.md`). For the chosen operation, produce all eight: (1) numerical definition (dimensions, signedness, scaling, accumulator width, rounding, saturation, output representation); (2) tile plan; (3) physical resource plan (cluster, subclusters, APUs/compute units, input aligner, local-memory banks/windows, L2/L3 offsets); (4) data-movement plan; (5) static configuration; (6) dynamic program/LCU actions; (7) completion contract; (8) cleanup contract. Any layer still unknown keeps the operation unqualified — the campaign iterates on research (Track R) until one operation clears all eight. **Result:** layer 1 COMPLETE (all group-E questions proved not applicable to a byte identity; fixed 16-byte shape; parameters proved none); layers 2–3 INCOMPLETE (tile geometry and resource assignment are the group-E/CCW unknowns); layer 4 specified host-side, device half blocked on the SoC session readiness protocol; layers 5–6 INCOMPLETE as predicted (CCW words; action sequencing); layer 7 completion contract SPECIFIED with fully sourced terms; layer 8 cleanup specified host-side, device partial-state ordering open. **Finding:** AES-NUM-002's prediction was scored against a different layer list than this roadmap's — the corrected mapping is recorded in the spec; the operation remains UNQUALIFIED, Campaign 4 does not exit, and iteration items R1–R5 (CCW layout, session readiness, placement values, action sequencing, partial-state teardown) are named.
- **4.4 Spec review gate — ✅ DONE 2026-10-24** (AES-NUM-004, `docs/HAILO10H_IDENTITY_COPY_SPEC_REVIEW_2026-10-24.md`). Field-by-field audit of the AES-NUM-003 spec against the AES-NUM-001 field table and all 16 Do Not Infer entries: **0 violations** — every field the spec uses carries a source and a known meaning or is explicitly graded UNKNOWN/OUT, and the IRQ, closed-file, and math≠executable entries are actively enforced by the spec's own terms. Finding F1 tightens layer 7: its "qualified result path" overreaches (no *program result* readback path is qualified; that question joins R2/R4). Finding F2 confirms the fixed-shape rationale's context-only disclaimer is load-bearing (the 2048 cap governs RPC messages, not the session-read payload). The corrected AES-NUM-002 layer mapping is **certified**. **Verdict: the spec passes as an honest specification, but Campaign 4's exit is NOT MET** — OUT-graded fields have a sourced unknown status, not a known meaning — so the operation remains UNQUALIFIED and **Campaign 5 is not contracted**. Campaign 4 enters its Track R iteration loop (R1 CCW layout → R2 session readiness → R3 placement → R4 sequencing → R5 partial-state teardown); each landing re-grades its layers by addendum and re-runs this gate on the changed layers only.
- **4.5 Track R R1 — CCW layout study — ✅ DONE 2026-10-24, verdict NOT PROVEN** (AES-NUM-005, `docs/HAILO10H_CCW_LAYOUT_STUDY_2026-10-24.md`). Bounded search of the pinned public HailoRT sources, the lane-D external compiler (`l-nmch/hailo-10h-llm-compiler`, which delegates all CCW generation to DFC; none of its 17 findings touches CCW words), this repo's evidence, and the open web found **no definition of a non-zero CCW word's fields** — the pinned config-buffer code carries CCW bytes opaquely. Three ancillary group-C facts were newly sourced (CCW consumed as a 64-bit word; the all-zero word is a NOP with defined CSM pop/no-forward/no-CRC/credit behaviour; two header constants recorded literally with meaning not established). Layers 2/5 are unchanged, so no re-grade and no gate re-run; Campaign 4's exit remains unmet and Campaign 5 is not contracted. Next: 4.6 = R2 (SoC session readiness + the F1 program-result readback question).

**Exit condition:** a human-readable specification in which every field of one tiny operation has a source and a known meaning.

### Campaign 5 — First numerical operation

**Goal:** one tiny, safe, deterministic operation executing on the physical Hailo-10H from an Aesir-generated program.

- **5.1 Encoder.** Implement the narrowest encoder for the Campaign 4 spec — typed IR to encoded bytes at the narrowest boundary; unknown fields fail closed, never substituted with zero.
- **5.2 Host qualification.** Byte-exact host tests against the spec and an independent oracle; ProgramIdentity printed pre-run.
- **5.3 Bounded physical run.** One fresh session; smallest buffers; exact device input bytes and exact device output bytes preserved.
- **5.4 Acceptance.** Physical output matches the independent expected output exactly (integer equality where the representation allows); repeated fresh sessions reproduce it.

**Exit condition:** physical output matches independent expected output, reproducibly across fresh sessions. Ladder level 3 cleared.

### Campaign 6 — Matrix contraction (the GEMM engine proof)

**Goal:** establish the contraction engine every transformer linear layer depends on.

- **6.1 Progressive corpus.** 1×N dot → small M×K × K×N → multiple tiles → partial accumulation — each step contracted separately, golden corpus saved (source values, numerical IR, tile plan, physical plan, emitted program, exact in/out bytes, expected output).
- **6.2 Quantization ladder entry.** Climb the Codex ladder in order: (i) exact/wider-precision proof; (ii) INT8 weights/activations if the discovered path supports them; (iii) A8W4 matrix path once layout and accumulator rules are known; (iv) mixed precision for sensitive paths. Numerical policy attaches to *operations* (`NumericalPolicy` records), never to "the model."
- **6.3 Tolerance gates.** Per-step declared tolerances; argmax/top-k agreement recorded alongside error norms.

**Exit condition:** exact or specified-tolerance results over a matrix corpus spanning tile boundaries, with quantized variants proven in ladder order.

### Campaign 7 — Transformer primitive suite

**Goal:** each transformer primitive independently verified and composable (ladder level 4), following the Codex's bring-up order.

- **7.1 Linear projection** (`Y = XW + b`) — sharding, tiling, quantized weight packing, accumulator behavior, bias path, output scale. Unlocks Q/K/V, output, MLP, and lm_head projections.
- **7.2 RMSNorm** — mean(x²) + ε, rsqrt, scale, learned weight; as a native op or a compiler recipe of primitives, whichever the hardware contract supports. Numerically sensitive; wider precision where the policy demands it.
- **7.3 RoPE** — explicit positions; one head before all heads; basis frequency, interleaving convention, **Q width and K width tracked independently** (GQA: Q ~ theta_size × Q heads, K ~ theta_size × KV heads), scaling variants and model-specific modifiers; who owns expansion (host/program/device) decided per plan, never double-applied.
- **7.4 Attention score path** — QKᵀ, scale, causal/window mask addition, softmax, with tiny dimensions where every score is inspectable. Masks are represented with explicit logical axes `[batch, query_position, head, key_position]` and lowered deliberately (pre-tiled where the contract requires; never a flat width plus a hopeful repeat — `AABBCC` ≠ `ABCABC`).
- **7.5 Attention value path** — softmax(scores) × V, output projection.
- **7.6 Gated MLP** — the architecture's actual activation carried from ModelIR (up/gate/down); SwiGLU is not assumed universal.

**Exit condition:** every primitive independently verified against the oracle and composable into a layer.

### Campaign 8 — One decoder block

**Goal:** source-bound ordinary weights drive one complete decoder layer on the device.

- **8.1 Composition.** Assemble Campaign 7's primitives into one block fed by explicitly supplied hidden state and cache tensors.
- **8.2 Checkpointing.** The acceptance artifact contains every intermediate numerical checkpoint that can be observed or independently reconstructed, traceable through the full lineage: result → device output buffer → physical descriptor → placed op → lowered op → mathematical op → source tensor binding → source file + extent + digest.

**Exit condition:** layer output matches the reference within declared tolerances (ladder level 5), and multi-layer composition clears level 6.

### Campaign 9 — Prefill

**Goal:** a tiny full model (or several decoder layers) processes a fixed prompt on the device.

- **9.1 Prefill plan.** Explicit token/embedding input, causal mask, position inputs, cache outputs, final normalization, lm_head.
- **9.2 lm_head as a first-class tiled operation.** Vocabulary-scale projection is sharded in TiledIR (`LmHeadPlan`: hidden size, vocab size, per-shard vocab ranges/weight extents/output buffers, host merge = concatenation first; distributed top-k only after correctness). Monolithic lm_head placement failure at ~152K vocab is an EXTERNAL EXPERIMENTAL warning already on record — design for shards from the start.
- **9.3 Acceptance.** Final logits and next token verified against the oracle (ladder level 7). Token IDs compared before logits — tokenizer identity, BOS/EOS policy, chat template, and submitted/returned token IDs are part of the execution record.

**Exit condition:** final logits and next token verified for a fixed prompt with explicit token IDs.

### Campaign 10 — Cache and token-by-token decode

**Goal:** persistent KV cache plus repeated token generation, proven small before proven long.

- **10.1 Cache as a first-class object.** Implement the `CachePlan`/`CacheResource` contract: cache ID, logical tokens/features, physical and padded entry bytes, source/device layouts, prefill-writer and TBT-reader/writer layouts, read/write offsets, rotation rule. Logical and physical sizes are never conflated. (The external project's central failure — prefill and TBT disagreeing on token-major cache layout, silently mixing token features — is the standing regression this design exists to prevent: layout conversion is explicit on **both** cache edges.)
- **10.2 Tiny ring first.** cache_length ≈ 8 (or the smallest supported configuration); prefill 3–4 tokens; one TBT token at a time; wraparound tested explicitly (ladder levels 8–9).
- **10.3 Drift and boundary runs.** 8, then 32, then context-boundary sequences; cache offset and numerical drift checked at each length.
- **10.4 Prefill/TBT agreement.** The two plans are separate execution plans sharing one cache contract: IDs, entry shape, byte layout, quantization, ring length, offset conventions, head ordering — a disagreement here produces fluent-looking garbage, so agreement is tested, not assumed.

**Exit condition:** explicit cache-offset tests, wrap tests, and multi-token numerical agreement recorded.

### Campaign 11 — Ordinary model load (the finish line, first crossing)

**Goal:** a user points Aesir at an ordinary GGUF/Safetensors model; no external compilation step exists.

- **11.1 Model choice.** A small real decoder with the supported feature set (RMSNorm, RoPE, GQA or MHA, gated MLP, cache, normal lm_head) — an integration test of the whole chain, chosen for architectural coverage, not demo value.
- **11.2 End-to-end run.** Source bytes → Aesir compiler → Hailo-10H execution → verified generation, with the working Route A Qwen2.5-1.5B result as the device's behavioral baseline (not a dependency).
- **11.3 1B-class step.** Once the small model is numerically stable, move to the 1B class that matches the Hailo-10H's realistic GenAI use.
- **11.4 Finish-line audit.** Score the run against the §8 checklist, item by item, in writing.

**Exit condition:** the model internally compiles, runs on the Hailo-10H, and returns coherent *verified* generation — the first native crossing.

### Campaign 12 — Broadening

**Goal:** turn the first path into architecture/format coverage rather than a demo special case.

- **12.1 Coverage matrix.** Formats × architectures × operators × quantization schemes, each cell carrying its evidence tag; explicit refusals for genuinely unimplemented cases (an honest refusal is a feature; a silent wrong answer is a defect).
- **12.2 Quantization maturation.** Per-architecture numerical policy (Qwen, Llama, Mistral families share machinery without pretending their quirks are identical); outlier transformation (rotation/equalization family) added only after a clean baseline exists — the production-flow lesson (QuaROT-style rotation + GPTQ-family methods in Hailo's published material) is a direction, not a recipe to copy.
- **12.3 Tier-3 backlog burn-down.** Remaining GGUF quant variants, Safetensors dtypes, alternative normalizations, non-SwiGLU activations, MoE routing/placement, unusual positional encodings, long-context/window policies — worked in leverage order, never ahead of Tier-1/Tier-2 soundness.

**Exit condition:** a maintained capability matrix with explicit, honest coverage claims, expanding toward the owner's 100% target.

---

## 6. Research Track R — the unknown numerical interface (parallel, feeds Campaigns 3–5)

Research is ordered because the unknowns are coupled; lanes produce *specifications*, never bytes sprayed at the chip.

- **Lane A — Public runtime and schema mining.** Continuously diff the public HailoRT tree (`hef.proto`, `context_switch_defs.h`, `libhailort/src/hef/`, `core_op/resource_manager/`, `vdma/`, `hrpc_protocol/rpc.proto`, `control_protocol.h`). For every fact: source URL, commit hash, affected release, license, exact concept extracted, and **what the fact does NOT prove**. Host metadata vs device-consumed payload is distinguished field by field; 5.3 vs 5.4 deltas are tracked explicitly.
- **Lane B — Kernel driver and UAPI.** Ioctl numbers and argument layouts, map/unmap rules, descriptor-list constraints, channel assignment semantics, cache-sync directions, interrupt completion semantics, connection lifecycle, failure/cleanup behavior. Arithmetic-resource geometry is never inferred from DMA descriptor capacity.
- **Lane C — Patents.** Patents generate *questions*, each terminating in one of three states: corroborated by public interface / corroborated physically / unresolved. A patent-only numeric constant is never promoted to program output.
- **Lane D — External experimental compiler.** The MIT-licensed `l-nmch/hailo-10h-llm-compiler` is mined as a behavioral checklist (graph shape, prefill/TBT split, cache entry behavior, RoPE input geometry, mask preparation, lm_head sharding, tokenizer/config behavior, numerical failure cases) and a regression-target source. Its DFC calls are not Aesir's backend; its findings are EXTERNAL EXPERIMENTAL until independently qualified.
- **Lane E — Bounded physical observations.** One question per experiment, in the Campaign 1 pattern. Good question: "Does the qualified grouped transport complete one typed lifecycle on the exact installed 5.3 profile?" Bad question: spraying likely-looking CCWs at the chip. The latter destroys causality and hardware safety alike.

**Standing rule:** reverse *specification*, not blind reverse engineering — the written spec (Campaign 4's field tables) exists before any general emitter.

---

## 7. Priorities (leverage order, from the Codex Part XXIV)

- **Tier 1 — blocks any native numerical operation:** (1) exact arithmetic/configuration encoding; (2) physical compute-resource geometry and legal placement values; (3) the static-configuration vs LCU-microprogram boundary; (4) exact program activation/ready/completion sequence for an Aesir-generated numerical context; (5) output/result buffer binding for that context. *Most research effort lives here.*
- **Tier 2 — blocks transformer-scale correctness:** precision/packing rules for matrix ops; accumulator/rounding/saturation behavior; cache physical format and conversion requirements; multi-context scheduling/resource reuse; lm_head sharding/merge policy; RoPE and mask host/device division; sensitive-operation precision policy (norm/softmax/gates).
- **Tier 3 — blocks broad coverage:** remaining quant variants and dtypes; alternative norms; non-SwiGLU activations; MoE; unusual positional encodings; long-context policies; per-architecture cache layouts. *Tier 3 breadth never distracts from Tier 1 silicon execution.*

---

## 8. The finish-line definition

Project Aesir has crossed the finish line for the first native Hailo model only when **all** of the following are true at the same time:

- [ ] The input is an ordinary, unmodified supported source-model file such as GGUF or Safetensors.
- [ ] The user did not run Hailo DFC or provide a vendor-precompiled model.
- [ ] Aesir owns source parsing and immutable source identity.
- [ ] Aesir owns architecture semantics and mathematical lowering.
- [ ] Aesir owns numerical-policy selection and device representation conversion.
- [ ] Aesir owns tiling and physical placement for the target Hailo-10H profile.
- [ ] Aesir emits the required hardware configuration/program bytes from qualified facts.
- [ ] Aesir owns program/resource transport and activation.
- [ ] The Hailo-10H physically executes the decoder computation.
- [ ] No CPU/CUDA/cloud path performs the model's LLM forward pass as fallback.
- [ ] Prefill is numerically verified.
- [ ] TBT is numerically verified.
- [ ] KV-cache behavior is verified across multiple tokens and wrap/boundary cases.
- [ ] Final logits or token choices meet declared numerical acceptance criteria.
- [ ] Cleanup/recovery behavior is qualified.
- [ ] The exact device/runtime/compiler/source identities are reported.
- [ ] The capability claim states the formats/architectures/operators actually implemented, without redefining the owner's broader target downward.

**Broad completion** repeats that path across the intended model-format and architecture matrix until ordinary compatible models no longer require hand-authored per-model compiler surgery (Campaign 12).

---

## 9. What not to do (standing prohibitions)

- Do not hide the vendor compiler behind Aesir — calling DFC from Mojo is still requiring DFC.
- Do not ship a small catalog of known compatible HEFs as "native support."
- Do not run fallback LLM layers on the Pi CPU. Host orchestration is allowed; CPU LLM inference is not the route.
- Do not invent unknown CCWs from patent diagrams. A plausible instruction is still an unknown instruction.
- Do not equate model size with fit — fit is placement, context strategy, cache, intermediates, numerical formats, and resource reuse.
- Do not claim hardware success from a mapped buffer, or numerical success from program acceptance, or a supported model from coherent text.
- Do not let testing infrastructure become a production dependency. Oracles stay isolated; production ownership stays in Aesir's architecture.

---

## 10. Session protocol (per Hailo engineering session)

**Bootstrap, in order:** (1) `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md` · (2) `docs/HAILO10H_SOURCE_EXECUTION_PROGRESS.md` · (3) `TODO.md` · (4) the current Hailo roadmap · (5) newest Hailo-related commits on `main` · (6) the active `TASK_hailo10h_*.md` contract · (7) evidence for the immediately preceding capability · (8) the exact installed target profile before any physical run. Never begin from an old roadmap merely because it has a large slice number.

**Before writing code, answer in writing:** What exact capability is being added? What does it explicitly NOT prove? Which files may change? Which previous owners are reused rather than duplicated? What host tests can prove it before hardware? What independent oracle checks the new bytes/math? What is the one bounded physical action, if any? What happens if cleanup is uncertain? What evidence must be retained? — then publish the task contract.

**Before a physical run:** clean build of the exact consumer; host acceptance complete; independent byte/schema oracle complete; frozen executable hash; frozen target profile; explicit outer watchdog; no uncontracted side effects; one-shot rule understood; raw evidence destination prepared.

**After a physical run:** PROVEN / NOT PROVEN, ledger updated, capability claims restated at their new exact bounds.

**Typed over bytes:** prefer `PlacedLinearOperation`, `SequencerAction`, `CacheResource`, `ProgramTargetArch`, `TransferGroup` over raw byte lists; encoding happens at the narrowest boundary possible. If an error is visible before encoding, do not debug bytes; if it appears only after encoding, prove the prior IR still correct before touching source semantics.

---

## 11. Roadmap maintenance

- This roadmap lives on branch `yrsa/finish-line-roadmap`. It is a living document: slices are checked off with their evidence tags and links to the contracts/runs that proved them, and §3.3's ledger is updated in the same commit as any capability change.
- Merges to `main` happen only at the owner's word.
- The Codex remains the authority for *why*; this roadmap is the authority for *what next*. Where they disagree, the Codex's evidence grading wins and this document is corrected.
