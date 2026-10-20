# Packed Q4_K source constant representation

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Consumer: the source compiler's bounded static constant reader, continuing
beyond floating source formats. Study the exact pinned, licensed public GGUF
Q4_K block layout before implementation; publish field/bit mapping facts and
provenance first. No external implementation may be copied or translated.
Test-only licensed external reference routines may serve as independent oracles
outside the production tree if their license/dependencies are recorded first.

Implement original Mojo bounded element windows over Q4_K source blocks,
including scale/minimum fields, group mapping and packed nibbles. Retain source
binding and exact element order. Prefer explicit affine constant components
(q, scale/min factors, source scale bit patterns) so a device precision/packing
policy is not silently chosen. Host parsing/compilation is permitted; never
execute a model, layer, attention or CPU/CUDA/cloud LLM forward.

Acceptance: independently generated blocks with asymmetric packed fields,
scale/min extrema, group/row/block-crossing/tail windows; exact component checks
and tiny standalone constant reconstruction oracles; malformed source/window/
bound/ownership refusals; source bytes unchanged. Use only synthetic fixtures,
no source model download or vendor compiled-model/container extraction.

This is incremental source-format conversion, not a permanent architecture or
format allowlist and not executable hardware lowering. Keep source identity,
actual device precision/layout/quantization policy, physical resource budgets,
CCW encoding, upload/activation and numerical hardware proof explicit. Publish
verified work and proceed automatically toward the unchanged owner objective.
