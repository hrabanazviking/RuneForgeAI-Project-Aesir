# Small-score strategy5 cooperative controls evidence — 2026-10-09

This is a narrow native fixture acceptance for the strict Llama 3.2 3B model on
RTX 2060 Max-Q (`sm_75`), context1536, F16 KV, activation precision0. It does not
change normal runtime selection. Enabled-control timing is not scored.

## Identity and artifacts

- Model SHA-256: `dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
- Accepted disabled-controls strategy5 source: existing 2026-10-03 four-case
  source CSV/report and source binary; the checker revalidated all three hashes.
  Source CSV SHA-256 `0dcc24b233b8ff094ac0486fcad7734fcd53ba0eba0c9f2e684a2c2316cd4d2d`,
  report SHA-256 `22395c06b4cc62444ff063ba439cfcef89f3922c5ff0daabb284f56e23932a27`,
  binary SHA-256 `3afd548ad0ef71952ae590aa13c06a6ebc08fff4355eacfee293af7998b82660`.
- Fresh controls-capable, controls-disabled target binary SHA-256:
  `0286f819c7b55e6d2fa91b5f8a67be429512c6444872acfc48041ad30de0ecf0`.
- Controls collector binary SHA-256:
  `e25f3b2a7c820f52bbec26cc30e10dd8a81d146bacaf4cdf748786b9aedb0a18`.
- Checkpoint replay target binary SHA-256:
  `1f2ae8ef889f659db2fca28a1289735f4bef0b6baa4aedc57c7993bd4112699f`.
- Final small-model constructor-probe build SHA-256:
  `2195be7a45258d6cd7426b8073baf7bccfcea416fc7bd377b6503908d7ec2d5a`;
  `reject-controls-with-replay` refused before model access.
- Fresh capable-but-disabled CSV SHA-256:
  `8581018dd305e4385846bc827378a42992fbf1539c7aedb364a0f4eb6997413f`.
- Controls CSV SHA-256:
  `b43ac761664b7cfca71155e2a21c517260e0578e570f23bb60613ab990961e05`.
- Report checksums: `disabled-capable.json` is
  `ade78b64383b682a16edc57bf547ff7853aaf7e015d40264471c0ac32ddedba3`;
  `controls.json` is
  `ec99cd7bd5f5f502cc278427d48c7653dd1318600ff135876c0d1391a173d4a9`.
- The full CSV captures are retained in the private untracked task artifact
  directory; its machine-local path stays out of Git.

## Results

The fresh capable-but-disabled model run matched the accepted strategy5 source
CSV/report/binary across all four native/matrix vectors, cache digests, IDs and
dispatch counts. It passed all four cases, 513,024 F32 values per owner, guards,
and independent
zero-GPU F32 CPU comparison. The four native/matrix cases passed the fixed
maximum-absolute `.05`, RMS `.005`, and full-vocabulary argmax criteria. Maximum
observed RMS was `0.0017843882` native and `0.0039867654` matrix. The independent
oracle used llama-cpp-python0.3.23, NumPy2.4.4, context4096, F16 KV, batch128,
four threads and GPU layers0.

Physical control collection and strict source-bound checking passed. Pre-expired
timeout stopped at0 layers; cooperative 10ms timeout stopped after2 synced
layers; owned SIGINT stopped after8 synced layers; invalid descriptor stopped at0
layers. Each aborted tile remained uncommitted and required reset. Reset preserved
the allocations and recovered all 513,024 native and matrix values exactly for
each of the four abort cases. Observer failure poisoned the fixture and refused
reuse/reset. All9,792 guards passed and the owner signal mask was restored.

The 10ms bound is cooperative, not hard real-time. Initial harness bring-up
attempts reused a preflight CSV destination before the successful run; their
checker failure reports were retained in the local work evidence directory, but
those superseded physical CSVs were not retained. The final successful captures
are preserved with the hashes above.

This does not test CUDA fault
repair, GPU loss, concurrency, long-running soak, tracing, persisted restore,
context recreation, general runtime/provider readiness or performance. Strategy5
and its controls remain test-only and default-disabled.

## Validation and runtime restoration

All three affected Mojo targets compiled for `sm_75` before physical capture.
The 45 focused Python contracts passed, documentation drift passed, and the
normal service binary was rebuilt after the test-source change. `aesir-brain.service`
was restarted and returned authenticated `GET /health` status200 with
`active/ready`, backend CUDA, context4096, `prefill_batch=4`, `cpu_offload=0`.

The compact checker reports are stored beside this file. Full raw CSV captures
remain outside Git to keep the source branch small; their hashes above bind them.
