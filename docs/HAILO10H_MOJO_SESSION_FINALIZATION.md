# RPC backing retention after uncertain file finalization

Date:2026-10-23. Pre-code contract:`TASK_hailo10h_session_finalization.md`,
published at`715862b782a7300f1b5ba33fe204a55a5dabc122`. Fixed broad owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Concrete correction

Original `SocSession.close` previously appended a driver close error and then
called context_finalized/release on both RPC storage owners. Because the original
driver invalidates its descriptor before reporting close failure,that path could
not establish whether context cleanup occurred. The historical physical storage
receipt did not test uncertain driver close. Its successful ordinary lifetime
observations remain intact.

The scoped correction adds18 production lines in`hailbru/soc_session.mojo`.
It records a permanent finalization-uncertain state and the combined errors,
arms retention on every existing allocation,revokes CPU ownership,and raises
before storage finalization/release. It conservatively retains even storage with
an earlier successful unmap. Repeated close and session operations refuse before
retrying an fd that may have been reused. Existing storage guards also refuse
reads,release,sync and unmap after this state. Destructors report uncertainty and
retain backing until process exit. No new raw OS interface or device request
was added;all other old production files and every old test remain unchanged.

Successful close still quiesces channels,cleans known mappings/descriptors,
closes the owning file,and releases host memory. Normal complete outputs remain
unchanged. Partial construction and prior channel/list/unmap errors retain their
original reporting,with close uncertainty added rather than swallowed.

## Actual scoped qualification

| Gate | Actual result |
|---|---|
| Pre-code actual input copies |691 Mojo/81 Python |
| Frozen old controls |141 plus6 missing affected consumers built before code |
| Final actual input copies |692 Mojo/82 Python |
| Actual affected executable closure |7 old consumers plus1 new API consumer |
| Stable final links before acceptance |9 Mojo and1 C;unchanged ABI binary hash exact |
| New API diagnostics |11 inherited warnings,zero warnings on added statements |
| Selected suites |6 new session methods plus12 old ABI methods;all18 pass |
| Traced session/native children |132,including frozen and old-gap comparators |
| Additional old ABI primary calls |323,including125 independent C oracle calls |
| Complete frozen output comparisons |210:12 lifecycle/argument plus198 ABI |
| Complete retained native output triples |653 |
| Direct poisoned-session reuse refusals |236 |
| Combined earlier cleanup plus close errors checked |10 |
| Separate ELF inspection |11 artifacts/22 dynamic and symbol tables |

All driver behavior in this slice is explicitly mocked against real harmless
`/dev/null` files and synthetic sysfs roots. The original C seam uses the pinned
public UAPI after retained license/provenance qualification. It independently
checks descriptor count/page/circular fields,connection handles/port,actual
USERPTR address/size/direction/type and sync extents. It intercepts raw SYS_close
as well as raw ioctl dispatch;no real Hailo open or ioctl occurs. Unexpected
operations abort. No vendor algorithm or implementation body is adopted.

Close failures are injected before effect and after actual host-file close.
Each combines with normal pending software state,partial allocation,map before/
after effect,malformed reply,unmap,channel-close and descriptor-release errors.
Fresh successful owners follow failures. Separate construction tests cover open,
identity,first/second descriptor creation and connection failures. Moves,
idempotent successful close,exception unwind,existing pending guards and complete
normal storage/session outputs pass. Wait/RPC consumers are linked and their
pre-device argument refusals compared;no waiter or RPC transaction is executed.

The132 traces contain180 owned VMAs:132 explicit unmaps and48 deliberate
retentions until exit. Four of those explicit releases belong to the two frozen
old-gap demonstrations;they reproduce the superseded behavior and are not
corrected cleanup evidence. All other explicit releases follow actual host-file
close. Uncertain new cases have no owner munmap or close retry. Actual close
counts are reported separately from attempted closes;before-effect close failures
retain the file until process finalization. No falsely balanced cleanup is claimed.

Every trace is reconstructed by PID across interrupted calls. Full current and
frozen stdout/stderr/exit triples are retained. Traces show no physical Hailo
open,real ioctl,network connect or excluded inference runtime. Source/test/
compiler/control identities and actual import closure were rechecked. ELF
dependency/symbol inspection is separate from behavior. The unchanged existing
ABI suite and its independent C/header oracle remain passing.

## Preserved attempts and boundaries

The first C type probe refused three misleading-indentation warnings under
`-Werror`;a later added enum comparison exposed a signedness warning. Exact failed
sources and diagnostics remain. Both were corrected before stable acceptance.
The Mojo type probe linked;all final tests pass without a test-run failure.
Inherited warnings on old request sites remain scoped rather than relabeled as
new work. No unrelated warning cleanup or historical evidence rewrite occurred.

Immutable raw actual copies,binaries,full outputs,traces,oracles and recipes:
`evidence/session-finalization-native-2026-10-23/`. Its2964 file identities cover
29356958 bytes;manifest SHA256:
`73f69c73adae842e3954e486d0dd4e17bec9cc2b498d67f956d732e2b5671900`.
Never rerun archived recipes into their directories. Inherited documentation
drift and nine ledger-schema errors remain scoped;no whole-repository or hosted
CI pass is claimed.

This verifies a host fault-injection lifetime correction. It does not establish
physical close-error behavior,DMA cancellation or late-completion safety. No
physical driver call,transfer,program submission,numerical operation or model
evaluation occurred. The earlier sealed map-only physical receipt remains
separate. Fixed2068-byte RPC storage has not become grouped program transport.

Continue original grouped backing/descriptor/deadline/late-cleanup work and exact
numerical precision/packing/configuration/placement/program activation/results.
Every missing source format,architecture and operation remains implementation
work toward broad ordinary UNMODIFIED model support100%. All eventual LLM
execution stays on Hailo-10H. No DFC,outside compiler/machine,precompiled
prerequisite,host/CUDA/cloud forward/proxy or guessed device write was introduced.
