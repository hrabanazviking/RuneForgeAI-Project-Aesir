# Same-file session and two-part sealed mapping owner

Date:2026-10-24. Publish before implementation. Parent:
`TASK_hailo10h_program_delivery.md`. Fixed owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. Boundary study:
`docs/HAILO10H_GROUP_SESSION_FINALIZATION_BOUNDARY_2026-10-24.md`.

Implement original `smidr/session_transfer_pin.mojo`,one bounded host diagnostic,
one direct API consumer and scoped independent Python/kernel/fault oracles.
Zero old production/test edits. The owner must hold one movable SocSession and
one movable SealedTransferBacking. Reuse the existing original _PinnedPart,
_view,_map and canonical backing validation/group codec helpers;do not duplicate
fd sealer,program parser,map/UAPI dispatcher,session cleanup or external code.
The previous SealedTransferPin owns a separate fresh driver and cannot certify
that its maps belong to a session's file context. Resolve that concrete gap.

Validate the actual two sealed backing fds,full source bytes and canonical
metadata/program intent before opening a session or beginning any mapping.
Both bounded read-only/private views must be verified while CPU-owned before
the first map. Map both ordered USERPTR tuples through exactly that retained
session.driver whose descriptor lists/assigned channels are owned by the session.
No different-file handle,caller pointer,arbitrary driver or borrowed backing
entry point. Canonical group intent may be derived from the owned assigned H2D
channel/list and the two actual logical extents;it conveys no submission or
capacity authority and requires the live retained owner. Do not read a pointer
view after mapping starts. Preserve independent backing fds until all required
context finalization and view-release work has completed.

On any partial map/reply/connection fault,retain the actual views and backing
through the existing session's stop/join/close/list/file-context cleanup. This
slice adds no prepare,cancel,transfer,cache sync or numerical request. A session
cleanup exception after confirmed file close is distinct from uncertain file
finalization:only the latter permanently poisons and retains both VMAs/fds to
process exit. Never retry uncertain fd closes or possibly completed munmaps at
reused identifiers. Repeated close after ordinary cleanup is harmless;repeated
operations on a poisoned owner refuse. Destructor paths must not accidentally
close retained backing or unmap views after uncertainty. No source bytes or CPU
ownership are restored merely because a queue cancellation returned0.

Report context/file cleanup as that software event. The pinned void stop helper
logs idle timeout and file finalization discards remote-close status;the owner
must never label successful file close as all-failure hardware idle or remote
logical closure confirmation. Actual grouped in-flight DMA/late failure remains
a later gate. Existing historical map/RPC successes remain preserved observations.

Before code,reverify/copy actual711 Mojo/88 Python inputs,161 current qualified
controls and compiler identity from the new contract archive. Compute actual
import/consumer closure. Build ALL new/affected/auxiliary native consumers and
scoped original C/kernel/fault helpers before any acceptance. Select the existing
sealed-transfer pin/backing and session-finalization/unwind consumers needed by
the reused interfaces;run their unmodified host-only suites with required
auxiliary images. No physical branch of a combined suite may execute.
Freeze final actual source/test copies and linked images before acceptance;
preserve every failed build,test and audit. Compare full stdout/stderr/exit for
every invoked old/new/auxiliary consumer,with complete current/frozen fault state
where needed. No host mock is physical execution proof.

Independent actual-kernel observations must check both sealed fds/distinct
identities,read-only/private VMA permissions,logical versus page extents and
full bytes before mapping. Same-file mock provenance must bind the actual fd
generation to assigned descriptor/channel replies and both map tuples;reject
same numeric handles from a different file generation. Cover first/second map
pre-effect and post-effect failures,wrong map replies,session close errors before
and after effect,confirmed close with earlier cleanup errors,failed/unconfirmed
file close,view/backing close errors,moves/scope expiry,repeat calls and fresh
successful recovery after every refusal. Prove both actual VMAs/fds stay retained
on uncertain finalization;do not substitute logs or cached booleans for observed
kernel resources. Test no pointer read after first map,including failure paths.

Trace new consumers with actual PID/call/fd-generation joins;account for every
owned fd,VMA and cleanup order,including deliberate retained-until-exit cases.
Inspect each linked image for excluded runtimes. Preserve inherited warnings
with zero new-statement warnings. Publish the exact scope and limitations.

HOST ONLY:no real device open,descriptor/connect/map/unmap/prepare/launch/close
ioctl,server/program request,model download or inference. A later physical
contract must establish a safe typed non-inference control transaction,actual
returned counts/completions,total deadline and late cleanup. Do not arbitrarily
split a metadata/program transaction. No precompiled prerequisite,DFC,external
compiler/machine,CPU/CUDA/cloud LLM execution/proxy,reset/rebind,kernel/firmware
change or invented register/opcode. Numerical configuration,packing,placement,
program/results and broad remaining source/model support stay implementation
work toward ordinary UNMODIFIED model support100% on Hailo-10H.

Verify,publish Hailo,verify exact remote head/tree,lease fast-forward main,
verify clean checkouts,then automatically continue actual transport/numerical
work. This contract grants no native capability or physical execution claim.
