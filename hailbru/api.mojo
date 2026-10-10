# HAILBRU public API surface (H079).
#
# The frozen API that VÖRÐR (D6) and SMIÐR (D3) program against.
# Every public function, its named errors, and thread-safety contract
# are documented in hailbru/API.md; this module re-exports the surface
# so `from hailbru.api import discover` is the one import downstream
# domains need. (L12: the API exposes no raw BAR pointer escape and no
# direct /dev path parameters — BarMapping/DmaBuffer are opaque
# handles; see API.md § "no-bypass rule".)

from hailbru.discovery import Bdf, discover, parse_bdf
from hailbru.config import (
    PciIdentity,
    LinkStatus,
    check_identity,
    read_config_bytes,
    read_identity,
    read_link_status,
    read_power_state,
)
from hailbru.bars import BarInfo, bars_sane, parse_resource
from hailbru.mechanism import (
    MechReport,
    probe_uio,
    probe_vfio,
    select_mechanism,
)
from hailbru.vfio import (
    vfio_assert_driver_bound,
    vfio_ioctl_checked,
    vfio_map_bar,
    vfio_open_container,
)
from hailbru.uio import (
    uio_driver_link_target,
    uio_find_nodes,
    uio_mmap_bar_offset,
    uio_open,
    uio_step_bind,
    uio_step_register_id,
    uio_step_restore,
    uio_step_unbind,
)
from hailbru.dma import (
    DmaBuffer,
    DmaRegistry,
    dma_cache_flush,
    dma_cache_invalidate,
    dma_fill_pattern,
    dma_verify_pattern,
    uio_dma_alloc,
    vfio_iommu_map,
)
from hailbru.regs import (
    BarMapping,
    map_emulated,
    map_sysfs_resource,
    reg_read16,
    reg_read32,
    reg_write32,
    reg_write32_verified,
    unmap_bar,
)
from hailbru.irq import (
    irq_close,
    irq_eventfd,
    irq_signal,
    irq_vfio_set_irqs,
    irq_wait,
    uio_irq_wait,
)
from hailbru.fw import (
    BootPoller,
    ChunkDesc,
    FirmwareEntry,
    ReadyPoller,
    firmware_check,
    fw_plan_chunks,
    fw_stage_verify,
    sha256_file,
    sha256_hex,
)
from hailbru.errors import herror
from hailbru.pm import (
    PM_STATE_D0,
    PM_STATE_D3HOT,
    find_pm_cap,
    pm_assert_state,
    pm_read_pmcsr,
    pm_read_power_state_file,
    pm_set_state,
    pm_state_name,
)
from hailbru.bringup import (
    BRINGUP_EXPECTED_DEVICE,
    BRINGUP_EXPECTED_DRIVER,
    BRINGUP_EXPECTED_VENDOR,
    BringupOpts,
    bringup_dump_registers,
    run_bringup,
)
from hailbru.guard import SessionGuard, guard_acquire, guard_release
from hailbru.removal import (
    WatchedBar,
    watch_bar_emulated,
    watcher_read32,
    watcher_sever,
)
from hailbru.reset import ResetReport, ResetStep, golden_check, reset
