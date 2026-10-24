# Same-file sealed session ownership: host qualification

Date:2026-10-24. Pre-code contract:`TASK_hailo10h_session_transfer_pin.md`,
published4fd644d3756e71063949bd86f3db6e29dc14a30d. Capability:AES-CONTROL-012.
Fixed target:`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Original implementation

`smidr/session_transfer_pin.mojo` owns one movable SocSession and one movable
SealedTransferBacking. Both actual sealed fds and full canonical bytes are
validated before session open. Both bounded read-only/private views are checked
before the first mapping. The existing original _PinnedPart,_view,_map,backing
validation,session cleanup and group codec are reused. No existing production
or test file changed and no external implementation was copied/translated.

Both H2D map tuples pass through the retained session's own driver,the same file
that owns its descriptor lists and assigned channels. Group intent is derived
from those captured assignments and the two actual owned logical extents.
Changed session/tuple fields refuse;no caller pointer,foreign driver or borrowed
backing constructor is provided. This is value intent,not submission/capacity
or standalone lifetime authority. A finalized/poisoned owner exposes no live
group. The diagnostic is host-mock only and is not a physical probe command.

Partial map/reply/construction errors keep both views and backing through the
existing session's cleanup. Extra mappings remain attached until whole-file
finalization. Earlier cleanup errors remain visible after independently confirmed
file close;they do not falsely poison the owner. Uncertain file close permanently
poisons it,retains both actual VMAs/fds to process exit,and never retries a close
at a potentially reused fd. View-release errors likewise never retry a possibly
completed munmap. Ordinary close is repeatable;views precede backing release.

A helper that fails before returning its session cannot expose its state fields.
The wrapper uses the existing named driver-fd-close/unconfirmed-finalization
error markers to retain resources on that path. Generic cleanup errors alone
are not treated as close uncertainty;the partial-construction fault test covers
that distinction. This is the current original helper interface contract.

Confirmed file-context cleanup is a software event. It is not renamed hardware
idle or remote logical closure confirmation. The pinned driver's void stop helper
can log an idle timeout and its file finalizer discards remote-close status;
see`HAILO10H_GROUP_SESSION_FINALIZATION_BOUNDARY_2026-10-24.md`.

## Accepted scope

Ten selected suites/**76 methods** pass,with **5554 primary calls and complete
stdout/stderr/exit comparisons**:3740 accept,1814 refuse,11108 full result triples.
Every invoked owned/historical/auxiliary consumer is paired,including test
oracles. The101 new-image comparisons are frozen-image reproducibility checks;
they are not evidence of a pre-existing implementation. Remaining comparisons
exercise selected unchanged consumers and their qualified test support.

The new seven-method suite uses101 native child calls,with44 individually joined
refusal/poison-to-fresh-success cases. Direct API checks add22 guarded recovery
cycles,each followed by fresh owner construction,and eight poisoned reuse
refusals across two uncertain-close cases. Full metadata/program bytes match
independent Python/protobuf/hash expectations. The protobuf compiler and hash
library are isolated test oracles and are absent from production linkage.

The original test-only driver seam binds actual file-fd generations to assigned
channel/descriptor replies and both map tuples. Foreign-generation handle cases
refuse in the mock. They are driver-interface fault tests,not physical lookup
proof. Coverage includes map errors before/after effects,wrong tuples/handles,
partial session construction,cleanup errors after confirmed close,uncertain
close before/after effects,moves/scope expiry/repeat close and independent
host munmap/backing-close errors. No inference or numerical oracle is invoked.

**Current and frozen traces are both audited:101 each.** For the current runs:

-225 actual read-only/private views compare261866 bytes with sealed files.
  Kernel seals,CLOEXEC,distinct inodes,logical sizes and VMA permissions are
  checked independently.258 actual sealed fds are created and240 close.
-204 owned views become PROT_NONE before the first mock mapping. Successful
  normal/failure/recovery execution thereafter detects forbidden CPU pointer
  reads. The246 descriptor reads after confirmed context close use pread.
-111 actual harmless mock files open and107 close.192 mapping effects are
  **mocked**,not device mappings. File-generation tracking handles repeated
  numeric fd reuse during the direct API's successive sessions.
-7292 observed file-fd generations and7270 closes are accounted for. The22
  deliberate survivors are18 sealed fds and4 uncertain mock-driver fds.
  These are file descriptors,not hardware DMA descriptor counts.
-225 owned VMAs have207 observed unmaps. Eight uncertainty cases retain both
  actual sealed fds and both actual VMAs,independently confirmed through kernel
  fd/mincore observations at exit. Separate host-close/unmap failures account
  for two additional sealed fds and two additional VMAs retained until exit.

Frozen runs independently meet the same resource observations. All new trace
lines/PIDs/calls are classified and joined;owned cleanup follows its actual file
close. There is no real Hailo open/ioctl,network connection,prepare/cancel/
transfer/cache-sync request,program activation or source-model execution.
Existing RPC consumers run only their argument-refusal paths in host regression;
no physical client exchange is invoked.

## Inputs,builds and retained failures

Fresh pre-code inputs:711 Mojo/88 Python tests,161 qualified controls,827 contract
archive paths and the pinned compiler. Final inputs:714 Mojo/89 Python tests.
Actual new executable closure is only the new diagnostic and direct API consumer.
All23 selected Mojo images and10 original C/C++ test helpers link before final
acceptance,with66 ELF tables and zero new-statement warnings. Inherited ABI/
session/storage warnings are recorded separately. No excluded inference/hash/
protobuf runtime is linked. Compiler SHA-256:
`be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39`.

The first new suite had6 failures across7 methods because the exit oracle also
logged the preload-bearing tracer process. Its complete inputs/results remain.
The first correction script asserted before writing;a shell without set-e still
started an unused second build with unchanged inputs. This tool observation is
explicitly transcribed,not presented as saved raw stderr. The corrected oracle
logs only processes that observed an owner and includes actual event PIDs.
A third full build/76-method run passed. A final API tightening then constructed
a fresh owner after every tuple refusal;all images were rebuilt and all76 methods
passed again. Production code did not change during these oracle/API refinements.
No failed or superseded build,test or audit is discarded.

`evidence/session-transfer-pin-native-2026-10-24/archive-identities.json` pins
**57948 paths/333236188 aggregate bytes**,in8 pages,covering all11 immutable raw
roots. Manifest SHA-256:
`7a97c372c714e87e4428348db361d90c1a7659048b4a5b2c05c578de48503c0e`.
Review copies retain normalized source/build locations;exact raw inputs and
scripts remain pinned. Publication review runs outside these raw roots.

This closes a host ownership gap. A separately contracted physical map-only
session qualification must precede live grouped control transfer. Actual grouped
counts/completion,total deadlines/late cleanup,numerical configuration,packing,
placement,original program activation/results and remaining format/architecture/
operation support remain required work. Broad ordinary UNMODIFIED model support
remains100% the owner's target. All eventual LLM execution stays Hailo-10H;
DFC,external compiler/machine,precompiled prerequisites and host/CUDA/cloud
inference/proxies remain excluded. No source-model numerical execution is claimed.

Publication review rehashed all57948 raw paths,161 controls,the compiler and
actual source/test/C inputs. Nine inherited schema diagnostics and23757 drift
findings are unchanged,with no new drift finding. Census is143 verified/188 total
(29 partial,15 missing and one historical noncanonical status). No whole-repository
or hosted-CI pass is claimed.
