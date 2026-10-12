# Æsir Hailo-10H campaign decision log

**Roadmap Slice 010 — complete**

This log separates campaign decisions from facts that still need evidence. The current user-approved scope is Hailo-10H LLM inference only; no Pi CPU LLM development is authorized.

| ID | Decision or open question | Current state | Evidence / next gate |
|---|---|---|---|
| D-001 | LLM inference target | **Decision:** Hailo-10H only. CPU LLM execution, fallback, shadow inference, and serving are excluded. | User instruction; `docs/HAILO10H_NO_CPU_INFERENCE.md` |
| D-002 | Æsir execution architecture | **Decision:** preserve the repository's Mojo-native path and current no-HEF/no-DFC/no-HailoRT-runtime requirements. | `docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md`; owner-only change control |
| D-003 | Existing Hailo implementation state | **Fact:** Hailo backend is not implemented; reserved enum/configuration is not dispatch or inference. | `aesir_engine/core/mimir_well.mojo`, `aesir_engine/aesir.mojo`, `CAPABILITY_LEDGER.md` |
| D-004 | Prior raw command transport | **Fact:** H102/H111 documented no completion from tested app/core mailbox paths and recorded Phase-D NO-GO. | `docs/smidr/H102_ATTEMPT_RECORD.md`, `docs/smidr/PHASE_D_GATE.md` |
| D-005 | Vendor Hailo GenAI path | **Decision:** comparison/research only; do not adopt HEF, proprietary DFC, HailoRT, or Hailo-Ollama as an implementation dependency under current constraints. | `docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md`; official documentation is context only |
| D-006 | Device mutation | **Decision:** current inventory is read-only. Do not unbind, reset, reflash, or change system configuration as part of census/revalidation without a documented safety basis and owner authorization. | `docs/HAILO10H_ACCESS_CENSUS.md` |
| D-007 | Failure handling | **Decision:** if Hailo execution cannot be verified, fail closed and report a blocker. No alternate CPU inference. | `docs/HAILO10H_INFERENCE_POLICY.md`, `docs/HAILO10H_NO_CPU_INFERENCE.md` |
| D-008 | Current native-path feasibility | **Open technical question:** whether any compliant, documented route can provide both command transport and executable configuration without HEF/DFC/vendor runtime. | Revalidation slices 031–040 and configuration research slices 071–080 |
| D-009 | First supported model | **Open technical question:** no model is selected until every required operation and representation is demonstrated on Hailo. | Model feasibility slices 141–150 |
| D-010 | Roadmap response to NO-GO | **Decision:** block dependent Hailo implementation; record INCOMPLETE and the exact missing evidence. Do not convert scope to Pi CPU inference. | Roadmap gate policy and Slice 040 |

## Change control

Only the project owner may change D-001 or D-002. Any proposed architecture change must identify the exact constraints to change and its consequences before implementation. Technical findings may update open questions and gate status, but cannot silently alter user scope.

## Acceptance

- Decisions are distinct from unresolved technical questions.
- The prior H111 NO-GO is recorded as historical evidence, not erased.
- CPU LLM development is explicitly excluded, including as a fallback.
- Vendor runtime/HEF/DFC adoption is not assumed.
- Owner-only choices are not made implicitly by the roadmap author.
