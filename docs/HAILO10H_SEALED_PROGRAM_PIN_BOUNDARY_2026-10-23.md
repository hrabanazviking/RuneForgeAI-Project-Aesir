# Sealed program USERPTR permission frontier

Date:2026-10-23. Continued after native sealed output was published at
`97bc8f87ffa138b9ba4008f2c33a82b25d7c97eb`. Fixed scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

The actual sealed-output tests establish immutable kernel file bytes and reject
writable shared mappings. They do not establish the driver's permissions when
mapping such backing for H2D. Existing physical evidence in
`HAILO10H_MOJO_DMA_STORAGE_OWNER.md` covers anonymous writable2068-byte RPC
buffers. That historical receipt is not a sealed-file mapping result.

The matching driver revision remains
`45e5fc53c6922fd6985febfc09399653497a2082`. Its full GPL-2.0 root license was
read first. Fresh root/license and UAPI bytes match retained copies. The public
[UAPI](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/hailo_ioctl_common.h)
retains `(GPL-2.0 WITH Linux-syscall-note) AND MIT`. Its mapping tuple supplies
address,extent,direction,type and returned handle;it does not declare read-only
VMA acceptance or seal/pin compatibility. No GPL implementation body or vendor
pinning algorithm is adopted or translated. A bounded public search supplied no
qualified exact-revision permission conclusion;that is not proof that none exists.

The [memfd interface manual](https://man7.org/linux/man-pages/man2/memfd_create.2.html)
describes sealing and ordinary mapping semantics. Those host interfaces cannot
certify a separate driver's mapping behavior. Manual example programs are not
adopted. Successful map/unmap also cannot certify physical byte movement or
coherence without a separately authorized transfer/result gate.

Next bounded experiment:`TASK_hailo10h_sealed_program_pin_probe.md`. Compare the
known anonymous writable control with read-only/private and writable/private
views of sealed synthetic program bytes. Use only the established typed
buffer-map/unmap endpoint,with no descriptor/channel/connection/transfer/program
request. Every attempt retains backing through known unmap or actual owning
file-context finalization. Qualify host mapping behavior and all cleanup/failure
paths before physical calls. Stop on identity mismatch,unreturned/uncertain
cleanup or busy ownership;never reset or take over an active channel.

Actual690 Mojo/80 Python copies and139 controls are frozen before the next
implementation. Raw exact license/UAPI receipts are under
`evidence/sealed-program-pin-contract-2026-10-23/`. This qualification makes no
new device request or native experiment and promotes no production capability.
Actual grouped descriptor counts,in-flight lifetime,total deadlines,late cleanup,
numerical precision/packing/configuration/placement,original program activation/
results and broad ordinary UNMODIFIED source-model execution remain required
work toward the fixed100% target. All LLM execution stays Hailo-10H only.
