# Original grouped control-frame transport: host qualification

Date:2026-10-24. Capability:AES-CONTROL-014. Pre-code contract:
`TASK_hailo10h_grouped_control_rpc.md`,published
5af009a6ad9ab1fc32fb3b8c567240309cf2cb16. Fixed target:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. This report qualifies host behavior,
not physical grouped DMA or numerical source-model execution.

## Original implementation

`hailbru/soc_group_rpc.mojo` retains a fresh SocSession and its two original
SocRpcStorage allocations. It reuses existing group/scalar/frame codecs,
SocExchangeProgress,blocking IRQ worker and cleanup interfaces. The input group
contains exactly the existing20-byte header and2048-byte padded body,as two
ordered spans of the SAME2068-byte mapped input storage. They are not separate
sealed files or independent mappings. No arbitrary pointer,fd,list,borrowed
session or caller-supplied group constructor is provided. Captured assignments
and storage tuples are checked before effects;copied group values confer no
submission or lifetime authority. Internal session fields are not a supported
caller-mutable handle interface.

One D2H posting precedes one direct H2D group per exchange. The owner submits no
prepared queue/cancel operation and adopts no external descriptor/count algorithm.
It retains actual directional returns,admits only positive counts below allocated
ring bounds,and separately correlates IRQ transfer completions. Asymmetric return
values are allowed. Tests inject these counts;no physical descriptor usage or
capacity follows from them.

One monotonic deadline starts before frame preparation and covers preflight
sync,write,posting,group launch,all waits,post-wait sync/read and reply validation.
Checks occur around effects and after the final validation. Late/backward events
or exhausted snapshots refuse admission. Synchronous calls may return after a
deadline;the clock checks reject that result. This is not arbitrary-syscall
preemption or a physical hard-latency guarantee. IRQ waiting uses the existing
bounded native worker and cancellation/join owner.

Transfer retention is armed before launch. CPU access uses existing explicit
ownership/completion/sync gates. A failed exchange permanently poisons the client;
reuse refuses and recovery requires a fresh owner. Original errors remain visible
through cleanup. Unconfirmed file finalization retains actual VMAs and never
retries a potentially reused fd. Existing session cleanup order is preserved.
Successful file close is software context finalization,not all-failure hardware
idle or remote logical cleanup confirmation. The public-driver limits in
`HAILO10H_GROUP_SESSION_FINALIZATION_BOUNDARY_2026-10-24.md` still apply.

The new bounded diagnostic is explicitly HOST-MOCK only with no physical-root
default. Synthetic action1 frames test transport bytes;they are not asserted to
be valid server operations. The old RPC client remains unchanged and runs only
argument-refusal paths in selected regression. Existing typed device-message
codecs are independently regressed;new grouped typed lifecycle integration and
any physical exchange remain subsequent work.

## Accepted native scope

