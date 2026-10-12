# Project AESIR: 200-slice Hailo-10H roadmap

**Goal:** make Project AESIR reliably useful with every LLM inference executed on the Hailo-10H accelerator. The Raspberry Pi CPU may run the operating system, AESIR orchestration, UI, tokenization, storage, and other non-LLM support code; it must never run an LLM inference path or fallback.

**Repository baseline:** Project Æsir is an experimental native Mojo LLM inference engine. Its Hailo design intent is local Hailo-10H inference through a pure-Mojo path, with no HEF, proprietary Dataflow Compiler, or vendor inference runtime dependency. The codebase currently has a reserved `HAILO_10` enum but no Hailo execution dispatch; the prior H111 Phase-D gate is NO-GO after documented mailbox silence. The machine census and campaign evidence are recorded in `docs/HAILO10H_*` and `docs/smidr/PHASE_D_GATE.md`.

**Execution model:** 20 phases × 10 slices = exactly 200 slices. Slices are Hailo-only. Hardware or host CPU may perform ordinary orchestration, parsing, tokenization, sampling, and control work, but no slice builds, runs, benchmarks, tests, or falls back to CPU LLM inference. Preserve the project's no-HEF/no-DFC/no-HailoRT-runtime constraint. If a Hailo-only gate is infeasible, record the evidence and stop at a decision point; do not substitute a CPU solution.

**Slice execution:** Work through the numbered slices in order when their gates are open. Each completed slice must leave a reviewable artifact, verified behavior, or evidence-backed decision. The vendor Hailo GenAI path is reference evidence only and does not meet Æsir’s no-HEF/no-proprietary-toolchain/no-vendor-runtime constraints.

## Repository-grounded gates

- Prior H111 is **NO-GO**: H102 recorded no mailbox completion on either documented doorbell despite the listed hardening attempts; H105–H110 were blocked. See `docs/smidr/PHASE_D_GATE.md` and `docs/smidr/H102_ATTEMPT_RECORD.md`.
- The current machine census is in `docs/HAILO10H_ACCESS_CENSUS.md`; it is an observation snapshot, not permission to unbind/reset/reflash the device.
- Current Æsir Hailo support is not an inference backend: the Hailo enum is reserved and NPU dispatch remains missing. Confirm against `CAPABILITY_LEDGER.md` and code before implementation.
- Official Hailo GenAI documentation may be consulted for current facts, but its HEF/DFC/HailoRT requirements do not satisfy this campaign's architecture. Do not install or invoke those tools as a workaround.
- A technical NO-GO blocks dependent slices. The roadmap still contains 200 planned slices, but blocked items remain blocked until new Hailo evidence or an explicit owner-approved architecture decision changes the constraints.

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

- [ ] **Slice 011.** Reconcile the checked-out branch and remote default branch without discarding owner changes.
- [ ] **Slice 012.** Record the exact current Æsir commit and identify the authoritative Hailo campaign artifacts.
- [ ] **Slice 013.** Inventory Hailo-related source and documentation without opening or changing device state.
- [ ] **Slice 014.** Record the observed Pi 5, Hailo-10H identity, PCI BDF, driver binding, and link width/speed.
- [ ] **Slice 015.** Record Hailo module memory claims separately from what the current device reports.
- [ ] **Slice 016.** Record the current OS, kernel, firmware, HailoRT package, and GenAI package versions as observations only.
- [ ] **Slice 017.** Check current PCIe/IOMMU/UIO/VFIO facts using read-only queries and mark unknowns explicitly.
- [ ] **Slice 018.** Review prior Phase-B/C bring-up evidence and distinguish historic state from current census.
- [ ] **Slice 019.** Reconcile H101–H111 evidence paths and confirm the Phase-D NO-GO remains current or needs a bounded revalidation.
- [ ] **Slice 020.** Publish a dated evidence inventory with source paths, freshness, and confidence labels.

## Phase 03: Constraints and decision control

- [ ] **Slice 021.** Record the owner-approved Hailo-only mission and explicitly prohibit Pi CPU LLM work.
- [ ] **Slice 022.** Record pure Mojo runtime policy and Python-test-only boundary from project doctrine.
- [ ] **Slice 023.** Record no-HEF, no-DFC, and no-vendor-inference-runtime requirements as campaign invariants.
- [ ] **Slice 024.** Record clean-room requirements for any vendor driver/runtime study, including license gate and provenance.
- [ ] **Slice 025.** Mark HailoRT/model-zoo/Ollama examples as comparison evidence, not an approved Æsir architecture.
- [ ] **Slice 026.** Define permitted host responsibilities: control plane, tokenizer, sampler, and data movement only.
- [ ] **Slice 027.** Define prohibited execution paths: CPU LLM, CPU fallback, CPU shadow inference, CUDA LLM, and cloud inference.
- [ ] **Slice 028.** Create a decision log that distinguishes technical evidence from owner choices.
- [ ] **Slice 029.** Define fail-closed behavior when no verified Hailo compute path exists.
- [ ] **Slice 030.** Approve the campaign gate policy: a failed prerequisite blocks dependent slices and never routes to CPU inference.

