# Strategy5 tracing baseline — 2026-10-10

AES500-012 captures a fresh capable-but-disabled strategy5 baseline before any
trace labels or profiling. The run is correctness-only; its timings are not used.

## Identities

- Model SHA-256:
  `dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
- Fresh sm_75 collector `/tmp/aesir-small-trace-baseline` SHA-256:
  `2195be7a45258d6cd7426b8073baf7bccfcea416fc7bd377b6503908d7ec2d5a`.
- Accepted strategy5 source CSV/report/binary SHA-256:
  `0dcc24b233b8ff094ac0486fcad7734fcd53ba0eba0c9f2e684a2c2316cd4d2d`,
  `22395c06b4cc62444ff063ba439cfcef89f3922c5ff0daabb284f56e23932a27`,
  `3afd548ad0ef71952ae590aa13c06a6ebc08fff4355eacfee293af7998b82660`.
- Independent reference GGUF SHA-256:
  `b0dd20c95a6605d9773d9d3153c52f89f21628f21048ff81bb184684b6f7a42b`.
- Independent reference derivation receipt SHA-256:
  `9325ff2a1d58cd5334f1423d8db2eaffc631dd853785ed287a37f48b51dec5a9`.
- Fresh CSV SHA-256:
  `2424a4934594c4e42520ace1d1143629ef76be709f38f3203b110a73a7bafaa2`.
- Accepted checker JSON SHA-256:
  `f3b60e2445c7665982656de652186e23d4de2b79827a3709da6e5fe3f1bf1482`.

## Result

The trace-capable-but-disabled strategy5 model collector completed four declared
cases (30, 37, 31 and 1070 input IDs), all four native/matrix vectors, 513,024
F32 values per owner, complete input IDs/cache hashes/counters, and 4,352 guards.
The strict source5 checker reported `passed=true`, `collection_complete=true`,
`fixture_reference.passed=true`, and `independent_reference.passed=true`. All
four native/matrix vectors, cache digests, IDs and dispatch counts matched the
accepted source5 capture. Maximum observed CPU-comparison RMS was0.0029158002;
all four native full-vocabulary argmaxes matched. The unprofiled baseline is
accepted for the declared model/device/prompts only.

The initial checker report using the old strategy default and the subsequent
system-Python report without the pinned `llama_cpp` environment were retained as
failed reports. The accepted checker was run from the existing oracle environment
pinned to llama-cpp-python0.3.23 / NumPy2.4.4 and zero GPU layers. Full CSV, all
reports, before/after identity files and process outputs are retained privately at
`/home/volmarr/Documents/Codex/2026-10-09/ma/work/aesir-small-trace-baseline-20261010/`.
The source/model/binary/source-report hashes matched before and after validation.

This baseline does not test traced/profiled parity, trace-event ownership, kernel
correlations or speed. Those are later AES500 slices.