Nine suites/**78 methods** pass,with **4737 primary and full frozen stdout/stderr/
exit comparisons**:2589 accept,2148 refuse,9474 full result triples. New/auxiliary
image comparisons are frozen-image reproducibility checks,not pre-existing
implementation proof. The eight selected unchanged suites contribute68 methods/
4450 comparisons,including14 comparisons involving retained historical images.
Two of these intentionally demonstrate the known close gap;they do not certify
corrected behavior in that old image.

The new ten-method suite contributes287 full current/frozen pairs and574 complete
traces. Each pair also compares the complete normalized mock fault-event state;
actual addresses/PIDs/TIDs are independently joined to kernel observations.
Coverage includes empty/boundary/maximum bodies,three sequential exchanges,
asymmetric/count-limit returns,sync and launch errors before/after effects,
malformed/foreign/partial/duplicate IRQs,snapshot exhaustion,reply faults,
clock errors/backward/late observations at every observed clock position,
partial construction,cleanup failures,moves,scope expiry,copy/assignment guards,
permanent poison and fresh-owner recovery. Six invalid preflight cases each have
a fresh same-process recovery. Combined effectful failures and uncertain closes
retain both real allocations;normal independent recovery runs follow separately.

The original C seam uses harmless actual `/dev/null` files and independent packed
header declarations. It validates owning generations,assigned lists/channels and
all group fields/unused storage. Python independently checks complete canonical
request bytes. Actual VMAs are protected with PROT_NONE during device-owned
phases to detect premature CPU access. Mock receive writes temporarily change
permissions only inside the test seam. A stalled mock IRQ exercises the real
pthread cancellation/join path. The seam supplies synthetic clock observations;
cleanup after that deliberate stall uses real clock values for its join grace.
No external queue,descriptor programming or launch algorithm is adopted.

For the **current image** (the frozen image independently matches):

-354 actual IRQ workers all exit before their owning context-close attempt.
-33761 observed file-fd generations,33754 closes and7 deliberately retained mock
  driver fds are fully accounted for. These are OS fds,not DMA descriptors.
-379 actual mock files open;372 close.675 launch effects are MOCKED,not Hailo DMA.
-742 actual owned VMAs have712 exact unmaps. Fourteen uncertain-close contexts
  retain both VMAs (28 total);two independent host-unmap failures retain one each.
  All host release follows its own confirmed file close. After-effect close errors
  can leave retained VMAs even though the actual mock fd already closed.
-2702 actual protection changes include1375 PROT_NONE transitions.332 complete
  synthetic wire packets match independent expected bytes.

All new trace calls/PIDs/TIDs are classified and joined. All mock ioctl codes
match independent public-header oracle output;prepare/cancel and unknown calls
are excluded. There is no actual Hailo open/ioctl,network connection,DMA,RPC packet,
program activation,model load or numerical operation. Old native worker controls
use private host pipes. No excluded inference runtime is linked.

## Inputs,builds and retained failures

Fresh pre-code actual inputs:715 Mojo/90 Python tests,164 controls,833 contract
archive paths and pinned compiler/UAPI/helper copies. Final inputs:718/91.
Zero old production or test files changed. The actual new executable closure
contains only the diagnostic and direct API consumer. All19 selected Mojo and4
C/C++ helpers link before final acceptance;46 ELF tables precede execution.
Zero warnings occur on new statements;inherited diagnostics remain scoped.
Compiler SHA-256:
`be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39`.

The first build retained an explicit test-consumer Int conversion error,C oracle
include/field-name/indentation errors and new unused-loop warnings. The second
build linked but its remaining API unused-loop warning blocked acceptance. The
third full build passed the warning gate;its first eight-method run had one
failure because the API diagnostic parsed `-1` as unsigned before invoking the
exchange. The signed parser correction and added scope/preflight/TID/stall checks
were fully rebuilt. A fifth full build added independent combined-close faults;
all ten new methods and all selected regressions pass. Production behavior did
not change during those oracle/API refinements after the unused-loop rename.

A separate progress reader hit an in-progress JSON write;that tool observation
is explicitly transcribed,not presented as raw native stderr. It did not alter
or repeat an acceptance run. Both the initial and stronger successful audits
are preserved. Every failed/superseded source copy,build,run and diagnostic remains.

`evidence/group-control-rpc-native-2026-10-24/archive-identities.json` pins
**37093 paths/853976464 aggregate bytes**,in5 pages across13 immutable raw roots.
Manifest SHA-256:
`132a8c355c2917792dcd76e3bb2a331cb549512ba3cbbf43c4f742e40ad2dc74`.
Review copies normalize paths;exact executed scripts are pinned. Publication
review runs outside these raw roots.

Census becomes145 verified/190 total,29 partial,15 missing and one historical
noncanonical status. Nine inherited ledger schema diagnostics and23757 drift
findings remain;no whole-repository or hosted-CI pass is claimed.

Continue typed non-inference grouped control lifecycle/cleanup qualification,
then separately bounded physical acceptance. Actual numerical configuration,
packing,placement,original program delivery/results and remaining formats,
architectures and operations remain implementation work toward broad ordinary
UNMODIFIED source-model support100%. Aesir owns its Mojo loading/conversion/
lowering/device generation;all eventual LLM execution stays Hailo-10H. No DFC,
outside compiler/machine,vendor-precompiled prerequisite,host/CUDA/cloud inference
or proxy is introduced. No numerical source-model execution is claimed.
