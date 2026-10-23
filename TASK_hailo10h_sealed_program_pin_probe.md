# Bounded original sealed program USERPTR map probe

Date:2026-10-23. Publish before implementation or physical calls. Parent:
`TASK_hailo10h_program_delivery.md`. Fixed broad scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`. Boundary qualification:
`docs/HAILO10H_SEALED_PROGRAM_PIN_BOUNDARY_2026-10-23.md`.

## Question and exact scope

Determine whether this matched Pi driver accepts H2D USERPTR mapping of a
read-only/private view of actual sealed program bytes,and compare a writable/
private view. The known control is existing anonymous writable2068-byte storage.
Accepted mapping is a mapping result only,not byte transfer/coherence or source-
model execution. Neither success nor refusal changes the broad model target.

Add only an original bounded Mojo diagnostic and scoped host/physical tests.
No shared production/test edits or live engine/RPC integration. Reuse original
seal_program_payload/window,open_soc_driver,SocDriver.request,soc_buffer,
soc_buffer_reply and qualified mmap/munmap/page-size/close helpers. No vendor
implementation/algorithm or new raw OS interface. Public UAPI remains exact;
no invented pin flags,registers/opcodes or descriptor-count formula.

The only permitted device operations are the established fresh identity queries
and H2D buffer-map/unmap tuples on a fresh owned file context. Do NOT create
lists,channels,connections,interrupts,cache-sync requests,transfer/prepare/cancel,
action2,server handles,program activation or numerical work. No service takeover,
reset,rebind,firmware/kernel change or inference. All LLM execution stays on
Hailo-10H;host synthetic storage/orchestration only.

## Qualification before device calls

Freshly verify/copy actual690 Mojo/80 Python inputs,139 frozen controls and the
unchanged compiler. Preserve all evidence/concurrent work. Read current original
storage retention/driver close code and historical physical acceptance first.
Freeze supplementary original controls before code if absent. Build every actual
new consumer and selected sealed-output/storage/ABI controls;freeze linked
inputs before tests. Scope inherited warnings/errors and pair every invoked
frozen consumer with complete stdout/stderr/exit. Preserve every failure.

First compile an independent installed-header C/kernel oracle for read-only/
private and writable/private views of sealed files. It must prove the actual
mapping permissions,exact logical bytes,sealed backing unchanged after private
mutation/restore,and all unmaps/closes. Kernel write/grow/shrink/shared-write
refusals remain required. This host oracle makes no device call. A host failure
blocks dependent device probing;it does not authorize dropping seals or silently
changing permissions.

Synthetic valid outer envelopes may contain arbitrary owned byte fixtures;they
are never submitted to a receiver. Use only70,4097 and16385 logical program bytes,
with explicit host work/allocation bounds and the actual OS page size. No external
model file,download,conversion/compiler or vendor-precompiled artifact is needed.
Bounded diagnostic flags select only enumerated profiles,not arbitrary addresses,
files,fd values,ioctls or driver operations.

Before mapping,validate sealed program/metadata/full integrity,establish an owned
host VMA with the enumerated protection and copy/compare every logical byte.
Retain the actual mmap return and exact extent locally;no untrusted scalar may
supply a dereference address. Check page/extent arithmetic and nonzero alignment.
Verify guards and partial construction/cleanup under host fault injection before
opening a device. Stop on a changed/unqualified host/driver profile.

## Physical ordering and bounded cleanup

Each child opens a fresh identity-checked Hailo10H driver5.3.0 context with the
existing helper. Record actual current identity/properties;historical facts are
not substituted. A busy/refused open is an observation,not permission to disrupt
another owner. Never reuse another context's handle or assigned channel.

Prepare only original USERPTR tuple(direction1,type0). Arm uncertain-map
retention BEFORE requesting buffer-map. A successful map must preserve the
complete original tuple and return a valid existing handle. On known successful
mapping,request buffer-unmap with its original tuple. On any failed request or
malformed reply,retain VMA and sealed fd through actual owning driver-fd close;
do not infer that a negative ioctl had no effect. Even on normal unmap,close the
driver context before host munmap and sealed-fd close. Do not touch mapped bytes
while mapping/uncertainty is armed. Compare exact sealed backing and logical
bytes after context finalization,then release all host owners.

If context finalization is unconfirmed,retain backing and report cleanup as
unconfirmed;do not manufacture successful teardown or continue another physical
case. Preserve both primary and cleanup errors. No child may launch DMA,so a
mapping receipt cannot certify in-flight ownership,deadline or late-error safety.

Use an initial anonymous writable control,then the two sealed mapping profiles
at three sizes. Follow each completed variant by a fresh anonymous control,
including after completed refusal. At most13 children in this physical batch,
one outstanding mapping per child,ten-second outer deadline each. A timeout or
unreturned operation stops the batch;report the actual unresolved state. A
bounded complete refusal is a useful result and does not require repeated probes
or guessed permission flags. Future runtime storage choices need a separate
published contract based on these actual results.

## Evidence and continuation

Trace every new host/physical child. Join PID-specific interrupted calls and
actual memfd decorations. Match every successful acquisition to its actual
close/unmap and require uncertain-map backing release after driver-context
finalization. Count actual permitted ioctls;assert no transfer,channel/register,
network or excluded inference runtime effects. Separate ELF from behavior.
Verify exact fixture bytes,all work/refusal/fault/move/partial-lifetime guards
and fresh-state recovery. Retain raw current/frozen outputs and source/test/
control copies. No whole-engine/hosted-CI or source-model execution claim.

Verify,commit/publish Hailo,verify exact remote head/tree,lease fast-forward main,
verify both clean checkouts,then continue actual grouped storage/descriptor/
deadline/cleanup and numerical/physical program work automatically. Missing
formats,architectures,operations and configuration remain implementation work
under broad support100%. No DFC,outside compiler/machine,precompiled prerequisite,
host/CUDA/cloud LLM forward/proxy or guessed device write is introduced.
