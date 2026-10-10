# AES500-024 — CUDA allocation lifetime implementation

## Scope

Add a session-local monotonic ID and ArcPointer-backed logical owner ledger to
`CUDAAllocationTracker`, `CUDADeviceResources`, and `CUDAF16Allocation`. Register
an allocation only after both buffers were created and the context setup fence
succeeded. On Mojo owner destruction, decrement logical live count/bytes exactly
once and classify the drop according to known wrapper/executor pending-work
state. Keep the existing policy budget monotonic. Do not implement reclaim,
pooling, implicit sync in a destructor, or a CUDA-driver memory claim.

GPU-3 constructs a batch of three allocations directly, so it must pass through
the same tracker and register only after the existing atomic reservation,
construction and shared synchronization succeed. Existing source-level raw
`device_buffer` access remains supported but is outside pending-work observation;
state this limitation plainly.

The tracker payload is mutated from the owner thread only. `ArcPointer` makes
shared ownership safe, not concurrent mutation. Concurrent resource/tracker use
is excluded until a lock/thread-affinity contract is implemented separately.

## Acceptance

- Each allocation receives a positive ID unique within its resource-session
  tracker. A failed construction may consume an ID; it cannot register a live
  owner or increment successful allocation count.
- Successful allocation reports exact logical live count and F16 bytes. Owner
  destruction after known synchronized work decrements those values and records
  the fenced owner destruction. A known pending operation at owner destruction
  is separately visible and never counted as fenced.
- Budget-limit rejection preserves budget reservation, successful count, live
  owner count/bytes and fenced-destruction counters.
- GPU-3 executor construction and move ownership track all three buffers; after
  executor scope ends, no logical live owners remain and six known fenced
  owner destructions are observed for two shapes.
- Run GPU-2 and GPU-3 opt-in physical probes on the declared sm_75 device. These
  prove only those synchronized paths, not general teardown safety or raw-pointer
  use.

## Commands

```bash
pixi run mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_gpu_resources.mojo -o /tmp/aes500-024-gpu-resources
/tmp/aes500-024-gpu-resources
pixi run mojo build -I aesir_engine --target-accelerator sm_75 aesir_engine/tests/test_gpu_gemm.mojo -o /tmp/aes500-024-gpu-gemm
/tmp/aes500-024-gpu-gemm
python3 scripts/check_doc_drift.py
git diff --check
```

## Limits

The ledger is a per-resource-session diagnostic. It does not decrement the
policy reservation, observe arbitrary direct device-buffer enqueue calls, retain
buffers following synchronization failure, prove async destruction safety,
show allocator reuse or driver free-memory changes, or establish thread-safe
concurrent use.
