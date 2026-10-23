# Original sealed program output ownership

Date:2026-10-23. Pre-code contract:`TASK_hailo10h_sealed_program_payload.md`,
published at`73760c1da459b77d41e687f88674cd2012231d56`. Fixed owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. Qualified existing host interfaces:
`HAILO10H_SEALED_SOURCE_COPY_CONTRACT.md`.

## Implemented consumer

Original `smidr/sealed_program_payload.mojo` owns an anonymous kernel-sealed file
containing exactly an existing staged program's bytes. `SealedProgramPayload`
retains the owned descriptor,host,program extent,copied request and canonical
metadata. It starts empty;explicit idempotent close invalidates ownership before
reporting errors. Its destructor closes only retained storage.

`seal_program_payload` checks the qualified host,positive independent write/read
attempt bounds,actual full-residue envelope and complete request/metadata before
creating storage. It uses already qualified CLOEXEC/sealing-enabled memfd and
fcntl interfaces,existing positional writes/reads,regular-file extent and close
helpers. No new raw OS interface or external implementation is introduced.
It writes at most4096 bytes per attempt,handles positive shorts and bounded
EINTR,rejects zero/oversized progress,checks exact extent,adds all four required
seals and checks them back. It reads actual sealed bytes,revalidates complete
canonical metadata/full integrity and compares every program byte with the staged
input before returning. All acquired files close on the tested failure paths.

`sealed_program_window` checks signed part/window/output limits before allocation.
Each access checks all consumed mutable owner/request fields,actual same-fd seals,
regular extent and CLOEXEC,then rereads the entire bounded program and reuses the
original payload validator before returning independent bytes. It never trusts a
cached integrity flag or count. Part0 selects metadata;part1 selects program.
Original sources/requests can change or expire after sealing without changing
the sealed object. Returned windows survive owner moves,closure and scope expiry.

Kernel immutability describes that actual sealed object. Mutable descriptor or
request fields and a substituted valid sealed object do not establish historical
artifact identity or source-to-executable coherence. A valid outer envelope does
not admit its opaque protobuf/CCWs as numerical device instructions. No physical
resource fit,numerical target,placement or executable admission is inferred.

## Actual acceptance evidence

| Gate | Verified result |
|---|---|
| Stable links before acceptance |8 warning-free Mojo and3 C links |
| Existing selected binaries |All6 hashes exactly equal their pre-code controls |
| Final selected suites |5 suites/38 methods,all pass |
| Primary native calls |3136 |
| Additional complete frozen comparisons |2842:2488 accept,354 refuse |
| Complete retained native stdout/stderr/exit pairs |5978 |
| New suite |6 methods/294 traced calls:195 accept,99 refuse |
| Independent byte comparisons |277987 new output bytes |
| Direct mutable-field/fresh recovery cycles |2086 |
| Actual anonymous files and closes |2326 created,2326 closed |
| Actual seals/positional reads/writes |2315 successful seals,7009 reads,2490 writes |
| Kernel protection refusals |72 |
| Fault injection |29 runs;first-owner phases and independent attempt budgets checked |
| Separate ELF inspection |11 artifacts/22 dynamic and symbol tables |

Independent Python struct/public-schema protobuf and pinned test-only XXH3
oracles construct and compare complete synthetic program/metadata/windows.
An original C/kernel oracle includes installed headers and independently verifies
seals,CLOEXEC,all bytes and write/grow/shrink/writable-shared-map refusals.
The same kernel refusals are also attempted on the actual Mojo-owned files.
Sizes cover empty residue,odd,page/multiblock and all byte values. Both parts,
empty/end windows,full bytes,UInt32/UInt64/signed/work limits,UTF8 names,outer
corruption,truncation/protobuf-only refusal and fresh success are exercised.

Direct API tests check source/request/metadata independence,all2068 metadata
bytes,every request field,host/fd/extent mutations,missing seals,CLOEXEC changes,
metadata extent changes,default/closed owners,moves,scope expiry and retained windows.
Forged fds are restored before destruction. Injected create/extent/write/read/
short/EINTR/zero/oversized/seal/get-seals/flags/corruption and post-effect close
failures preserve fresh in-process recovery. Separate read/write bounds are
verified from first-owner fault events;kernel traces verify actual acquisitions
and closes. Test-only syscalls and fault libraries never ship in production.

Selected old payload8/390,integrity11/2072,envelope8/194 and sealed-source5/186
methods/calls all pass with complete independent frozen comparisons. Frozen
filesystem fixtures use separate pre-call byte copies,including mutation modes;
fault logs and trace outputs stay separate. No old source or test input changed.
Before production,actual687 Mojo/79 Python inputs and137 controls were frozen.
Final actual copies contain690 Mojo/80 Python files. All old hashes and the
compiler are unchanged;import closure finds exactly two new executable consumers.

Preserved failures: a test-only Int-to-Int64 cast failed the first API type probe;
its exact source/diagnostics remain. The first regression runner incorrectly
paired ldd ASLR addresses and lacked the auxiliary Python import path. Its failed
comparisons/import refusal remain;the corrected runner uses a fresh acceptance
directory and unchanged source/test inputs. Final38 methods pass. The clean
production type probe was never executed. No failure or inherited gate is hidden.

Every new native call has a full trace joined by PID across unfinished/resumed
syscalls,one observed exec and its returned exit. All owned memfd lifetimes are
balanced. No observed Hailo open,connect,ioctl or excluded inference/hash/protobuf
runtime load occurs in those native consumers. Production performs no mapping;
only test oracles attempt writable shared mappings and receive EPERM. Raw copies,
failures,full outputs and census are under
`evidence/sealed-program-native-2026-10-23/`. Inherited drift/nine schema errors
remain scoped;no whole-repository or hosted-CI pass is claimed.

## Remaining physical and numerical work

This verifies sealed host output ownership. No mapping,pinning,cache sync,DMA,
action2 submission,server handle,program activation or hardware result occurred.
Seals do not qualify future USERPTR pin compatibility. Existing RPC storage and
progress remain fixed2068-byte components;grouped physical descriptor accounting,
in-flight lifetime,total deadlines and late cleanup still require qualification.
Numerical precision/packing/configuration/placement,original upload/activation/
results and all missing formats,architectures and operations remain required work
toward the fixed broad ordinary UNMODIFIED source-model target100%. All LLM
execution stays Hailo-10H only. No DFC,outside compiler/machine,precompiled-model
prerequisite,host/CUDA/cloud forward/proxy or guessed device write is introduced.
