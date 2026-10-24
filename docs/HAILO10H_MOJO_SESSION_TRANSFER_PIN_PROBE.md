# Same-file sealed session maps: bounded physical acceptance

Date:2026-10-24. Capability:AES-CONTROL-013. Pre-code contract:
`TASK_hailo10h_session_transfer_pin_physical.md`,published
8a3d263fc9b8d85267b2a943a63ed50de51296f2. Fixed scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. Original host owner:
`HAILO10H_MOJO_SESSION_TRANSFER_PIN.md`.

## Original probe and host preflight

The new Mojo probe reuses the published owner and pure synthetic backing/request
factories. It bounds logical program sizes to70,4097,16385 bytes before allocation;
validates the owned two-part group and141-byte canonical value;captures actual
session properties;finalizes its whole session file;then compares complete sealed
metadata/program bytes and releases views/backing. Repeat close is idempotent and
post-close group access refuses. No old production or test input changed.

Fresh pre-code actual inputs:714 Mojo/89 Python tests,163 qualified controls and
811 contract archive paths. Final inputs:715/90. The actual new consumer closure
is one probe;the unchanged session control and ABI inspector are selected.
All3 Mojo/2 C/C++ helper links and10 ELF tables precede acceptance. There are zero
new-statement warnings;inherited ABI/session/storage warnings remain recorded.
Compiler SHA-256:
`be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39`.

Host preflight passes3 methods:58 native/auxiliary invocations,29 complete frozen
stdout/stderr/exit pairs (18 accept,11 refuse per image),56 traces. Independent
protobuf/hash/header oracles check full synthetic bytes and ioctl layouts. These
oracles are test-only and absent from production linkage. Each traced child joins
actual file generations and fault events;no physical device opens or ioctls occur.
Across current and frozen runs,76 actual sealed fds and76 read-only/private views
are observed;all76 views become PROT_NONE before mock maps.68 sealed closes and
68 exact unmaps follow confirmed owning mock-file closure. Deliberate uncertain
cleanup cases retain8 sealed fds/8 VMAs and2 mock files. All2916 file generations
are accounted for by2906 closes and those10 deliberate survivors. This is mocked
fault/lifetime evidence,not physical failure recovery or DMA acceptance.

## One physical batch,completed once

After successful host audit,exactly four private native children ran under a
20-second outer deadline each:one unchanged session baseline,then one new-owner
case for each enumerated size. All four return0,with empty stderr,no timeout,
no unresolved termination and no preload/fault injection. The dispatch/completion
receipts forbid repeats;no completed child was rerun.

Fresh read-only module identity before the batch:

- Kernel6.12.112-v8-16k-hailo+,driver5.3.0.
- Source version91195A5A35A8DAAA5717B7D.
- Live build ID380557783212772d9b067ff0163631a222c26d64.
- Module file SHA-256:
  `756d58f7ffb51ca5999e09b7ae14b422b3b0450cf29d2cdabf8babc9491481e4`.

These are identity metadata,not reproducible loaded-module byte or firmware
identity proof. Actual properties report H10H board type2,PCIe DMA type0,one
engine,firmware-loaded true and maximum descriptor page4096. No firmware version
was queried. Host page size is16384;session descriptor page is512. Assigned
channels are0/16 for all four children.65536 allocated descriptors per direction
is existing allocation policy,not usage,launch count or capacity qualification.
Returned list handles are opaque and are not interpreted as physical addresses.

Each new child maps its actual2068-byte metadata and logical program views
through the same session file that owns the assigned lists/channels. Metadata
mapping extent is16384 for each case;program mapping extents are16384,16384,
32768 respectively. The group remains a checked value only;it is never submitted.
The unchanged baseline maps no user buffers.

The independent physical trace audit accounts for:

-4 actual device-file opens and4 closes;130 file generations/130 closes overall.
-38 permitted ioctl calls:driver-info4,properties4,descriptor-create8,connect4,
  buffer-map6,connection-close4,descriptor-release8. All match independently
  qualified header/ABI codes and their owning file generation.
-6 actual sealed fds/6 closes,6 read-only/private VMAs/6 exact unmaps. Whole device
  file close precedes owned host unmapping/backing release. No explicit buffer
  unmap ioctl is added;these mappings finalize through the whole owning file.
-60 sealed positional reads,22 after context closure. Complete original metadata
  and program bytes match independent preflight expectations after finalization.

All PIDs/call records are classified and joined. Per-child ordering is driver
identity/properties,two list creates,connection,two maps for new children,
connection close,two list releases,device-file close,owned host release.
No IRQ,cache sync,prepare,cancel,launch,DMA transfer,RPC packet,network connection,
program activation or numerical/model request occurs. ELF inspection finds no
excluded inference runtime linkage. Physical success establishes mapping and
observed software cleanup only. It supplies no descriptor-use formula,coherence,
all-failure hardware idle,remote logical cleanup confirmation or numerical
source-model execution. The pinned driver's void stop helper and ignored remote
close result retain the limitations documented in
`HAILO10H_GROUP_SESSION_FINALIZATION_BOUNDARY_2026-10-24.md`.

## Immutable evidence and limits

`evidence/session-transfer-pin-probe-2026-10-24/archive-identities.json` pins
1111 paths/14623862 aggregate bytes in one page across seven immutable roots.
Manifest SHA-256:
`0a35b1a4d7e5aa4b1d48b990e4fa7381f0c93fb93b436d8da042b46691f22870`.
Six roots retain exact builds,source/test copies,host/physical runs and audits.
The seventh preserves the first archive-recorder failure:it wrongly expected
C build rows to contain the Mojo-only returncode field. It stopped before writing
an archive. The corrected recorder verifies the retained successful build script,
empty C diagnostics,linked-image hashes and final stable receipt. No native build,
acceptance or physical audit failed,and no device call was repeated for recording.
Review copies normalize paths;exact executed scripts remain pinned. Raw roots
are not reused as output directories for publication review.

The811 contract paths,163 controls,compiler,all final actual inputs,full host
pairs and current/frozen images are reverified. Nine inherited ledger schema
diagnostics and23757 drift findings remain;no global repository/hosted-CI pass
is claimed. Census becomes144 verified/189 total,29 partial,15 missing and one
historical noncanonical status.

Continue actual grouped transfer/count/completion/total-deadline/late cleanup,
and numerical configuration,packing,placement,original program delivery/results.
Broad ordinary UNMODIFIED source-model support remains100% the fixed target;
remaining formats,architectures and operations are implementation work. Aesir owns
its Mojo compiler and Hailo-10H execution;DFC,outside compiler/machine,vendor
precompiled prerequisites and host/CUDA/cloud inference/proxies remain excluded.
