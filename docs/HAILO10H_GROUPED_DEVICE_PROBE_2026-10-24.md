# One grouped physical control attempt: rejected offset, preserved cleanup

Date:2026-10-24. Contract before code: `TASK_hailo10h_grouped_device_probe.md`,
published4d9f14c on both branches. Owner scope remains broad ordinary UNMODIFIED
source-model support100%,with original Mojo loading/internal compilation and
Hailo-only LLM execution. The owner's concurrent finish-line codex905f296 is
preserved in this history. Its evidence/ownership/one-shot rules were reread.

## PROVEN

**HOST VERIFIED:** Original `smidr/tools/group_device_probe.mojo` consumes the
existing typed grouped owner with a5000ms total lifecycle budget. It refuses
implicit physical use,checks the host page before opening,and checks expected
protocol2/architecture6/firmware5.3.0 only after bounded cleanup. Its result
prints sanitized booleans;no handle,serial,logger or private wire is printed.

The original test-only `tests/group_device_syscall_observer.c` forwards the
actual syscall symbol. It preserves arguments/results/errno,stores bounded
records in memory while ownership is live,and flushes at process finalization.
Outgoing bytes are captured before input device-sync;incoming bytes only after
successful output CPU-sync. It never reads a device-owned page,adds an ioctl,
changes a descriptor return or injects a physical fault. Logging failure,
pre-existing destination and bounded overflow leave the Mojo result/cleanup
unchanged. Initialization handles calls from earlier DSO constructors.

Fresh actual722 Mojo/92 Python inputs,171 retained controls,compiler and11
helper/schema/UAPI inputs were copied before edits. Final723 Mojo/93 Python
copies,23 Mojo/7 C/C++ links and60 ELF tables precede final acceptance. Zero
warnings originate in the new sources;inherited warnings remain visible.
All27 previously qualified native/control/helper images rebuild byte-identically
to f827417's final images. Its90 methods/5134 complete pairs remain inherited
proof for those identical artifacts;they were not rerun or counted as new tests.

Seven new host methods pass88 four-way complete comparisons:current/frozen,
with/without observer. This is176 complete current/frozen stdout/stderr/exit
pairs,17 accepted scenarios and71 refusals. Two additional complete auxiliary
pairs cover actual test-only protobuf compilation and the actual UAPI oracle.
The actual public schema independently checks704 fixture frames. No model
compiler or production protobuf dependency is introduced.

Across352 new host traces:520 real IRQ workers exit before owning-file close;
45184 file generations/45180 closes plus4 deliberate retained mock fds;612
owned VMAs/596 releases plus16 deliberate retentions;4340 real mprotect changes,
2216 PROT_NONE boundaries.164 loaded observer bindings,4314 complete observed
calls,276 outgoing/194 incoming CPU-owned snapshots are joined to actual PID/TID,
fd and VMA traces.310 dropped records occur only in deliberate zero/one-capacity
logger tests. Normal-capacity qualified runs have no overflow. All Hailo ioctls
are mocked in these host children. Four auxiliary traces balance32 file opens/
closes (see the exact auxiliary census rather than inferring device activity).

**PHYSICALLY VERIFIED negative boundary:** Exactly ONE new private-process-group
child ran,with a20s outer watchdog. Fresh installed metadata matched kernel
6.12.112-v8-16k-hailo+,driver5.3.0,source-version91195A5A35A8DAAA5717B7D,
build-ID380557783212772d9b067ff0163631a222c26d64 and module SHA-256
756d58f7ffb51ca5999e09b7ae14b422b3b0450cf29d2cdabf8babc9491481e4.
Host page16384,unmodified module parameters and a read-only standard PCIe
configuration snapshot were recorded before admission. The existing driver
owner queried/validated5.3.0,H10H PCIe,one DMA engine and firmware-loaded before
allocation/launch. Returned maximum descriptor page4096 selected policy512.
No configuration write,reset,rebind,firmware/module/kernel change occurred.

