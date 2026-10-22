# Original owned sealed source-byte copies

Date: 2026-10-22. Contract before production. Parent:
`TASK_hailo10h_source_compiler_plan.md`. Fixed scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
The observed byte-digest leaf is verified at `28c7768`; it does not supply an
immutable source version or parsed-metadata/artifact coherence.

## Qualified interface and reuse

`docs/HAILO10H_SEALED_SOURCE_COPY_CONTRACT.md` records license-first UAPI review,
installed ARM64 constants and an isolated C/kernel oracle. The current Pi accepts
anonymous regular memfds, the four required seals, positional reads and exact
regular-file extent checks. This is host storage evidence, not numerical Hailo
or source-model execution. No external code body is adopted.

Reuse `hailbru/syscall.mojo` gateway, descriptor close, positional read/write and
regular-file size helpers, plus `hailbru/source_digest.mojo` for the final sealed
content digest. Add a new leaf; keep all existing production modules and APIs
unchanged. No new kernel, driver, firmware, device operation or external compiler.
Do not use `/proc/self/fd` or `/dev/fd` reopening as a parser integration shortcut.
Do not change the existing GGUF parser, collection owners or fingerprint flags
in this slice. Their eventual sealed-descriptor integration is separate work.

## Native ownership and copy API

Add `hailbru/source_sealed_copy.mojo`. Define movable `SealedSourceBytes` with
`arch:String`, `fd:Int64`, `source_bytes:Int64`, `digest_hex:String`,
`source_read_calls:Int`, `copy_write_calls:Int`, `digest_read_calls:Int`.
Default construction owns no fd (`-1`), zero extents/counts and empty digest.
Its destructor releases only its owned exact descriptor. Add idempotent explicit
`close(mut self) raises`, invalidating fd ownership before reporting close errors.
No transfer/reopen API is required in this slice. Writable public fields are not
tamperproof identity evidence; tests must restore synthetic fd mutations before
owner destruction.

Add:

```
seal_source_copy(arch:String,source_fd:Int64,expected_size:Int64,
  source_byte_bound:Int,read_call_bound:Int,write_call_bound:Int,
  digest_call_bound:Int) raises -> SealedSourceBytes
```

Validate ARM64 host, exact source fd range, nonnegative size no larger than the
SHA256 limit, positive policies and full-file byte bound before reading source
bytes or creating destination storage. Require the same borrowed regular fd's
actual size to match before and after copying. Empty files are valid under
positive policies. Never seek, write, seal, reopen or close the borrowed source.

Create a new memfd with `MFD_CLOEXEC|MFD_ALLOW_SEALING`. Check the returned fd's
exact range and distinctness from the borrowed source before taking ownership.
Copy from offset zero using one at-most4096-byte owned I/O buffer, indexed source
reads and destination positional writes. Handle positive short reads/writes,
reject early zero/oversized results, retry EINTR only within independent explicit
read/write attempt budgets and count every attempt. Retain the unsafe buffer's
owner through every read and write. Close the new fd on every failure; free all
owned scratch storage on every path. No source-size allocation outside the
bounded anonymous destination, and no device-memory fit claim.

Check exact destination regular-file size, add
`F_SEAL_WRITE|F_SEAL_SHRINK|F_SEAL_GROW|F_SEAL_SEAL`, then read back the required
seal mask on that same fd. Unknown additional seal bits may coexist. Fail if any
required seal is absent; never expose an unsealed result. Compute the full final
digest from the sealed fd using the verified bounded reader and its separate
read-call budget. The copy helper's I/O buffer ends before digest reading begins.
Return only after all gates pass. A claimed digest must describe the sealed
bytes actually returned, not merely the earlier source read stream.

Add:

```
read_sealed_source_digest(owner:SealedSourceBytes,first:Int,count:Int,
  read_byte_bound:Int,read_call_bound:Int) raises -> BorrowedSourceDigest
```

Check live fd/host, current same-fd required seals and exact owner extent before
delegating. Return an independent owned digest. Default/closed/forged owners
refuse; no mutable digest string or public boolean can certify identity.

A bounded path CLI may open an ordinary regular source read-only with existing
helpers, delegate, close the source on every path, demonstrate owned sealed
reads and close the destination. It must not modify the source. New reporting
may state `sealed_copy_bytes_verified=true` only after the actual seal/extent/
digest gates. Keep `atomic_original_snapshot_verified`,
`source_fingerprint_verified`, `binding_identity_verified`, `execution_tested`
and `device_access` false. Do not promote old immutable-source flags.

The copy is an immutable observed stream after sealing. Concurrent writes to the
original can still create a mixed copied stream. This is not an atomic snapshot
of an original file version, nor proof that a preexisting parse matches it.
Future consumers must parse and compile from the sealed bytes themselves before
claiming coherent bindings. Host memory/work bounds are explicit policies,
not permanent model-format or architecture restrictions.

## Acceptance and publication

Before code, verify the frozen653 source identities/actual snapshots,104 current
controls and67 Python identities/actual snapshots. Inventory imports and build
actual affected new leaves plus selected source-owner/digest/constant/byte-tile
controls. No unrelated model or engine execution. Preserve full old/control
outputs and every failed attempt. No old test inputs may be changed to get a pass.

Use independent Python byte fixtures and the installed-header C oracle. Cover
empty, odd, page/multiblock sizes, all byte values, observed digest equality and
exact complete copied bytes. Prove source fd position/ownership and source bytes
unchanged, kernel seals and close-on-exec on the returned actual fd, write/grow/
shrink and writable-shared-map refusal, and read success after original source
mutation/closure. Refuse missing seals, wrong extent, invalid/closed/default
owners, bad policies/ranges, read/write EINTR/short/EOF/oversized/error outcomes,
copy/digest budgets, create/seal/get-seals/extent failures and post-effect cleanup.
Preserve fresh-state recovery and actual balanced source/destination lifetimes.

Trace real anonymous descriptors, positional offsets/counts and readonly source
access. Join PID-specific split calls and accept the actual `(deleted)` memfd
fd decoration without weakening access/lifetime checks. Derive actual trace
counts; separate dependency inspection from native calls. No target-device,
network, ioctl, inference or external crypto/runtime access. No model/layer/
attention forward. Verify, commit/publish Hailo branch, verify exact remote head/
tree, fast-forward main and verify both clean checkouts, then continue.

The next integration gate is source parsing/conversion/artifact coherence using
owned sealed bytes. Actual H10H numerical instructions/configuration/precision/
packing/placement, original program delivery/activation/results/cleanup and broad
ordinary unmodified source-model execution remain required under the full target.

## Native slice completed

2026-10-22: `docs/HAILO10H_MOJO_SEALED_SOURCE_COPY.md` records ten clean Mojo
builds,1091 primary calls,905 complete frozen-control pairs and93 new traces.
Immutable owned observed copies are verified. Sealed-descriptor parsing and
source/artifact coherence remain separate required work; old flags stay false.
