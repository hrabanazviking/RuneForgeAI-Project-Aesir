# Æsir Hailo campaign control

This file records owner-authorized scope and technical controls for the Hailo-10H campaign. Decisions about project architecture remain with the owner.

## Slice 021 — owner-approved Hailo-only mission (complete)

The user explicitly directs the roadmap toward running Project Æsir LLMs on the Hailo-10H and excludes development of Project Æsir Pi CPU inference at this time. This campaign therefore treats Hailo-10H as the only LLM execution target. No CPU fallback, CPU shadow LLM inference, or CPU-serving work is authorized. Ordinary Pi orchestration remains allowed.

Evidence: user instruction recorded in this task; `docs/HAILO10H_MISSION.md`; `docs/HAILO10H_NO_CPU_INFERENCE.md`.

## Slice 022 — Pure Mojo runtime policy (complete)

Æsir's shipped execution path remains native Mojo under the repository's engineering doctrine. Python remains test-only where existing policy allows it. This slice adds no Python runtime dependency and no CPU inference implementation.

Evidence: ENGINEERING_DOCTRINE.md, AGENT_ONBOARDING.md, and the Hailo mission constraints.

## Slice 023 — No HEF, DFC, or vendor-runtime requirements (complete)

This campaign preserves the existing explicit architecture requirements: do not create, read, or require HEF artifacts; do not install or invoke the proprietary Hailo Dataflow Compiler; and do not link, dlopen, or require HailoRT/Hailo-Ollama as Æsir runtime dependencies. The feasibility risk is accepted as a possible blocker, not silently resolved by relaxing these constraints.

Evidence: docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md and the repository's MÍMISBRUNNR architectural laws.

## Slice 024 — Clean-room research and license gate (complete)

Vendor drivers, HailoRT, and other third-party implementations may be studied only under the repository's clean-room procedure: check license and study permissions first, record sources and intent, extract general concepts rather than code, and independently design any Æsir implementation. Do not copy or mechanically translate source. If the needed protocol/configuration cannot be derived within these boundaries, record the blocker.

Evidence: ENGINEERING_GOALS_AND_BOUNDARIES.md, DEPENDENCY_POLICY.md, docs/plunder/.

## Slice 025 — Vendor GenAI examples are reference evidence only (complete)

Official Raspberry Pi/Hailo LLM documentation, Hailo GenAI Model Zoo, and Hailo-Ollama can establish what the vendor-supported Hailo-10H path requires. They do not establish an Æsir-compatible implementation: the current documented path uses Hailo model artifacts and vendor runtime components that conflict with Slice 023. Do not install or invoke those components as a workaround.

Evidence: docs/HAILO10H_OS_SOFTWARE_IDENTITY.md and docs/HAILO10H_MODULE_MEMORY_EVIDENCE.md; official source links are recorded there.

## Slice 026 — Permitted host responsibilities (complete)

The Pi may run operating-system and ordinary application work: request parsing, file and model-metadata reading, tokenization, process/device orchestration, non-content diagnostics, and response formatting. Host-side work must not compute transformer layers or model logits. Any generation sub-operation whose classification is unclear must be resolved by evidence and architecture review before implementation; it must not become hidden CPU inference.

Evidence: docs/HAILO10H_COMPONENT_BOUNDARIES.md and docs/HAILO10H_NO_CPU_INFERENCE.md.

## Slice 027 — Prohibited inference routes (complete)

This campaign does not develop CPU LLM execution, CPU fallback, CPU shadow inference, CPU model serving, CUDA LLM execution, or cloud inference. Existing CPU/CUDA code remains untouched. On missing/unverified Hailo capability, Æsir reports an error and does not dispatch model execution elsewhere.

Evidence: docs/HAILO10H_INFERENCE_POLICY.md, docs/HAILO10H_NO_CPU_INFERENCE.md, and docs/HAILO10H_NETWORK_ASSUMPTIONS.md.

## Slice 028 — Decision log and change control (complete)

