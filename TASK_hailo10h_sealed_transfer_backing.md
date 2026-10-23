# Owned sealed backing for metadata plus separate program bytes

Date:2026-10-23. Publish before implementation. Parent:
`TASK_hailo10h_program_delivery.md`. Fixed broad owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Concrete transport preparation gap

Original sealed output owns immutable program bytes but retains canonical2068-
byte RPC metadata in a copied list. The matching sender/receiver boundary requires
metadata plus a separate exact program phase;it does not authorize an isolated
action2 message or arbitrary chunking. The actual pin probe194b959 establishes
bounded read-only/private H2D mapping compatibility for sealed program fixtures,
not transaction delivery. Corrected session finalizationafa6d08 refuses uncertain
close and retains backing;it does not provide grouped storage or descriptor proof.

Add original immutable backing for that ordered two-part byte transaction.
Retain a moved existing SealedProgramPayload and independently own an anonymous
sealed2068-byte metadata file. Reuse full original program/request/integrity/
canonical metadata validators and the already qualified memfd/fcntl/positional
I/O/regular extent/CLOEXEC/close helpers. No external algorithm or new raw OS
interface. Only new production modules/diagnostics/scoped tests;no existing
production or test edits in this slice.

Construction must validate the actual source owner and complete wire intent
before allocating metadata storage. Copy all metadata bytes,handle bounded
independent positional write/read attempts and exact progress,seal the file,
check actual same-fd flags/extent/seals,and compare the full readback to the
fresh canonical metadata. Retain both actual owners across moves and partial
construction. Explicit close invalidates descriptors before reporting failures,
continues closing independent host owners and preserves combined errors;no
uncertain fd retry. There is no in-flight device state in this host-only owner.

Bounded metadata/program windows return independent owned copies. Before any
access,revalidate consumed mutable owner/request fields,the actual program and
its full integrity,metadata seals/extent/CLOEXEC and all2068 actual metadata
bytes against freshly canonical metadata. Do not trust cached flags,counts or
the mutable copied metadata list. Signed bounds and work limits are checked
before allocation. Zero/end windows must not bypass validation. Returned copies
survive owner moves,closure and scope expiry. No scalar pointer is dereferenced
and no caller-controlled address,device handle or ioctl is accepted.

This proves immutable bytes in the actual retained sealed objects,not historical
global artifact identity or coherence between independently substituted valid
objects. A valid outer program still does not admit opaque protobuf/CCWs as
numerical instructions. Broad remaining formats/architectures/operations and
physical encoding remain required work rather than permanent eligibility limits.

## Exact acceptance gates

Before code,freshly verify/copy actual692 Mojo/82 Python inputs,148 frozen
controls and the pinned compiler. Supplement missing old controls before edits.
Build every new actual consumer and selected original sealed-output,payload,
integrity/group/ABI and corrected session lifetime controls. Freeze all links
before acceptance;scope inherited warnings and pair every invoked frozen
consumer with complete stdout/stderr/exit. Preserve all failed attempts and
actual source/test/control copies;never overwrite earlier pinned recipes/caches.

Independent Python struct/public RPC-schema and pinned test-only XXH3 oracles
must compare complete metadata/program/window bytes,including odd/page/large
fixture extents,UTF8/limits and corrupt program/metadata/request/field refusals.
An installed-header C/kernel oracle must inspect the actual owned metadata file,
all2068 bytes,seals/CLOEXEC and write/grow/shrink/shared-write refusals. Keep
software-license/provenance checks before external test declarations/libraries;
no external implementation is adopted in production.

Direct API/fault tests cover partial construction,independent I/O budgets,
short/EINTR/zero/oversized progress,missing seals,wrong extent/flags,actual
readback corruption,close before/after effect,moves/default/closed owners,
all consumed mutable fields and fresh-state recovery. Restore deliberately
forged descriptors before destruction. Trace every new child,reconstruct actual
memfd lifetimes by PID across interrupted calls,and account for every acquisition
and release. Separate ELF dependency/symbol evidence from behavior. No whole-
repository or hosted-CI success is inferred from selected passing tests.

No mapping,pinning,cache sync,driver open,ioctl,descriptor/channel/connection,
transfer,action2/server/program request,model evaluation or numerical operation
is authorized by this host slice. Do not run real storage/wait/RPC consumers.
Only their separately scoped host controls may run. Actual grouped descriptor
accounting,completion,total deadlines/cancellation/late cleanup and numerical
admission remain mandatory before physical program delivery.

Verify,commit/publish Hailo,verify exact remote head/tree,lease fast-forward main,
verify clean checkouts,then automatically continue original grouped physical
storage/descriptor/deadline and actual numerical configuration/program/results.
All eventual LLM execution stays Hailo-10H. No DFC,outside compiler/machine,
precompiled prerequisite,host/CUDA/cloud forward/proxy,guessed opcode/write,
reset/rebind or kernel/firmware change. Broad ordinary UNMODIFIED source-model
support remains100% the target;host metadata/storage never counts as execution.
