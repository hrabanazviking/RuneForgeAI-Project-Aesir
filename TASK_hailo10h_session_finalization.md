# Preserve RPC storage when driver finalization is unconfirmed

Date:2026-10-23. Publish before production edits. Parent:
`TASK_hailo10h_program_delivery.md`. Fixed broad scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Concrete original transport gap

After publishing the sealed mapping receipt194b959,inspection of original
`SocSession.close` finds that a driver close error is appended to failures but
both storage owners are then marked context_finalized and released. Existing
historical physical storage tests did not inject driver-close uncertainty.
`SocDriver.close` invalidates its fd before raising;therefore a negative return
does not establish whether the original context finalized. The bounded new pin
diagnostic already treats this state conservatively. Reusing the old session
cleanup for grouped output must first resolve this concrete gap.

Implement the smallest original session fix preserving both existing RPC storage
owners on uncertain file finalization. Explicitly poison that session against
reuse/repeated cleanup which might release retained backing or close a reused
descriptor. Arm retention even when earlier explicit unmaps completed;report
uncertainty consistently rather than guessing from an error. Preserve earlier
channel/list/unmap errors alongside the close failure. Successful close retains
all existing output and lifecycle behavior. No new OS interface,driver operation,
vendor implementation or unrelated runtime integration.

Only `hailbru/soc_session.mojo` may change among existing production files.
Add original isolated API/fault tests and bounded host diagnostic as necessary;
no existing tests are edited. Do not modify sealed-program pin evidence or other
archived inputs. Public structs may define isolated test oracles after their
retained license/provenance is checked;no external cleanup algorithm is adopted.

## Qualification and exact evidence boundaries

Actual691 Mojo/81 Python inputs and141 existing controls are copied/rehashed
before production. The actual import graph finds seven existing executable
consumers of SocSession. Freeze supplementary old controls before code where any
are missing. Build every affected consumer plus selected original ABI/storage/
driver controls;record inherited warnings. Freeze final links before acceptance.

Independent host-only seams must distinguish raw SYS_close from libc close and
use real harmless host files behind exact synthetic sysfs/device fixtures.
No seam opens Hailo. Mock all old session ioctl structs through the pinned public
UAPI,assert no unexpected operation,and clearly label these observations as
mock evidence. Exercise close before effect and close after actual effect,
including prior uncertain map/unmap/channel close and descriptor-release errors.
Retain VMAs on both cases,refuse CPU access/release/reuse after poisoning,and
verify no close retry or munmap after unconfirmed finalization. Attempt every
partial construction and fresh-state recovery. Include normal repeated close,
exception unwind,moves,pending-storage ownership and complete normal outputs.

Trace new native children with PID-specific unfinished/resumed reconstruction.
Compare acquisitions to actual lifetime-scoped close/unmap,including address/fd
reuse. Deliberate retention until exit must not be falsely counted as explicit
balanced cleanup. Pair every invoked frozen consumer with full stdout/stderr/
exit;normal outcomes must match,while the corrected uncertain-close behavior is
an intentional stricter refusal documented separately. Never run old physical
storage/wait/RPC tests against the real device under this host contract.

This slice authorizes no physical driver call,cache sync,DMA launch,connection,
server/program request,numerical operation or model evaluation. Actual physical
close-error behavior is not inferred from mocks. The old fixed2068-byte RPC
transport remains fixed;grouped descriptor accounting,total deadlines and late
completion safety require their own qualification before grouped submission.

Separate ELF dependency/symbol checks from behavior;verify actual source/test/
compiler/control copies,preserve every failed attempt,and scope inherited drift/
schema/hosted-CI failures. Verify,commit/publish Hailo,verify exact remote tree/head,
lease fast-forward main,verify clean checkouts,then automatically continue original
grouped storage and actual numerical configuration/program/results work.

Broad ordinary UNMODIFIED model support100% stays fixed;missing formats,
architectures,operations and physical encoding are required implementation work.
All LLM execution stays Hailo-10H. No DFC,outside compiler/machine,precompiled
prerequisite,host/CUDA/cloud forward/proxy,guessed opcode/write,reset/rebind or
kernel/firmware change. Host lifetime evidence does not count as source execution.