docs/HAILO10H_DECISION_LOG.md is the campaign decision record. It distinguishes user-authorized scope, project architecture, observed hardware facts, and unresolved technical questions. Only the project owner may change the Hailo-only mission or relax the no-HEF/no-DFC/no-vendor-runtime requirements; a blocker does not imply approval to change them.

## Slice 029 — Fail-closed behavior (complete)

If Hailo identity, a permitted execution interface, the selected model representation, or accelerator execution cannot be verified, Æsir returns a specific error and performs no LLM inference. It must not retry through CPU, CUDA, a remote endpoint, or an unapproved vendor service.

Evidence: docs/HAILO10H_INFERENCE_POLICY.md and docs/HAILO10H_NO_CPU_INFERENCE.md.

## Slice 030 — Gate and blocker policy (complete)

Every dependent implementation slice requires evidence-backed GO decisions for safe transport, command completion, and executable Hailo configuration generation. A missing prerequisite marks downstream work BLOCKED; it does not count as a simulated pass, trigger CPU work, or erase the 200-slice plan. The campaign may honestly conclude INCOMPLETE with the blocking evidence named.

Evidence: docs/HAILO10H_ONLY_200_SLICE_ROADMAP.md; docs/smidr/PHASE_D_GATE.md.

## Slice 031 — Re-read H111 with dated claims isolated (complete)

Re-read docs/smidr/PHASE_D_GATE.md and docs/smidr/H102_ATTEMPT_RECORD.md. H111 is dated 2026-10-10 and records NO-GO. Its concrete finding is zero completion on the tested app/core command paths, with H105–H110 blocked. The verdict is scoped to those attempts and that tested environment; it is not a claim that no future Hailo path can ever exist.

Evidence crosswalk: docs/HAILO10H_PHASE_D_RECONCILIATION.md.

## Slice 032 — Check Æsir changes since the H111 baseline (complete)

Compared GitHub main to docs/cross-cutting-hailo-mission. The feature branch is 47 commits ahead and not behind main; the reported changed-file inventory consists of campaign documentation and the corrected legacy-roadmap notice. No Æsir source change or newer hardware compute proof appears in that comparison. Main remains pinned at 3b2608a3993ddbadaaac5d7799f22966d5d62896.

Limit: this confirms repository history through the observed branch tips; continue checking before future implementation.

## Slice 033 — Review current official Hailo execution documentation (complete)

Current official Hailo documentation reviewed: Hailo GenAI Model Zoo describes Hailo-Ollama on HailoRT; the Hailo Model Zoo documents Dataflow Compiler compilation and HEF output for hardware execution; Raspberry Pi's AI HAT+ 2 LLM guide describes its Hailo GenAI package/Hailo-Ollama path. The reviewed public materials do not document a raw, HEF-free, DFC-free, vendor-runtime-free LLM compute API for Æsir to call. This is a bounded documentation finding, not proof that no private or future interface exists.

Sources: https://github.com/hailo-ai/hailo_model_zoo_genai ; https://github.com/hailo-ai/hailo_model_zoo ; https://www.raspberrypi.com/documentation/computers/ai.html

## Slice 034 — Review upstream driver/runtime release changes (study only) (complete)

Read-only review of Hailo's public hailort-drivers v5.3.0 → v5.4.0 comparison was performed under the repository's existing clean-room study-only boundary. The source headers identify GPL-2.0; no source was copied into Æsir. The integrated firmware-control implementation changed request/response framing (the expected-MD5 field is removed) and changed timeout handling to a fixed default. This is a meaningful control-path research lead. It is not evidence that the H102 direct app/core mailbox protocol, doorbell, or completion behavior changed; H102's vendor ioctl attempt also reported the integrated-device operation unsupported.

Sources: https://github.com/hailo-ai/hailort-drivers/releases ; https://github.com/hailo-ai/hailort-drivers/compare/v5.3.0...v5.4.0 ; source paths reviewed: linux/integrated_nnc/src/fw_control.c at tags v5.3.0 and v5.4.0. Follow existing docs/plunder/HAILO_* study records and license policy for any deeper study.

## Slice 035 — Compare installed identity with historic H102 environment (complete)

