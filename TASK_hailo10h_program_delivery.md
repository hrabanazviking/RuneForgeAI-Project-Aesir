> **Controlling owner clarification — 2026-10-20:** broad model support,
> ordinary model files, Aesir-owned internal Mojo translation, no outside model
> compiler or specially compiled artifact prerequisite. See
> `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

# Original program delivery and activation boundary

Date: 2026-10-20. Contract before continued study/implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Consumer: the original SMIÐR program builder and HAILBRÚ device owner, toward
the fixed source-model-to-Hailo-10H objective. Source constant readers and
mathematical IR now have independent host evidence; actual numerical program
encoding and delivery remain open. Investigate these backend dependencies
directly without treating constant-format coverage as device execution.

Read existing public-context/server/driver receipts first. Under the existing
license-first, pinned-source, interface-facts-only discipline, trace the host
driver, integrated-device path and server dispatch to determine which endpoint
can accept an Aesir-generated program and how activation/lifecycle work. Name
every missing program structure, topology/register/CCW fact and privilege or
device-environment distinction. Seek public hardware/configuration facts as
needed, checking licenses before source bodies. Do not copy/translate external
implementations or extract vendor compiled-model contents.

Acceptance for each research slice: pinned provenance, explicit caller → wire
or ioctl → receiver → operation mapping, exact supported/unsupported facts,
and a concrete next original implementation or narrower evidence experiment.
Implement bounded host codecs only after real field definitions are published;
test with independent public-header/byte oracles. No invented register/opcode,
arbitrary device write, guessed request, reset/rebind/firmware/kernel change,
model download or CPU/CUDA/cloud/proxy inference is authorized by this study.
Physical requests require a separately established safe typed endpoint and
bounded cleanup contract. Preserve historical and concurrent work.

The goal remains Mojo-owned compilation/execution for source models fitting
Hailo-10H, with all LLM execution on that hardware. A compiled container format
may be a required output of our compiler; that fact would not authorize a
vendor-catalog-only product or replacing original program generation with
borrowed numerical programs. Report unsolved gaps honestly, publish verified
slices, and advance automatically toward the unchanged owner objective.

2026-10-23 separate payload qualification:
`docs/HAILO10H_PROGRAM_PAYLOAD_BOUNDARY_2026-10-23.md` distinguishes full2068-byte
metadata from the exact separate program buffer and the grouped request/read
boundary. Original owned staging follows `TASK_hailo10h_program_payload_staging.md`;
no arbitrary chunking,live payload transfer or numerical execution follows.

Original owned payload staging is now verified under
`docs/HAILO10H_MOJO_PROGRAM_PAYLOAD.md`:43 selected methods and2495 complete
frozen comparisons. This supplies copied byte preparation,not DMA submission or
immutable/executable identity. Continue grouped-buffer driver constraints,sealed
output,in-flight ownership/deadlines/cleanup and actual numerical program work.

Next grouped USERPTR wire gap is qualified in
`docs/HAILO10H_GROUPED_TRANSFER_BOUNDARY_2026-10-23.md`:actual header objects
establish8 entries and141-byte layout;existing original codec emits one entry.
Original codec contract:`TASK_hailo10h_soc_group_codec.md`. No production group
implementation,physical DMA or numerical execution is claimed by that contract.


Original grouped USERPTR value codec is now verified under
`docs/HAILO10H_MOJO_SOC_GROUP.md`:20 selected methods,218 complete frozen pairs
and1609 new traces. This supersedes only the preceding no-production-code status.
Actual descriptor accounting,owned immutable output and in-flight DMA/deadline/
cleanup qualification remain required before physical metadata/program delivery.


Next qualified physical-interface frontier:
`docs/HAILO10H_GROUPED_PHYSICAL_BOUNDARY_2026-10-23.md`;public size-based channel
readiness is explicitly unsuitable as descriptor accounting. No grouped formula
or physical submission is qualified. Continue original sealed output ownership
under pre-code `TASK_hailo10h_sealed_program_payload.md`,then actual descriptor/
pinning/deadline/cleanup and numerical program work. No external algorithm adopted.


Original sealed program output ownership is now verified under
`docs/HAILO10H_MOJO_SEALED_PROGRAM_PAYLOAD.md`:38 selected methods,2842 complete
frozen pairs and2326 balanced memfds. Exact sealed bytes are available to future
owned transport;pinning compatibility,grouped descriptor accounting,in-flight
lifetime/deadlines/late cleanup and actual numerical program work remain open.


Next bounded physical qualification:
`TASK_hailo10h_sealed_program_pin_probe.md`,with boundary facts in
`docs/HAILO10H_SEALED_PROGRAM_PIN_BOUNDARY_2026-10-23.md`. Establish actual
read-only/private versus writable/private H2D mapping compatibility of sealed
backing using only existing typed map/unmap and known cleanup. No transfer,
channel/server/program request or numerical operation is permitted by this probe.

The bounded probe is complete under
`docs/HAILO10H_MOJO_SEALED_PROGRAM_PIN_PROBE.md`:all13 physical map/unmap cases
pass,including all six sealed variants. Read-only/private H2D USERPTR acceptance
is now observed for the tested profile;DMA/coherence,grouped descriptor counts,
in-flight ownership/deadlines/late cleanup and numerical execution remain open.
Use these actual results for the next original grouped storage contract.

Before reusing existing session cleanup,resolve its concrete close-error gap
under`TASK_hailo10h_session_finalization.md`:the current code marks storage
finalized after a close exception. This new host-only contract preserves backing
and poisons uncertain sessions;it authorizes no real device request. Continue
grouped storage/descriptor/deadline and numerical program work after publication.

The scoped close-error correction is verified under
`docs/HAILO10H_MOJO_SESSION_FINALIZATION.md`:18 selected methods,210 full frozen
pairs and permanent retention/refusal on unconfirmed finalization. This closes
the tested host lifetime gap only. Physical grouped descriptor/DMA/deadline/late
cleanup and numerical source-model execution remain required implementation work.

Next original grouped preparation contract:
`TASK_hailo10h_sealed_transfer_backing.md`. Own sealed canonical2068-byte metadata
alongside the retained sealed program,using existing interfaces and independent
full-byte oracles. This host-only slice permits no device request or transfer;
actual grouped descriptors/deadlines and numerical configuration/results remain
open under the same broad target.

That host backing slice is now verified under
`docs/HAILO10H_MOJO_SEALED_TRANSFER_BACKING.md`:57 methods/4699 full frozen
comparisons and independent actual metadata kernel checks. Both ordered parts
retain sealed host bytes;physical grouped storage/descriptors/completion/total
deadlines/late cleanup and actual numerical program/results remain open.

Next original two-part pin ownership contract:
`TASK_hailo10h_sealed_transfer_pin.md`. Actual702/85 inputs and154 current controls
are frozen before code;the closed composition probe is never executed. Host
fault/cleanup qualification precedes a separately bounded two-buffer map-only
batch. No descriptor count,DMA,numerical admission or execution is inferred.

That original ownership slice is verified under
`docs/HAILO10H_MOJO_SEALED_TRANSFER_PIN.md`:both actual sealed parts map/unmap on
one fresh owning driver;7 physical children,10 maps/unmaps,69 selected methods
and4976 complete frozen pairs. No descriptor capacity,DMA/coherence,original
program activation or numerical result is inferred. Continue those actual gaps.

Next bounded wire prerequisite:`TASK_hailo10h_soc_prepare_codec.md`,qualified in
`docs/HAILO10H_PREPARE_INTERFACE_2026-10-24.md`. The139-byte prepare and8-byte
cancellation objects have17 independent public-header probes. Their original
host codec introduces no device operation or descriptor-count/capacity proof.
Actual numerical and grouped transport/result work remains open.

That bounded codec is verified under`docs/HAILO10H_MOJO_SOC_PREPARE.md`:
25 methods/2763 complete frozen comparisons,zero old production/test edits.
This supplies original139/8-byte intent only. Actual preparation side effects,
descriptor counts,active cancellation and numerical program execution remain open.

Read-only driver qualification continues in
`docs/HAILO10H_PREPARE_DRIVER_BOUNDARY_2026-10-24.md`:live/file build IDs and
source-version strings agree;all37 C/header files in each installed source tree
match the pinned public revision. Selected preparation effects include buffer
ownership/sync and prepared-queue insertion status;active DMA cancellation is
not established. No device call,new native capability or count formula follows.
Next original same-file group/control-RPC work needs its own bounded contract.

Next original progress prerequisite:`TASK_hailo10h_observed_group_progress.md`.
Separate actual per-direction launch returns from IRQ transfer completion and
bound all admitted events by one total deadline. Host-only qualification must
precede same-file ownership or any live grouped control-RPC request.

That host progress prerequisite is verified under
`docs/HAILO10H_MOJO_OBSERVED_GROUP_PROGRESS.md`:15 methods/1928 complete frozen
comparisons,including44 legacy pre-edit observations. Actual same-file sealed
ownership,host fault/late cleanup and physical grouped control RPC remain open;
no capacity prediction or numerical source-model execution is inferred.

Next bounded cleanup qualification:
`docs/HAILO10H_GROUP_SESSION_FINALIZATION_BOUNDARY_2026-10-24.md`. File-context
cleanup order is public,but the void stop helper logs idle timeout and file
finalization drops remote-close status. No all-failure hardware quiescence or
remote-cleanup confirmation follows. Original same-file map-only host owner
follows`TASK_hailo10h_session_transfer_pin.md`;no physical request is authorized.

That original same-file owner is host-qualified under
`docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN.md`:76 methods/5554 complete frozen
comparisons,zero old production/test edits. No physical request or all-failure
hardware/remote cleanup confirmation follows. Next separately bounded physical
map-only session qualification precedes live grouped transfer/numerical work.