## Phase 04: Hailo-only feasibility revalidation

- [ ] **Slice 031.** Re-read the H111 decision and identify exactly which claims are dated and hardware-specific.
- [ ] **Slice 032.** Check upstream Æsir history for any Hailo-path change after the H111 evidence commit.
- [ ] **Slice 033.** Check official Hailo documentation for any newly documented raw-compute interface, using dated citations.
- [ ] **Slice 034.** Check upstream Hailo driver/runtime releases for any documented mailbox protocol change; study only.
- [ ] **Slice 035.** Check whether the current installed firmware/device version differs materially from the H102 test environment.
- [ ] **Slice 036.** Determine whether a new non-invasive observation can distinguish stale evidence from unchanged behavior.
- [ ] **Slice 037.** Write a bounded revalidation plan that does not unbind, reset, or reflash the live device without a documented safety basis.
- [ ] **Slice 038.** Execute only read-only revalidation probes needed to establish present device/software identity.
- [ ] **Slice 039.** Compare current observations to H102/H111 and state whether evidence invalidates, narrows, or confirms NO-GO.
- [ ] **Slice 040.** Publish the Hailo compute feasibility verdict; if NO-GO remains, mark implementation slices BLOCKED pending owner decision.

## Phase 05: Toolchain and legal feasibility

- [ ] **Slice 041.** Verify current Mojo compiler support for the project's target architecture from official Mojo documentation.
- [ ] **Slice 042.** Determine whether Æsir's existing build can target the current Pi environment; do not create CPU inference work.
- [ ] **Slice 043.** Map the minimum POSIX/device-control primitives a Mojo-only Hailo transport would require.
- [ ] **Slice 044.** Verify whether those primitives are available under the project's dependency and licensing policies.
- [ ] **Slice 045.** Map firmware ownership and redistribution constraints without fetching or bundling firmware.
- [ ] **Slice 046.** Inventory official Hailo LLM artifacts and record why their HEF/DFC/runtime requirements conflict with Æsir constraints.
- [ ] **Slice 047.** Inventory public research claiming direct Hailo execution and verify hardware, artifact, toolchain, and license requirements.
- [ ] **Slice 048.** Create a clean-room research log with source URLs, licenses, facts, and unanswered questions.
- [ ] **Slice 049.** Ask no code path to depend on proprietary tools; identify whether any compliant configuration-generation route is evidenced.
- [ ] **Slice 050.** Issue a technical/legal feasibility recommendation with explicit unresolved owner decisions.

## Phase 06: Safe device-access contract

- [ ] **Slice 051.** Specify the HAILBRÚ ownership boundary for PCI discovery, BARs, DMA, interrupts, and device commands.
- [ ] **Slice 052.** Document the current bound-driver state and prohibit accidental simultaneous driver ownership.
- [ ] **Slice 053.** Specify a read-only default mode for all device census and diagnostics.
- [ ] **Slice 054.** Define explicit preconditions and operator safeguards for any future mutating device probe.
- [ ] **Slice 055.** Specify PCI identity checks that fail closed on a non-Hailo-10H endpoint.
- [ ] **Slice 056.** Specify BAR/resource validation and bounds checks before any mapping operation is permitted.
- [ ] **Slice 057.** Document the current missing-IOMMU-group limitation for VFIO on this machine.
- [ ] **Slice 058.** Document UIO availability as unverified until module and interrupt/DMA behavior are tested under an approved procedure.
- [ ] **Slice 059.** Reject sysfs BAR access as a DMA execution solution unless a safe, evidenced DMA contract is established.
- [ ] **Slice 060.** Publish HAILBRÚ access contract and gate all device-touching implementation on a GO decision.

## Phase 07: Firmware and control-plane evidence

