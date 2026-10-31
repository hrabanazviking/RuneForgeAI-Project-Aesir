# Aesir Capability Ledger Cross-Check (J-012)

**Measured:** 2026-10-31, from the tree and the campaign records. **Nothing here is taken from memory:** each row cites its file or record. The canonical checkout `~/workspace/RuneForgeAI-Project-Aesir` is dirty (branch `platform/cloud-hypervisor-epyc`, uncommitted modifications — verified by `git status` this slice) and was inspected **read-only** only. `origin/main` = `caec4149` (ls-remote verified this slice).

## Engine core

| Capability | Aesir's truth | Citation |
|---|---|---|
| MoE support | **None.** No expert/routing code anywhere in `aesir_engine/core/` (grep `expert` this slice: zero core files). All wave families are dense. | tree grep, 2026-10-31 |
| Expert streaming / cache | **None** (follows: no MoE). Dense whole-model residency via GGUF + spill (below). | tree |
| Dense spill (model > VRAM) | **PROVEN, token-identical** to whole-GPU runs: Llama-3 spill 31/32 layers on GPU, output identical, 4,746 MiB VRAM, ~10–11.5 tok/s; re-verified from clean origin/main (S-011). | `ROADMAP_204_STATE.md` S-011 + verification runs |
| KV precision | **f16.** `mimir_well.mojo` KV storage is `Scalar[f16]` pointers. No 8-bit KV exists. | `aesir_engine/core/mimir_well.mojo` lines 12, 580 |
| Speculative decoding | **Acceptance arithmetic only.** `core/speculative.mojo` header: "Validated speculative-token acceptance arithmetic and explicit integration gaps" — its result type "does not mutate or claim ownership of KV state". No draft loop, no drafter loading, no MTP support in the engine. (The CLI's `cursor_draft.mojo` is a text-editor draft, not a token drafter.) | `aesir_engine/core/speculative.mojo` |
| Threading | Parallel primitives exist (`thread_par.c`, SIMD width-16 decode per S-030); **no** documented thread-topology auto-trials, no placement engine, no per-pass device choice. GPU use is CUDA, gated in code (`core/cuda_gate.mojo`, `amd_gate.mojo`, `intel_gate.mojo`). | tree; S-030 record |
| GPU | CUDA path proven on RTX 2060 (sm_75): per-arch GPU sessions, Gemma-4 full-GPU-path session, vision convergence. No Vulkan path. Prefill is not a separately-shaped GPU pass class; decode-shaped GPU work is the proven shape. | wave records; S-001/S-002/S-014 |
| NPU | Hailo only, and **parked** by law (finish-line campaign owns the chip; text-on-chip still not achieved there). No Intel-NPU anything. | roadmap law; finish-line state |
| Determinism | CPU grading discipline is exact (teacher-forcing rank/gap vs ggml CPU comparator); no user-facing repeatability option. | wave method (S-058 oracle hygiene) |

## Quant / architecture truth (the wave + 204 Parts II–III, all sha-pinned, tf/fr graded)

| Family | Truth | Citation |
|---|---|---|
| Llama arch (Llama-3 class) | PROVEN across rungs incl. spill (test_llama3_spill on main); Stheno-8B (Llama-3-based) graded Q3_K_M crown. | wave; S-011 |
| Qwen2 (SmolLM2, Coder-3B/7B) | PROVEN — crowns Coder-3B Q8_0, Coder-7B Q4_K_M. | Part II closing |
| Qwen3 (Zen-4B) | PROVEN across the rung ladder (S-026 laptop round: Q4_K_M/Q6_K/Q5_K_M/Q3_K_M/Q2_K/IQ2_M faithful). | S-026 |
| Mistral3 (Ministral) | PROVEN short-length; YaRN-at-length NOT PROVEN → 204 S-104. | S-027/S-028 note |
| Gemma-4 | CUDA generation PROVEN (vision convergence session); **CPU generation NOT PROVEN** — 204 S-039/S-040 own it. IQ rows on Gemma-4 repeatedly NOT PROVEN as an *arch class* (S-082/S-084/S-085), decoders exonerated by non-Gemma controls. | S-039/S-040; S-082–S-085 |
| MoE archs (qwen3moe/qwen35/qwen35moe/qwen3next/gemma4-MoE) | **Absent entirely** (see MoE row). | tree |
| Quants PROVEN faithful | Q2_K, Q3_K (S/M/L + S variants), Q4_K (M/S), Q5_K (M/S), Q6_K, Q8_0, legacy Q4_0/Q4_1/Q5_0/Q5_1 (S-083), IQ2_M, IQ3_S/M/XXS/XS (S-085), IQ4_XS/IQ4_NL (S-084). | S-080–S-085 |
| IQ1_S | Coherence-graded only: token-exact parity NOT PROVEN BY CONSTRUCTION (ggml's own CPU vs CUDA kernels disagree); road S-095. | S-029 verdict |
| MXFP4 / NVFP4 / Q2_0 | Not in the matrix. | S-079 census |
| Vision | Gemma mmproj CUDA convergence PROVEN; vision encoder runs CPU-side → ledger stays `partial`. Qwen-VL not present. | Part II closing |
| Embeddings | Server route exists (below); no graded embedding-model parity record. | server tree |

## Surfaces

| Surface | Aesir's truth | Citation |
|---|---|---|
| CLI/chat | Extensive: REPL + TUI, line editor, history, autosave, recovery, transcript viewer, model selector, doctor, hardware report command, modelfile, sampling controls. | `aesir_engine/cli/` listing (44 modules) |
| Learned/saved config | `cli/model_preferences.mojo`, `cli/quantization_tuning_storage.mojo`, `cli/native_settings.mojo` exist — preferences persist; **no measured** placement/tuning learning. | cli listing |
| Server | OpenAI-shaped core: `/health`, `/v1/chat/completions`, `/v1/embeddings` routed in `server/api.mojo`; `server/openai.mojo`, `server/ollama.mojo`, `server/keyfiles.mojo` (API keys), local protocol/transport. No Responses/Files/Batches/etc.; no served browser chat page evidenced; no TLS/Origin discipline evidenced. | `aesir_engine/server/` (api.mojo lines 168–176 + listing) |
| MCP | **None** in the engine tree (grep hits are gate files and vendored MAX packages). | tree grep |
| Bench | Measurement kernels + the wave battery (step-33 harness, RESULTS grading) exist as campaign tooling; **no** user-facing configuration-sweep bench or machine-report tool. | `aesir_engine/tests/measurement_kernels.mojo`; model-tests records |
| Library/embedding | Aesir is consumed via Yggdrasil's adapters (Ollama adapter Y-023, Aesir native adapter Y-024 — Yggdrasil campaign records) and its CLI/server; **no stable C ABI** evidenced in the tree. | tree; Yggdrasil CAMPAIGN_STATE (external record) |
| Converters | GGUF is read natively; HF→GGUF import exists in the MAX-side tooling lineage (import-model skill/custom pipeline), with no LoRA-merge-at-conversion and no MTP-preservation record. | campaign records |
| Context | Spill proof at context 4096; no published context ladder; no sliding-window KV economy; chat context slides via history management, recap-summarisation not evidenced. | S-011; cli listing |

## 204-road position (for IN-204 grading)

`ROADMAP_204_STATE.md`: Part III frontier **S-086** (IQ2 family completion); S-083/S-084/S-085 DONE and banked to main (`04838f0a`, `caec4149`, S-085 sections in 7 family RESULTS). S-039/S-040 (Gemma-4 CPU) genuinely open. S-046/S-052 VM legs BLOCKED-WITH-REASON (VM MemAvailable ~522 MB). Vision development sits in 204 Part V. Hailo parked.
