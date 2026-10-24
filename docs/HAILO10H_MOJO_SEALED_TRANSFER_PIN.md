# Owned sealed metadata and program views through driver finalization

Date:2026-10-24. Pre-code contract:`TASK_hailo10h_sealed_transfer_pin.md`,
published314de97 before production. Fixed broad owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. All LLM execution stays Hailo-10H.

## Original transport owner

New original `smidr/sealed_transfer_pin.mojo` moves the existing two-part sealed
backing into one owner with two read-only/private host views and a fresh qualified
driver file. Zero old production or test files changed. Existing full actual
program/request/integrity/metadata validators and driver/UAPI/syscall helpers
remain unchanged. No vendor body,new OS interface or descriptor formula is added.

Construction validates actual sealed backing and independent positive work/
allocation/read bounds,then rounds each actual logical extent with the actual
page size. It compares every logical view byte against validated backing before
opening/mapping a device. Its sole CPU pointer dereference uses each actual local
mmap result in that construction scope. No caller pointer is accepted. After
mapping starts,there is no CPU view dereference. Both original logical extents
remain separate from rounded VMA sizes and packed transaction intent.

Each map is armed before the ioctl and its full reply tuple/handle is validated;
handle0 remains valid. Cleanup attempts known mappings in reverse order,continues
independent failures,then closes the owning driver before either host view or
sealed file is released. Explicit finalization permits independent actual backing
reads after confirmed driver close. Moves/defaults/idempotent successful close
and returned independent copies are qualified.

An unconfirmed driver close permanently poisons the owner,retains both actual
VMAs and sealed fds until process finalization,and refuses repeated close or
finalization without retry. This includes identity/open-helper cleanup failures
before the driver owner returns. Primary and independent cleanup errors remain.
A host munmap or sealed-close error after confirmed driver close does not prevent
independent cleanup and is never retried at a possibly reused resource.

This owner supplies mapping lifetime preparation. It adds no transfer submission,
channel/descriptor admission,physical program or numerical execution API.
Mutable diagnostic values are not executable credentials or generic artifact
identity. Synthetic outer envelopes never reach a receiver.

## Actual host acceptance

| Gate | Result |
|---|---|
| Actual old/final Mojo inputs |702 /705 |
| Actual old/final Python inputs |85 /86 |
| Frozen current qualified controls |154 |
| Old production/test edits |0 |
| All stable links before acceptance |21 Mojo /9 C or C++ |
| New statement warnings |0;four original driver/discovery/ABI warnings remain scoped |
| Selected methods |69:63 old and6 new |
| Old primary calls /complete frozen pairs |5342 /4976 |
| Frozen accepts /refusals |3251 /1725 |
| New primary calls |92 |
| New refusal/poison cases followed by fresh success |42 |
| Actual independent kernel-view checks |163 /215930 complete logical bytes |
| Additional independent kernel permission cases |6,with24 write/grow/shrink/shared-write refusals |
| New actual memfds /explicit closes |192 /170 |
| New actual read-only private VMAs /explicit unmaps |163 /141 |
| Deliberate both-part retention cases |10,each retaining2 actual fds and2 VMAs until exit |
| Separate before-effect host-release retentions |2 sealed fds and2 VMAs |
| Observed fd generations /actual closes |4954 /4927 |
| Actual harmless mock driver files /confirmed closes |76 /71 |
| Actual sealed positional reads after confirmed mock-file close |222 |
| Separate ELF tables |60 across30 linked images |

Independent Python struct/checksum and pinned public RPC-schema oracles compare
complete metadata/program bytes at70,4097,16385 program extents. Original C seams
independently inspect actual seals,CLOEXEC,all logical bytes and r--p VMAs,validate
both complete UAPI tuples,and track the two mappings separately. They use real
harmless host files;mock effects never count as physical results. Before/after
map/unmap/close faults,malformed replies,partial views,work/host/request guards,
independent release failures and repeated poisoned-owner refusals pass. No actual
physical close-error or DMA-cancellation behavior is claimed from these seams.

