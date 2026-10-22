# Original owned sealed source-byte copies

Date: 2026-10-22. Pre-code contract: `caf3240`,
`TASK_hailo10h_sealed_source_copy.md`. Fixed scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented boundary

`hailbru/source_sealed_copy.mojo` owns a bounded anonymous host file containing
an observed source stream. It validates the borrowed regular descriptor, size
and explicit policies before creating destination storage. Positional source
reads and destination writes handle short progress and bounded EINTR retries;
every attempt consumes its independent permit. One at-most4096-byte copy buffer
is retained through unsafe-pointer use and ends before final digest reading.

After exact source/destination extent checks, the new owner adds and reads back
all four kernel seals: write, shrink, grow and further-seal protection. It hashes
the actual sealed destination using Aesir's existing digest reader. No unsealed
result is returned. Explicit close invalidates ownership before reporting errors;
exception cleanup releases the destination while retaining the borrowed source.
A separate sealed-window reader checks current seals and owner extent.

`smidr/tools/sealed_source_copy.mojo` accepts ordinary byte files, closes the
original, reads the sealed owner and closes it. It reports only
`sealed_copy_bytes_verified=true`; atomic-original, existing immutable-source,
fingerprint, binding, execution and device-access flags remain false.
All653 previous Mojo modules,67 previous Python inputs and104 frozen controls
are unchanged. No parser, source consumer or old API is modified.

## Verification

Evidence: `evidence/sealed-source-copy-2026-10-22/`.

- Ten clean Mojo builds: two new entrypoints and eight selected old controls;
  two clean C builds supply the fault shim and installed-header/kernel oracle.
  All656 current source identities and actual source snapshots are preserved.
- Five suites,28 methods and1091 primary native calls. Five new methods make186
  calls:130 zero exits, including handled guard/recovery cases, and56 expected
  nonzero refusals. Complete copied bytes match208069 independent byte values.
- Empty, odd, padding/page and multi-block cases, all byte values, seeded data,
  full synthetic GGUF files across15 current geometries and an ordinary synthetic
  safetensors file are copied as bytes. This is not format-parser integration.
- Actual kernel seals/CLOEXEC, write/grow/shrink/shared-writable-map refusals,
  original mutation/closure independence, mutable-owner refusal and recovery,
  read/write/digest budgets, short progress, EINTR/EOF/oversize/errors and
  creation/seal/get-seals/extent/post-effect failure cleanup pass.
- Eight frozen controls match905 complete comparisons:770 successful outputs
  and135 nonzero exit/stdout/handled-error cases. The two intentional old fixture
  mutations are restored before the control and their complete final bytes
  compared afterward. No native pair is skipped. Dependency inspection is
  classified separately from native API calls.
- Ninety-three new traces show92 matched source-path opens/closes,69 matched
  anonymous destination creates/closes,409 kernel positional reads and179
  positional writes including refusals. Independent fault logs check attempt
  permits. Four intentional original-file mutations match exact expected bytes.
  Twenty-eight digest and three legacy traces also pass lifetime audits.

All native suites passed without production or test corrections. Audit attempts
are preserved: the first token check confused normal fatal-signal handler
registration with signal delivery; the next split-call parser did not recognize
an unresolved `???` name during worker termination after `exit_group(1)`.
Corrections retain access, extent, budget and lifetime checks, reject actual
fatal-signal delivery, and join matching PID/name records. The one opaque exit
record remains unclassified; no effect is inferred from it. No target-device,
network, ioctl or external crypto/inference runtime appears in decoded effects
or dependencies. The recorder's initial digest-audit path error and partial
outputs are also retained; no test/report was omitted to correct it.

## Limits and next work

The owned copy is immutable after sealing. Concurrent writes to the original
can still produce a mixed observed copy; this is not an atomic original-file
snapshot. No existing parse or compiled artifact is bound to the copy yet.
The next slice must parse the same sealed bytes through an owned descriptor,
with actual mapping capacity and lifetime guards, before source coherence can
be claimed. Public writable fields are not tamperproof attestations.

The bounded public-interface follow-up found no qualified relation between the
known `kernel_done_count` completion field and the patent's microcode-length/
opcode-check concepts. Existing host codecs already preserve that field; it
supplies no new numerical encoding or reason to issue a hardware request.

Actual H10H numerical instructions/configuration,precision,packing,placement,
original program delivery/activation/results/cleanup and broad ordinary model
execution remain required. No host/cloud LLM forward or external compiler was
introduced. No whole-repository or hosted-CI pass is claimed.
