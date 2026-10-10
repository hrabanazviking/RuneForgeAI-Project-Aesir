# AES500-015 — Strategy5 tracing unit evidence

## Objective

Prove the strategy5 owned-range parser and CUDA activity attribution fail closed
for the bounded contract before collecting a physical profiled session. This is
unit evidence only; it does not prove hardware execution, profiled/unprofiled
parity, or performance.

## Scope

- Verify strategy5 tile range count, namespace, kind, parent/thread identity,
  disjointness, and canonical source order (all full b32 tiles, then final b4).
- Verify each source tile has exactly 28 ordered layer-owned child ranges, and
  each child owns one successful launch API and one matching small-attention
  kernel with exact selected grid/block geometry.
- Reject unpaired/crossing launch APIs, duplicate/missing correlations, foreign
  kernels, projection labels, malformed resource records, and invalid kernel
  intervals. Preserve complete asynchronous GPU intervals without clipping to
  CPU child-range bounds.
- Verify whole-session analyzer routing is strategy5-exclusive and bypasses the
  strategy3/4 projection and fused attributors.
- Verify the explicit CUDA setup API allowlist is accepted only before the report
  analysis interval and before the owned parent range; other out-of-capture
  activity remains rejected and the setup count is exposed in the report.
- Keep parser, report, source-hash, full-session, and no-speed-claim checks in
  the Python contract suite.

## Acceptance commands

```bash
PYTHONPATH=scripts python3 -m unittest scripts/test_check_fused_attention_trace.py
PYTHONPATH=scripts python3 -m unittest scripts/test_check_cuda_trace.py scripts/test_check_turing_prefill_trace.py scripts/test_check_fused_attention_trace.py scripts/test_cuda_projection_ranges.py scripts/test_check_turing_down_projection_trace.py
python3 -m py_compile scripts/cuda_fused_attention_ranges.py scripts/check_cuda_trace.py scripts/check_turing_prefill_trace.py scripts/test_check_fused_attention_trace.py
git diff --check
python3 scripts/check_doc_drift.py
```

## Evidence boundary

The accepted result records test counts and exact command outcomes. Synthetic
activity databases and fixture rows prove checker logic only. Physical strategy5
profiled/unprofiled captures remain AES500-016 and must bind to the accepted
strategy5 source/model/binary, use exclusive paths, and pass the full-session
checker before any hardware attribution claim.
