# Sealed program USERPTR mapping on the actual Hailo-10H

Date:2026-10-23. Pre-code contract:`TASK_hailo10h_sealed_program_pin_probe.md`,
published at`1717edb41189b71c04720e55cae7019b04616a9d`. Fixed broad owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. This receipt establishes bounded
mapping compatibility;no bytes were transferred to a receiver.

## Original diagnostic

`smidr/tools/sealed_program_pin_probe.mojo` reuses original sealed output,
full program integrity,driver identity,USERPTR tuple and OS lifetime helpers.
It accepts only host/device mode,the three named profiles and enumerated sizes.
It owns the actual mmap return and rounded extent locally. No caller supplies
an address,descriptor,handle,ioctl or operation. There are zero old production
or test edits and no new raw OS interface or borrowed implementation.

Sealed fixtures are valid outer envelopes containing arbitrary synthetic bytes,
not numerical programs. The diagnostic compares every logical byte before use.
The writable/private profile mutates and restores its private view while checking
that the actual sealed backing remains unchanged. It moves ownership before use.
Host bounds are32768 logical bytes,1MiB rounded allocation and independent16
read/write attempts. Actual page size comes from the OS;this Pi reports16384.

Device mode opens a fresh identity-checked file,arms uncertain-map retention
before buffer-map,validates the entire original reply tuple and handle,and
unmaps with the original tuple on known success. Every completed case closes
the actual owning driver file before reading/releasing backing. Errors and
malformed replies retain backing through context finalization. Unconfirmed
close reports failure and retains the VMA/sealed descriptor until process exit;
no explicit backing release or claimed successful teardown follows. Uncertain
host munmap is not retried on a potentially reused address. No CPU byte access
occurs while mapping uncertainty is armed.

## Independent host qualification before physical calls

The installed-header C/kernel oracle independently checks all six sealed profile/
size pairs:41104 exact bytes,24 actual write/grow/shrink/shared-write refusals,
three expected read-only-write SIGSEGVs in bounded children,and balanced releases.
It has no driver interface. This establishes kernel mapping permissions,not
Hailo pin compatibility.

| Gate | Actual result |
|---|---|
| Final links before host acceptance |5 Mojo and5 C/C++ |
| Existing selected binaries |All4 hashes exactly equal pre-code controls |
| New consumer diagnostics |4 inherited warnings;zero new-code warnings |
| Selected host suites |24 methods:6 new,6 sealed-output,12 ABI;all pass |
| Primary recorded native calls |672,including independent C oracle calls |
| Complete frozen comparisons |478:317 accept,161 refuse |
| Retained current/frozen stdout,stderr and exit triples |1150 |
| New diagnostic calls/traces |55 |
| Independent new output byte comparisons |87884 |
| New traced memfds |43 acquired,41 explicitly closed,2 retained until exit |
| New traced file VMAs |40 acquired,37 explicitly unmapped,2 retained until exit,1 uncertain injected munmap |
| Separate ELF audit |10 artifacts/20 dynamic and symbol tables |

Host-only driver seams open `/dev/null`,not Hailo. They exercise pre/post-effect
map/unmap failures,malformed tuples/handles,pre/post-effect close failures,
partial allocation,identity refusal and uncertain host release. Fresh recovery
calls follow each failure. Their mock properties,ioctls and results are never
physical evidence. Actual traces confirm no host Hailo open,ioctl,network connect
or excluded inference runtime. The two close-uncertain cases deliberately retain
backing until process exit;they are not falsely counted as explicit balanced
cleanup. Storage's old consumer is linked/hash-compared only,never executed:
its channel/connection/cache-sync operations are outside this probe contract.

Before production,actual690 Mojo/80 Python inputs,139 frozen controls and one
supplementary storage control were copied and verified. Final actual copies
contain691 Mojo/81 Python files. All old inputs and the pinned Mojo compiler
remain unchanged. Actual source import inspection finds one new executable
consumer. Full linked binary identities were checked again before physical use.

## Actual physical batch

All13 children completed within their ten-second outer process-group deadlines.
The batch used an initial fresh anonymous writable2068-byte control,each sealed
variant below,and a fresh anonymous control after every variant. No retries,
permission guesses,busy overrides or service changes occurred.

| Sealed view | Logical bytes | Actual VMA bytes | Map / unmap |
|---|---:|---:|---|
| Read-only/private |70 |16384 |accepted / confirmed |
| Read-only/private |4097 |16384 |accepted / confirmed |
| Read-only/private |16385 |32768 |accepted / confirmed |
| Writable/private |70 |16384 |accepted / confirmed |
| Writable/private |4097 |16384 |accepted / confirmed |
| Writable/private |16385 |32768 |accepted / confirmed |

All seven anonymous controls also mapped/unmapped successfully. Each fresh driver
reported5.3.0,board type2,PCIe DMA type0,one DMA engine,loaded firmware and
descriptor maximum page size4096. These are current driver properties;no fresh
firmware-version RPC was sent. The OS's16384-byte pages and descriptor maximum
page size4096 are distinct observed quantities,not an inferred descriptor rule.

Full PID-joined traces show13 driver opens/13 closes,26 identity queries,
13 buffer-map and13 buffer-unmap ioctls. Every other device request is absent.
All13 owned VMAs were unmapped after driver close;all six sealed files closed
after their VMAs. Exact logical bytes were compared after finalization:
41104 sealed bytes plus14476 control bytes,total55580. Sealed backing remains
unchanged. There were no deadlines,refusals or unconfirmed physical cleanups.

This is current positive read-only/private USERPTR acceptance for this bounded
H2D map-only profile. It proves neither DMA transfer nor cache coherence,physical
scatter/gather descriptor accounting,grouped in-flight ownership,late completion
safety,program admission,activation,numerical operation or source-model execution.
Only one mapping was outstanding per child. Arbitrary lengths,permissions,
devices,driver versions and live program paths are not certified by these cases.

## Preserved failures and evidence

The first host fault seam intercepted libc close while the existing driver uses
raw SYS_close. Its failed test run is preserved;the corrected seam passes all
tests before physical calls. A build recipe initially refused an already existing
snapshot directory;it was corrected to a fresh directory without overwriting the
first build or failed log. The first physical trace census incorrectly matched
an earlier runtime unmap at a reused anonymous address. Its failed audit is
preserved;the corrected census limits releases to the acquired owner's lifetime.
No physical case was rerun. Production Mojo did not change after its first link.

Raw actual copies,binaries,failed and passing full outputs,traces and recipes are
immutable local evidence. `evidence/program-pin-native-2026-10-23/` records7035
file identities,40112634 bytes;manifest SHA256:
`3f237b30e5febd036525efffb8bbc84a216a826c7a78a0e01da2690da69b9064`.
Do not rerun archived recipes into these directories. Public tracked summaries
separate host/mock and physical evidence. Inherited documentation drift and nine
ledger-schema errors remain scoped;no repository-wide or hosted-CI pass is claimed.

## Continued work toward broad source-model execution

Read-only sealed output can now inform a separately contracted original grouped
storage owner. Actual grouped descriptor counts,ownership through completion,
total deadlines/cancellation/late cleanup,metadata plus program delivery and
receiver semantics remain required before physical program submission. Numerical
precision/packing/configuration/placement,original activation/results and every
missing format,architecture and operation remain implementation work toward the
fixed broad ordinary UNMODIFIED source-model target100%. All eventual LLM
execution stays on Hailo-10H. No DFC,outside compiler/machine,precompiled-model
prerequisite,host/CUDA/cloud forward/proxy or invented opcode was introduced.
