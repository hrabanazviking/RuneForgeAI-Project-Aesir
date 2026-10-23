# Original owned program payload staging in Mojo

Date:2026-10-23. Pre-code contract:`TASK_hailo10h_program_payload_staging.md`,
published at`c21df88df4f26cc6f2d78c3aff7e05c4bc3ef029`. Public boundary:
`HAILO10H_PROGRAM_PAYLOAD_BOUNDARY_2026-10-23.md`. Fixed owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented consumer

Original `smidr/program_payload.mojo` connects actual owned v3 envelope bytes to
existing action2 metadata. `ProgramPayloadRequest` retains copied message-id,
virtual-device handle,name and explicit host bound. `ProgramPayloadSnapshot`
retains separate copied metadata/program lists. `stage_program_payload` validates
actual extents and existing full-residue integrity before metadata construction
and copies. Metadata declares actual len(program),uses the existing RPC codec,
and has deterministic zero padding to2068 bytes. Program bytes stay separate,
with no invented header/prefix,concatenation or DMA chunking policy.

`validate_program_payload` compares every expected/retained request field,
revalidates actual envelope extents/full checksum,and rederives/compares every
canonical metadata byte. `program_payload_window` checks signed part/window/work
bounds before allocation,then validates before copying selected bytes. Returned
windows survive source mutation,moves and local snapshot destruction. Part0
means metadata;part1 means program. This stage does not invoke SocRpcClient or
open a program/model/device file. The bounded hex tool is diagnostic only and
cannot become a separate user model-conversion prerequisite.

Explicit limitation: outer integrity is not immutable or executable identity.
A deliberately rehashed same-length replacement and a different internally valid
header layout can remain valid new wire intent. Tests preserve these acceptances.
Protobuf-only integrity refuses this narrow stage because its remainder is
unchecked. This is a component profile,not a permanent model eligibility rule.
No protobuf semantics,numerical CCW,target,placement or hardware admission follows.

## Actual native evidence

| Gate | Result |
|---|---|
| Stable warning-free builds before acceptance |6 Mojo consumers;two new and four selected old |
| Selected suites |5 suites/43 methods;all pass |
| Primary native calls |2885 |
| Additional complete frozen comparisons |2495:2260 accept,235 refuse |
| Full retained native stdout/stderr/exit pairs |5380 |
| New suite |8 methods/390 calls:221 accepted wire cases,151 refusals,17 malformed calls,one direct API |
| Direct API guards and recovery |2092 cycles,including all2068 metadata bytes,14 residue bytes,every request field and segment extents |
| New traces |390,covering every new consumer call |
| Independent dependency inspection |6 executables/12 ELF dynamic and symbol tables |

Independent Python struct packing,licensed test-only XXH3 and actual public-schema
protobuf descriptors check complete metadata,program and window bytes. They cover
zero through8192-byte synthetic sections,outer hash boundaries,empty/end windows,
all header-byte mutations,all residue-byte mutations,full/protobuf-only mode,
message/handle bounds,UTF8,NUL/default names,exact2048-byte body fit,signed and
host/output bounds. Direct API additionally checks source and request independence,
returned-window mutation,moves,scope expiry and every consumed mutable field.
No model/layer/attention or other LLM forward runs.

Envelope8/194,integrity11/2072,program-RPC8/140 and frame8/89 methods/calls pass
with complete independent frozen output comparisons. The four old consumers were
freshly rebuilt and frozen before production,then rebuilt again before acceptance;
all four final executable hashes equal those pre-code builds. Full primary/frozen
stdout/stderr are retained even where older suites normally truncate large logs.

Every new trace joins one observed executable launch to its returned exit,with no
observed Hailo open,network connect,ioctl or excluded inference/hash/protobuf runtime
load. The isolated test oracles remain outside production. Actual license/hash
provenance is retained;production has no vendor,XXH3 or protobuf runtime dependency.
This scopes the tested consumers,not whole-engine effects or hardware behavior.

All681 old Mojo/77 Python inputs remain exact. Final actual copies contain684
Mojo/78 Python files. The existing128 controls plus four clean pre-code supplementary
original controls are unchanged. Import-closure recomputation finds exactly two
new executable consumers. The compiler binary hash is unchanged. One pre-code
snapshot-copy setup refused a missing directory;completed snapshots and all clean
links were verified before any production/acceptance. Both clean type probes were
never executed. No native build or acceptance test failed.

Raw identities/census:`evidence/program-payload-native-2026-10-23/`. An independent
final census rereads full paired outputs,checks exact raw programs,protobuf counts,
canonical padding/windows,trace returns and actual source/control hashes. Inherited
document-drift and nine ledger-schema errors remain byte-identical;no whole-repo
or hosted-CI pass is claimed.

## Next physical work

This verifies copied byte preparation and guarded selection. It does not submit
an action2,own server handles or prove a live receiver accepts a program. The
existing fixed-buffer RPC exchange still lacks the payload phase. Do not send
isolated create-model metadata or choose arbitrary split/chunk sizes.

Continue actual grouped-buffer driver/descriptor constraints,read-only/sealed
compiler output,in-flight DMA lifetimes,total deadlines and late-failure cleanup.
Numerical configuration/precision/packing/placement,original upload/activation/
results/cleanup and broad ordinary unmodified model execution remain required.
The fixed100% broad source target and Hailo-only LLM execution are unchanged;
no DFC,outside compiler/machine,vendor-precompiled prerequisite or host/proxy LLM
route is introduced. No device request,reset,rebind,firmware or kernel change ran.
