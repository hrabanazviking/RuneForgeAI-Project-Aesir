# Native compute work guidance

Read INTERFACE.md, README.md, the capability ledger and AI.rules.part2.md before
editing. Compute owns kernels/session plans; loader owns validated GGUF spans;
CLI owns configuration/transport. No provider substitution belongs in core.

Format equations belong in packed_quantization.mojo. Keep scalar kernels as
references. Block projections require admitted alignment/extents and preserve
arithmetic/reduction order. Prepared descriptors are built after validation.
Prefix reuse is bounded to exact positions/tokens in one owning model/session,
with fresh final logits and rebuilt sampler history. Keep poisoned-session,
reset, cancellation and serialized mutation semantics intact.

Run independent real-weight parity and physical cached/fresh equivalence before
deployment. Compilation, synthetic checks or fluent answers do not promote broader
model/hardware support. Rebuild after Mojo edits; benchmark with other GPU work
idle and retain failures. See project-root docs/NATIVE_PERFORMANCE.md for evidence,
commands, memory/control semantics and context-recreation limits.