Actual PID-specific traces retain every observed descriptor generation and exact
owned VMA extent. Twenty-seven observed descriptors remain until process exit:
22 sealed fds and5 deliberately unclosed mock files. Twenty-two owned VMAs remain:
20 from poisoned cases and2 before-effect munmap faults. None is counted as an
explicit successful release. No opaque record or invented cleanup effect is used.
New host traces show no real Hailo open/ioctl,network or excluded inference runtime.
All154 controls,800 contract archive paths,actual source/test copies and compiler
identity are reverified. All old source/test bodies remain exact.

## Actual physical map-only batch

Seven children completed sequentially:initial anonymous2068-byte control,then
three two-part cases each followed by a fresh anonymous control. Actual current
profile is driver5.3.0,Hailo10H/PCIe/one engine,firmware loaded,descriptor maximum
page4096 and host page16384. The4096 property matches the pinned prior physical
receipt;it is not the512 value used by independent host mocks.

All3 new owners map both the sealed2068-byte metadata and separate70/4097/16385-
byte program on one fresh driver file. Across groups and controls,the trace audit
records7 device opens/closes,14 identity/property ioctls,10 successful maps and
10 successful unmaps. All6 sealed views and6 sealed fds release after actual
owning-file close;all4 anonymous control views also release after close. Twenty-
two actual sealed reads occur after driver finalization and complete returned
bytes match independent oracles. Typed map code checks original tuples;the
strace audit does not claim independent raw ioctl-payload capture.

Only established identity and map/unmap endpoints are called. No cache sync,
prepare/cancel/transfer,descriptor/channel/connection,action2,program activation,
model or numerical work occurs. This establishes bounded simultaneous mapping
and cleanup compatibility,not DMA/coherence,descriptor count,program validity,
transfer deadlines,late completion safety or source-model execution.

## Preserved attempts and immutable evidence

The first library type probe lacked main;the first API probe needed an explicit
Int64 conversion;the first C probe needed limits.h and unambiguous indentation.
Exact failed sources/diagnostics remain. A first native-build recipe referenced
a missing historical metadata path,and the next link review rejected two new
unused-initialization warnings. Both new warnings were removed before acceptance.
No failed/warned probe binary was executed as acceptance.

The first host audit overcounted mock-file closes by reusing a numeric fd after
its original generation closed. The final audit keys that count to its actual
/dev/null acquisition generation;the471 preliminary count is withdrawn in favor
of71. Actual raw traces/native results never changed. The first physical audit
also retained a runtime partial-VMA assertion failure;the final audit explicitly
classifies51 unrelated runtime partial unmap records while checking every owned
mapping's exact extent and release ordering.

The first physical harness stopped after its successful initial control because
it incorrectly expected the mock's512 property. The actual4096 matches immutable
prior physical evidence. The corrected driver reuses that exact completed control
and runs only the six remaining children:seven total,without repeating a device
case. That failed harness and both sets of raw receipts remain preserved.

Immutable paged manifest:
`evidence/sealed-transfer-pin-native-2026-10-24/archive-identities.json`.
Its27656 raw paths cover223873126 aggregate bytes in3 pages;SHA256:
`70a02c420401876a4a0830a572a7a99e2473cfeb24a533707f02f9843b44f30a`.
Never edit archived recipes/logs or rerun them into those directories. Publication gates retain the identical nine inherited schema errors. Drift
reports23409 findings:23408 inherited plus one retained audit compiler path.
Census succeeds with140 verified/185 total. Complete output identities and the
drift delta are retained;no whole-repository or hosted-CI pass is claimed.

Continue actual grouped descriptor accounting,completion/total deadlines/late
cleanup and H10H numerical encoding/packing/placement/program/results under
`TASK_hailo10h_numerical_encoding_sources.md`. Every missing source format,
architecture and operation remains required implementation work toward broad
ordinary UNMODIFIED model support100%. No DFC,outside compiler/machine,vendor-
precompiled prerequisite,host/CUDA/cloud LLM forward/proxy or guessed device write.
