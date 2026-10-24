# Installed-driver provenance and prepared-transfer side effects

Date:2026-10-24. Continued after original wire codec b07e051 under
`TASK_hailo10h_program_delivery.md` and
`TASK_hailo10h_numerical_encoding_sources.md`. Owner scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Actual read-only provenance

The PCI driver's module symlink identifies `hailo1x_pci`. The device-node prefix
is different:an initial `modinfo hailo1x` query refused because that module name
does not exist. The corrected queries follow actual sysfs ownership rather than
inferring the module name from the node. No module is loaded,unloaded or changed.

| Observation | Actual value |
|---|---|
| Running kernel |6.12.112-v8-16k-hailo+ |
| Loaded and installed-file driver version |5.3.0 |
| Loaded and installed-file source-version string |91195A5A35A8DAAA5717B7D |
| Live sysfs note and installed-file GNU build ID |380557783212772d9b067ff0163631a222c26d64 |
| Installed module-file SHA256 |756d58f7ffb51ca5999e09b7ae14b422b3b0450cf29d2cdabf8babc9491481e4 |
| Installed DKMS and package source trees |37 C/header files each;all74 file blobs match public45e5fc53c6922fd6985febfc09399653497a2082 |

The public recursive Git tree is complete,not truncated. Each comparison uses
both actual SHA256 and the Git blob identity of the actual local file. This is
source-file equality plus matching module identity metadata. It is not a
reproducible-build proof,a hash of all loaded kernel bytes,proof of build flags
or a conclusion about other kernel/firmware code. No disassembly or driver
implementation is adopted. Package copyright and modinfo identify GPLv2;the
full GPL-2.0 text precedes source inspection. Selected Linux files retain their
GPL-2.0 notices;common VDMA files retain MIT notices and their full license text
is preserved separately. No file is relabelled under another license.

## Caller → request → selected receiver facts

The inspected exact-revision dispatch maps preparation and cancellation to their
separate ioctl handlers. These facts come from the matched source files;they
are not new hardware observations or an Aesir implementation of the vendor code.

| Selected interface boundary | Consequence for original Aesir ownership |
|---|---|
| Linux prepare looks up the descriptor handle in its owning file context. Referenced transfer buffers are obtained/mapped through that context. | Numeric values or mappings created on another driver file do not establish an admitted prepared group. Keep actual file/channel/list/buffer ownership together. |
| USERPTR preparation synchronizes referenced buffers for device ownership and retains buffer references before inserting a prepared transfer. | Preparation has effects beyond constructing139 bytes. Arm retention before requesting it;negative status cannot grant CPU access or imply no partial effect. |
| The common preparation helper computes an internal descriptor count,but Linux prepare then returns prepared-queue insertion status. | The internal count is not exposed by the prepare ioctl. Do not reinterpret status0 as a descriptor count or copy a count algorithm into Aesir. |
| Cancellation targets the descriptor list's prepared queue,releases prepared references and resets list counters. | The8-byte cancellation request does not establish active-channel quiescence or cancellation of already launched DMA. Do not reuse it as a generic stop operation. |
| The separate launch path consumes a prepared transfer when present,and publishes channel availability through its own path. | Prepared-state ownership and launched-state completion/cleanup need distinct evidence. Host byte codecs and earlier map-only results prove neither. |

These facts establish selected request/effect boundaries,not a complete call-
graph safety audit. Lower mapping/cache/error paths and whole file-finalization
behavior still need their own qualification. No descriptor-capacity formula,
physical address/register/arithmetic opcode,numerical instruction or safe live
preparation recipe follows. Aesir must not copy/translate the inspected vendor
queue,descriptor-programming,counting or launch algorithms.

Primary selected sources:
[dispatch](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/vdma/vdma.c#L339),
[Linux preparation/cancellation](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/vdma/ioctl.c#L569),
[common preparation/cancellation/launch](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/vdma_common.c#L371).

## Concrete continuation and preserved evidence

Next qualify an original same-file grouped transaction owner and a separately
contracted bounded experiment using an already qualified non-inference RPC
request/reply. Establish complete byte equivalence,actual assigned channel/list/
buffer identities,positive returned launch counts,completion correlation,total
deadline and late cleanup before device calls. This research authorizes no such
call. No arbitrary source-program split,action2/model upload or numerical
operation is proposed as a substitute for valid Aesir-generated instructions.
Numerical encoding/packing/placement and actual original-program/results remain
required work toward broad ordinary UNMODIFIED source-model support100%.

No production/test code,model or kernel state changed. No new device open,
ioctl,preparation,cancellation,DMA,program activation or model execution occurred.
This report adds no native capability ID. It is bounded interface research,not
compiler or source-model execution. No DFC,outside compiler/machine,vendor-
precompiled prerequisite,host/CUDA/cloud LLM forward/proxy or guessed write.

Evidence:`evidence/prepare-driver-provenance-2026-10-24/` pins38 raw paths and
157704 aggregate bytes;manifest SHA256:
`c6cd406903a7898e6b4487f067babf3ecfa83a37f9d45314e7a2a8e7631930fa`.
The initial wrong-module-name query is explicitly transcribed as a tool
observation;it is not presented as a raw saved command file. A manifest-recording
relative/absolute-path error is likewise preserved with its correction. All
source/module identity metadata and selected qualified source copies remain
immutable outside production. Preserve historical receipts and concurrent work.