The current live sample reports kernel 6.12.112-v8-16k-hailo+, hailo1x module 5.3.0, and device firmware 5.3.0. H102 records the same kernel family and a loaded firmware, but does not pin an exact firmware version for the mailbox attempts. Therefore firmware equivalence cannot be established from the available H102 record. Upstream driver v5.4.0 exists, but it is not installed and was not applied to this machine. No upgrade or reboot was performed.

Evidence: docs/HAILO10H_HOST_DEVICE_IDENTITY.md, docs/HAILO10H_OS_SOFTWARE_IDENTITY.md, docs/smidr/H102_ATTEMPT_RECORD.md.

## Slice 036 — Assess non-invasive discriminating observations (complete)

Read-only device identity, current driver/firmware versions, PCI link state, node/module state, and the upstream v5.4 source delta are now known. None directly reports whether the H102 app-CPU/core mailbox service accepts a clean-room raw command. No additional non-invasive indicator in the available supported tools was identified that would distinguish the historic silent-mailbox state from a recovered command service. Do not infer success from device scan/identify.

## Slice 037 — Bound a safe revalidation plan (complete)

Revalidation is limited to (a) compare public docs/source changes under clean-room policy, (b) read the current device/software identity and sysfs access state, and (c) compare those facts with H102/H111. No unbind, rebind, reset, firmware upload, or raw mailbox write is in this plan. Any future mutating device experiment requires a separate safety case with exact state-restoration steps before execution; this slice grants no such authorization.

## Slice 038 — Complete read-only current-state probes (complete)

Executed read-only commands to record OS/kernel/firmware identity, PCI BDF/device ID and driver, Hailo device architecture/firmware, PCI link speed/width and maximum, IOMMU group presence, device nodes, loaded modules, UIO module availability, host memory, Pi temperature, and throttling flag. The probes made no writes to device resources and ran no LLM inference.

Evidence: docs/HAILO10H_HOST_DEVICE_IDENTITY.md, docs/HAILO10H_OS_SOFTWARE_IDENTITY.md, docs/HAILO10H_ACCESS_MECHANISMS.md.

## Slice 039 — Compare current evidence against H102/H111 (complete)

Current observations confirm the same Hailo-10H identity and kernel family as historic campaign records, but do not demonstrate command completion. The historical attempt's exact firmware build is not pinned. The upstream v5.4 firmware-control change is potentially relevant but not proven to alter the direct command mailbox or resolve its silence. The old failure remains valid for the attempt as run; no current result supersedes its NO-GO gate.

## Slice 040 — Publish feasibility verdict and block dependent work (complete)

Verdict for Æsir's current constrained path: **NO-GO / BLOCKED**. No documented, evidence-backed route currently provides both Hailo command completion and executable model configuration while preserving no-HEF/no-DFC/no-HailoRT-runtime requirements. Keep model execution and integration slices blocked. The v5.4 integrated firmware-control framing change is a bounded research lead for future owner-reviewed investigation, not permission to update system packages or alter constraints. No CPU LLM branch is available.

Evidence: docs/HAILO10H_PHASE_D_RECONCILIATION.md, docs/HAILO10H_ACCESS_MECHANISMS.md, docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md, and upstream release comparison linked in Slice 034.

## Slice 041 — Verify Mojo ARM64 toolchain status from official docs (complete)

Modular's current Mojo requirements list Linux ARM64 support, and the compilation-target documentation lists AArch64 code generation. The documented/tested Linux environments specify Ubuntu 22.04+ and ARM64 AWS Graviton2/3; other Linux distributions are expected where glibc requirements are met but are not tested. These pages do not name Raspberry Pi 5/Cortex-A76 as a validated runtime host. Finding: ARM64 support exists, while Pi 5 toolchain/runtime support remains unverified.

Sources: https://docs.modular.com/mojo/requirements/ ; https://docs.modular.com/mojo/tools/compilation/

## Slice 042 — Check Æsir build target against the Pi (complete)

