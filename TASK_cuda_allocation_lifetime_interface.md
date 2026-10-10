# AES500-023 — CUDA allocation lifetime interface gate

## Contract outcome

The public owner is `CUDAF16Allocation`; its `HostBuffer` and `DeviceBuffer` are
owned fields associated with a `DeviceContext`. One logical allocation accounts
for both buffers. `CUDADeviceResources` owns a context and a monotonic session
budget, but it does not own returned allocations as a collection. Existing
allocation count is a success counter, not a live-object count or release count.

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

1. A release event is a **logical owner release**, distinct from the session's
   conservative budget reservation and from allocator/driver memory reuse.
2. A successful release may be acknowledged only after the owning context stream
   has synchronized successfully. The baseline operation already synchronizes
   each transfer; current code has no explicit release or in-flight counter.
3. If synchronization fails, no release count or reusable-byte count may advance.
   The allocation must remain owned and available for a retry or explicit
   terminal handling; callers must not treat the failed fence as completion.
4. Moving an allocation preserves its single logical identity and one owner.
   Copying, double release, unknown release, identity reuse while live, counter
   underflow and overflow must fail before mutating published accounting.
5. Failed allocation construction remains transactional: all acquired fields are
   destroyed, the exact budget reservation rolls back once and success/live
   counters remain unchanged.
6. The interface must not report driver free memory or MAX pool reuse based on a
   logical owner release. That requires separate API evidence and is out of scope.
7. Destructors cannot raise in Mojo. Therefore any release API that needs a
   fallible stream fence must expose that fence as an explicit raising operation
   while the owner is still available. Implicit scope destruction is not the
   successful release receipt.

## Implementation design constraint

Do not add bookkeeping that outlives the buffer owners without an equally clear
lifetime owner. The implementation slice must select a representation for the
live allocation registry, unique IDs, and release receipts, and prove move
behavior. If no safe representation can retain an allocation after a failed
fence, keep this work at an explicit no-release-while-work-is-pending contract;
do not claim recovery or leak-freedom.

## Validation and exclusions

AES500-024 must test owner moves, two live owners released in either order,
failed/partial allocation rollback, explicit successful synchronization before
release, and an injected synchronization failure that leaves accounting
unchanged and the owner retained. AES500-025 covers checked counter bounds and
invalid IDs. Physical evidence may prove only the tested MAX version/device and
must keep driver memory observations separate from logical owner accounting.

This interface does not add automatic release, allocator pooling, concurrent
allocation, asynchronous cancellation, process-crash recovery or production
runtime claims. The baseline and contract are tracked in
`docs/evidence/cuda-allocation-lifetime-baseline-2026-10-10/`.

## Primary references

- [Mojo ownership](https://docs.modular.com/mojo/manual/values/ownership/)
- [Mojo GPU programming fundamentals: asynchronous operations, synchronization,
  buffer ownership and deallocation](https://docs.modular.com/mojo/manual/gpu/fundamentals/)
- Pinned project environment: MAX 26.5.0 and Mojo 1.0.0 (`pixi.lock` / `pixi.toml`).

The hosted docs describe language/library conventions; they do not substitute
for a MAX 26.5.0 source-level guarantee about destruction with pending work.
