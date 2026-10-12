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

## Slice 058 — Mark UIO usability as unverified (complete)

The kernel contains uio_pci_generic.ko.xz, but the module is not bound to the Hailo endpoint, and this census does not demonstrate UIO interrupt behavior, a safe DMA model, or Hailo control-command completion. Availability is not capability. No UIO binding or probe was performed.

Evidence: docs/HAILO10H_ACCESS_MECHANISMS.md and docs/smidr/H102_ATTEMPT_RECORD.md.

## Slice 059 — Reject sysfs BAR access as a DMA execution mechanism (complete)

Sysfs resource exposure may support bounded register inspection in some configurations, but it does not itself provide an evidenced DMA allocation/address mapping, interrupt/completion path, or command protocol. Do not treat BAR mmap alone as a viable LLM execution transport. Require separately proven safe DMA and command-completion contracts before considering any mechanism.

Evidence: docs/HAILO10H_ACCESS_MECHANISMS.md; docs/smidr/PHASE_D_GATE.md.

## Slice 060 — Publish HAILBRÚ access contract and gate implementation (complete)

The HAILBRÚ boundary, exclusive-ownership rules, read-only default, identity validation, BAR bounds, and VFIO/UIO status are recorded in this campaign-control log and access-mechanism inventory. Any device-touching implementation remains BLOCKED until the feasibility gate establishes an allowed, safe transport; current H111 NO-GO remains operative. No CPU LLM branch is permitted.

## Slice 061 — Record current firmware/control identity (complete)

The current read-only identify sample reports HAILO10H, firmware 5.3.0 (release,app), logger version 0, and control protocol v2. This is identity/version telemetry exposed through installed Hailo tooling; it does not show that Æsir's direct mailbox service is accepting commands.

Evidence: docs/HAILO10H_HOST_DEVICE_IDENTITY.md and docs/HAILO10H_OS_SOFTWARE_IDENTITY.md.

## Slice 062 — Compare firmware version with H102 evidence (complete)

H102 and Phase-D records identify the same kernel family and say the SOC firmware batch was loaded, but they do not record an exact firmware build/version for the raw mailbox attempts. Current identify output is 5.3.0. Therefore an exact firmware-version match or difference cannot be asserted; the current reading does not retroactively alter H102's measured no-completion result.

Evidence: docs/smidr/H102_ATTEMPT_RECORD.md; current identity snapshot.

## Slice 063 — List control signals observable without device ownership (complete)

Available read-only signals include PCI vendor/device identity, driver binding, negotiated/max PCIe link, node/module presence, supported hailortcli firmware/control-protocol identification, Pi thermal/throttle state, and host software versions. The reviewed outputs do not expose an Æsir-accessible raw mailbox-ready/command-acceptance signal. Hailo device temperature and usable accelerator-memory telemetry are also not currently established.

Evidence: docs/HAILO10H_HOST_DEVICE_IDENTITY.md, docs/HAILO10H_ACCESS_MECHANISMS.md, docs/HAILO10H_RESOURCE_ENVELOPE.md.

## Slice 064 — Reconcile app/core doorbell semantics with primary-source study (complete)

The campaign's documented mailbox model records the app-CPU doorbell at BAR4+0x1754 and the core-doorbell value 0x2 as studied protocol values; H101 marks claims with corroboration status. H102 then exercised both documented targets and observed no completion. These offsets/values remain research-derived interface claims, not an official public raw-compute contract and not a reason to issue more writes now.

Evidence: docs/plunder/HAILO_COMMAND_QUEUE.md, docs/smidr/H102_ATTEMPT_RECORD.md, and docs/smidr/PHASE_D_GATE.md.

## Slice 065 — Record historic app/core mailbox non-completion (complete)

H102's attempt record documents repeated app-CPU mailbox submissions plus a final core-doorbell probe: writes/readbacks appeared as expected, but no completion bit, MSI, or response was observed. A vendor ioctl attempt also did not expose the raw operation on the integrated device. This is the measured historic failure signature; no retry was executed by this slice.

## Slice 066 — Check official updates for mailbox changes (complete)

Public driver release v5.4.0 exists beyond the installed 5.3.0. The reviewed v5.3→v5.4 integrated firmware-control source changes request/response framing and timeout behavior, but the public release material reviewed does not state that the raw app/core doorbell protocol or H102 no-completion failure is fixed. The source delta is not enough to infer that it is the same interface.

Evidence: Slice 034 source comparison; https://github.com/hailo-ai/hailort-drivers/releases and https://github.com/hailo-ai/hailort-drivers/compare/v5.3.0...v5.4.0.

## Slice 067 — Define positive evidence for firmware control reachability (complete)

