# Native kernel efficiency and stable execution — 2026-10-01

Volmarr authorizes further speed, efficiency, design and stability improvements,
including publication to the owning GitHub repositories. Mythic Engineering roles
operate sequentially. The existing working deployment and corpus are preserved.

## Current truth and ownership

Clean main starts at 198398d. Native Llama 3.2 3B Q4_K_M runs on sm_75 with
bounded exact-prefix reuse; cache-disabled costs remain about 1.16–9.97 seconds
for the published five-query subset. Packed projections dominate GPU time.
Each output row uses one warp; packed byte arithmetic uses machine-width Int.
RMS normalization also uses one warp, leaving most launched warps idle for a
single hidden vector. Full batched prefill and broad-device performance are open.

Compute owns quant decoding, projections, normalization and numerical boundaries.
Generation owns state/control; tooling owns measurement and recovery evidence.
The first slice profiles the current binary, then tests narrower packed arithmetic
and better cooperative normalization or projection scheduling against references.
Only measured, numerically validated changes enter production dispatch. Extend
physical parity probes to real admitted widths, tails and independent numerical
calculations. Preserve original reference kernels and all unrelated code/data.

## Invariants and gates

No model, tokenization, sampling, transport, authentication, corpus, embedding,
resource ceilings or dependency changes. Pointer/span arithmetic remains wide;
narrow quant arithmetic is permitted only for proven bounded byte products.
Keep exact accumulation where possible; any changed reduction must pass an
independent numerical oracle, exceptional-value rejection and whole-output gates.
No hidden provider substitution, deletion, driver churn or untested support claim.

Archive current binary/manifest and record same-machine old/new cache-disabled
and cached HTTP replies, counts, errors, memory and timing. GPU work is serialized;
owned temporary probes are bounded and reaped. Stop only the native GPU service
as required and restore it after checks. Test real GGUF rows, physical reference
parity, prefix/sampling/deadline reset, authenticated service faults and API modes.
Run final counted master, negative control, documentation and fixture checks.
Rebuild after final Mojo edits and verify exact pushed CI and deployed service.

## Completion record

Update core/test interfaces, README_AI, native manual, TODO, DEVLOG and the
partial performance ledger with exact achieved results and remaining boundaries.
Publish raw reproducible evidence and a portable human report. Reject speculative
speed changes that fail correctness or representative timing. No universal
optimality or general Ollama/device/model superiority claim is authorized by a
narrow benchmark. Further slices require their own stated evidence and scope.
