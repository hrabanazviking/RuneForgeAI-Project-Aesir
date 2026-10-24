# Observed grouped launch counts and bounded exchange progress

Date:2026-10-24. Publish before implementation. Parent:
`TASK_hailo10h_program_delivery.md`. Fixed owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. This is a host-only transport
prerequisite for the future same-file grouped control-RPC owner,not a device
submission,descriptor-capacity prediction or source-model execution slice.

Read the native RPC,grouped physical boundary and prepared-driver boundary
receipts first. The prepare ioctl returns queue status,not descriptor count.
Launch returns descriptor count;IRQ records count completed transfers,not
individual descriptors. Preserve these distinct meanings. No formula using
bytes,pages or number of spans may predict grouped counts.

Permit one existing production edit:`hailbru/soc_progress.mojo`. Add a distinct
constructor for observed per-direction counts bounded by the caller's actual
allocated ring capacities. Keep its legacy three-argument exact-count policy
and existing IRQ parser/state transitions. Store separately the actual positive
input/output launch returns;counts may differ. Capacities must be powers of two
in[2,65536],and each returned count must be below its own capacity. These checks
only bound a returned result;they never certify enough capacity before launch.
Do not duplicate/replace the canonical IRQ decoder or invent a count. No old
RPC consumer changes or physical execution are permitted by this slice.

Add original `hailbru/soc_exchange_progress.mojo`,one bounded host inspector,
one direct API consumer and independent Python tests. The wrapper owns one
outstanding D2H-before-H2D pair and the observed-count progress. Validate
nonnegative monotonic start,timeouts1..60000ms,overflow-safe absolute deadline,
nondecreasing event timestamps and snapshot budget1..32. Admission/remaining,
launch returns and complete IRQ snapshots must be strictly before the total
deadline;late terminal replies refuse. A snapshot consumes one budget entry,
even if it makes zero progress;the final permitted snapshot may complete.
Inspectors never acquire a real clock or driver. Supplied timestamps are test
values and are not physical timing evidence.

A refused admitted event poisons the wrapper permanently;no subsequent call
may revive it or authorize storage release. Invalid IRQ batches cannot commit
partial completion. Completion requires both launch returns and both distinct
transfer completions within deadline/budget. The wrapper has no backing,fd,
DMA,cleanup or quiescence authority. A completion flag is host accounting only.
Do not misrepresent prepared cancellation as active-DMA quiescence.

Before code,freeze actual708 Mojo/87 Python inputs,158 current qualified
controls,compiler identity and pre-edit progress/RPC executable links. Build
all actual affected and auxiliary native consumers before any acceptance:
legacy progress,RPC device (link-only),new inspector and direct API. Compute
actual import closure;no source edits beyond the one permitted module and new
files. Freeze final sources and binaries before running tests. Scope inherited
warnings and preserve every failed build/test/audit. Compare full stdout,
stderr and exit for every invoked old/new frozen consumer;physical RPC is never
invoked. Run the unmodified legacy progress suite against old/final images.

Independent Python state/IRQ oracles cover unequal launch counts,all channel
pairs,capacity/count edges,negative/zero returns,launch ordering/duplicates,
both completion orders,combined/empty/zero IRQs,all record count bytes,unowned/
error/inactive/duplicate/noncanonical-header/length inputs. Cover every deadline
edge,clock reversal/overflow,late final snapshot and exact exhaustion of32
zero-progress wakes. Direct API tests exercise poison persistence,atomic IRQ
refusal,recovery via a fresh owner and ordinary moves/scope expiry. Numeric,
hex and argument counts must be bounded before parsing/allocation. All refused
inspector cases are followed by fresh success. Trace new consumers,join actual
calls/PIDs and account for file/VM effects;inspect linked images separately.

No device open/ioctl,mapping,cache sync,prepare/cancel/launch,channel/server
request,program/model download or numerical execution. Same-file resource
ownership and bounded physical control RPC require the next separate contract
and host fault/lifetime qualification. Actual numerical configuration,packing,
placement,activation and hardware results remain required under broad ordinary
UNMODIFIED source-model support100%. No DFC,outside compiler/machine,precompiled
prerequisite,CPU/CUDA/cloud LLM execution/proxy,invented opcode/register,
reset/rebind or kernel/firmware change.

Verify,publish Hailo,verify exact remote head/tree,lease fast-forward main,
verify clean checkouts,then automatically continue same-file owner and actual
numerical/physical gaps. No whole-repository or hosted-CI pass is implied.
