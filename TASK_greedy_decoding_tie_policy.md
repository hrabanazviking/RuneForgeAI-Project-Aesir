# AES500-181 — greedy decoding tie policy

## Objective and owner

Specify deterministic tie behavior for greedy token selection before modifying
either CPU or CUDA implementation. Owners are `sample_token_from_logits` in
`aesir_engine/core/sampler.mojo` and `argmax_kernel` plus the
`NativeCUDASampler.select` fast path in `aesir_engine/core/gemma4_kernels.mojo`
and `aesir_engine/core/cuda_sampling.mojo`.

## Inputs, outputs, and selected policy

The CPU sampler receives F16 logits, a positive vocabulary size, sampling
parameters, context, and suppress-token IDs; it returns one token ID. Native
CUDA greedy selection receives a device F32 logit span and writes one Int32
token ID. For finite logits and an otherwise eligible vocabulary, greedy mode
returns the lowest token ID whose logit equals the maximum. This matches the
current CPU strict-`>` scan and the CUDA warp reduction's minimum-ID tie
reduction; the slice will make the contract explicit and executable.

CPU sanitizes non-finite values to `-1e9`; CUDA reports `-1` when any scanned
logit is non-finite. This semantic difference is out of scope and must remain
documented rather than silently reconciled here. Suppression is handled in the
CPU sampler; the plain CUDA greedy branch does not apply suppression or
repetition penalties. Penalized/native sampling is a separate ordered path.

## Invariants and exclusions

- Equal finite maxima select the smallest token ID independent of scan/warp
  partitioning.
- Unique finite maxima preserve their existing selected ID.
- Empty CPU vocabulary keeps its existing return value `0`; native CUDA rejects
  empty vocabulary during sampler construction.
- Non-finite handling, suppression semantics, logits precision, RNG behavior,
  top-k/top-p ordering, performance, and whole-model output quality are outside
  this contract.
- No model-backed inference or accelerator performance claim follows from
  synthetic logits tests.

## Acceptance

Establish a pre-change tie baseline; expose the exact owning interface and test
accepted/rejected input behavior; implement only if current code contradicts
the selected tie rule. Add CPU vectors for ties at the first, middle, and last
positions and native CUDA synthetic vectors including cross-warp ties when the
available runtime permits. Run the pinned Mojo master suite, docs drift, and
the applicable GPU test or record its explicit unavailable boundary.


## Progress receipts

- AES500-182 baseline: see `docs/evidence/greedy-tie-baseline-2026-10-10/README.md`.
- AES500-183 interface: `core/INTERFACE.md`, `sampler.mojo`, and
  `gemma4_kernels.mojo` state the lowest-ID finite tie rule and exclusions.
- AES500-184 implementation: CPU source and CUDA reduction already satisfy the
  finite tie rule; no algorithm change was needed.
- AES500-185 unit evidence: `sampling.greedy_tie_policy` covers a tied maximum
  and a unique maximum. Master suite: 231 passed, zero failed, one skipped
  (232 total).
- AES500-186 integration: master suite exercises the public CPU sampler. A
  physical RTX 2060 CUDA probe was attempted but failed during PTX JIT with
  `CUDA_ERROR_INVALID_PTX`; it does not establish CUDA integration behavior.
- AES500-187 adversarial evidence: tied maxima at first/middle/final positions
  across three scan-order vectors all select the lowest tied ID. Master suite:
  232 passed, zero failed, one skipped (233 total).
- AES500-188 primary review confirms the CPU strict-greater scan and CUDA
  warp-max/min-ID reduction. The Auditor agent was unavailable at the service
  thread cap; independent signoff is not claimed.
- AES500-189 syncs the interface, task, roadmap, ledger, TODO and devlog, while
  preserving the PTX JIT failure and synthetic-evidence limits.
