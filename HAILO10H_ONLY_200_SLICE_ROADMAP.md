> **OWNER CLARIFICATION — 2026-10-20:** Broad model support is 100% the target.
> Aesir must load ordinary model files and own internal translation/execution in
> Mojo. No outside model compiler, external compile host or specially compiled
> model prerequisite. Missing formats/architectures/operators are implementation
> work, never permanent eligibility restrictions. Controlling scope:
> `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

> **OWNER TARGET CORRECTION — 2026-10-19:** Project Aesir must implement the
> Mojo path needed to run source models that fit the Hailo-10H hardware. The
> owner explicitly rejects limiting the product to compatible vendor-precompiled
> models and forbids changing the target. Earlier catalog-only execution rules
> in this document are superseded. Historical precompiled-model receipts remain
> observations, not completion evidence for the owner's actual objective.

# Project AESIR: 200-slice Hailo-10H roadmap

**Goal (fixed by the owner):** implement Project Aesir in Mojo so source models of the right size for this Hailo hardware can run on it; compatible vendor-precompiled catalog models must not define the support boundary. All LLM inference must execute on Hailo-10H. The Raspberry Pi CPU may run the operating system, AESIR orchestration, UI, tokenization, storage, and other non-LLM support code; it must never run an LLM inference path or fallback.

**Current frontier (2026-10-19):** the direct in-process Mojo/C++ HailoRT GenAI backend and canonical CLI are implemented, with device/model readiness, owned lifetime, timeout recovery, chat/reset and response fingerprints evidenced through slices 133–138. Slices 139–140 add a repeatable acceptance runner and pass fresh physical readiness, inference, context preservation/reset and cleanup checks. Slice 141 inventories active and historical format boundaries; catalog candidate selection at slice 142 is withdrawn. The active work is the source-model/compiler gap contract `TASK_hailo10h_mojo_model_execution.md`, with current verified primitives and next work in `docs/HAILO10H_SOURCE_EXECUTION_PROGRESS.md`. The qualified profile is HailoRT/firmware 5.3.0 with Qwen2.5-1.5B-Instruct on Hailo-10H. CPU/CUDA LLM paths and inference proxies remain excluded. H111 describes the historical raw-mailbox experiment, not this supported API route. Checked research slices are evidence/decision artifacts, not 132 implemented runtime features.

**Source compiler frontier (2026-10-19):** the independent Mojo device RPC round-trip is physically verified without HailoRT linkage. Source inventory and the first typed dense-decoder semantic graph now pass bounded structural checks. The graph preserves source bindings, query/KV and key/value widths, tied weights and lifetimes. Explicit hypothetical storage accounting now passes independent lifetime/overflow checks; actual device resource qualification, numerical recipes/lowering, executable program generation/upload and source-model execution remain open. RMSNorm/SiLU/softmax mathematical recipes now integrate into a global graph with explicit constants/predicates and recalculated lifetimes. Expanded-schedule storage is independently checked under explicit byte/pool/budget assumptions; it does not certify hardware fit. Four public context-action record codecs match independent Python/C++ oracles; this supplies no CCW math encoding or raw-context upload endpoint. See `docs/HAILO10H_MOJO_SEMANTIC_PLAN.md`, `docs/HAILO10H_MOJO_CONTEXT_ACTIONS.md` and the source-execution progress table.

**Native frontier update (2026-10-20):** all current original branch histories
are integrated into main at `1edae4f`. Original lazy source-bound matrix
schedules pass seven methods/860 native calls and preserve head-split shapes,
packed source identities and explicit workspace scenarios. These are internal
compiler structures. Subsequent source byte tiles, Q5/Q6 component readers and action4 configure
codec now have independent host evidence. Active next contract:
`TASK_hailo10h_program_integrity.md`.
Numerical hardware encoding, precision/packing/placement and source-model
execution remain open. Main hosted CI fails at historical master compilation.

**Native source ownership update (2026-10-22):** Aesir's existing GGUF parser,
constant readers, byte tiles and structural compiler now consume one owned sealed
observed source through a checked descriptor and independently bounded read-only
mapping. Evidence: `docs/HAILO10H_MOJO_SEALED_GGUF_SOURCE.md`. Compiler/artifact
identity and actual numerical configuration/packing/placement/program execution
remain open. The broad ordinary unmodified model target remains100%.

**Retained ordinary compiler-input update (2026-10-23):** Aesir now rederives
its existing projection schema from actual retained sealed config/index/shards
and guards canonical representation windows. Evidence:
`docs/HAILO10H_MOJO_OWNED_ORDINARY_BINDING.md`;26 clean Mojo/9 C builds,
2251 complete frozen pairs and1133814 exact source component words. This verifies
observed compiler-input binding, not source-model execution. Owned graph
integration and actual numerical configuration/packing/placement/program/results
remain required work toward broad ordinary unmodified model support100%.

**Retained ordinary mathematical compiler update (2026-10-23):** ordinary
sealed sources now stay owned through the existing mathematical graph builders,
with bounded guarded semantic component reads. Evidence:
`docs/HAILO10H_MOJO_OWNED_ORDINARY_COMPILER.md`;30 clean Mojo/9 C,
14 suites/95 methods and3264 complete frozen comparisons. This is compiler IR,
not source-model execution. Duplicate tied-output identity, remaining adapters
and actual numerical configuration/packing/placement/program/results remain work.

**Grouped launch value update (2026-10-23):** original copied USERPTR groups
now serialize/parse canonical141-byte1..8-span intent with complete guards.
Evidence:`docs/HAILO10H_MOJO_SOC_GROUP.md`;20 selected methods/218 frozen pairs,
1609 new traces. Physical grouped delivery,numerical configuration/placement and
source-model execution remain required work toward the fixed broad target100%.

**Sealed output update (2026-10-23):** original program bytes now have actual
kernel-sealed host ownership with fresh integrity/metadata/window guards.
Evidence:`docs/HAILO10H_MOJO_SEALED_PROGRAM_PAYLOAD.md`;38 selected methods,
2842 full frozen pairs and2326 balanced memfds. USERPTR pinning,grouped physical
DMA,numerical configuration/placement and source-model execution remain work.

**Retained source-bit comparison update (2026-10-23):** complete raw tensor
comparison now passes33 methods/2412 frozen pairs through actual sealed ordinary
owners. Evidence:`docs/HAILO10H_MOJO_ORDINARY_TENSOR_IDENTITY.md`. Both source
names remain;typed graph alias integration and actual numerical H10H execution
remain work toward the unchanged broad model target100%.

**Retained tied-output compiler update (2026-10-23):** typed sharing now retains
both original source bindings and full packed bytes,with fresh byte guards and
mathematical graph/constant integration.56 suites/401 methods and18405 complete
frozen pairs;`docs/HAILO10H_MOJO_OWNED_TIED_OUTPUT_COMPILER.md`. Actual H10H numerical
configuration,placement,transport/results and broad remaining model coverage
stay open under the fixed broad ordinary unmodified source-model target100%.

**Two-part physical mapping update (2026-10-24):** original sealed metadata/
program ownership passes69 methods/4976 frozen pairs and7 actual map-only
children,including3 simultaneous two-part cases.10 maps/unmaps and driver close
before release;`docs/HAILO10H_MOJO_SEALED_TRANSFER_PIN.md`. Actual grouped DMA,
descriptors/deadlines and numerical/source-model execution remain open under
broad ordinary unmodified source-model support100%.

**Original prepare/cancel values (2026-10-24):**139/8-byte owned wire codecs
reuse existing checked group/scalar semantics;25 methods/2763 complete frozen
pairs and2988 new traces. `docs/HAILO10H_MOJO_SOC_PREPARE.md`. No actual
preparation/cancellation,descriptor count or source-model execution follows.
Actual transport and numerical/broad compiler gaps remain required work.

**Execution model:** 20 phases × 10 slices = exactly 200 slices. Every model operation must execute on Hailo-10H. Host CPU may perform ordinary application orchestration, tokenization, request handling, and I/O; it may not execute, shadow, serve, or fall back to LLM inference. Implement the Mojo-owned source-model import, lowering, device-program generation and execution needed for the owner's fixed target. The existing vendor-precompiled GenAI route is historical integration evidence and cannot define completion or supported-model scope. Do not route inference through Hailo-Ollama, another service, CPU, CUDA, or cloud. When a gate fails, keep working through bounded diagnostics, version/model alternatives supported by Hailo, and implementation fixes; record temporary blockers without converting them into terminal project decisions.

**Slice execution:** Work through the numbered slices in order, completing the action and leaving a reviewable artifact, verified behavior, or evidence-backed decision. Build Æsir as the Mojo owner of the source-model-to-Hailo execution path; close the actual compiler, operation, configuration and transport gaps without substituting a catalog-only product. Keep the runtime boundary in-process; Hailo-Ollama is not the target.

## Repository-grounded gates

- Prior H111 is **NO-GO**: H102 recorded no mailbox completion on either documented doorbell despite the listed hardening attempts; H105–H110 were blocked. See `docs/smidr/PHASE_D_GATE.md` and `docs/smidr/H102_ATTEMPT_RECORD.md`.
- The current machine census is in `docs/HAILO10H_ACCESS_CENSUS.md`; it is an observation snapshot, not permission to unbind/reset/reflash the device.
- Current direct-backend evidence is recorded in `docs/HAILO10H_SLICE_134_READINESS.md` through `docs/HAILO10H_SLICE_138_PROVENANCE.md`. General backend enums and historical NPU dispatch are distinct from the canonical Hailo build. See `CAPABILITY_LEDGER.md` for the narrow scope.
- Official HailoRT GenAI documentation and installed headers define the supported direct execution path. Keep model/runtime versions matched and record licensing, provenance, and compatibility.
- A failed probe triggers diagnosis and a concrete next attempt (supported model/runtime pair, corrected integration, or supported host profile); it does not authorize CPU inference or a proxy substitution.

## Non-negotiable acceptance rule

All LLM model execution must be demonstrated on Hailo-10H with runtime/device evidence. CPU-only inference, CPU fallback, CPU shadow LLM inference, CPU model-serving, and work whose purpose is to run LLMs on the Pi CPU are out of scope. No NO-GO branch may route into CPU LLM development. CPU use for ordinary application orchestration is allowed.

## Phase 01: Scope and success criteria

- [x] **Slice 001.** Record Æsir's documented mission as a local, Mojo-native inference engine whose LLM execution target for this campaign is Hailo-10H only; preserve local model/data control, disclose accelerator provenance, and fail closed when Hailo inference is unavailable. Evidence: `docs/HAILO10H_MISSION.md`.
- [x] **Slice 002.** Define the primary interaction loop and target user.
- [x] **Slice 003.** List required inputs, outputs, and integrations.
- [x] **Slice 004.** Mark every model inference path as Hailo-10H only.
- [x] **Slice 005.** Explicitly exclude CPU LLM inference, fallback, and model-serving paths.
- [x] **Slice 006.** Separate host orchestration from accelerator inference responsibilities.
- [x] **Slice 007.** Define offline behavior and network assumptions.
- [x] **Slice 008.** Set initial latency, throughput, and quality targets as hypotheses.
- [x] **Slice 009.** Define memory, power, and thermal operating envelopes.
- [x] **Slice 010.** Create a decision log for unresolved product choices.

## Phase 02: Repository and hardware evidence

- [x] **Slice 011.** Reconcile the checked-out branch and remote default branch without discarding owner changes.
- [x] **Slice 012.** Record the exact current Æsir commit and identify the authoritative Hailo campaign artifacts.
- [x] **Slice 013.** Inventory Hailo-related source and documentation without opening or changing device state.
- [x] **Slice 014.** Record the observed Pi 5, Hailo-10H identity, PCI BDF, driver binding, and link width/speed.
- [x] **Slice 015.** Record Hailo module memory claims separately from what the current device reports.
- [x] **Slice 016.** Record the current OS, kernel, firmware, HailoRT package, and GenAI package versions as observations only.
- [x] **Slice 017.** Check current PCIe/IOMMU/UIO/VFIO facts using read-only queries and mark unknowns explicitly.
- [x] **Slice 018.** Review prior Phase-B/C bring-up evidence and distinguish historic state from current census.
- [x] **Slice 019.** Reconcile H101–H111 evidence paths and confirm the Phase-D NO-GO remains current or needs a bounded revalidation.
- [x] **Slice 020.** Publish a dated evidence inventory with source paths, freshness, and confidence labels.

## Phase 03: Constraints and decision control

- [x] **Slice 021.** Record the owner-approved Hailo-only mission and explicitly prohibit Pi CPU LLM work.
- [x] **Slice 022.** Record pure Mojo runtime policy and Python-test-only boundary from project doctrine.
- [x] **Slice 023.** Record the Hailo-10H-only execution invariant; select direct in-process HailoRT GenAI as the integration route and exclude Hailo-Ollama.
- [x] **Slice 024.** Record clean-room requirements for any vendor driver/runtime study, including license gate and provenance.
- [x] **Slice 025.** Approve official HailoRT GenAI APIs and compatible Hailo model artifacts for direct Æsir integration; explicitly prohibit inference proxies including Hailo-Ollama.
- [x] **Slice 026.** Define permitted host responsibilities: control plane, tokenizer, sampler, and data movement only.
- [x] **Slice 027.** Define prohibited execution paths: CPU LLM, CPU fallback, CPU shadow inference, CUDA LLM, and cloud inference.
- [x] **Slice 028.** Create a decision log that distinguishes technical evidence from owner choices.
- [x] **Slice 029.** Define fail-closed behavior when no verified Hailo compute path exists.
- [x] **Slice 030.** Approve the campaign gate policy: a failed prerequisite blocks dependent slices and never routes to CPU inference.

## Phase 04: Hailo-only feasibility revalidation

- [x] **Slice 031.** Re-read the H111 decision and identify exactly which claims are dated and hardware-specific.
- [x] **Slice 032.** Check upstream Æsir history for any Hailo-path change after the H111 evidence commit.
- [x] **Slice 033.** Check official Hailo documentation for any newly documented raw-compute interface, using dated citations.
- [x] **Slice 034.** Check upstream Hailo driver/runtime releases for any documented mailbox protocol change; study only.
- [x] **Slice 035.** Check whether the current installed firmware/device version differs materially from the H102 test environment.
- [x] **Slice 036.** Determine whether a new non-invasive observation can distinguish stale evidence from unchanged behavior.
- [x] **Slice 037.** Write a bounded revalidation plan that does not unbind, reset, or reflash the live device without a documented safety basis.
- [x] **Slice 038.** Execute only read-only revalidation probes needed to establish present device/software identity.
- [x] **Slice 039.** Compare current observations to H102/H111 and state whether evidence invalidates, narrows, or confirms NO-GO.
- [x] **Slice 040.** Publish the Hailo compute feasibility verdict; if NO-GO remains, mark implementation slices BLOCKED pending owner decision.

## Phase 05: Toolchain and legal feasibility

- [x] **Slice 041.** Verify current Mojo compiler support for the project's target architecture from official Mojo documentation.
- [x] **Slice 042.** Determine whether Æsir's existing build can target the current Pi environment; do not create CPU inference work.
- [x] **Slice 043.** Map the minimum POSIX/device-control primitives a Mojo-only Hailo transport would require.
- [x] **Slice 044.** Verify whether those primitives are available under the project's dependency and licensing policies.
- [x] **Slice 045.** Map firmware ownership and redistribution constraints without fetching or bundling firmware.
- [x] **Slice 046.** Inventory official Hailo LLM artifacts and record why their HEF/DFC/runtime requirements conflict with Æsir constraints.
- [x] **Slice 047.** Inventory public research claiming direct Hailo execution and verify hardware, artifact, toolchain, and license requirements.
- [x] **Slice 048.** Create a clean-room research log with source URLs, licenses, facts, and unanswered questions.
- [x] **Slice 049.** Ask no code path to depend on proprietary tools; identify whether any compliant configuration-generation route is evidenced.
- [x] **Slice 050.** Issue a technical/legal feasibility recommendation with explicit unresolved owner decisions.

## Phase 06: Safe device-access contract

- [x] **Slice 051.** Specify the HAILBRÚ ownership boundary for PCI discovery, BARs, DMA, interrupts, and device commands.
- [x] **Slice 052.** Document the current bound-driver state and prohibit accidental simultaneous driver ownership.
- [x] **Slice 053.** Specify a read-only default mode for all device census and diagnostics.
- [x] **Slice 054.** Define explicit preconditions and operator safeguards for any future mutating device probe.
- [x] **Slice 055.** Specify PCI identity checks that fail closed on a non-Hailo-10H endpoint.
- [x] **Slice 056.** Specify BAR/resource validation and bounds checks before any mapping operation is permitted.
- [x] **Slice 057.** Document the current missing-IOMMU-group limitation for VFIO on this machine.
- [x] **Slice 058.** Document UIO availability as unverified until module and interrupt/DMA behavior are tested under an approved procedure.
- [x] **Slice 059.** Reject sysfs BAR access as a DMA execution solution unless a safe, evidenced DMA contract is established.
- [x] **Slice 060.** Publish HAILBRÚ access contract and gate all device-touching implementation on a GO decision.

## Phase 07: Firmware and control-plane evidence

- [x] **Slice 061.** Inventory the current firmware identity from supported read-only tooling.
- [x] **Slice 062.** Compare current firmware identity with the exact H102 test identity where logs allow.
- [x] **Slice 063.** Document which firmware status signals are observable without taking device ownership.
- [x] **Slice 064.** Review documented app-CPU and core doorbell semantics against primary sources.
- [x] **Slice 065.** Record that the historic app and core mailbox submissions yielded no completion.
- [x] **Slice 066.** Check whether any official update documents mailbox access restrictions on integrated Hailo-10H.
- [x] **Slice 067.** Define what positive evidence would prove the firmware control service is reachable.
- [x] **Slice 068.** Define what negative evidence is sufficient to block compute submissions safely.
- [x] **Slice 069.** Keep new mailbox experiments blocked until owner-approved safety, state restoration, and evidence gaps are explicit.
- [x] **Slice 070.** Publish a firmware/control-plane evidence matrix with supported, contradicted, and unknown claims.

## Phase 08: Configuration-generation research

- [x] **Slice 071.** Restate the chip-executable configuration problem independently of the transport problem.
- [x] **Slice 072.** Inventory H019 unknown configuration elements and current confidence per element.
- [x] **Slice 073.** Reassess whether public sources expose operation encoding or scheduler/configuration semantics.
- [x] **Slice 074.** Survey public compiler outputs only where legally and technically permissible; do not invoke DFC.
- [x] **Slice 075.** Define a clean-room method for recording externally observed formats without copying source code.
- [x] **Slice 076.** Determine what evidence would validate a generated configuration without submitting it to hardware.
- [x] **Slice 077.** Assess whether a configuration generator can be technically complete with currently available evidence.
- [x] **Slice 078.** Reject undocumented magic bytes and synthetic success claims in generated configurations.
- [x] **Slice 079.** Specify a stopping criterion for unbounded reverse engineering under this campaign.
- [x] **Slice 080.** Publish a configuration-surface feasibility decision; block execution work if the control/config surfaces remain unknown.

## Phase 09: Hailo-only compute proof design

- [x] **Slice 081.** Define the smallest useful Hailo compute operation and its exact input/output contract.
- [x] **Slice 082.** Define an independent host-side oracle strictly for verifying Hailo results, never for LLM inference.
- [x] **Slice 083.** Specify an artifact-free test representation consistent with the no-HEF rule.
- [x] **Slice 084.** Specify how proof inputs and outputs will be checksummed and retained.
- [x] **Slice 085.** Define completion, timeout, device-health, and result-integrity evidence required for a pass.
- [x] **Slice 086.** Define repeatability requirements for an operation that has actually executed on the accelerator.
- [x] **Slice 087.** Define how telemetry will prove silicon execution rather than host-side emulation.
- [x] **Slice 088.** Define the safety checks and restore procedure before any mutating device proof.
- [x] **Slice 089.** Write go/no-go criteria for the first real Hailo operation; no CPU fallback branch.
- [x] **Slice 090.** Keep the first compute proof BLOCKED until transport and configuration generation both have evidence-backed GO decisions.

## Phase 10: Native Hailo transport prerequisites

- [x] **Slice 091.** Review existing HAILBRÚ implementation and separate historical code from currently usable interface.
- [x] **Slice 092.** Document exact device-discovery behavior and its permissions requirements.
- [x] **Slice 093.** Document BAR metadata parsing contract without mapping device resources.
- [x] **Slice 094.** Specify memory ownership and DMA address semantics required by a Hailo operation.
- [x] **Slice 095.** Specify interrupt/completion semantics required by the prior mailbox model and unresolved gaps.
- [x] **Slice 096.** Document concurrency and exclusive-access rules for the endpoint.
- [x] **Slice 097.** Define error types for absent device, wrong device, permission denial, and unsupported mechanism.
- [x] **Slice 098.** Define cleanup invariants for file descriptors, mappings, and device ownership.
- [x] **Slice 099.** Prepare transport implementation acceptance criteria guarded behind feasibility GO.
- [x] **Slice 100.** Record transport implementation status without claiming inference capability.

## Phase 11: Hailo compute enablement gate

- [x] **Slice 101.** Reconcile command-submission transport requirements with the H102 failure signature.
- [x] **Slice 102.** Identify any new official mechanism that could replace the silent firmware mailbox path.
- [x] **Slice 103.** Require independently sourced evidence before changing doorbell or completion assumptions.
- [x] **Slice 104.** Assess whether firmware protocol access is possible without vendor runtime dependence.
- [x] **Slice 105.** Assess whether raw compute configuration is possible without HEF/DFC.
- [x] **Slice 106.** Join transport and configuration evidence into a single dependency graph.
- [x] **Slice 107.** Define a technical NO-GO result for unresolved transport, encoding, or legal barriers.
- [x] **Slice 108.** Define the sole GO criterion: one real Hailo-10H operation with device-completion and output evidence.
- [x] **Slice 109.** Record whether Hailo-only inference work is unblocked; if not, stop dependent implementation slices.
- [x] **Slice 110.** Publish the campaign gate and leave all CPU inference slices absent.

## Phase 12: Model computation mapping research

- [x] **Slice 111.** Inventory transformer operations required by Æsir's selected model family from existing loaders and architecture docs.
- [x] **Slice 112.** Map each operation to a Hailo compute primitive only when that primitive is verified on-device.
- [x] **Slice 113.** Record unsupported or unknown operations without substituting CPU execution.
- [x] **Slice 114.** Assess Hailo memory layout requirements from documented, permissible evidence.
- [x] **Slice 115.** Assess tensor precision and quantization contracts required by the selected model.
- [x] **Slice 116.** Define weight and activation representations for a hypothetical proven Hailo primitive.
- [x] **Slice 117.** Map attention and KV-cache operations to Hailo only where device capability is measured.
- [x] **Slice 118.** Map prefill and decode dependency chains with no host LLM math.
- [x] **Slice 119.** Identify minimal model architecture that could be supported by a demonstrated Hailo operation set.
- [x] **Slice 120.** Publish an operation coverage matrix; no LLM integration until every required op has Hailo proof.

## Phase 13: Host-to-device data path contract

- [x] **Slice 121.** Define host/device tensor ownership transitions around verified Hailo operations.
- [x] **Slice 122.** Specify transfer integrity checks and evidence counters.
- [x] **Slice 123.** Specify bounded staging memory without copying inference compute onto the host.
- [x] **Slice 124.** Define synchronization needed between transfer and accelerator completion.
- [x] **Slice 125.** Define behavior for partial transfers and device timeouts.
- [x] **Slice 126.** Define address, alignment, and size constraints from verified hardware documentation.
- [x] **Slice 127.** Define cache-coherency assumptions and require hardware evidence before use.
- [x] **Slice 128.** Define cleanup after cancellation or device removal.
- [x] **Slice 129.** Specify transfer benchmarks only after the compute path exists.
- [x] **Slice 130.** Publish data-path contract gated on verified Hailo transport and compute.

## Phase 14: Æsir Hailo backend integration design

- [x] **Slice 131.** Inspect existing Æsir backend enums, configuration validators, and dispatch points.
- [x] **Slice 132.** Document each missing connection from model request to Hailo submission and result.
- [x] **Slice 133.** Add a direct in-process HailoRT GenAI backend boundary for Æsir; ensure it cannot dispatch CPU/CUDA inference.
- [x] **Slice 134.** Implement Hailo-10H discovery and startup readiness through HailoRT; expose actionable diagnostics.
- [x] **Slice 135.** Load a version-matched Hailo GenAI model artifact into HailoRT and establish session ownership/lifetime.
- [x] **Slice 136.** Map HailoRT errors to typed Æsir errors and implement retry/recovery without changing inference device.
- [x] **Slice 137.** Pass prompts and generation controls through the direct GenAI API; keep model inference on Hailo.
- [x] **Slice 138.** Attach runtime, device, model, and execution-provenance evidence to each response.
- [x] **Slice 139.** Add a hardware-integration seam while distinguishing mocks from actual Hailo execution evidence.
- [x] **Slice 140.** Complete a real direct-backend inference smoke run on the attached Hailo-10H and record output and device evidence.

Phase 14 evidence: `TASK_hailo10h_direct_lifecycle.md`, `docs/HAILO10H_SLICE_134_READINESS.md` through `docs/HAILO10H_SLICE_139_HARDWARE_SEAM.md`, plus `docs/HAILO10H_SLICE_140_SMOKE.md`. Slices 133–138 checkboxes were reconciled on 2026-10-19 against their 2026-10-12 implementation receipts.

## Phase 15: First model feasibility

- [x] **Slice 141.** List Æsir's currently supported model formats and architecture families from repository evidence.
- [ ] **Slice 142 — WITHDRAWN CATALOG WORK ORDER.** The owner rejected the precompiled-only restriction before this slice was implemented or published. Resume only under `TASK_hailo10h_mojo_model_execution.md`; phase-15 dependent catalog assumptions must be reconciled against the fixed source-model target before execution.
- [ ] **Slice 143.** Record model license, revision, tokenizer, and architecture metadata.
- [ ] **Slice 144.** Estimate accelerator memory needs from documented capacity; label estimates rather than measurements.
- [ ] **Slice 145.** Pin the official Hailo model artifact, tokenizer, source, integrity digest, and license metadata.
- [ ] **Slice 146.** Verify model artifact/runtime compatibility; if it fails, select the next supported artifact/version pair and continue.
- [ ] **Slice 147.** Map every model layer to the operation coverage matrix.
- [ ] **Slice 148.** Reject the model candidate if any required op or configuration format is unverified.
- [ ] **Slice 149.** Document what new Hailo capabilities would be needed to revisit rejected candidates.
- [ ] **Slice 150.** Publish a candidate decision; do not execute any LLM on the Pi CPU.

Phase 15 progress and per-slice receipts: `docs/HAILO10H_PHASE15_PROGRESS.md`.

## Phase 16: Hailo proof benchmark and correctness gates

- [ ] **Slice 151.** Freeze a Hailo operation correctness corpus containing no CPU inference tasks.
- [ ] **Slice 152.** Define numerical comparison methods for accelerator outputs against a host math oracle.
- [ ] **Slice 153.** Define accelerator provenance evidence required for each benchmark record.
- [ ] **Slice 154.** Measure first-operation latency only after a real Hailo op can execute.
- [ ] **Slice 155.** Measure repeated-operation latency distribution on the Hailo device only.
- [ ] **Slice 156.** Measure transfer and compute timing separately where device evidence supports it.
- [ ] **Slice 157.** Measure accelerator utilization and temperature through supported telemetry when available.
- [ ] **Slice 158.** Define no-op and negative-control cases that catch host-side simulation masquerading as inference.
- [ ] **Slice 159.** Set performance thresholds from measured Hailo data, not TOPS marketing claims.
- [ ] **Slice 160.** Publish a proof gate; leave benchmark work blocked until real Hailo compute is established.

## Phase 17: Hailo-only inference pipeline

- [ ] **Slice 161.** Design prefill execution across the verified Hailo operation set.
- [ ] **Slice 162.** Design decode execution where every LLM layer operation is dispatched to Hailo.
- [ ] **Slice 163.** Define Hailo-resident or explicitly transferred KV-cache behavior from measured support.
- [ ] **Slice 164.** Define bounded context behavior from actual accelerator memory evidence.
- [ ] **Slice 165.** Define sampler interface while ensuring all model math remains on Hailo.
- [ ] **Slice 166.** Define stream output and cancellation behavior for Hailo requests.
- [ ] **Slice 167.** Define multi-turn state lifecycle without retaining stale accelerator state.
- [ ] **Slice 168.** Define batch behavior only for batch shapes demonstrated on Hailo.
- [ ] **Slice 169.** Run a real model trace only after every required operation is accelerator-verified.
- [ ] **Slice 170.** Keep full inference integration BLOCKED until Hailo provenance and coherent-output evidence pass.

## Phase 18: Hailo-only reliability and packaging

- [ ] **Slice 171.** Define device readiness and service lifecycle for the verified Hailo backend.
- [ ] **Slice 172.** Define error recovery that retries or stops; never changes inference to CPU.
- [ ] **Slice 173.** Define device-removal handling and actionable user-visible errors.
- [ ] **Slice 174.** Define process restart semantics without claiming accelerator recovery before testing.
- [ ] **Slice 175.** Define diagnostics that separate host orchestration from Hailo execution.
- [ ] **Slice 176.** Define model/artifact integrity checks consistent with approved model path.
- [ ] **Slice 177.** Define privacy-safe logging for prompts and Hailo telemetry.
- [ ] **Slice 178.** Define a reproducible deployment profile pinned to verified hardware/software versions.
- [ ] **Slice 179.** Define package checks that reject CPU LLM backends and prohibited artifacts.
- [ ] **Slice 180.** Publish packaging plan only for a proven Hailo-only build; otherwise report blocker.

## Phase 19: End-to-end Hailo acceptance

- [ ] **Slice 181.** Run the primary Æsir user journey only when the inference path is proven on Hailo.
- [ ] **Slice 182.** Verify every LLM operation in a complete request has Hailo execution evidence.
- [ ] **Slice 183.** Verify missing Hailo device fails closed with no CPU LLM subprocess.
- [ ] **Slice 184.** Verify no CPU LLM packages, models, or fallback configuration are invoked by Æsir.
- [ ] **Slice 185.** Verify Hailo inference after reboot using accelerator-specific evidence.
- [ ] **Slice 186.** Verify offline operation with approved artifacts when architecture permits.
- [ ] **Slice 187.** Verify cancellation, timeouts, malformed input, and memory limits around Hailo execution.
- [ ] **Slice 188.** Verify logs and diagnostics disclose device, model, and runtime provenance.
- [ ] **Slice 189.** Have the owner evaluate an end-to-end generated response from the Hailo-backed build.
- [ ] **Slice 190.** Publish acceptance decision with measured evidence and unresolved defects.

## Phase 20: Release, blocked-state, and maintenance

- [ ] **Slice 191.** Create a release candidate only if every required LLM operation is proven on Hailo-10H.
- [ ] **Slice 192.** Publish exact supported Hailo module, carrier, OS, firmware, and driver matrix.
- [ ] **Slice 193.** Publish measured Hailo model coverage, context limits, throughput, and known gaps.
- [ ] **Slice 194.** Publish installation and recovery instructions that preserve Hailo-only inference.
- [ ] **Slice 195.** Publish device-unavailable behavior and confirm it never falls back to CPU inference.
- [ ] **Slice 196.** Create regression checks for Hailo firmware and driver changes using supported probes.
- [ ] **Slice 197.** Revalidate every accelerator proof after a material Hailo software update.
- [ ] **Slice 198.** Track upstream Hailo documentation and research for compliant raw-execution interfaces.
- [ ] **Slice 199.** Close remaining direct HailoRT GenAI integration defects; preserve Hailo-only inference and no-proxy rules.
- [ ] **Slice 200.** Publish the verified Æsir Hailo-10H release profile, measured inference evidence, and next Hailo-targeted improvements.


## Compiler-owned observed input update — 2026-10-22

Original Mojo now retains a sealed GGUF source through existing mathematical
compilation and source-byte tile reads. Native evidence:
`docs/HAILO10H_MOJO_OWNED_GGUF_COMPILER.md` (9 clean builds,23 methods/596 calls,
480 complete frozen pairs,209 ownership traces). This does not certify a chip
program or numerical source execution. The broad100% ordinary-model target,
remaining formats/architectures/operations and physical numerical configuration,
packing/placement/delivery/results requirements remain unchanged.

Next ordinary-format ownership work is contracted before production in
`TASK_hailo10h_sealed_safetensors_source.md`: the original Safetensors mapped
parser/constant reader will consume an Aesir-owned sealed fd. Bounded physical
lead continuation is recorded in
`docs/HAILO10H_NUMERICAL_LEADS_CONTINUED_2026-10-22.md`; it qualifies no numerical
device encoding and is not implementation or execution evidence.


## Owned ordinary Safetensors input update — 2026-10-22

`docs/HAILO10H_MOJO_SEALED_SAFETENSORS_SOURCE.md` records the original sealed-fd
parser/constant-input owner:117 current entries,115 frozen controls,50 suites/
354 methods and14325 complete comparisons. All40 old parser/conversion/query
bodies remain exact. This completes the published Safetensors ownership contract;
it provides no numerical Hailo or source-model execution evidence. Owned ordinary
config/index/shards and compiler bindings follow. The broad100% target and actual
numerical configuration/packing/placement/program delivery/results remain work.


Next input-ownership contract: `TASK_hailo10h_sealed_source_metadata.md` and
`docs/HAILO10H_SEALED_SOURCE_METADATA_CONTRACT.md`. A new leaf will retain sealed
ordinary config/index bytes through existing parsers.666 source identities,
117 controls and71 Python inputs are frozen; a closed type probe builds without
execution. No production or numerical/source-model execution claim follows.

## 2026-10-24 observed exchange progress

Original returned-count/deadline state now has15 methods/1928 full frozen
comparisons;`docs/HAILO10H_MOJO_OBSERVED_GROUP_PROGRESS.md`. This is host event
accounting,not grouped submission or source-model execution. Continue actual
same-file ownership,late cleanup,physical control RPC and numerical program/
results toward broad ordinary UNMODIFIED source-model support100%.

## 2026-10-24 same-file host ownership

Original sealed session ownership passes76 methods/5554 full frozen comparisons
and retains both actual fd/VMA pairs after uncertain finalization.
`docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN.md`. This is host qualification;physical
map-only session evidence,actual grouped transfer/late cleanup and numerical
program/results remain required toward broad ordinary UNMODIFIED models100%.


Same-file physical mapping is now qualified under
`docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN_PROBE.md`:3 host methods/29 full frozen pairs,one unchanged session baseline and
three new-owner children. Six real mappings and their owning-file/host release
complete;38 permitted ioctls,zero DMA/RPC packet/program/model submission. This
is map-only acceptance,not numerical source-model execution or all-failure
hardware/remote cleanup confirmation. Actual grouped counts/completion/total
deadlines/late cleanup and numerical configuration/packing/placement/program/
results remain required toward broad ordinary UNMODIFIED models100%.


Prepared/direct launch continuation:
`docs/HAILO10H_GROUP_LAUNCH_BOUNDARY_2026-10-24.md` qualifies queue-status versus
actual launch-return distinctions without adopting a count algorithm or a
zero-buffer trigger. Next original HOST-ONLY grouped control owner follows
`TASK_hailo10h_grouped_control_rpc.md` on the existing natural20/2048 frame
boundary.715/90 actual inputs and164 controls are frozen before code. No new
implementation,device request,DMA or source-model execution is claimed here.


Original grouped control-frame host qualification now passes78 methods/4737
complete frozen comparisons under`docs/HAILO10H_MOJO_GROUP_CONTROL_RPC.md`.
Natural20/2048 spans share one owned input mapping;actual return policy,IRQ
correlation,total deadline and permanent poison have host fault evidence.354
actual IRQ workers per image exit before context-close attempts. No real Hailo
ioctl/DMA,RPC packet,program or numerical execution occurs. Continue typed
non-inference grouped lifecycle/cleanup,then separately bounded physical evidence
and actual numerical configuration/packing/placement/program/results toward
broad ordinary UNMODIFIED source-model support100%.


Next original HOST-ONLY typed lifecycle contract:
`TASK_hailo10h_grouped_device_rpc.md`. Reuse existing create20/identify22/
destroy21 codecs on the published grouped client;track handle presence and
uncertain logical cleanup under one lifecycle deadline,with at most four
exchange attempts. Fresh718 Mojo/91 Python inputs,168 current controls and
823 contract archive paths are frozen before code. Manifest SHA-256:
`97825114ea5507bbb2ba31d342c1f99bc821950e5e2a5c90de2dc75fb2ae4ddb`. No new implementation,device call or numerical/source-model execution
is claimed by this contract.


Original typed grouped lifecycle host qualification is verified under
`docs/HAILO10H_MOJO_GROUP_DEVICE_RPC.md`:90 methods/5134 full frozen comparisons.
Fresh ownership,known-handle presence,one total lifecycle admission deadline,
no destroy retry and uncertain logical/file cleanup are exercised. No real Hailo
ioctl/DMA or numerical execution occurs. Continue separately bounded physical
control evidence and actual numerical configuration/packing/placement/original
program/results toward broad ordinary UNMODIFIED source-model support100%.


Next bounded physical control contract:`TASK_hailo10h_grouped_device_probe.md`.
Fresh722 Mojo/92 Python inputs,171 retained controls and831 archive paths are
frozen before code. Host-qualify the new diagnostic and direct-syscall observer
first;then exactly one new typed20/22/21 grouped lifecycle may observe actual
returns/completion and cleanup on a fresh matched profile. No implementation or
physical call follows merely from the contract. Actual numerical/packing/
placement/original program/results and broad remaining models remain work.


2026-10-24 negative grouped physical boundary:
`docs/HAILO10H_GROUPED_DEVICE_PROBE_2026-10-24.md`. Exactly one contracted child
observes D2H return5,H2D EINVAL and kernel offset20/page512 refusal. No accepted
handle/identity/assigned completion;local cleanup is accounted separately from
remote/hardware idle. The batch is closed without repeat. Next host work follows
`TASK_hailo10h_aligned_grouped_control.md`;numerical/packing/placement/program/
results and broad ordinary UNMODIFIED source-model support100% remain work.
