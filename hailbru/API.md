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
requires a 2068-byte DMA message and excludes trailing bytes from the body.
Unknown actions and nonzero remote statuses are preserved, not interpreted.
Malformed frames raise `BadRpcFrame`; the native hex tool raises `BadRpcHex`
for invalid or excessive hex input. No device round-trip is implied.

Caller: `smidr/tools/hrpc_frame.mojo`, a real native recorded-frame inspector.
Evidence: `docs/HAILO10H_MOJO_HRPC_FRAMING.md` and its independent wire tests.

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
