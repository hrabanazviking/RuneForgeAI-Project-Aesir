# Complete retained ordinary tensor representation comparison

Date:2026-10-23. Pre-code contract:`TASK_hailo10h_ordinary_tensor_identity.md`,
published1a1516d before implementation. Broad ordinary unmodified model support
100% remains fixed under`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Original implementation and exact boundary

New`smidr/ordinary_tensor_identity.mojo`compares two complete canonical tensor
representations through actual retained indexed/unindexed ordinary bindings.
It reuses policy comparison,full source refresh/schema comparison and the existing
sealed constant reader. Same format,kind,axes,shape and exact counts are checked
before component-window allocation. Both complete operands are charged against
the total raw-element bound. Temporary windows have a separate positive chunk
bound;tails and maximal bounds are checked without overflowing products.

Every raw word is compared,including after the first difference. The returned
observation owns both canonical/original names,paths,shapes,axes,kinds,spans,
element/byte counts and full differing-element/first-difference statistics.
No floating-point arithmetic,approximation,whole-shard copy,new dtype decoder,
path reopen,fd duplicate,remap or new OS interface is introduced. Both source
owners remain with the caller;returned descriptions survive schema mutation
and explicit close. All695 old Mojo and83 old Python inputs are unchanged.

This is a complete stored-representation observation for each invocation. It
does not make an editable result a permanent identity token,merge source names,
resolve graph aliases or establish historical artifact identity. The ordinary
compiler's four preserved duplicate tied-output fixture refusals still pass.
Different kinds/shapes remain explicit comparison/compiler implementation work.
No missing format,architecture or operation becomes permanent model eligibility.

## Independent acceptance

Four suites pass33 methods:7 new,10 owned ordinary compiler,8 retained collection
and8 owned binding. All14 Mojo/2 C links completed before final acceptance.
Both new consumers are warning-free;all12 rebuilt old binaries match their
frozen hashes. Actual copies include695/83 old and698/84 final Mojo/Python inputs;
all150 frozen controls and the compiler identity are reverified. The actual
new import closure contains exactly the new inspector and test API.

Final3588 primary calls and2412 complete frozen comparisons retain6000 complete
stdout/stderr/exit triples. Old comparisons include1080 accepts/1332 refusals,
full original-file/directory restoration and independent fault-log comparisons.
New1176 calls include797 complete independent comparisons and379 refusals.
All640 individual payload-byte mutations across indexed/unindexed F16,BF16,F32
inputs are detected. Exact raw signed zeros/NaN payloads,separate shards,same-name
comparison,chunk tails,missing Unicode/NUL names,bounds,kind/shape differences,
every existing schema/policy mutation,owner fields,caches,moves and close are
covered. Independent reconstruction checks184192 source bytes from retained
fixtures and their deterministic mutation order,without another native run.

Eight complete original-mutation pairs preserve observed sealed input after
same-size edits,truncation,rename and replacement. Thirty-nine complete fault
pairs cover metadata/hash/read/EOF/close,copy/write/seal/mapping failures and
positive short reads,each with fresh success. Existing nonraising Safetensors
close limitations remain unchanged. No host model/layer/attention forward runs.

## Actual lifecycle audit and retained failures

All1176 new traces have reconstructed PID/call joins,one exec and actual exit.
3660 original source fds close;3656 actual sealed files close;1847 read-only
shared mappings unmap with their exact captured capacities before owner close.
Original source descriptors close before sealed mapping. Each admitted original
label opens once;revalidation does not reopen it. Actual tracing records61020
sealed digest reads,3636 successful seal installations and48981 actual seal
checks. No opaque record was omitted or assigned a fabricated effect.
No new trace opens Hailo,uses ioctl/connect or loads excluded inference/hash/
protobuf runtimes. Sixteen ELF artifacts have32 separate dynamic/symbol tables.

The first API type probe refused positional String slicing;its source/diagnostics
are retained. The test API now uses explicit UTF-8 byte slicing. The first full
run preserved two harness errors:Python argv cannot carry NUL,and one EOF fault
phase was beyond this shorter comparison path. NUL is now constructed inside
the test API;actual read phases qualify EOF/hash tests. Source code and test
copies from both runs remain;all three old suites passed in the failed first run.
The production comparison body never changed after its first successful link.
Two pre-audit extraction scripts had syntax errors;the corrected extraction
and complete final audit pass without native reruns. None is hidden as acceptance.

Immutable raw archives contain43625 files,1769634446 bytes. Manifest:
`evidence/ordinary-identity-native-2026-10-23/archive-identities.json`,SHA256
`aae13609830bd9ff2253ebb854cec3bb9cd1b64ba7e6baac0979194786b5ee8b`. Never edit or rerun recipes into these archived directories.
Inherited documentation drift and nine schema errors remain scoped;no whole
repository or hosted-CI pass is claimed.

## Continue source lowering and actual numerical execution

Next qualify a typed tied-output source alias that preserves both source
bindings and freshly rechecks actual bytes before graph consumption. Do not
drop the head,flip the tie flag or use a cached comparison as authority.
Actual numerical H10H precision,packing,configuration,placement,original program
transport/activation/results/cleanup remain open under
`TASK_hailo10h_numerical_encoding_sources.md`. All LLM execution stays on H10H;
no DFC,outside compiler/machine,vendor-artifact prerequisite,host/CUDA/cloud
forward/proxy or guessed opcode/device write is introduced by this slice.
