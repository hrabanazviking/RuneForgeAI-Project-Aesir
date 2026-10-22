# Original bounded source-byte digests

Date: 2026-10-22. Pre-code contract: `c2c678c`,
`TASK_hailo10h_source_byte_digest.md`. Fixed scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented boundary

`hailbru/source_digest.mojo` adds an owned incremental SHA256 state and a bounded
borrowed regular-file window reader. It reuses Aesir's existing compression in
`hailbru/fw.mojo`; that module and all previous production sources are unchanged.
Indexed byte consumption keeps at most one pending compression block. State
shape, count agreement, maximum length and sealed-state checks precede updates.

The file reader uses the existing ARM64 positional-read and regular-file extent
helpers. It checks the same descriptor's size before and after reading, permits
positive short reads, bounds every attempt including EINTR, and owns one I/O
buffer of at most 4096 bytes. It neither seeks nor closes the borrowed descriptor.
Empty windows, including EOF, are supported under positive policies.

`smidr/source_byte_digest.mojo` connects the reader to a live GGUF owner without
reading mapped payload bytes. Its returned digest survives source closure.
`smidr/tools/source_byte_digest.mojo` reports an
`observed_source_byte_window_digest`. The generic state is format-neutral;
additional adapters remain implementation work.

## Verification

Evidence: `evidence/source-byte-digest-2026-10-22/`.

- Eight clean Mojo builds: two new entrypoints and six selected source-owner,
  constant and byte-tile controls. All 649 previous Mojo sources, 66 previous
  Python inputs and 102 frozen binary controls retain their original identities.
  The new leaves do not change any old import closure or consumer API.
- Four suites, 23 methods and 905 primary native calls. The new six methods make
  451 calls: 418 successes and 33 refusals. Two published NIST examples, Python
  hashlib and the original bounded byte wrapper agree on complete digests.
- Independent chunkings cover empty input, all byte values, seeded inputs,
  padding/block/page boundaries, caller ownership, invalid/overflow/sealed states
  and recovery. Actual synthetic GGUF windows cover all 15 admitted storage
  geometries, full metadata/payload files, odd tails and empty EOF selections.
- Six rebuilt legacy controls match 454 complete comparisons: 352 successful
  outputs and 102 nonzero exit/stdout/handled-error cases. No pair is skipped.
- Twenty-eight new traces show 28 matched source opens/closes, ten whole read-only
  maps with matching unmaps, 78 kernel positional reads and 40 same-descriptor
  stat calls. Three legacy traces also pass lifetime checks. Injected errors do
  not issue kernel reads. No target-device, network, ioctl, inference runtime or
  external crypto runtime access was found. Dependency inspection is separate
  from native API calls.

Initial build diagnostics and two qualification failures remain archived. The
first runner incorrectly hashed its growing output log as an input. A later
complete-byte audit found that a test-only unsafe write pointer outlived its
buffer owner, changing a different byte than intended. The fixture now retains
its owner through the write and independently compares complete final bytes.
All four suites, eight builds and trace audits were repeated successfully after
that correction; production code did not change after its first passing tests.
Published receipts follow complete comparisons; full raw attempts, fixtures,
outputs and actual source snapshots remain in the pinned local archives.

## Limits and next work

A digest identifies the observed stream. Same-size concurrent writes can produce
a mixed stream; before/after size checks do not establish an atomic snapshot.
The existing GGUF parser is not certified against concurrent mutation by this
new path. Parsed metadata, compiled artifacts and later uploads are not yet
bound to one immutable source version. All fingerprint, immutable-source,
binding-identity, execution and device-access flags remain false.

Next qualify owned immutable source bytes, then connect parsing, conversion and
artifact binding to them. Physical H10H numerical instructions/configuration,
precision/packing/placement, original program delivery/activation/results/cleanup
and broad ordinary unmodified model execution remain required. No CPU/CUDA/cloud
model forward, external compiler or vendor-precompiled prerequisite is introduced.
No whole-repository or hosted-CI pass is claimed.
