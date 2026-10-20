# HAILBRÚ Public API Surface (H079)

The frozen API that downstream domains (VÖRÐR D6, SMIÐR D3) program against.
Import one module: `from hailbru.api import discover`. The full surface is
re-exported there; the authoritative signatures live in the modules below.

## Discovery (`hailbru.discovery`)

| Function | Signature | Errors |
|----------|-----------|--------|
| `discover` | `(arch: String, sysfs_root: String, vendor: UInt16, device: UInt16) raises -> String` | `DeviceNotFound`, `MultipleDevices`, `BadSysfs` |
| `parse_bdf` | `(s: String) raises -> Bdf` | `BadBdf` |

## Identity / config space (`hailbru.config`)

| Function | Signature | Errors |
|----------|-----------|--------|
| `read_identity` | `(arch: String, sysfs_root: String, bdf: String) raises -> PciIdentity` | `ConfigReadFailed`, `BadBdf` |
| `check_identity` | `(ident: PciIdentity, vendor: UInt16, device: UInt16, class_code: UInt32) raises` | `IdentityMismatch` |
| `read_config_bytes` | `(arch: String, sysfs_root: String, bdf: String, n: Int) raises -> List[UInt8]` | `ConfigReadFailed` |
| `read_link_status` | `(arch: String, sysfs_root: String, bdf: String) raises -> LinkStatus` | `BadSysfs` |
| `read_power_state` | `(arch: String, sysfs_root: String, bdf: String) raises -> String` | `BadSysfs` |

## BARs (`hailbru.bars`)

| Function | Signature | Errors |
|----------|-----------|--------|
| `parse_resource` | `(arch: String, sysfs_root: String, bdf: String) raises -> List[BarInfo]` | `BarParseFailed`, `BadBdf` |
| `bars_sane` | `(bars: List[BarInfo]) raises -> Bool` | `BarParseFailed` |

## Mechanism (`hailbru.mechanism`)

| Function | Signature | Errors |
|----------|-----------|--------|
| `probe_vfio` | `(arch: String, dev_root: String) -> MechReport` | none (report carries reason) |
| `probe_uio` | `(arch: String, dev_root: String) -> MechReport` | none (report carries reason) |
| `select_mechanism` | `(vfio_ok: Bool, uio_ok: Bool) -> String` | none (pure) |

`select_mechanism` returns `"vfio"`, `"uio"`, or `"sysfs-recon"`. On Mimir's
kernel it returns `"sysfs-recon"` — the recon-only posture, honestly not
named a driver mechanism (H004).

## VFIO (`hailbru.vfio`) — F3-banked

All raise `MechanismUnavailable` on kernels without VFIO (Mimir today);
`vfio_ioctl_checked` raises `VfioError` on ioctl failure. `vfio_iommu_map`
raises `IommuError` when the IOMMU is absent — fail-closed, never simulated.

## UIO (`hailbru.uio`) — F3-banked

Bind/unbind steps (`uio_step_unbind`, `uio_step_bind`, `uio_step_restore`,
`uio_step_register_id`) raise `MechanismUnavailable` when `uio_pci_generic`
is absent and `PrivilegeRequired` without root. Every step is reversible;
`uio_step_restore` returns the original driver.

## DMA (`hailbru.dma`)

| Function | Signature | Errors |
|----------|-----------|--------|
| `DmaRegistry().alloc` | `(arch: String, size: Int64, want_lock: Bool) raises -> DmaBuffer` | `DmaError`, `DmaLockFailed` |
| `DmaRegistry().free` | `(arch: String, addr: Int64, size: Int64) raises` | `DmaError` (double/unknown free named) |
| `vfio_iommu_map` | `(arch: String, container_fd: Int, dma_addr: Int64, size: Int64) raises` | `IommuError` (fail-closed, F3) |
| `uio_dma_alloc` | `(arch: String, mech: String, size: Int64) raises -> DmaBuffer` | `MechanismUnavailable` (F3) |
| `dma_cache_flush` / `dma_cache_invalidate` | `(arch: String, addr: Int64, size: Int64)` | none — **documented no-ops** (H018: userspace cannot issue DC CVAC/IVAC) |

CPU-side allocation and mlock work today. IOMMU mapping is F3-banked.

## Registers (`hailbru.regs`)

