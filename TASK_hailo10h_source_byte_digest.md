# Bounded original source-byte digests

Date:2026-10-22. Publish before production. Parent:
TASK_hailo10h_source_compiler_plan.md. Owner scope:
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. IQ4 source readers are verified
at9588604. This slice starts source-content identity work;it is not numerical
Hailo execution,an immutable model snapshot or complete compile-artifact binding.

## Existing implementation audit and reuse

Aesir already owns SHA256 compression and byte/file wrappers in hailbru/fw.mojo.
Reuse its original _sha256_block. Keep that module and its public signatures
unchanged. Do not add a second compression algorithm or external crypto/runtime
dependency. The path-opening firmware hash/check/staging/register/boot workflows
are outside this slice. Existing os_fd_regular_size and os_pread_metadata supply
regular-fd extent and positional ARM64 reads. Their byte-access ABI is reused
for source bytes without changing the kernel,driver or syscall layer.

The source compiler still reports source_fingerprint_verified=false. Leave all
existing flags and APIs unchanged. A computed byte digest does not prove that
parsed metadata,a compiled artifact and a later hardware upload observe one
immutable source version. Concurrent same-size writes can produce an observed
byte stream rather than an atomic snapshot. That later coherence/binding gate
stays explicit. Hashing never runs a model or authorizes a device program.

## Exact incremental native API

Add hailbru/source_digest.mojo with movable SourceSha256State:
chain:List[UInt32],pending:List[UInt8],byte_count:UInt64,sealed:Bool. Its default
constructor owns the standard eight-word initial state and empty pending data.
Public source_sha256_update(mut state,data:List[UInt8]) and
source_sha256_finish(mut state)->String raise on invalid/sealed state. Add
sha256_source_bytes(data)->String as a convenience wrapper.

Before update/finalize,check eight chain words,pending length0..63 and exact
byte_count modulo64 agreement. Keep byte_count at most2^61-1;reject an update
that would exceed it before mutation/allocation. Update consumes input by index,
keeps only a pending block and never copies the entire remaining chunk after
each64-byte block. Reuse original compression on complete blocks. Finalize uses
standard padding and big-endian bit length,returns64 lowercase hex characters
and seals the state. Reject further updates/finalization. Consumed caller data
and returned digests have independent ownership. No claim of tamperproof state
or cryptographic certification follows from structural state validation.

Define movable BorrowedSourceDigest(source_bytes:Int64,first:Int,count:Int,
read_calls:Int,digest_hex:String) and
 digest_borrowed_regular_window(arch:String,fd:Int64,expected_size:Int64,
 first:Int,count:Int,read_byte_bound:Int,read_call_bound:Int).
Validate exact fd range,host,nonnegative expected size/range,positive byte/read
policies,subtractive first/count extent and SHA byte limit before payload or
requested buffer allocation. Empty windows,including at EOF,are valid under
positive policies. Require actual same-fd regular size to equal expected_size
before and after hashing. Use one at-most4096-byte host buffer and positional
reads only within the requested window. Accept positive short reads with
progress;reject zero before completion and results larger than the request.
Retry EINTR only within the explicit read-call budget;every attempt consumes
one permit. Other read errors and budget exhaustion fail. Free owned temporary
storage on every path. Never reopen the path,seek or close the borrowed fd.
This buffer size is a host policy,not device geometry. Other host ABIs remain
implementation work;the current positional ABI is ARM64 Linux on this Pi.

Add smidr/source_byte_digest.mojo with movable SourceByteDigest containing
source_bytes:Int64,first:Int,count:Int,read_calls:Int,digest_hex:String.
read_source_byte_digest(source:PackedGGUF,first,count,read_byte_bound,
read_call_bound) checks a live mapped owner/fd,nonnegative source size and valid
data origin,then delegates to the same-fd reader using the owner's expected size.
No tensor dtype dispatch or tensor arithmetic is involved. No mmap payload
access is used by the new hashing path;positional reads avoid SIGBUS on a file
truncated after mapping. Add read_source_byte_digest_window for an owned path.
The returned object owns its digest and survives source closure.

Add bounded CLI/test APIs. New output scope is observed_source_byte_window_digest;
byte_digest_computed may be true after success. source_fingerprint_verified,
immutable_source_verified,binding_identity_verified,execution_tested and
 device_access remain false. Preserve all old consumer outputs. General byte
state is format-neutral;the first borrowed-source adapter is GGUF. Safetensors,
collections and coherent artifact binding remain work,never permanent exclusions.

## Verification and publication

Before code,verify649 source identities/actual snapshots,102 current controls
and66 Python identities;preserve actual old input contents. Audit imports and
build the actual affected entrypoints from stable sources. New leaves need not
trigger unrelated model/engine execution. Preserve every old source/API unless
an additional pre-code contract explicitly requires a shared-owner change.
Compare complete legacy-control outputs in the selected source-owner/constant/
byte-tile regressions;classify direct/strace API calls separately from ldd.

Use published NIST SHA256 examples,independent Python hashlib and the existing
original sha256_hex on bounded small byte arrays. Cover empty input,all256 byte
values,seeded data,55/56/63/64/65 and multi-block/tail boundaries,independent
chunkings,empty updates,large-count state guards,invalid state,sealed reuse,
caller/return ownership and fresh-state recovery. Native test arithmetic is
hashing/byte parsing only;no model/layer/attention forward.

Hash actual unmodified synthetic GGUF metadata/payload windows and full files,
including each admitted storage geometry,odd final bytes and page boundaries.
Compare full digests with independent byte slices. Cover bounds,closed/forged
size owners,regular-fd type/extent,short reads,EINTR/EOF/EIO,budget exhaustion,
size-change cleanup and unchanged fd position/ownership. Restore synthetic
owner-field mutations before destruction. Same-size content replacement must
change a subsequent digest;do not label that an atomic/coherent snapshot proof.

Trace actual positional offsets/counts and matched source lifetime cleanup;
prove unchanged fixture bytes and no target-device/network/ioctl/inference or
external crypto runtime. Retain all raw attempts,PID-aware split-syscall joins,
actual trace census,input/binary/source hashes and distinct status/report paths.
No old test or comparison may be silently skipped to obtain a pass.

Verify,commit/publish Hailo branch,read remote head/tree,fast-forward main and
verify both clean checkouts,then continue automatically. No owner action needed.
All LLM execution remains on Hailo-10H. Actual numerical lowering/configuration,
precision/packing/placement,valid original program delivery/activation/results/
cleanup and broad unmodified source-model execution remain required work.
