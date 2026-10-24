# Prepared queue versus direct grouped launch

Date:2026-10-24. Continued after same-file map-only acceptance43b761b under
`TASK_hailo10h_program_delivery.md`. Fixed owner scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. This is bounded interface research;
no production implementation,new capability ID,device call or numerical proof.

## Qualified distinctions

Fresh GPLv2 license bytes precede four selected pinned source/header resources;common
files retain their own MIT or syscall-note/MIT notices. The complete MIT text
is retained from the previously qualified HailoRT license,not relabelled as a
separate driver-repository license file. Fresh source/header bytes match the
complete public tree at45e5fc53c6922fd6985febfc09399653497a2082 and earlier
qualified local files. No external algorithm is copied or translated.

The selected [Linux receiver](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/vdma/ioctl.c#L683)
looks up the descriptor list through the owning file. After engine,channel and
maximum-buffer checks,it consumes a queued prepared transfer when present;
otherwise it prepares the supplied group. It then forwards the common launch
return. The separate prepare request instead returns queue insertion status.
There is no returned prepared-transfer identity joining a later caller-supplied
buffer tuple to the queued item. These selected facts do not audit every lower
error path or qualify an empty-buffer launch on an empty queue.

The [common launch boundary](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/vdma_common.c#L441)
returns the descriptor count for that launch after updating channel availability.
Aesir can observe that actual return;it must not copy its calculation,derive a
count from bytes/buffers,or substitute a preparation status. Counts and IRQ
transfer completions remain separate observations.

The [packed public declaration](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/hailo_ioctl_common.h#L436)
embeds prepare fields in launch plus engine/cyclic fields. It supplies no queue
identity or prepared-only discriminator. The current original group codec admits
one through eight actual spans. Its refusal of zero is preserved;no guessed
zero-buffer trigger is required for the next original path.

## Original continuation decision

Use the existing direct group codec on a fresh owned control session without
prepared-queue state. The existing2068-byte control-frame mapping already has a
natural20-byte header and2048-byte padded body. Two ordered spans of that same
owned mapping can preserve exact old control bytes without arbitrary program
chunking. This is a proposed host-qualified transport component,not physical
admission,independent sealed mappings or a new numerical program format.

`TASK_hailo10h_grouped_control_rpc.md` contracts the original host-only owner,
actual asymmetric launch returns,IRQ correlation,one total deadline and late/
uncertain cleanup. It preserves existing RPC code and forbids physical tests.
A later physical control experiment needs separate evidence and a bounded
contract. Map-only success does not qualify DMA,coherence or all-failure hardware
idle/remote cleanup. Actual numerical encoding/configuration,packing,placement,
original program/results and all remaining model breadth remain implementation
work toward ordinary UNMODIFIED source-model support100%,with all LLM execution
on Hailo-10H and no DFC,outside compiler/machine,precompiled prerequisite or
host/CUDA/cloud inference/proxy.

## Preserved evidence

`evidence/group-launch-boundary-2026-10-24/archive-identities.json` pins the
fresh resources,public tree,failure/correction and actual pre-code715 Mojo/90
Python inputs,164 current controls,compiler,UAPI/helper copies. An initial
retrieval script assumed a separate MIT-license filename;the exact public tree
has none and the script stopped after fetching GPLv2. Its failure is retained.
The correction uses the already qualified MIT text and exact tree file names.
No native image was built,no model downloaded and no device call repeated.

Archive:833 paths/6398947 aggregate bytes. Manifest SHA-256:
`c5a18c34dae72e8c848a64dffa1811b11cc506990f1a80cbf943d278864fe8cc`. Contract and capability evidence remain distinct;
no ledger verification count changes from this research.