| Function | Signature | Errors |
|----------|-----------|--------|
| `map_sysfs_resource` | `(arch: String, sysfs_root: String, bdf: String, index: Int, size: Int64, writable: Bool) raises -> BarMapping` | `MapFailed`, `PrivilegeRequired`, `BadBdf` |
| `map_emulated` | `(arch: String, path: String, size: Int64) raises -> BarMapping` | `MapFailed` |
| `reg_read16` / `reg_read32` | `(m: BarMapping, off: UInt16) -> UInt16/UInt32` | none (bounds-checked at map) |
| `reg_write32` / `reg_write32_verified` | `(m: BarMapping, off: UInt16, val: UInt32) raises` | `ReadbackMismatch` |
| `unmap_bar` | `(arch: String, m: BarMapping)` | none |

`map_sysfs_resource` with `writable=False` gives a read-only mapping —
the H068 posture. Live-device writes are forbidden while the vendor driver
is bound (H005 §6); write/readback is exercised on emulated BARs only.

## Interrupts (`hailbru.irq`)

`irq_eventfd`, `irq_wait` (raises `IrqTimeout`), `irq_signal`,
`irq_close`, `irq_vfio_set_irqs` (F3: raises `MechanismUnavailable`
without VFIO), `uio_irq_wait` (F3). The eventfd/ppoll plumbing is real;
device IRQs need MSI-X eventfds (F3-banked).

## Firmware (`hailbru.fw`)

| Function | Signature | Errors |
|----------|-----------|--------|
| `firmware_check` | `(arch: String, fw_root: String, entries: List[FirmwareEntry]) raises -> List[VerifiedBlob]` | `FirmwareMissing`, `FirmwareCorrupt`, `BadSysfs` |
| `sha256_file` / `sha256_hex` | pure Mojo SHA-256 | `BadSysfs` on unreadable file |
| `fw_plan_chunks` | `(total: Int64, chunk: Int64) -> List[ChunkDesc]` | none (pure) |
| `fw_stage_verify` | `(arch: String, path: String, expected: String) raises` | `FirmwareCorrupt` |
| `BootPoller` / `ReadyPoller` | structs | `FirmwareBootTimeout` / `DeviceNotReady` |

## Integrated-device RPC envelope

`hailbru.hrpc_frame` owns a pure-Mojo, non-device envelope codec for the
little-endian HailoRT v5.3.0 host protocol. It does not submit work or execute
models. `HrpcFrame` owns UInt32 message/action/remote-status values and copied
opaque body bytes. `encode_hrpc_frame` emits the exact logical packet;
`decode_hrpc_frame(data, padded_dma_buffer=False)` validates the 20-byte header,
magic, 2048-byte body maximum and exact packet size. Explicit padded mode
requires a 2068-byte message-buffer snapshot and excludes trailing bytes from
the body. This is not a claim about physical DMA alignment or transfer size.
Unknown actions and nonzero remote statuses are preserved, not interpreted.
Malformed frames raise `BadRpcFrame`; the native hex tool raises `BadRpcHex`
for invalid or excessive hex input. No device round-trip is implied.

## Packed integrated-device session ABI

`hailbru.soc_abi` owns Linux LP64 little-endian 5.3.0 packed codecs and the
admitted session request numbers. It encodes descriptor creation/release,
connect/close, masks and single user-pointer engine-zero transfers; it decodes
descriptor/channel outputs, driver properties/version and interrupt records.
Native `smidr/tools/soc_abi.mojo` consumes these interfaces without device
access. Invalid storage/arguments raise `BadSocAbi`. Numeric enums preserve
unknown values. Zero handles are admitted; the all-ones sentinel rejects.
This is byte compatibility, not DMA or session ownership admission. Callers
must establish identity, allocation, assigned resources and lifetime separately.

## Owned integrated-device driver file

`hailbru.soc_driver.open_soc_driver(sysfs_root, dev_root) raises -> SocDriver`
discovers the PCI identity and associated node, verifies the opened character
fd's device numbers, then queries/qualifies the installed 5.3.0 Hailo-10H
driver profile. `SocDriver` is movable, not copyable; `close()` is idempotent
and exception unwinding closes the fd. `request(operation, mut data)` accepts
only the admitted ABI operations, checks storage size and refuses a closed fd.
It returns `Int64`: successful transfer descriptor counts are preserved;
negative results raise with captured errno, and unexpected positive results
from other operations reject. A transfer count still needs ring-owner bounds
and completion checks; it does not itself mean completed work.
It is a low-level HAILBRÚ operation, not proof of descriptor/channel/buffer
ownership. The current real caller performs read-only driver queries.
Errors: `SocDriverMismatch`, `SocOpenFailed`, `SocSessionClosed`,
`SocIoctlFailed`, `SocCleanupFailed`, plus existing discovery/OS/ABI errors.

## Assigned integrated-device connection

