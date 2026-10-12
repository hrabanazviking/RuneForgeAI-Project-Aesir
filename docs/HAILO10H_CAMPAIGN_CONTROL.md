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
