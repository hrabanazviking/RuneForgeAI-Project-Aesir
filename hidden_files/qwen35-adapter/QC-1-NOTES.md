# QC-1 — GGUF writer core (2026-11-14)

Worker slice on worktree /home/volmarr/aesir-qc-1, branch yrsa/qc-1,
base ff823ef3 (= yrsa/hip-serve tip). Deliverable definition:
QC-0-PLAN.md section 6 (QC-1), bound by section 2 (writer state +
emission spec derived from our reader) and section 5 (emission
order, metadata rules).

Method: ONE worker running the Forge roles sequentially
(recon -> spec -> build -> proof -> regressions). No sub-agents
were spawned (depth limit), per the commission.

Machine state at start (measured 2026-11-14 ~14:47 EST):
purpleraider up 4h46, load ~0.1, MemAvailable ~118 GB of 121 GB.
No mojo/aesir build processes running; the Q35-6 sibling worktree
(/home/volmarr/aesir-q35-6) showed no active compile (only a git
remote-https fetch in flight) — no CPU contention observed.
Running services are the ordinary desktop set (sddm/plasma/
NetworkManager/...); aesir-gate, Ollama, Voxta are NOT running —
down per Volmarr's orders, untouched by this slice.

## Module placement decision

`aesir_engine/loader/gguf_writer.mojo` — beside the two readers it
must satisfy (loader/gguf.mojo GGUFSeer, loader/packed_gguf.mojo
PackedGGUF), in the same package so it imports GGMLType and reuses
GGUFSeer's own _tensor_byte_size as the single pricing source of
truth (a writer that prices differently from the reader is the
classic silent-corruption shape; Q8-1's lesson). A core/ sibling
was rejected: the writer speaks the loader's file format, not
engine maths; quantization itself (QC-2, core/quantize.mojo per
the plan) will call this module from core, not live in it.

## Design (spec-as-built; readers arbitrate)

[to be completed as built — see final notes below]