The repository's aesir_engine/pixi.toml declares only linux-64. The reviewed project manifest does not declare linux-aarch64, and the default project CI/build evidence is x86_64. This is a packaging/build-target gap for the current AArch64 Pi environment; it does not prove that Mojo cannot compile Æsir there. No build or inference workload was run in this documentation slice.

Evidence: aesir_engine/pixi.toml and CAPABILITY_LEDGER.md.

## Slice 043 — Map required Mojo/POSIX device-control primitives (complete)

The Hailo transport research requires host-side PCI discovery plus bounded file/device operations such as open/read/close, resource mapping/unmapping, ioctl or an approved alternative, synchronization, and completion waits; DMA additionally needs a valid device-visible address and ownership contract. Mojo documents std.ffi external_call for C interoperability. Availability of an FFI call does not establish a safe DMA/IOMMU path or a Hailo command protocol.

Sources: https://docs.modular.com/mojo/std/ffi/ ; docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md; docs/HAILO10H_ACCESS_MECHANISMS.md.

## Slice 044 — Review primitive availability against dependency policy (complete)

Mojo stdlib and OS/POSIX interfaces are distinct from third-party runtime dependencies. The project's DEPENDENCY_POLICY classifies libc functions as dependencies requiring justification. Any proposed FFI list therefore needs an explicit API-by-API justification and must avoid dynamic HailoRT loading or proprietary libraries. No dependency approval is inferred from the existence of std.ffi.

Evidence: DEPENDENCY_POLICY.md, docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md, and the official Mojo FFI docs.

## Slice 045 — Record firmware ownership and redistribution boundary (complete)

The project architecture treats Hailo firmware as proprietary and user-side supplied: Æsir must not fetch, embed, commit, or redistribute firmware blobs. Existing bring-up source records firmware names and hashes only as operational evidence; campaign artifacts must not copy firmware payloads. Any firmware prerequisite must be documented separately from Æsir's own code and verified without placing the blob in the repository.

Evidence: repository Hailo architectural laws L7, docs/plunder/HAILO_FW_LOAD_REGISTERS.md, and dependency/licensing policy.

## Slice 046 — Inventory official LLM artifacts against the campaign constraints (complete)

Official Hailo material describes LLM serving through Hailo-10H artifacts and HailoRT, and its model/compilation workflow uses the Dataflow Compiler to generate HEF. These requirements conflict with the current Æsir no-HEF/no-DFC/no-vendor-runtime design. The artifacts remain reference evidence only and are not selected for Æsir.

Sources: https://github.com/hailo-ai/hailo_model_zoo_genai ; https://github.com/hailo-ai/hailo_model_zoo ; https://www.raspberrypi.com/documentation/computers/ai.html.

## Slice 047 — Review public direct-Hailo LLM research and its prerequisites (complete)

The public hailo-10h-llm-compiler project documents Hailo Dataflow Compiler 5.3.0 as a proprietary prerequisite and generates HEF artifacts served through Hailo-Ollama/HailoRT. Its public hardware results therefore do not demonstrate a path compatible with Æsir's current no-DFC/no-HEF/no-vendor-runtime requirements. No code or artifact from that project was imported.

Source: https://git.mitgai.net/l-nmch/hailo-10h-llm-compiler/blob/main/README.md ; https://community.hailo.ai/t/i-compiled-an-llm-for-the-hailo-10h/19685.

## Slice 048 — Record clean-room source, licenses, facts, and unknowns (complete)

Clean-room study log: Hailo official driver repository (GPL-2.0; study-only per repository doctrine), Hailo Model Zoo GenAI (MIT repository but depends on HailoRT and compiled artifacts), official Hailo Model Zoo (DFC/HEF workflow), Raspberry Pi official AI docs, Modular Mojo official requirements/compilation/FFI docs, and public Hailo-10H LLM compiler (MIT code with proprietary DFC requirement). Facts are recorded as requirements and architectural observations only; no upstream source code or distinctive implementation was copied. Unknowns: a supported raw command API, artifact-free executable configuration format, and Pi-specific Mojo runtime validation.

Source inventory paths/links are in docs/HAILO10H_CAMPAIGN_CONTROL.md slices 033–047 and docs/plunder/HAILO_* guides.