- [ ] **Slice 061.** Inventory the current firmware identity from supported read-only tooling.
- [ ] **Slice 062.** Compare current firmware identity with the exact H102 test identity where logs allow.
- [ ] **Slice 063.** Document which firmware status signals are observable without taking device ownership.
- [ ] **Slice 064.** Review documented app-CPU and core doorbell semantics against primary sources.
- [ ] **Slice 065.** Record that the historic app and core mailbox submissions yielded no completion.
- [ ] **Slice 066.** Check whether any official update documents mailbox access restrictions on integrated Hailo-10H.
- [ ] **Slice 067.** Define what positive evidence would prove the firmware control service is reachable.
- [ ] **Slice 068.** Define what negative evidence is sufficient to block compute submissions safely.
- [ ] **Slice 069.** Keep new mailbox experiments blocked until owner-approved safety, state restoration, and evidence gaps are explicit.
- [ ] **Slice 070.** Publish a firmware/control-plane evidence matrix with supported, contradicted, and unknown claims.

## Phase 08: Configuration-generation research

- [ ] **Slice 071.** Restate the chip-executable configuration problem independently of the transport problem.
- [ ] **Slice 072.** Inventory H019 unknown configuration elements and current confidence per element.
- [ ] **Slice 073.** Reassess whether public sources expose operation encoding or scheduler/configuration semantics.
- [ ] **Slice 074.** Survey public compiler outputs only where legally and technically permissible; do not invoke DFC.
- [ ] **Slice 075.** Define a clean-room method for recording externally observed formats without copying source code.
- [ ] **Slice 076.** Determine what evidence would validate a generated configuration without submitting it to hardware.
- [ ] **Slice 077.** Assess whether a configuration generator can be technically complete with currently available evidence.
- [ ] **Slice 078.** Reject undocumented magic bytes and synthetic success claims in generated configurations.
- [ ] **Slice 079.** Specify a stopping criterion for unbounded reverse engineering under this campaign.
- [ ] **Slice 080.** Publish a configuration-surface feasibility decision; block execution work if the control/config surfaces remain unknown.

## Phase 09: Hailo-only compute proof design

- [ ] **Slice 081.** Define the smallest useful Hailo compute operation and its exact input/output contract.
- [ ] **Slice 082.** Define an independent host-side oracle strictly for verifying Hailo results, never for LLM inference.
- [ ] **Slice 083.** Specify an artifact-free test representation consistent with the no-HEF rule.
- [ ] **Slice 084.** Specify how proof inputs and outputs will be checksummed and retained.
- [ ] **Slice 085.** Define completion, timeout, device-health, and result-integrity evidence required for a pass.
- [ ] **Slice 086.** Define repeatability requirements for an operation that has actually executed on the accelerator.
- [ ] **Slice 087.** Define how telemetry will prove silicon execution rather than host-side emulation.
- [ ] **Slice 088.** Define the safety checks and restore procedure before any mutating device proof.
- [ ] **Slice 089.** Write go/no-go criteria for the first real Hailo operation; no CPU fallback branch.
- [ ] **Slice 090.** Keep the first compute proof BLOCKED until transport and configuration generation both have evidence-backed GO decisions.

## Phase 10: Native Hailo transport prerequisites

- [ ] **Slice 091.** Review existing HAILBRÚ implementation and separate historical code from currently usable interface.
- [ ] **Slice 092.** Document exact device-discovery behavior and its permissions requirements.
- [ ] **Slice 093.** Document BAR metadata parsing contract without mapping device resources.
- [ ] **Slice 094.** Specify memory ownership and DMA address semantics required by a Hailo operation.
- [ ] **Slice 095.** Specify interrupt/completion semantics required by the prior mailbox model and unresolved gaps.
- [ ] **Slice 096.** Document concurrency and exclusive-access rules for the endpoint.
- [ ] **Slice 097.** Define error types for absent device, wrong device, permission denial, and unsupported mechanism.
- [ ] **Slice 098.** Define cleanup invariants for file descriptors, mappings, and device ownership.
- [ ] **Slice 099.** Prepare transport implementation acceptance criteria guarded behind feasibility GO.
- [ ] **Slice 100.** Record transport implementation status without claiming inference capability.

## Phase 11: Hailo compute enablement gate

- [ ] **Slice 101.** Reconcile command-submission transport requirements with the H102 failure signature.
- [ ] **Slice 102.** Identify any new official mechanism that could replace the silent firmware mailbox path.
- [ ] **Slice 103.** Require independently sourced evidence before changing doorbell or completion assumptions.
- [ ] **Slice 104.** Assess whether firmware protocol access is possible without vendor runtime dependence.
- [ ] **Slice 105.** Assess whether raw compute configuration is possible without HEF/DFC.
- [ ] **Slice 106.** Join transport and configuration evidence into a single dependency graph.
- [ ] **Slice 107.** Define a technical NO-GO result for unresolved transport, encoding, or legal barriers.
- [ ] **Slice 108.** Define the sole GO criterion: one real Hailo-10H operation with device-completion and output evidence.
- [ ] **Slice 109.** Record whether Hailo-only inference work is unblocked; if not, stop dependent implementation slices.
- [ ] **Slice 110.** Publish the campaign gate and leave all CPU inference slices absent.

