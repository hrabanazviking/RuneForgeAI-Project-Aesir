# Sealed-descriptor GGUF parser integration contract

Date: 2026-10-22. Native work order: `TASK_hailo10h_sealed_gguf_source.md`.
Owned sealed observed copies are verified at `a035435`; current GGUF loading
still reopens a path and does not consume those copies.

The existing original GGUFSeer and PackedGGUF parsers will be reused. The
contract permits three shared changes: checked exclusive transfer from the
sealed owner, fd-based read-only mapping with independently recorded capacity,
and a shared PackedGGUF table interpretation body used by both constructors.
The new adapter will consume the sealed descriptor directly. No label,
`/proc/self/fd` or `/dev/fd` reopen is permitted.

This also closes a concrete ownership gap: current range checks and munmap use
public mutable file_size. The new recorded mapping extent must bound reads and
supply the actual unmap length, including after a file_size mutation. Existing
path outputs, source representations and diagnostics remain preserved.

Pre-code qualification:656 source identities and actual snapshots,106 current
controls and68 Python identities/actual snapshots are frozen in
`evidence/sealed-gguf-contract-2026-10-22/`. A movable wrapper containing
PackedGGUF compiles cleanly; the probe is never executed and establishes no new
parser behavior. Conservative static local import analysis finds100 affected
existing control entrypoints and6 unaffected. Recompute after changes and cover
every actual affected entrypoint with stable builds and frozen comparisons.
No model/engine/master execution is authorized by this inventory.

The new route may establish that its parsed metadata and payload views refer to
one owned sealed file. Concurrent original writes can still produce a mixed
copy, so no atomic original-file snapshot follows. Existing global source
fingerprint, immutable-source, artifact-binding and execution flags stay false.
Compiler artifact/session identity still needs integration after this slice.

The full broad ordinary-model target remains fixed. Missing formats, ranks,
architectures and operations remain implementation work. Actual numerical H10H
configuration/packing/placement and original program execution/results/cleanup
remain open. No external compiler, precompiled prerequisite or host/cloud LLM
forward is introduced.