## Slice 049 — Assess whether a compliant configuration-generation route is evidenced (complete)

The reviewed official path depends on the proprietary DFC and HEF; the reviewed independent compiler project also depends on DFC and emits HEF. Existing Æsir H104 emits a deterministic host-side candidate, but PHASE_D_GATE.md explicitly marks its chip executability unproven and H102 transport failed. No evidence-backed route presently satisfies no-DFC/no-HEF plus actual Hailo execution. Do not promote host-side generation artifacts to a passing configuration generator.

## Slice 050 — Issue a technical/architecture feasibility recommendation (complete)

Recommendation: continue only evidence research and reversible design work under the current architecture; keep the native Hailo LLM execution path BLOCKED. Officially documented Hailo-10H LLM paths found in this review require components the project excludes, while the prior clean-room transport attempt ended NO-GO. A future implementation decision requires materially new evidence for both command completion and configuration generation, or an explicit owner decision changing those architecture constraints. This is not permission for CPU LLM work and is not a claim that Hailo hardware cannot run LLMs through supported vendor paths.

Decision recorded in docs/HAILO10H_DECISION_LOG.md and the Slice 040 gate.

## Slice 051 — Define HAILBRÚ device-ownership boundary (complete)

Only HAILBRÚ may discover PCI endpoints, inspect BAR/resource metadata, acquire device ownership, map accelerator resources, allocate or submit DMA buffers, configure interrupts, issue device ioctls, or submit commands. Model, API, memory, and orchestration domains may consume only a published HAILBRÚ interface and may not access PCI resources directly.

Evidence: repository architecture/domain boundaries; docs/HAILO10H_COMPONENT_BOUNDARIES.md.

## Slice 052 — Record current driver ownership and exclusivity (complete)

The live Hailo endpoint is bound to kernel driver hailo1x. Treat that binding as exclusive ownership. Æsir must not map or submit raw commands while hailo1x owns the endpoint, and no campaign action may unbind or rebind it under the present read-only plan.

Evidence: docs/HAILO10H_ACCESS_MECHANISMS.md and docs/HAILO10H_HOST_DEVICE_IDENTITY.md.

## Slice 053 — Make read-only the default device mode (complete)

All census, diagnostics, and feasibility checks default to read-only operations. Reading PCI identity/link metadata or supported Hailo identify output does not authorize BAR writes, firmware transfer, ownership changes, DMA, interrupts, reset, or command submission. A future mutating path must be explicitly separate, gated, and auditable.

## Slice 054 — Specify safeguards for future mutating probes (complete)

No mutating device probe is included or authorized by these slices. Before any future attempt, require a written safety case naming the exact operation, impact, preconditions, saved baseline, rollback/restore procedure, timeout, expected state afterward, and evidence to stop on failure. Require owner review of that concrete procedure before touching the live endpoint. No such procedure is executed here.

## Slice 055 — Require fail-closed PCI identity checks (complete)

Any future HAILBRÚ acquisition path must verify the expected PCI vendor/device identity and Hailo architecture before touching device resources. A missing, ambiguous, or mismatched identity returns a named error and performs no mapping, write, bind change, firmware operation, or LLM execution. Current observed identity is 1e60:45c4 and HAILO10H; this is inventory, not acquisition permission.

## Slice 056 — Specify BAR metadata and bounds validation (complete)

Before any future mapping, HAILBRÚ must validate the resource index, resource size, offset, access width, alignment, and overflow-safe end bound against the OS-provided resource metadata. Unknown BAR semantics or out-of-range access must fail closed. This is an acceptance contract only; this slice performs no BAR mapping.

## Slice 057 — Document VFIO's missing IOMMU group (complete)

The Hailo endpoint currently has no sysfs iommu_group, although /dev/vfio/vfio exists and VFIO_PCI support is present. Therefore the current view does not supply an endpoint VFIO group or establish an IOMMU-backed DMA path. No VFIO binding or IOMMU setting was changed.

Evidence: docs/HAILO10H_ACCESS_MECHANISMS.md.