## Phase 12: Model computation mapping research

- [ ] **Slice 111.** Inventory transformer operations required by Æsir's selected model family from existing loaders and architecture docs.
- [ ] **Slice 112.** Map each operation to a Hailo compute primitive only when that primitive is verified on-device.
- [ ] **Slice 113.** Record unsupported or unknown operations without substituting CPU execution.
- [ ] **Slice 114.** Assess Hailo memory layout requirements from documented, permissible evidence.
- [ ] **Slice 115.** Assess tensor precision and quantization contracts required by the selected model.
- [ ] **Slice 116.** Define weight and activation representations for a hypothetical proven Hailo primitive.
- [ ] **Slice 117.** Map attention and KV-cache operations to Hailo only where device capability is measured.
- [ ] **Slice 118.** Map prefill and decode dependency chains with no host LLM math.
- [ ] **Slice 119.** Identify minimal model architecture that could be supported by a demonstrated Hailo operation set.
- [ ] **Slice 120.** Publish an operation coverage matrix; no LLM integration until every required op has Hailo proof.

## Phase 13: Host-to-device data path contract

- [ ] **Slice 121.** Define host/device tensor ownership transitions around verified Hailo operations.
- [ ] **Slice 122.** Specify transfer integrity checks and evidence counters.
- [ ] **Slice 123.** Specify bounded staging memory without copying inference compute onto the host.
- [ ] **Slice 124.** Define synchronization needed between transfer and accelerator completion.
- [ ] **Slice 125.** Define behavior for partial transfers and device timeouts.
- [ ] **Slice 126.** Define address, alignment, and size constraints from verified hardware documentation.
- [ ] **Slice 127.** Define cache-coherency assumptions and require hardware evidence before use.
- [ ] **Slice 128.** Define cleanup after cancellation or device removal.
- [ ] **Slice 129.** Specify transfer benchmarks only after the compute path exists.
- [ ] **Slice 130.** Publish data-path contract gated on verified Hailo transport and compute.

## Phase 14: Æsir Hailo backend integration design

- [ ] **Slice 131.** Inspect existing Æsir backend enums, configuration validators, and dispatch points.
- [ ] **Slice 132.** Document each missing connection from model request to Hailo submission and result.
- [ ] **Slice 133.** Design a Hailo-only backend interface without CPU/CUDA alternatives in the campaign.
- [ ] **Slice 134.** Define startup readiness as Hailo device plus verified Hailo operation capability.
- [ ] **Slice 135.** Define model loading so host parsing prepares tensors but does not execute LLM layers.
- [ ] **Slice 136.** Define how unsupported operations fail with a named Hailo capability error.
- [ ] **Slice 137.** Define sampling and output assembly on the host as non-LLM orchestration only.
- [ ] **Slice 138.** Specify runtime evidence attached to each generated response for accelerator provenance.
- [ ] **Slice 139.** Specify test seams that cannot report simulated Hailo success as hardware proof.
- [ ] **Slice 140.** Publish a backend integration design; keep code implementation blocked until gate GO.

## Phase 15: First model feasibility

- [ ] **Slice 141.** List Æsir's currently supported model formats and architecture families from repository evidence.
- [ ] **Slice 142.** Select one candidate model architecture for Hailo mapping, without approving a vendor HEF path.
- [ ] **Slice 143.** Record model license, revision, tokenizer, and architecture metadata.
- [ ] **Slice 144.** Estimate accelerator memory needs from documented capacity; label estimates rather than measurements.
- [ ] **Slice 145.** Define conversion-free or project-approved input representation for candidate weights.
- [ ] **Slice 146.** Check whether model quantization needed by Hailo can be produced without prohibited tooling.
- [ ] **Slice 147.** Map every model layer to the operation coverage matrix.
- [ ] **Slice 148.** Reject the model candidate if any required op or configuration format is unverified.
- [ ] **Slice 149.** Document what new Hailo capabilities would be needed to revisit rejected candidates.
- [ ] **Slice 150.** Publish a candidate decision; do not execute any LLM on the Pi CPU.

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
- [ ] **Slice 199.** If the no-HEF/no-DFC path remains blocked, publish INCOMPLETE with the exact technical and owner decision needed.
- [ ] **Slice 200.** Revise the next roadmap only from new Hailo evidence or an explicit owner-approved architecture change.

