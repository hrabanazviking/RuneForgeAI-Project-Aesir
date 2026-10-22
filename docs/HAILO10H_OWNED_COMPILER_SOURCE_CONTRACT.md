# Owned source lifetime through internal compilation

Date: 2026-10-22. Native work order: `TASK_hailo10h_owned_gguf_compiler.md`.
Sealed parsing and source-reader integration are verified at73f89e9. The current
standalone path semantic reader closes its parser before returning its graph.
The next original Mojo leaf will own both the existing sealed parser and the
existing expanded graph, compile from the same actual immutable bytes and read
source weight tiles through that owner without reopening a path.

The consuming compiler factory will validate actual seals, extent and mapping,
recompute the actual digest and rehydrate writable cached tables with the ONE
existing header/table interpreter before building existing compiler structures.
No shared production source change or parallel parser/decoder is authorized.
No new operation semantics or device format follows from this ownership work.

Pre-code qualification verifies660 actual sources/snapshots,109 native controls
and69 qualified Python inputs/snapshots. A movable owner-plus-expanded-graph
probe compiles cleanly and is never executed; it proves type feasibility only.
Evidence: `evidence/owned-compiler-contract-2026-10-22/`.

Native acceptance must compare complete graph/recipe/global fields, source words,
bindings/components/tiles, original-change independence, cache rehydration,
move/close/failure recovery and traced descriptor/mapping cleanup. Consumer
qualification includes directory-selected binaries; control fault logs remain
separate and complete fixture mutations are paired. Retain opaque termination
records without inferring effects and keep all attempts.

A scoped compiler-input flag may follow actual owned-byte gates. Existing global
fingerprint, immutable-source, artifact identity and execution flags stay false.
The original copy can be mixed under concurrent writes. Actual numerical H10H
encoding/configuration, packing/placement, program execution/results/cleanup and
broad ordinary formats/architectures/operations remain open implementation work.
The owner's broad unmodified-model target remains100%; no outside compiler,
precompiled prerequisite or host/cloud LLM forward is introduced.
