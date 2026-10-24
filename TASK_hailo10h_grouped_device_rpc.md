# Original typed grouped device lifecycle: host qualification contract

Date:2026-10-24. Publish before new code. Parent:
`TASK_hailo10h_program_delivery.md`. Owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. Broad ordinary UNMODIFIED
source-model support100% remains fixed. Generic grouped transport is host-qualified
at556b528480d6d81a52da82e321b56d5133193190 under
`docs/HAILO10H_MOJO_GROUP_CONTROL_RPC.md`;its synthetic action1 vectors do not
qualify a real server endpoint. Historical single-span physical RPC receipts in
`docs/HAILO10H_MOJO_NATIVE_RPC.md` are preserved,not reused as grouped acceptance.

Implement a new original HOST-MOCK typed lifecycle diagnostic/helper and direct
API/test support. Reuse the published SocGroupRpcClient and existing
`hailbru/hrpc_device.mojo` request/reply functions. Only already qualified
create20,identify22,destroy21 operations are in scope. Do not invent fields,
remote handles,opcodes or descriptor-count formulas. Preserve all old production/
test bodies. No model,program,action2/action17 or numerical request.

The new helper owns a fresh grouped client and derives every frame through the
existing typed functions. Track logical handle presence separately from its
UInt32 value;zero is valid. Mark a handle known only after a valid typed create
reply. Validate the typed identity and destroy reply using existing parsers;
mock identity values are synthetic,never a new physical profile observation.
Do not expose a caller-supplied remote handle or borrowed-session constructor.

Bound the lifecycle after session establishment by one monotonic total deadline,
including frame exchanges,typed parsing and any admitted logical cleanup. Each
exchange receives only the remaining budget through the published transport;
never renew it for a later phase. Check time before/after effectful/parse stages,
reject invalid/backward/late observations and cap budget at60000ms. A userspace
admission deadline does not preempt arbitrary synchronous kernel calls. Host
acceptance has an independent20-second private-process-group watchdog.

Normal success has exactly three correlated exchanges. Track destroy-attempted
before making that request. On failure,preserve the primary error. At most one
additional typed destroy may be attempted,only with an actually parsed known
handle,a healthy available transport,remaining overall budget,and no previous
destroy attempt. A poisoned exchange client is never reused. Do not retry a
possibly completed destroy or guess a handle after a corrupt/unknown create
reply. Report logical cleanup as unconfirmed whenever destruction lacks a valid
correlated typed success. Software file close is not remote logical destruction
or all-failure hardware idle proof. At most four exchange attempts are admitted.

Close/join the actual owning session through existing helpers after logical
cleanup decisions. Preserve uncertainty errors and real fd/VMA retention;never
free or retry a possibly reused fd after unconfirmed finalization. Successful
host mocks do not strengthen the public driver's void-stop/ignored-remote-close
limits documented in
`docs/HAILO10H_GROUP_SESSION_FINALIZATION_BOUNDARY_2026-10-24.md`.

Before code,reverify/copy actual718 Mojo/91 Python inputs,168 qualified current
controls,compiler and actual C/UAPI/schema/helper inputs in this contract archive.
Any new C seam may extend ONLY our original grouped-control oracle;copy inputs
before edits. Build exact actual new/affected/selected/auxiliary consumer closure
before acceptance;freeze final source/test/helper copies and all images. Reuse
public field definitions and independently generated protobuf/header oracles;
no external implementation or production protobuf dependency. Require zero
new-statement warnings and retain inherited diagnostics separately.

Host acceptance must independently compare complete request/reply bytes,handle
presence/identity and whole canonical grouped streams against test-only protobuf
oracles. Pair every invoked native and auxiliary stdout/stderr/exit triple with
its frozen image;new-image pairs are reproducibility checks. Regress the current
grouped client,old typed device codecs and actual affected session/worker/storage/
progress consumers. Trace all host children and join PID/TID/call/file generations;
observe actual CPU access protection,worker joins and owning-file/host release
or deliberate retention. Cover zero/nonzero/boundary handles,all three phases,
wire and typed-body faults before/after effects,malformed/unknown create handles,
late parsing/cleanup,poison refusal,uncertain close and fresh-owner recovery.
Inspect ELF separately;preserve every failed/superseded attempt.

HOST MOCKS ONLY:explicit mock roots,no physical default and no existing physical
RPC test invocation. No actual Hailo open/ioctl,IRQ/cache sync,prepare/cancel/DMA,
RPC packet,program activation,model load or numerical operation. A later bounded
physical grouped lifecycle requires these complete results,a fresh actual profile
and a separate cleanup/deadline/count/completion contract first.

Verify,publish Hailo,verify exact remote head/tree,lease fast-forward main and
verify both clean checkouts. Fetch shared refs sequentially. Then continue actual
physical/numerical encoding,configuration,packing,placement,original program/
results and all remaining formats/architectures/operations toward the same broad
target. No DFC,outside compiler/machine,vendor-precompiled prerequisite,CPU/CUDA/
cloud LLM inference or proxy. Hailo-10H owns all eventual LLM execution.
