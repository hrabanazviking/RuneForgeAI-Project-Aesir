# H079 — compile-time API surface test.
#
# Imports every public name re-exported by hailbru.api and touches each
# one's type. If the frozen surface changes (rename/remove/signature
# drift), this file fails to COMPILE — the breakage is caught at build
# time, not by downstream domains at runtime.
#
# Build: mojo build -I . hailbru/tools/api_surface_test.mojo -o /tmp/api_surface_test

from hailbru.api import (
    Bdf,
    BarInfo,
    BarMapping,
    BootPoller,
    ChunkDesc,
    DmaBuffer,
    DmaRegistry,
    FirmwareEntry,
    LinkStatus,
    MechReport,
    PciIdentity,
    ReadyPoller,
    bars_sane,
    check_identity,
    discover,
    dma_cache_flush,
    dma_cache_invalidate,
    dma_fill_pattern,
    dma_verify_pattern,
    firmware_check,
    fw_plan_chunks,
    fw_stage_verify,
    herror,
    irq_close,
    irq_eventfd,
    irq_signal,
    irq_wait,
    irq_vfio_set_irqs,
    map_emulated,
    map_sysfs_resource,
    parse_bdf,
    parse_resource,
    probe_uio,
    probe_vfio,
    read_config_bytes,
    read_identity,
    read_link_status,
    read_power_state,
    reg_read16,
    reg_read32,
    reg_write32,
    reg_write32_verified,
    select_mechanism,
    sha256_file,
    sha256_hex,
    uio_dma_alloc,
    uio_driver_link_target,
    uio_find_nodes,
    uio_irq_wait,
    uio_mmap_bar_offset,
    uio_open,
    uio_step_bind,
    uio_step_register_id,
    uio_step_restore,
    uio_step_unbind,
    unmap_bar,
    vfio_assert_driver_bound,
    vfio_ioctl_checked,
    vfio_iommu_map,
    vfio_map_bar,
    vfio_open_container,
)


def main() raises:
    # Pure functions exercised at compile+run time (no hardware).
    var sel = select_mechanism(False, False)
    if sel != "sysfs-recon":
        raise herror("DmaError", "select_mechanism drift: " + sel)
    var chunks = fw_plan_chunks(1048576, 65536)
    if len(chunks) != 16:
        raise herror("DmaError", "fw_plan_chunks drift")
    var abc = List[UInt8]()
    abc.append(97)
    abc.append(98)
    abc.append(99)
    var h = sha256_hex(abc)
    if h != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad":
        raise herror("DmaError", "sha256_hex drift")
    var bdf = parse_bdf("0001:01:00.0")
    if bdf.domain != 1:
        raise herror("DmaError", "parse_bdf drift")
    # Opaque-handle types are nameable (no-bypass: no raw pointers escape).
    var reg = DmaRegistry()
    var poller = BootPoller(1000, UInt32(0xABCD), UInt32(0xFFFF))
    var rpoller = ReadyPoller(1000, UInt32(0x1), UInt32(0x1))
    _ = reg
    _ = poller
    _ = rpoller
    print("API surface OK: all imports resolve, pure functions stable")