`hailbru.soc_session.open_soc_session(sysfs_root, dev_root) raises -> SocSession`
owns the verified driver, two circular descriptor lists and assigned channels
for port 12133. `require_open()` rejects a closed owner; `close()` is idempotent.
Explicit cleanup and exception unwinding close the connection before releasing
lists. Uncertain connect/close uses file-context finalization; list cleanup
continues after an individual failure. Errors retain the driver/cleanup codes
above. The native consumer exercises the real lifecycle without user DMA
buffers, message exchange, model loading or inference. Transfer-buffer owners
must be added and independently verified before a typed RPC round-trip.

Caller: `smidr/tools/hrpc_frame.mojo`, a real native recorded-frame inspector.
Evidence: `docs/HAILO10H_MOJO_HRPC_FRAMING.md` and its independent wire tests.

`hailbru.hrpc_device` adds the pinned create/identify/destroy control messages.
`device_*_request(message_id[, handle])` returns an owned `HrpcFrame`.
Requests carry status 1 (`HAILO_UNINITIALIZED`), established by the installed
reference observation; successful replies require status 0.
`device_create_reply(frame, expected_message_id)` returns the UInt32 handle;
`device_identify_reply` returns observed numeric protocol/firmware/logger /
architecture fields plus explicit firmware-message presence. It never assumes
that absent/default identity fields prove Hailo-10H. `device_destroy_reply`
checks correlated success and bounded wire validity without asserting a live
device operation. Zero handles are valid protobuf values and are preserved.

This is a bounded proto3 subset, not a general protobuf runtime. It skips
unknown varint/fixed64/length-delimited/fixed32 fields, rejects duplicate
recognized singular fields, invalid keys, wrong known wire types, out-of-range
integers, length overruns and malformed varints. Correlation and remote-status
failure precede body decoding. Named errors are `BadRpcProtobuf`,
`RpcReplyMismatch` and `RpcRemoteFailure`.

Caller: native `smidr/tools/hrpc_device.mojo` and the planned owned session
client. Evidence: `docs/HAILO10H_MOJO_HRPC_DEVICE_MESSAGES.md` and current
`docs/HAILO10H_DMA_PROTOCOL_CORRECTIONS.md`.

## Thread-safety

HAILBRÚ has **no mutable globals** (verified by grep: zero module-level
`var` in `hailbru/*.mojo`). All state lives in caller-owned structs
(`DmaRegistry`, `BarMapping`, `BootPoller`). The `arch` parameter is
threaded explicitly. Functions are safe to call concurrently provided each
thread uses its own struct instances; sharing one `DmaRegistry` across
threads without external locking is not supported.

## No-bypass rule (L12)

HAILBRÚ is the ONLY domain that opens `/dev` nodes, mmaps PCI BARs, or
issues ioctls. The API exposes **no raw BAR pointer escape** and **no
direct /dev path parameters**: `BarMapping` and `DmaBuffer` are opaque
handles. Downstream domains go through this API; they never touch device
nodes directly. `grep -r "open.*dev\|mmap\|ioctl" --include="*.mojo"` outside
`hailbru/` must return empty (checked in C4_REVIEW.md).

## Original program metadata/lifecycle wire values (`hailbru.hrpc_program`)

`program_create_request(message_id, vdevice_handle, program_bytes, name,
host_program_limit)` constructs only bounded metadata. The separate program
bytes are not copied or sent. `program_handle_request(message_id, action,
handle)` admits action 3/5/10/11/12. `program_create_reply` returns a checked
handle; `program_empty_reply` validates a matching successful lifecycle reply.
All return owned values and open no device. These do not acquire/own actual
server resources, prove numerical program validity or admit hardware execution.
Wire conventions, tests and physical gates:
`docs/HAILO10H_MOJO_PROGRAM_RPC_CODEC.md`.

## Original configure/stream wire values (`hailbru.hrpc_configure`)

`HrpcInferStream` and `HrpcConfigureParams` own field values/lists.
`plain_infer_stream(name,order,kind)` supplies explicit non-NMS unset sentinels.
`configure_request(message_id,params)` returns an owned action4 HrpcFrame;
`configure_reply(frame,message_id)` returns typed handle/queue metadata.
Nonempty UTF-8 names, per-direction uniqueness, batch UInt16 range, valid
handles, pinned body bounds and strict reply wire/correlation/status checks
apply. Raw uint32 format/power/latency and fixed32 float words are metadata,
not device precision/capability admission. No device/resource owner or submission
consumer exists in this codec. Exact evidence and remaining physical gates:
`docs/HAILO10H_MOJO_CONFIGURE_RPC_CODEC.md`. New error: `BadConfigureRpc`;
shared framing/protobuf/program-handle/reply errors retain their prior codes.
