# CUDA allocation lifetime unit evidence — 2026-10-10

AES500-025 adds `test_cuda_allocation_tracker_adversarial()` to the CPU-only
`test_cuda_resource_budget.mojo` module and the master case ledger.

## Bound sources

- Mojo: Mojo 1.0.0 (ed45d567)
- `core/cuda_resources.mojo` SHA-256: `bd0c9ea0d65c1dc2d0c413bb337281262934636f6a49460fb05444fd26db927c`.
- `tests/test_cuda_resource_budget.mojo` SHA-256: `1dc63d53691195056729933068114aa55e86f01a1e150208de789a52d2cfecb6`.
- `tests/run_all.mojo` SHA-256: `a0cbfabcccc735f6ba96893b1c9b683ec1ea3b439bd098cd45401106a6435cb9`.
- Targeted stdout SHA-256: `68cc7dfeb4f403ff4afa164445b7d4030e4c0e8070ce2d2ae758acd435c162bb`.

## Cases

The CPU-only tracker test proves increasing positive session-local IDs, exact
registration counts/bytes, no mutation on count or byte overflow rejection, ID
exhaustion without next-ID mutation, fenced owner destruction, separate known
unfenced owner destruction, and fail-visible owner underflow. It does not inject
GPU synchronization failure or establish thread-safe mutation.

Targeted output:

```text
CUDA resource budget accounting: PASS
CUDA resource budget transactional rejection: PASS
CUDA resource budget overflow and rollback: PASS
CUDA allocation tracker adversarial contracts: PASS
CUDA resource policy admission: PASS
```

The full master suite passed with 191 cases, no failures, one explicit skip for
the absent optional GGUF fixture, and 192 total. The focused CUDA trace Python
suite passed 74 tests. Repository drift and whitespace checks passed. Hosted CI
for the exact pushed revision remains the release gate.
