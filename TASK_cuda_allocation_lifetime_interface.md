# AES500-023 — CUDA allocation lifetime interface gate

## Contract outcome

The public owner is `CUDAF16Allocation`; its `HostBuffer` and `DeviceBuffer` are
owned fields associated with a `DeviceContext`. One logical allocation accounts
for both buffers. `CUDADeviceResources` owns a context and a monotonic session
budget, but it does not own returned allocations as a collection. The follow-on
implementation adds an ArcPointer-backed session ledger shared with owners. Its
IDs are session-local; its live/destruction counters are diagnostics, not budget
release or allocator telemetry.

Mojo ownership guarantees prompt destruction when an owner and its references
end, and its type author is responsible for resource cleanup. MAX's GPU manual
states that `DeviceContext` operations are asynchronous and ordered on its
associated stream; `synchronize()` waits for all queued operations on that
stream. The same manual describes `HostBuffer` and `DeviceBuffer` as subject to
Mojo ownership/lifecycle and says device buffers persist while referenced or
until their context is destroyed. It does not promise that destroying a buffer
with in-flight work implicitly fences that work or returns memory to the CUDA
driver.

## Required interface boundary

1. Logical owner lifetime is distinct from the session's conservative budget
   reservation and from allocator/driver memory reuse.
2. A fenced owner-destruction counter means only that tracked wrapper/executor
   enqueue operations had a successful synchronization before Mojo destroyed the
   allocation owner. It does not mean budget was released or memory was reused.
3. If synchronization fails and the still-owned allocation is later destroyed,
   the tracker records that separately when tracked work remains pending. It does
   not retain the buffers or promise retry safety. Callers must retain the owner
   themselves if they need to retry the fence.
4. Moving an allocation preserves one owner and its session-local ID. The
   ArcPointer refcount protects tracker lifetime; tracker payload mutation is
   single-host-thread scoped because ArcPointer does not synchronize the payload.
5. Failed allocation construction remains transactional: all acquired fields are
   destroyed, the exact budget reservation rolls back once and success/live
   counters remain unchanged.
6. The interface must not report driver free memory or MAX pool reuse based on a
   logical owner release. That requires separate API evidence and is out of scope.
7. Destructors cannot raise in Mojo. The tracker therefore records destruction
   without trying to fence from `__deinit__`; its counters are diagnostic and do
   not make implicit destruction safe with pending GPU work.

## Implementation design constraint

Do not add bookkeeping that outlives the buffer owners without an equally clear
lifetime owner. The implementation uses an ArcPointer-backed session counter and per-owner
ID/state. It must keep the session budget monotonic, surface counter corruption,
and label owner destruction with known pending work separately. It does not
claim to retain or recover owners after a failed fence.

## Validation and exclusions

AES500-024 local validation covers two live owners, session-local IDs,
transactional budget rejection, synchronized transfers, executor moves and
owner destruction. The physical GPU-2/GPU-3 checks bind the tested MAX
version/device; they do not inject a CUDA synchronization failure. AES500-025
will add adversarial counter/identity cases. Physical evidence may prove only
the tested MAX version/device and
must keep driver memory observations separate from logical owner accounting.

This interface does not add budget release, allocator pooling, thread-safe
tracker mutation, asynchronous cancellation, process-crash recovery or
production runtime claims. Direct public `device_buffer` use can bypass the
tracker's pending-operation observations. The baseline and contract are tracked in
`docs/evidence/cuda-allocation-lifetime-baseline-2026-10-10/`.

## Primary references

- [Mojo ownership](https://docs.modular.com/mojo/manual/values/ownership/)
- [Mojo GPU programming fundamentals: asynchronous operations, synchronization,
  buffer ownership and deallocation](https://docs.modular.com/mojo/manual/gpu/fundamentals/)
- Pinned project environment: MAX 26.5.0 and Mojo 1.0.0 (`pixi.lock` / `pixi.toml`).

The hosted docs describe language/library conventions; they do not substitute
for a MAX 26.5.0 source-level guarantee about destruction with pending work.
