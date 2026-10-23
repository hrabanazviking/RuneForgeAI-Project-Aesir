# Own original program bytes beside exact action2 metadata

Date:2026-10-23. Publish before production. Parent:
`TASK_hailo10h_program_delivery.md`. Facts:
`docs/HAILO10H_PROGRAM_PAYLOAD_BOUNDARY_2026-10-23.md`. Fixed owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Add ONLY original `smidr/program_payload.mojo`,bounded host tool and scoped tests.
Zero old production/test edits. Reuse existing envelope integrity/layout,program
create protobuf and RPC codec; no parser/hash/protobuf algorithm copy or external
implementation adoption.

Movable ProgramPayloadSnapshot owns separate metadata/program byte lists and a
copied request:message-id,virtual-device handle,name,positive host program bound.
Validate supplied actual bytes before copying/constructing metadata. Require
full-residue outer integrity; refuse protobuf-only mode,whose unchecked remainder
cannot meet this narrow contract. Count actual len(program),never cached claims.
Create existing action2 metadata from that count,frame with existing codec,pad to
exactly2068 bytes with zeros. Preserve program as a separate exact owned copy.
Never concatenate,insert a prefix,synthesize instructions or select DMA chunks.

Before a snapshot window,compare supplied expected request against retained
intent,freshly validate envelope extents/full checksum and derive/compare complete
canonical metadata. Refuse altered request/metadata/length or checksum-invalid
payload before copying. Check signed part/window/output-work bounds before
allocation; allow empty end windows. No cached unchecked offset selects bytes.
Returned windows and source/copy/move lifetimes remain independent.

This checks byte preparation and wire intent,NOT cryptographic/immutable artifact
identity: deliberate replacement by a fully rehashed same-length envelope can be
valid new wire intent. Test/report this limitation. Sealed output,DMA ownership,
numerical admission and physical transfer remain required work. Outer checksums
do not validate protobuf semantics,CCWs,target,placement or hardware acceptance.

Tool accepts bounded synthetic hex and reuses decimal/hex helpers. No program/
model file loader,host model/layer/attention forward,vendor runtime,raw OS,fd/map,
device/network request or SocRpcClient.exchange. Never send isolated action2.
Internal compiler output preparation must not become a user conversion workflow.

Before code reverify actual681 Mojo/77 Python copies,128 native controls and same
compiler against published contract. Rebuild all new consumers plus selected old
envelope,integrity,program-RPC and frame consumers; link all before acceptance.
Use independent synthetic Python struct/protobuf/XXH3 oracles and actual public
schema,licensed before use. Compare full metadata/payload bytes,windows,empty/end
bounds,source/copy/move independence,modes,header/extents/hash tampering and every
consumed mutable field. Exercise UTF8/default/maximum handles and integer/work/
host-policy refusals followed by fresh success. Preserve all attempted inputs
and build failures.

Run selected old suites; compare full stdout/stderr/exit with every invoked frozen
control. Trace every new consumer for device/network/ioctl/process/runtime effects;
inspect ELF separately. Reverify sources/controls and retain raw evidence. Report
inherited gate failures. Verify->publish Hailo->exact remote head/tree->FF main
preserving owner work->verify clean->continue automatically.

Broad ordinary unmodified model support100% remains fixed. Missing source,
architecture,operation and numerical/physical configuration/program transport/
activation/results/cleanup remain required. No DFC,outside compiler/machine,
precompiled prerequisite,CPU/CUDA/cloud LLM/proxy,guessed opcode/register/write,
reset/rebind,firmware/kernel change or hardware submission.
