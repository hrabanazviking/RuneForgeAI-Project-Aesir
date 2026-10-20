# Source-model compiler plan and executable-program gap

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_mojo_model_execution.md`.

## Immutable objective and current facts

Build the Mojo-owned source-model compilation/execution path needed for models
that fit the Hailo-10H hardware. Only the owner can change this goal. The first
format/architecture fixture is an incremental test, never a permanent model
allowlist or permission to substitute a vendor-precompiled product.

The native transport now physically exchanges create/identify/destroy without
linking HailoRT. This does not make `smidr/config_gen.mojo` executable: it still
emits host fp16 vectors/SMIDR-CFG. `smidr/descriptor.mojo` still carries explicit
COMPUTE_UNKNOWN for compute encoding. No existing Mojo IRGraph/NetworkPlan
implementation was found in the inspected compiler sources. These actual gaps
must stay visible while implementation advances.

## Acceptance slices

1. Connect source metadata/tensor descriptors to an original typed SMIÐR plan.
   Inspect/reuse the bounded existing GGUF reader's file ownership and parsing
   APIs without invoking its CPU/CUDA execution paths or backend support
   registry. Validate tensor byte extents, dimensions, dtype/quantization tags
   and architecture facts. Preserve original source/weight bytes and provenance.
2. Emit source operations/weight bindings and memory lifetimes for the first
   independently checkable dense decoder fixture. Cover model/session dimension
   differences (query versus KV heads, context, weight sharing) and checked
   arithmetic. Do not guess unknown precision, geometry, SRAM, DDR allocation
   or firmware limits. Resource estimates require explicit budgets/provenance
   and must never label memory fit as executable architecture support.
3. Carry explicit unresolved operation/layout/quantization/configuration gates.
   A plan is not a chip program. Unknown source layouts/formats remain named
   importer work; unknown device encoding remains named backend work. No
   COMPUTE_UNKNOWN or host-test envelope can be submitted as executable data.
4. Study already licensed/pinned public program-format, infer-model upload and
   activation interfaces; record exact facts before implementation. Separate
   envelope/metadata parsing from actual operation/context encoding. Build
   independent bounded parser/emitter tests only for established fields; no
   invented opcodes, copied vendor implementation or borrowed model program.
5. Continue the real first-operation gate on Hailo-10H: Aesir-generated source
   operation → numerical recipe/lowering → actual program/configuration →
   verified transport → real result and cleanup. Expand operation, architecture,
   quantization and format coverage toward the same broad target.

## Evidence and boundaries

Production is Mojo, with all device/syscalls inside HAILBRÚ. Test oracles can
inspect metadata, structural arithmetic and tiny primitive mathematics, but
must not run a CPU/CUDA/cloud LLM forward, shadow inference or inference proxy.
Host compilation, parsing, packing and orchestration remain permitted. No new
model download/catalog selection, kernel/module/firmware change, reset or
binding change is part of this contract. No existing source, model or owner
strategy upload is discarded. Each actual parser/lowering/program capability
needs independent acceptance; record negative results and publish each bounded
verified slice before advancing.