A positive control-service proof must show a correctly identified Hailo-10H endpoint accepts a well-formed, non-compute control request and returns a correlated completion/response within a bounded timeout, with device-state snapshots before/after and no host-side emulation. A board-identify response through the vendor stack is not sufficient proof for Æsir's raw command path. No request was submitted in this slice.

## Slice 068 — Define negative evidence and its limits (complete)

A bounded attempt that produces no correlated completion/response, together with a trace showing request bytes, target/doorbell, elapsed timeout, and unchanged/restored device state, is sufficient to fail that tested mechanism and block downstream compute work. It does not prove that every firmware version or every conceivable interface is impossible. H102 already satisfies this tested-path fail condition.

Evidence: docs/smidr/H102_ATTEMPT_RECORD.md.

## Slice 069 — Keep new mailbox experiments blocked (complete)

New mailbox writes remain blocked: there is no current mutating-probe safety case, driver-ownership handoff/restore plan, or new non-invasive signal isolating the control-service issue. The H102 attempt record is already comprehensive evidence for the tested path. A future attempt requires a separate owner-reviewed concrete safety plan before device mutation; this campaign performs none.

## Slice 071 — State the chip-configuration problem separately from transport (complete)

Hailo command transport and executable configuration are independent prerequisites. Even a working PCIe/DMA/doorbell path cannot compute unless the Hailo-10H firmware receives a valid operation description, tensor layout, memory placement, data-movement plan, schedule, and completion contract. Conversely, a valid configuration candidate cannot help while the tested submission path has no completion. This separation prevents transport results from being presented as compute proof.

Evidence: docs/plunder/HAILO_CONFIG_SURFACE.md and docs/smidr/PHASE_D_GATE.md.

## Slice 072 — Inventory H019 configuration elements and confidence (complete)

H019 lists seven MUST-HAVE elements for a minimal operation: (1) operation encoding, (2) tensor descriptors, (3) memory allocation, (4) data movement, (5) scheduling/order, (6) completion signaling, and (7) firmware handshake. The H104 host-side candidate covers tensor facts and Æsir's envelope only; its own record says chip executability is unproven. The required device encodings for elements 1 and 3–7 remain unknown/unverified.

Evidence: docs/plunder/HAILO_CONFIG_SURFACE.md, docs/smidr/PHASE_D_GATE.md.

## Slice 073 — Review public sources for operation/configuration semantics (complete)

Current public Hailo Model Zoo documents graph parse/optimize/compile flows and downloadable precompiled HEF models; the GenAI Model Zoo documents pre-trained artifacts and HailoRT serving. These sources establish the supported compilation workflow but do not provide a public raw operation-word/scheduler encoding specification for a Mojo generator. This is a bounded public-documentation finding, not a claim about private developer materials.

Sources: https://github.com/hailo-ai/hailo_model_zoo ; https://github.com/hailo-ai/hailo_model_zoo_genai.

## Slice 074 — Survey public compiler outputs only within clean-room limits (complete)

The publicly documented community LLM compiler requires proprietary DFC 5.3.0 and creates HEF output; official Model Zoo likewise exposes compiled HEFs. Such outputs are outside this campaign's no-HEF rule and do not provide a compliant configuration artifact. No compiled artifact was downloaded, unpacked, or used for reverse engineering in this slice. Any later survey must first satisfy source license, project clean-room, and owner-scope rules.

Evidence: docs/HAILO10H_CAMPAIGN_CONTROL.md Slices 034, 046–048; public project README linked in Slice 047.

## Slice 075 — Specify clean-room configuration research method (complete)

For any future permissible configuration research: record the public source, version, license, and exact question before study; use designated docs/plunder/HAILO_* notes; record facts and confidence without copying source or proprietary artifacts; keep implementation authors separated from source text where practical; obtain independent validation; and stop when evidence is insufficient or constraints would be crossed. No raw vendor source or HEF payload is added to this repository by this slice.

Evidence: ENGINEERING_GOALS_AND_BOUNDARIES.md, DEPENDENCY_POLICY.md, and repository clean-room Hailo study docs.

## Slice 076 — Define what can validate a candidate without hardware submission (complete)

Static validation may check a candidate generator's deterministic encoding, field bounds, internal schema, source traceability, and malformed-input rejection. These checks can validate host-side candidate structure only. Without a successful, correlated Hailo firmware completion and correct on-device result, no static checker can establish that undocumented control words are accepted or chip-executable.

Evidence: H104's explicit host-side-only status in docs/plunder/HAILO_CONFIG_SURFACE.md; H105/H111 criteria in docs/smidr/PHASE_D_GATE.md.

## Slice 077 — Assess generator completeness against current evidence (complete)

