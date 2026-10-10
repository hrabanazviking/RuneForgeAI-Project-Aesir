# AES500-017 — Strategy5 trace adversarial evidence

## Objective

Exercise hostile ranges, CUDA setup activity, successful-launch correlations and
resource records against the accepted strategy5 tracing boundary. Keep this
slice deterministic and checker-focused; it does not require another physical
GPU run.

## Adversarial matrix

- Missing, duplicate, overlapping, reordered and out-of-parent child ranges.
- Wrong NVTX kind, label namespace, text ID, owner thread and end thread.
- Missing, duplicated, unpaired, failed, crossing and wrong-thread launch/kernel
  correlations; wrong kernel prefix and exact grid/block resource fields.
- Empty, reversed or out-of-capture asynchronous kernel intervals. GPU intervals
  that merely finish after their CPU child range remain complete and untrimmed.
- Pre-analysis CUDA API records: allow only the exact strategy5 setup names in
  the same process, with status 0 except `cuMemCreate` status 101. CUDA status
  101 is `CUDA_ERROR_INVALID_DEVICE`; the capture lacks call arguments, so the
  receipt records this result without claiming it was benign or unsupported.
  Each record must end before the owned prefill range. Unknown names, other
  nonzero statuses and overlap with the owned range fail closed.
- Strategy and trace-mode exclusivity, including no projection-stage labels or
  fused strategy borrowing.

## Acceptance

```bash
PYTHONPATH=scripts python3 -m unittest scripts/test_check_cuda_trace.py scripts/test_check_turing_prefill_trace.py scripts/test_check_fused_attention_trace.py scripts/test_cuda_projection_ranges.py scripts/test_check_turing_down_projection_trace.py
python3 -m py_compile scripts/check_cuda_trace.py scripts/cuda_fused_attention_ranges.py scripts/test_check_fused_attention_trace.py
git diff --check
python3 scripts/check_doc_drift.py
```

Evidence is test output plus hosted CI for the exact pushed head. No synthetic
case is represented as physical CUDA proof; the accepted physical integration
receipt remains AES500-016.