| Physical observation | Result |
|---|---|
| Assigned channels | H2D0,D2H16 |
| Same-file USERPTR maps | two2068-byte stores |
| D2H scalar2068 launch | actual return5 |
| H2D two-span20/2048 launch | return-1,errno22 (`EINVAL`) |
| Second H2D span offset within its existing map |20 |
| Kernel read-only diagnostic | invalid buffer offset20;descriptor page512 |
| Accepted handle/identity/destroy | none |
| Assigned IRQ records / owned IRQ workers started |0 /0 |
| CPU-owned captures | one outgoing create20 frame;no incoming read |
| Watchdog expiration / observer overflow | none /none |
| Local cleanup | disable,channel-close,2 unmaps,2 list releases,file-close succeed |
| Host release | both exact16384-byte VMAs released after owning file close |
| Actual process fd census |33 generations/33 closes,one owning-device fd |

The physical observer resolves libc syscall and records19 actual Hailo ioctls,
with complete before/after pairs. Four startup Mojo runtime threads are distinct
from an IRQ worker;no wait request starts an owned IRQ worker on this path.
The request budget starts after establishment. The first exchange fails after
D2H admission and H2D rejection;the transport is permanently poisoned. No guessed
handle is destroyed and no identify/destroy request is sent. The physical batch
is CLOSED. There was no repeat or follow-on physical child.

## PUBLIC INTERFACE FACT

Fresh retained license bytes precede the selected source copies. MIT common
source and GPL2 Linux receiver remain research inputs,not translated production
algorithms. The matching common source SHA-256 is
`eec40d2a23b211fb06b05a888c097e0a79d9fde1cb701fcdae3fd29f581de675`.
The public tree is45e5fc53c6922fd6985febfc09399653497a2082.

The [Linux receiver](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/vdma/ioctl.c#L606)
expresses a USERPTR span's offset relative to the existing mapping. The
[common boundary](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/vdma_common.c#L256)
rejects a mapping-relative offset that is not divisible by that list's descriptor
page size. The actual kernel diagnostic identifies offset20/page512 in this
attempt. This qualifies an admission constraint,not a descriptor-use formula.
Natural logical header/body lengths do not require physically adjacent span
addresses. A separate host-only contract must establish aligned backing,
CPU-owned scatter/gather and compatibility before any future physical contract.

## NOT PROVEN

The grouped lifecycle did not succeed physically. A D2H launch return5 is one
observed return,not a byte/count formula,capacity or completion. No assigned IRQ
completion,accepted create/identify/destroy reply,logical device destruction,
all-failure hardware idle or remote-close confirmation is established. Successful
local close/unmap/release is reported separately from those unknowns.

No action2/action17,prepare/cancel request,program transfer/activation,arithmetic
configuration,source-model loading or numerical/LLM execution occurs. Existing
host-qualified grouped codecs remain host-qualified;their natural adjacent
20/2048 span layout is now physically rejected on this profile. Historical
map-only/scalar batches were not repeated. The full source-model target remains
unchanged;actual numerical encoding,packing,placement,program/results and wider
formats/architectures/operators remain implementation work.

## Retained failures and exact evidence

Initial observer constructor ordering caused host startup SIGSEGV before an
owner existed;lazy once initialization fixes it. Later host harness replays
exposed frozen-path and retained-owner stdout parsing mistakes;all failures are
retained. Superseded trace audits retain their path/count/packed-field/fd-reuse
mistakes and corrections. None caused another physical child. No old published
Mojo/Python/C body was edited in this slice. No whole-repository or hosted-CI
pass is claimed.

Raw private wire,PID/fd/VMA traces and all source/test/helper/image copies stay
local. The published manifest contains identities and sanitized censuses only.

`docs/evidence/grouped-device-probe-2026-10-24/archive-identities.json` pins
9318 files/375493142 aggregate bytes across25 immutable roots.
Manifest SHA-256:`cd60195db64ceec0f9e87527a184618f41f2d7029d48e0ba32b49b49efbb9201`.

Global census:146 verified/192 total,30 partial,15 missing and one historical
noncanonical status. The9 inherited schema errors and23757 historical drift
findings remain byte-identical before/after staging. Neither is a passing gate.
