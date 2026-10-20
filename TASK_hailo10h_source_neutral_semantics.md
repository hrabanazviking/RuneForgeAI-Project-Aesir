# Ordinary source formats into native semantic compilation

Date: 2026-10-20. Contract before further frontend integration.
Parent: `TASK_hailo10h_source_compiler_plan.md`.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Consumer: the original SMIÐR semantic/expanded graph, matrix schedules and static
source readers. GGUF currently supplies architecture/configuration and matrix
bindings directly to `semantic_plan.mojo`; ordinary safetensors now supplies
owned full-rank metadata and bounded static words separately. Audit the exact
format-specific dependencies and publish a narrowed typed source-neutral input
and compatibility plan before implementation. Do not count those separate
primitives as a connected source-model compiler yet.

A weight file alone does not contain all architecture/configuration facts.
Trace ordinary model config/index metadata and tensor naming/shape conventions
from license-first pinned public declarations, plus existing project importers.
Do not download/evaluate models or copy/translate external implementations.
Retain original source format/dtype namespace, full shape/file extents and
semantic-name provenance; a numeric source-kind cast across formats is invalid.
Safetensors row-major axes and GGUF columns/rows must be mapped from established
facts, not silently transposed. Scalars/empty/arbitrary-rank inputs must retain
truthful representation even when an operation-specific shape is still missing.

Separate owned mathematical decoder parameters and checked semantic weight
bindings from container parsing so the existing GGUF entry point can delegate
without losing its validation or changing emitted graph/lifetime behavior.
Ordinary safetensors/config/shard source adapters must eventually supply the
same exact mathematical inputs while retaining actual backing locations and
format tags. Never fabricate architecture/default fields or drop modifiers.
Missing architecture/dtype/shard/operator semantics remain explicit work toward
broad support; do not turn today's coverage into permanent model eligibility.

After facts/design are published, implement bounded original Mojo changes and
independent structure/shape/binding/refusal/ownership/regression evidence under
a concrete narrowed contract. No CPU/CUDA/cloud model/layer/attention forward,
external compiler, special user conversion/artifact, inference proxy or guessed
device numerical encoding. Continue actual Hailo instruction/configuration,
precision/packing/placement/upload/activation/result/cleanup research and code
where field evidence permits. Publish each verified slice and advance
without routine owner prompts; the fixed broad ordinary-model target remains.

2026-10-20 narrowing: `docs/HAILO10H_SOURCE_NEUTRAL_SEMANTIC_AUDIT.md`
records current format coupling and the first implementation contract: extract
owned typed decoder parameters and a compatible mathematical graph builder.
Storage remains explicitly GGUF-specific in that phase; tagged storage and
ordinary config/index/name facts must precede the safetensors semantic adapter.
