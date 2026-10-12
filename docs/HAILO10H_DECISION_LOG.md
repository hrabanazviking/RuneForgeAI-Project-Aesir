# Æsir Hailo-10H campaign decision log

**Roadmap Slice 010 — complete**

This log separates campaign decisions from facts that still need evidence. The current user-approved scope is Hailo-10H LLM inference only; no Pi CPU LLM development is authorized.

| ID | Decision or open question | Current state | Evidence / next gate |
|---|---|---|---|
| D-001 | LLM inference target | **Decision:** Hailo-10H only. CPU LLM execution, fallback, shadow inference, and serving are excluded. | User instruction; `docs/HAILO10H_NO_CPU_INFERENCE.md` |
| D-002 | Æsir execution architecture | **Correction (2026-10-12):** retain Æsir as the user-facing Mojo application, with direct in-process HailoRT GenAI calls for LLM execution on Hailo-10H. Compatible Hailo model artifacts are allowed. The prior no-HEF/no-DFC/no-HailoRT restrictions were introduced by campaign authors and were not part of the owner's target instruction; they are retired for this mission. | Owner direction: make Æsir work on Hailo-10; no CPU LLM work; no target substitutions. |
| D-003 | Existing Hailo implementation state | **Fact:** Hailo backend is not implemented; reserved enum/configuration is not dispatch or inference. | `aesir_engine/core/mimir_well.mojo`, `aesir_engine/aesir.mojo`, `CAPABILITY_LEDGER.md` |
| D-004 | Prior raw command transport | **Fact:** H102/H111 documented no completion from tested app/core mailbox paths and recorded Phase-D NO-GO. | `docs/smidr/H102_ATTEMPT_RECORD.md`, `docs/smidr/PHASE_D_GATE.md` |
| D-005 | Vendor Hailo GenAI path | **Decision:** use the direct in-process HailoRT GenAI API and a compatible Hailo model artifact. Hailo-Ollama and all inference proxy/service substitutions are prohibited. | Owner direction and local HailoRT 5.3.0 GenAI headers; `HAILO10H_ONLY_200_SLICE_ROADMAP.md` |
| D-006 | Device mutation | **Decision:** current inventory is read-only. Do not unbind, reset, reflash, or change system configuration as part of census/revalidation without a documented safety basis and owner authorization. | `docs/HAILO10H_ACCESS_CENSUS.md` |
| D-007 | Failure handling | **Decision:** diagnose and repair Hailo execution; never route inference to CPU or a proxy. | `docs/HAILO10H_DIRECT_BACKEND_RECOVERY.md` |
| D-008 | Direct inference feasibility | **Open implementation task:** integrate and execute HailoRT GenAI directly from Æsir; historical raw-mailbox NO-GO does not block this API route. | Slices 133–140 |
| D-009 | First supported model | **Open technical task:** select a Hailo-10H model artifact compatible with the installed HailoRT, then run it through Æsir's direct backend. | Slices 141–150 |
| D-010 | Roadmap response to failures | **Decision:** diagnose and repair the Hailo path or select another supported Hailo version/model pair. CPU and proxy substitutions are never permitted; no technical failure is a reason to abandon the Hailo target. | Roadmap execution rule |

## Change control

The owner correction above preserves D-001 and the Hailo-10H target. Future implementation choices must preserve direct Hailo-10H execution, prohibit CPU LLM inference, and prohibit inference-service substitutions such as Hailo-Ollama.

## Acceptance

- Decisions are distinct from unresolved technical questions.
- The prior H111 NO-GO is recorded as historical evidence, not erased.
- CPU LLM development is explicitly excluded, including as a fallback.
- Direct HailoRT GenAI is approved as an implementation dependency; Hailo-Ollama is explicitly excluded.
- Owner-only choices are not made implicitly by the roadmap author.
