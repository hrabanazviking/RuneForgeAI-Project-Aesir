# Original grouped prepare and cancellation value codecs

Date:2026-10-24. Publish before implementation. Parent:
`TASK_hailo10h_program_delivery.md`. Qualified declarations:
`docs/HAILO10H_PREPARE_INTERFACE_2026-10-24.md`. Fixed owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Add only `hailbru/soc_prepare.mojo`,a bounded inspector,direct API tests and
scoped independent Python/public-header oracles. Zero old production/test edits.
Reuse existing SocUserptrGroup,encode_soc_group,decode_soc_group and checked
handle/length/zero-byte helpers. Do not copy/replace the existing group parser,
slot rules,UAPI dispatcher,driver or any external implementation.

Encode prepare by validating the actual group through the existing141-byte
canonical encoder and returning an independent139-byte prepare body. Decode
exact139-byte input by adding ONLY canonical engine0/cyclicfalse tail and using
the existing full group decoder. No truncation,debug relaxation,unchecked slot,
length bypass,untrusted cached count or arbitrary integer narrowing. All channel,
handle,count,type,span/overflow/unused-slot rules stay identical. The result owns
its copied source list;source byte/list mutation,moves and scope expiry cannot
alter a returned independent object or bytes.

Encode/decode cancellation as exact8-byte checked handle value,using qualified
original scalar helpers. SentinelUInt64max refuses;0 remains valid. It is a
separate operation value,not a descriptor release call. Inspectors may report
existing ioctl numbers but must never issue them. Every numeric/hex/text input
has a bound before parsing/allocation;all exact-length failures remain visible.

Before code reverify/copy actual705 Mojo/86 Python files,156 controls,compiler
identity and all868 published contract archive paths. Only two new executable
consumers should depend on the new module;compute actual closure. Build all new
and auxiliary native consumers plus the three selected existing group/ownership/
ABI consumers and independent public-header oracles before ANY acceptance run.
Freeze final actual inputs/linked images;scope inherited warnings and preserve
all failed attempts. No unqualified device consumer may run.

Independent full bytes from Python struct and the pinned public UAPI must agree
for every1..8 count/slot,asymmetric/reversed spans,zero/max valid handles,UInt64/
UInt32 edge and walking bits,metadata2068+program70,seeded vectors and every
canonical unused/debug field. Existing141-byte launch encoding must equal the
prepare body plus its two explicit zero flags for the same valid source values.
Cancellation must match public-header8-byte objects and known current scalar
helper bytes without conflating request operations.

Test all shorter/trailing lengths directly through the API as well as inspector
bounds;all count bytes,used type fields,each unused byte,debug flags,channel/
handle/address/size/overflow/mutable-list guards. Returned copies must survive
input mutation/moves/close-free scope expiry. Every refusal is followed by fresh
successful construction/round trip. Compare full stdout/stderr/exit for EVERY
invoked selected frozen consumer,including auxiliary ownership/C++ oracles where
invoked. Keep complete current/frozen fault/input state when needed. Run existing
unmodified group/ABI suites. Trace all new consumers with actual PID/call joins
and account for observed effects;inspect ELF dependencies/symbols separately.

This is original host wire preparation,not descriptor accounting or executable
admission. No source model,driver open,map,ioctl,prepare/cancel/transfer request,
cache sync,channel/server/program activation or numerical operation may run.
No guessed descriptor count,opcode/register,budget or physical ordering follows
from header fields or prior map-only receipts. All LLM execution stays Hailo10H.

Verify,commit/publish Hailo,verify exact remote head/tree,lease fast-forward main,
verify clean checkouts,then continue actual grouped descriptor/status/completion/
deadline/late cleanup and numerical configuration/packing/placement/program/
results. Broad ordinary UNMODIFIED model support100% remains fixed;missing
formats,architectures and operations remain implementation work. No DFC,outside
model compiler/machine,precompiled prerequisite,host/CUDA/cloud inference/proxy,
reset/rebind,kernel/firmware change or invented device write.
