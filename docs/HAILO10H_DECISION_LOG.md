> **OWNER TARGET CORRECTION — 2026-10-19:** Project Aesir must implement the
> Mojo path needed to run source models that fit the Hailo-10H hardware. The
> owner explicitly rejects limiting the product to compatible vendor-precompiled
> models and forbids changing the target. Earlier catalog-only execution rules
> in this document are superseded. Historical precompiled-model receipts remain
> observations, not completion evidence for the owner's actual objective.

**D-011 — controlling owner directive:** the target is immutable without
explicit owner revision. The owner rejects precompiled-only model support.
Earlier D-002/D-005 interpretations that made vendor catalog artifacts the
product boundary are superseded. Device APIs may be evaluated as mechanisms;
they cannot redefine the requested source-model capability.

# Æsir Hailo-10H campaign decision log

**Roadmap Slice 010 — complete**

This log separates campaign decisions from facts that still need evidence. The current user-approved scope is Hailo-10H LLM inference only; no Pi CPU LLM development is authorized.

| ID | Decision or open question | Current state | Evidence / next gate |
|---|---|---|---|
| D-001 | LLM inference target | **Decision:** Hailo-10H only. CPU LLM execution, fallback, shadow inference, and serving are excluded. | User instruction; `docs/HAILO10H_NO_CPU_INFERENCE.md` |
| D-002 | Æsir execution architecture | **Correction (2026-10-12):** retain Æsir as the user-facing Mojo application, with direct in-process HailoRT GenAI calls for LLM execution on Hailo-10H. Compatible Hailo model artifacts are allowed. The prior no-HEF/no-DFC/no-HailoRT restrictions were introduced by campaign authors and were not part of the owner's target instruction; they are retired for this mission. | Owner direction: make Æsir work on Hailo-10; no CPU LLM work; no target substitutions. |
| D-003 | Existing Hailo implementation state | **Current fact (2026-10-19):** the dedicated canonical direct Hailo backend passes the physical slice-140 smoke. Reserved generic backend enums remain a separate surface. | `docs/HAILO10H_SLICE_140_SMOKE.md`, `CAPABILITY_LEDGER.md` |
| D-004 | Prior raw command transport | **Fact:** H102/H111 documented no completion from tested app/core mailbox paths and recorded Phase-D NO-GO. | `docs/smidr/H102_ATTEMPT_RECORD.md`, `docs/smidr/PHASE_D_GATE.md` |
| D-005 | Vendor Hailo GenAI path | **Decision:** use the direct in-process HailoRT GenAI API and a compatible Hailo model artifact. Hailo-Ollama and all inference proxy/service substitutions are prohibited. | Owner direction and local HailoRT 5.3.0 GenAI headers; `HAILO10H_ONLY_200_SLICE_ROADMAP.md` |
| D-006 | Device mutation | **Decision:** current inventory is read-only. Do not unbind, reset, reflash, or change system configuration as part of census/revalidation without a documented safety basis and owner authorization. | `docs/HAILO10H_ACCESS_CENSUS.md` |
| D-007 | Failure handling | **Decision:** diagnose and repair Hailo execution; never route inference to CPU or a proxy. | `docs/HAILO10H_DIRECT_BACKEND_RECOVERY.md` |
| D-008 | Direct inference feasibility | **Physically evidenced (2026-10-19):** canonical direct HailoRT readiness, inference, context lifecycle and cleanup pass. Historical raw-mailbox NO-GO remains distinct. | `docs/HAILO10H_SLICE_140_SMOKE.md` |
| D-009 | First supported model | **Qualified smoke candidate:** the pinned Qwen2.5-1.5B-Instruct artifact runs with installed HailoRT 5.3.0. Formal metadata/license/compatibility and coverage acceptance remain next. | Slice 140 evidence; slices 141–150 |
| D-010 | Roadmap response to failures | **Decision:** diagnose and repair the Hailo path or select another supported Hailo version/model pair. CPU and proxy substitutions are never permitted; no technical failure is a reason to abandon the Hailo target. | Roadmap execution rule |

## Change control

The owner correction above preserves D-001 and the Hailo-10H target. Future implementation choices must preserve direct Hailo-10H execution, prohibit CPU LLM inference, and prohibit inference-service substitutions such as Hailo-Ollama.

## Acceptance

- Decisions are distinct from unresolved technical questions.
- The prior H111 NO-GO is recorded as historical evidence, not erased.
- CPU LLM development is explicitly excluded, including as a fallback.
- Direct HailoRT GenAI is approved as an implementation dependency; Hailo-Ollama is explicitly excluded.
- Owner-only choices are not made implicitly by the roadmap author.