A complete configuration generator is not currently evidenced. The essential compute encoding and allocation/scheduling/handshake contracts remain unknown, while command submission failed. SMIÐR-CFG v1 is explicitly a test format that describes inputs and expected values, not a chip program. Under present evidence, extending this generator toward chip execution would risk inventing undocumented fields and would be blocked.

## Slice 078 — Reject undocumented magic bytes and simulated execution claims (complete)

Any future generator must tie every emitted field/value to a documented or experimentally verified meaning. A deterministic blob, JSON manifest, passing host-side schema check, BAR write/readback, or model output produced outside the Hailo does not establish Hailo compute. Unknown encodings must remain explicitly unknown; no sentinel value may be described as executable.

## Slice 079 — Set a stopping rule for unbounded reverse engineering (complete)

Pause configuration reverse engineering when both transport completion and operation encoding lack an evidence-backed path, when further progress requires prohibited DFC/HEF use, or when validation would require an unreviewed mutating hardware experiment. Resume only after new public/documented evidence, an approved safe test plan, and a clear discriminating experiment exist. This prevents endless low-evidence byte guessing.

## Slice 080 — Publish current configuration-surface feasibility verdict (complete)

Verdict: **NO-GO for a Hailo-executable configuration generator under the current evidence and constraints.** H019 still has unknown mandatory device encodings; H104 covers host-side tensor facts/envelope only; public compiled outputs depend on excluded tooling/artifacts; H102 transport does not complete. Keep on-chip compute and LLM integration BLOCKED. Preserve the host-side artifacts as research data, not functioning kernels.

Evidence: docs/plunder/HAILO_CONFIG_SURFACE.md, docs/smidr/PHASE_D_GATE.md, docs/HAILO10H_PHASE_D_RECONCILIATION.md.

## Slice 081 — Define the minimal Hailo compute operation (complete; proof remains gated)

Proposed first proof: one length-64 FP16 vector-add operation, matching the existing H104 host-side candidate. Define exact input vectors, elementwise output, buffer lengths, dtype, and zero-tolerance bitwise output criterion. This is a minimal accelerator compute proof only, not an LLM capability. It remains unexecutable until transport and configuration prerequisites pass.

## Slice 082 — Define an independent host oracle for the operation (complete; proof remains gated)

The test-only host oracle computes the expected 64-lane FP16 vector-add result from pinned input bit patterns. Its only role is comparison against returned Hailo output; it must never accept prompts, load a model, run transformer operations, or generate LLM tokens. Keep oracle provenance and expected values independent of the candidate config generator.

## Slice 083 — Specify an artifact-free proof representation (complete; proof remains gated)

The proof representation must use Æsir-owned documented descriptors and raw test buffers, not HEF, HAR, proprietary DFC output, HailoRT objects, or model-serving artifacts. Existing SMIÐR-CFG v1 is only a host-side manifest and is not considered executable until the device gate proves otherwise.

## Slice 084 — Define checksums and retained proof evidence (complete; proof remains gated)

For a future hardware attempt, checksum and preserve exact input bytes, candidate configuration bytes, manifest, expected output, returned device output, and pre/post device identity/state snapshots. A passing result must be reproducible from retained bytes; missing output or mismatched checksums fails the proof.

## Slice 085 — Define completion, timeout, and integrity evidence (complete; proof remains gated)

A pass requires a correlated device completion within a predeclared bounded timeout, successful output readback, unchanged/healthy device state, and output bytes matching the oracle criterion. Timeout, missing interrupt/status, invalid response, or integrity mismatch is a fail with raw trace preserved. Host process completion alone is not device completion.

## Slice 086 — Set repeatability requirements for a real operation (complete; proof remains gated)

After the first operation passes, require 100 repeated submissions with unique sequence accounting and identical deterministic outputs for the pinned input. Record per-operation completion and latency. Repeatability runs are meaningful only after proven on-chip execution; no host-side loop or simulation may satisfy them.

## Slice 087 — Require evidence of physical Hailo execution (complete; proof remains gated)

Accelerator provenance must combine endpoint identity, device/firmware completion evidence correlated to the submitted operation, device-returned output bytes, and a negative control showing the host-only path cannot produce a passing device record. Device discovery, a BAR write/readback, or mocked completion by itself is insufficient.

## Slice 088 — Define safety preconditions and restoration for mutation (complete; proof remains gated)

A future mutating proof requires the safety case defined in Slice 054, including exclusive ownership, exact driver handoff, safe memory/DMA mapping, known completion timeout, saved register baseline, restoration steps, and stop conditions. Device must return to the recorded driver/firmware state after success or failure. This slice defines criteria only; no mutation is authorized or executed.
