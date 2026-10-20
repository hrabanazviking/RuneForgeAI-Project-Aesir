# Task: Strategy5 tracing source baseline and capture prerequisites

## Slice

AES500-012 follows the owned strategy5 trace contract in AES500-011. It publishes
and verifies a fresh, untraced, trace-capable-but-disabled strategy5 baseline for
the declared public37 and public1070 prefill sessions before any profiled run.

## Scope and invariants

- No NVTX calls, profiler launch, tracing capability, inference arithmetic change,
  production selection or speed score is admitted by this baseline slice.
- Build the existing strategy5 collector from current source for sm_75 and bind the
  actual executable, model, accepted source5 CSV/report/binary and independent CPU
  reference provenance by SHA-256.
- The collector must produce all complete native/matrix logits, committed input
  IDs, final state, cache digest, actual small/down/closed-fused/scalar dispatch
  counts and guard totals for public37 and public1070.
- Compare the four native/matrix vectors, cache digests, IDs and dispatch counts
  byte-for-byte with accepted strategy5 source. Run the independent zero-GPU
  reference comparison on the fresh collection. Preserve all output and failure
  artifacts outside Git in a new exclusive work directory.
- This does not yet prove profiled/unprofiled parity or any trace attribution.

## Inputs and observed identities

- Model SHA-256:
  `dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
- Accepted strategy5 source CSV/report/binary SHA-256:
  `0dcc24b233b8ff094ac0486fcad7734fcd53ba0eba0c9f2e684a2c2316cd4d2d`,
  `22395c06b4cc62444ff063ba439cfcef89f3922c5ff0daabb284f56e23932a27`,
  `3afd548ad0ef71952ae590aa13c06a6ebc08fff4355eacfee293af7998b82660`.
- Independent reference model SHA-256:
  `b0dd20c95a6605d9773d9d3153c52f89f21628f21048ff81bb184684b6f7a42b`; its
  independently pinned F32 derivation receipt is part of the existing local
  oracle evidence set.
- Physical device/tool baseline is RTX 2060 Max-Q sm_75, Llama3.2 3B Q4_K_M,
  context1536, F16 KV, activation precision0, locked Mojo/MAX26.5.0 and Nsight
  Systems2023.4.4. Nsight availability is reconnaissance only.

## Gate

Build first. Run fresh public37 and public1070 strategy5 collection, strict source5
comparison, independent CPU oracle, post-capture rehashes and documentation/drift
checks. Review the exact output before committing/pushing and recording the remote
head. Tracing implementation is a later slice.

## Completion receipt — 2026-10-10

Fresh capable-disabled collection passed all four source5 cases, exact source5
vectors/cache/IDs/counts, independent pinned zero-GPU CPU comparison and guards.
Compact hashes/results are recorded in
`docs/evidence/small-attention-trace-baseline-2026-10-10/README.md`; raw CSV and
failed reports remain in the private task directory listed there.
