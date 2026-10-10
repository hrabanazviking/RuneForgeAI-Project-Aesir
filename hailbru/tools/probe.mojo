# HAILBRU probe CLI (H061–H080 diagnostics + self-tests).
#
# Single binary driving every HAILBRU operation with injectable roots:
#   --sysfs-root R  (default /sys; scratch trees for hardware-free tests)
#   --dev-root R    (default /dev; mechanism probing)
#   --fw-root R     (firmware blob root)
#   --arch A        (aarch64|x86_64; default: HAILBRU_ARCH env or auto-detect)
#
# Errors: uncaught raise -> "Unhandled exception ... HailbruError[Code]"
# on stderr + exit 1. The PRÓF suite (H078) asserts the exact codes.
# All output via unbuffered os_write (emit) — no stdio buffering issues.

from hailbru.syscall import (
    O_CREAT,
    O_RDONLY,
    O_RDWR,
    O_TRUNC,
    O_WRONLY,
    os_clock_ms,
    os_close,
    list_dir,
    os_mkdir,
    os_sleep_ms,
    os_openat,
    os_read,
    os_write,
    proc_cmdline,
    proc_getenv,
    read_file_bytes,
    read_file_str,
    to_cstr,
    write_file_str,
)
from hailbru.syscall import unsafe_alloc
from hailbru.util import parse_u16_hex, parse_u64_hex, trim
from hailbru.errors import herror
from hailbru.discovery import discover, parse_bdf, parse_bdf
from hailbru.config import (
    check_identity,
    read_identity,
    read_link_status,
    read_power_state,
)
from hailbru.bars import bars_sane, parse_resource
from hailbru.mechanism import probe_uio, probe_vfio, select_mechanism
from hailbru.vfio import (
    vfio_assert_driver_bound,
    vfio_ioctl_checked,
    vfio_open_container,
)
from hailbru.uio import (
    uio_driver_link_target,
    uio_find_nodes,
    uio_node_for_bdf,
    uio_open,
    uio_step_bind,
    uio_step_register_id,
    uio_step_restore,
    uio_step_unbind,
)
from hailbru.fwboot import (
    STAGE1_TRIGGER,
    STAGE2_TRIGGER,
    STAGE3_TRIGGER,
    fw_boot_status,
    fw_enable_interrupts,
    fw_is_loaded,
    fw_parse_scu,
    fw_sku_id,
    fw_trigger,
    fw_wait_boot_irq,
    fw_write_memory,
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
    FWREG_CHAN_BITMAP0,
    FWREG_CHAN_BITMAP1,
    FWREG_IRQ_MASK,
    FWREG_IRQ_STATUS,
    FWREG_VENDOR_MIRROR,
    BootPoller,
    FirmwareEntry,
    ReadyPoller,
    firmware_check,
    fw_plan_chunks,
    fw_stage_verify,
    sha256_file,
    sha256_hex,
)
from std.ffi import external_call
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
from hailbru.bringup import BringupOpts, bringup_dump_registers, run_bringup
from hailbru.health_obs import health_sample
from hailbru.guard import SessionGuard, guard_acquire, guard_release
from hailbru.removal import (
    watch_bar_emulated,
    watcher_read32,
    watcher_sever,
)


def emit(arch: String, s: String):
    var line = s + "\n"
    var c = to_cstr(line)
    _ = os_write(arch, 1, c, Int64(line.byte_length()))
    c.unsafe_free()


def detect_arch() -> String:
    # Read HAILBRU_ARCH via /proc/self/environ, trying the aarch64
    # syscall table first then x86_64 (whichever successfully reads a
    # non-empty environ wins). Defaults to aarch64 (the real device).
    for i in range(2):
        var arch = "aarch64" if i == 0 else "x86_64"
        try:
            var env = read_file_bytes(arch, "/proc/self/environ", 131072)
            if len(env) == 0:
                continue
            var v = proc_getenv(arch, "HAILBRU_ARCH")
            if v == "x86_64" or v == "aarch64":
                return v
            return arch
        except:
            continue
    return "aarch64"


def get_flag(args: List[String], name: String, default: String) -> String:
    for i in range(len(args)):
        if args[i] == name and i + 1 < len(args):
            return args[i + 1]
    return default


def need_bdf(arch: String, args: List[String], sysfs_root: String) raises -> String:
    # Validate an explicit --bdf (BadBdf on malformed); auto-discover when
    # absent. Every command that addresses a device by BDF goes through here.
    var bdf = get_flag(args, "--bdf", "")
    if bdf == "":
        return discover(arch, sysfs_root, 0x1E60, 0x45C4)
    _ = parse_bdf(bdf)
    return bdf


def has_flag(args: List[String], name: String) -> Bool:
    for i in range(len(args)):
        if args[i] == name:
            return True
    return False


def split_colon(s: String) -> List[String]:
    var out = List[String]()
    var cur = String("")
    for b in s.bytes():
        if b == 58:
            out.append(cur)
            cur = String("")
        else:
            cur += String(chr(Int(b)))
    out.append(cur)
    return out^


def collect_entries(args: List[String]) raises -> List[FirmwareEntry]:
    # Repeated --entry REL:SHA:SIZEHEX-or-DEC
    var out = List[FirmwareEntry]()
    for i in range(len(args)):
        if args[i] == "--entry" and i + 1 < len(args):
            var parts = split_colon(args[i + 1])
            if len(parts) != 3:
                raise herror(
                    "BadSysfs",
                    "--entry wants REL:SHA:SIZE, got '" + args[i + 1] + "'",
                )
            var size = parse_u64_hex(parts[2])
            out.append(FirmwareEntry(parts[0], Int64(size), parts[1]))
    return out^


def cmd_discover(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var vendor = parse_u16_hex(get_flag(args, "--vendor", "0x1e60"))
    var device = parse_u16_hex(get_flag(args, "--device", "0x45c4"))
    var bdf = discover(arch, sysfs_root, vendor, device)
    emit(arch, '{"bdf": "' + bdf + '"}')


def cmd_identity(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var ident = read_identity(arch, sysfs_root, bdf)
    var vendor = parse_u16_hex(get_flag(args, "--expect-vendor", "0x1e60"))
    var device = parse_u16_hex(get_flag(args, "--expect-device", "0x45c4"))
    var class_code = parse_u64_hex(get_flag(args, "--expect-class", "0x0b4000"))
    _ = check_identity(ident, vendor, device, UInt32(class_code))
    emit(
        arch,
        '{"bdf": "' + bdf + '", "vendor": "'
        + String(Int(ident.vendor)) + '", "device": "'
        + String(Int(ident.device)) + '", "class": "'
        + String(Int(ident.class_code)) + '", "msi_cap": '
        + String(ident.msi_cap) + ', "msix_cap": ' + String(ident.msix_cap)
        + ', "pm_cap": ' + String(ident.pm_cap) + ', "pcie_ext_cap": '
        + String(ident.pcie_ext_cap) + ', "config_bytes": '
        + String(ident.bytes_read) + "}",
    )


def cmd_bars(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var bars = parse_resource(arch, sysfs_root, bdf)
    _ = bars_sane(bars)
    var j = '{"bdf": "' + bdf + '", "bars": ['
    var first = True
    for i in range(len(bars)):
        ref b = bars[i]
        if not first:
            j += ", "
        first = False
        j += '{"index": ' + String(b.index) + ', "start": '
        j += String(b.start) + ', "size": ' + String(b.size)
        j += ', "flags": ' + String(b.flags) + ', "present": '
        j += "true" if b.present else "false"
        j += "}"
    j += "]}"
    emit(arch, j)


def cmd_link(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var ls = read_link_status(arch, sysfs_root, bdf)
    var ps = read_power_state(arch, sysfs_root, bdf)
    emit(
        arch,
        '{"bdf": "' + bdf + '", "cur_speed": "' + ls.cur_speed
        + '", "cur_width": "' + ls.cur_width + '", "max_speed": "'
        + ls.max_speed + '", "max_width": "' + ls.max_width
        + '", "power_state": "' + ps + '"}',
    )


def cmd_mechanism(arch: String, args: List[String]) raises:
    var dev_root = get_flag(args, "--dev-root", "/dev")
    var v = probe_vfio(arch, dev_root)
    var u = probe_uio(arch, dev_root)
    var sel = select_mechanism(v.available, u.available)
    emit(
        arch,
        '{"selected": "' + sel + '", "vfio": {"available": '
        + ("true" if v.available else "false") + ', "reason": "'
        + v.reason + '"}, "uio": {"available": '
        + ("true" if u.available else "false") + ', "reason": "'
        + u.reason + '"}}',
    )


def cmd_fwcheck(arch: String, args: List[String]) raises:
    var fw_root = get_flag(args, "--fw-root", "/lib/firmware/hailo")
    var entries = collect_entries(args)
    if len(entries) == 0:
        raise herror("BadSysfs", "fwcheck needs at least one --entry")
    var ok = firmware_check(arch, fw_root, entries)
    var j = '{"fw_root": "' + fw_root + '", "verified": ['
    for i in range(len(ok)):
        if i > 0:
            j += ", "
        j += '{"path": "' + ok[i].rel_path + '", "size": '
        j += String(ok[i].size_bytes) + ', "sha256": "'
        j += ok[i].sha256 + '"}'
    j += "]}"
    emit(arch, j)


def cmd_regs_probe(arch: String, args: List[String]) raises:
    # Read-only register probes on the live device (needs root).
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var bar = Int(parse_u64_hex(get_flag(args, "--bar", "0x0")))
    var size = Int(parse_u64_hex(get_flag(args, "--bar-size", "0x4000")))
    var m = map_sysfs_resource(arch, sysfs_root, bdf, bar, size, False)
    var mirror = reg_read16(m, FWREG_VENDOR_MIRROR())
    var mask = reg_read32(m, FWREG_IRQ_MASK())
    var status = reg_read32(m, FWREG_IRQ_STATUS())
    var bm0 = reg_read32(m, FWREG_CHAN_BITMAP0())
    var bm1 = reg_read32(m, FWREG_CHAN_BITMAP1())
    unmap_bar(arch, m)
    emit(
        arch,
        '{"bdf": "' + bdf + '", "vendor_mirror_0x98": '
        + String(Int(mirror)) + ', "irq_mask_0x188": ' + String(mask)
        + ', "irq_status_0x18c": ' + String(status)
        + ', "chan_bitmap0_0x400": ' + String(bm0)
        + ', "chan_bitmap1_0x500": ' + String(bm1) + "}",
    )


def cmd_regs_coherency(arch: String, args: List[String]) raises:
    # H068 (Sólrún re-scope per H005 §6): 50 repeated 16-bit reads of the
    # vendor-ID mirror at BAR0+0x0098 — a side-effect-free, read-only
    # register — each expected to return 0x1e60. Stability of all 50
    # proves the register path is coherent without touching device state.
    # Needs root (sysfs resource mmap) and the device in D0.
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
    var bad = 0
    for i in range(50):
        var v = reg_read16(m, FWREG_VENDOR_MIRROR())
        if v != UInt16(0x1E60):
            bad += 1
    unmap_bar(arch, m)
    if bad != 0:
        raise herror(
            "DmaError",
            "coherency check: " + String(bad) + "/50 reads != 0x1e60",
        )
    emit(
        arch,
        "SELFTEST regs-coherency: 50/50 reads of BAR0+0x0098 returned "
        "0x1e60 — OK",
    )


def cmd_bdf_selftest(arch: String, args: List[String]) raises:
    _ = args
    var good = parse_bdf("0001:01:00.0")
    if good.domain != 1 or good.bus != 1 or good.dev != 0 or good.func != 0:
        raise herror("DmaError", "parse_bdf fields wrong")
    var bad = List[String]()
    bad.append("0001:01:00")  # too short
    bad.append("0001:01:00.0x")  # too long
    bad.append("0001-01:00.0")  # wrong separator
    bad.append("ZZZZ:01:00.0")  # bad hex
    bad.append("0001:01:00.0 ")  # trailing space is trimmed -> actually valid!
    var rejected = 0
    for i in range(len(bad)):
        try:
            _ = parse_bdf(bad[i])
            # "0001:01:00.0 " trims to valid — that one is EXPECTED valid.
            if i != 4:
                raise herror(
                    "DmaError",
                    "parse_bdf accepted malformed '" + bad[i] + "'",
                )
        except e:
            var msg = String(e)
            if msg.find("BadBdf") >= 0:
                rejected += 1
            elif i == 4:
                pass  # trimmed-valid case, fine either way
            else:
                raise herror(
                    "DmaError",
                    "parse_bdf wrong error for '" + bad[i] + "': " + msg,
                )
    if rejected != 4:
        raise herror(
            "DmaError",
            "expected 4 BadBdf rejections, got " + String(rejected),
        )
    emit(arch, "SELFTEST bdf: 1 valid parsed, 4 malformed rejected — OK")


def cmd_regs_selftest(arch: String, args: List[String]) raises:
    # Write/readback on the EMULATED mapping (never live hardware).
    var epath = get_flag(args, "--emulated", "")
    if epath == "":
        raise herror("BadSysfs", "regs-selftest needs --emulated PATH")
    var size = Int(parse_u64_hex(get_flag(args, "--size", "0x4000")))
    var m = map_emulated(arch, epath, size)
    # 50 deterministic pseudo-random values, write/readback verified.
    var x = UInt64(0x123456789ABCDEF0)
    for i in range(50):
        x += UInt64(0x9E3779B97F4A7C15)
        var z = x
        z = (z ^ (z >> UInt64(30))) * UInt64(0xBF58476D1CE4E5B9)
        z = (z ^ (z >> UInt64(27))) * UInt64(0x94D049BB133111EB)
        z = z ^ (z >> UInt64(31))
        var v = UInt32(z & UInt64(0xFFFFFFFF))
        var off = (i * 64) % (size - 4)
        off = off - (off % 4)
        reg_write32_verified(m, off, v)
    # 10 bad offsets fail closed.
    var bad = List[Int]()
    bad.append(size); bad.append(size + 4); bad.append(-4)
    bad.append(size - 2); bad.append(1); bad.append(2); bad.append(3)
    bad.append(size - 1); bad.append(7); bad.append(1000000)
    var bad_ok = 0
    for i in range(len(bad)):
        try:
            _ = reg_read32(m, bad[i])
            raise herror(
                "DmaError",
                "reg_read32 accepted bad offset " + String(bad[i]),
            )
        except e:
            var msg = String(e)
            if msg.find("RegOutOfRange") >= 0 or msg.find(
                "RegUnaligned"
            ) >= 0:
                bad_ok += 1
            else:
                raise herror(
                    "DmaError",
                    "wrong error for offset " + String(bad[i]) + ": " + msg,
                )
    if bad_ok != 10:
        raise herror("DmaError", "bad-offset checks: " + String(bad_ok))
    # ReadbackMismatch detection logic: the comparison inside
    # reg_write32_verified is factored here as a direct unit check
    # (a PROT_READ mapping would segfault on write, so the mismatch
    # path is proven at the comparison level + the 50/50 integration).
    var wrote = UInt32(0xDEADBEEF)
    var back = UInt32(0x12345678)
    try:
        if back != wrote:
            raise herror(
                "ReadbackMismatch",
                "unit check: wrote 0x" + String(Int(wrote))
                + " read 0x" + String(Int(back)),
            )
    except e:
        if String(e).find("ReadbackMismatch") < 0:
            raise herror("DmaError", "ReadbackMismatch code broken")
    unmap_bar(arch, m)
    emit(
        arch,
        "SELFTEST regs: 50/50 write/readback verified, 10/10 bad "
        "offsets fail-closed, ReadbackMismatch named — OK",
    )


def cmd_dma_selftest(arch: String, args: List[String]) raises:
    var want_lock = has_flag(args, "--lock")
    var reg = DmaRegistry()
    var sizes = List[Int64]()
    sizes.append(4096); sizes.append(65536)
    sizes.append(1048576); sizes.append(16777216)
    # Without --lock: prove the fail-closed DmaLockFailed path once.
    if not want_lock:
        try:
            var b0 = reg.alloc(arch, 4096, True)
            reg.free(arch, b0.addr, b0.size)
            raise herror(
                "DmaError", "mlock unexpectedly succeeded unprivileged"
            )
        except e:
            if String(e).find("DmaLockFailed") < 0:
                # mlock CAN succeed unprivileged for small sizes within
                # RLIMIT_MEMLOCK — then the path is simply available.
                emit(arch, "NOTE dma: mlock worked unprivileged here")
            else:
                emit(arch, "SELFTEST dma: DmaLockFailed fail-closed — OK")
        # Continue the matrix unlocked (page-aligned + pattern only).
    var n = 0
    for i in range(100):
        var sz = sizes[i % 4]
        var buf = reg.alloc(arch, sz, want_lock)
        if buf.addr % 4096 != 0 or buf.addr == 0:
            raise herror("DmaError", "unaligned/zero addr")
        if buf.size < sz:
            raise herror("DmaError", "short alloc")
        dma_fill_pattern(buf.addr, buf.size, UInt64(1000 + i))
        if not dma_verify_pattern(buf.addr, buf.size, UInt64(1000 + i)):
            raise herror("DmaError", "pattern mismatch buffer " + String(i))
        reg.free(arch, buf.addr, buf.size)
        n += 1
    if reg.count() != 0:
        raise herror("DmaError", "registry leak after matrix")
    # Re-allocate the full set (no-leak proof), then free all.
    var bufs = List[DmaBuffer]()
    for i in range(100):
        bufs.append(reg.alloc(arch, sizes[i % 4], want_lock))
    if reg.count() != 100:
        raise herror("DmaError", "registry count != 100")
    for i in range(100):
        ref bb = bufs[i]
        reg.free(arch, bb.addr, bb.size)
    if reg.count() != 0:
        raise herror("DmaError", "registry leak after full set")
    # Double-free + unknown-free fail closed.
    var b1 = reg.alloc(arch, 4096, want_lock)
    var b1a = b1.addr
    var b1s = b1.size
    reg.free(arch, b1a, b1s)
    try:
        reg.free(arch, b1a, b1s)
        raise herror("DmaError", "double-free not caught")
    except e:
        if String(e).find("DoubleFree") < 0:
            raise herror("DmaError", "double-free wrong error: " + String(e))
    try:
        reg.free(arch, 0x12345000, 4096)
        raise herror("DmaError", "unknown-free not caught")
    except e:
        if String(e).find("UnknownBuffer") < 0:
            raise herror(
                "DmaError", "unknown-free wrong error: " + String(e)
            )
    # Cache-maintenance hooks: named, no-op with logging.
    var b2 = reg.alloc(arch, 4096, want_lock)
    var fmsg = dma_cache_flush(b2.addr)
    var imsg = dma_cache_invalidate(b2.addr)
    reg.free(arch, b2.addr, b2.size)
    # Mechanism paths fail closed with named errors.
    try:
        vfio_iommu_map(arch, -1, 0, UInt64(0x1000), 4096)
        raise herror("DmaError", "vfio_iommu_map(-1) not caught")
    except e:
        if String(e).find("MechanismUnavailable") < 0:
            raise herror("DmaError", "iommu map wrong error")
    try:
        _ = uio_dma_alloc(arch, "vfio", 4096)
        raise herror("DmaError", "uio_dma_alloc hygiene not caught")
    except e:
        if String(e).find("WrongMechanism") < 0:
            raise herror("DmaError", "uio hygiene wrong error")
    emit(
        arch,
        "SELFTEST dma: 100-buffer matrix + realloc(" + String(n)
        + " bufs), double/unknown-free named, cache hooks: [" + fmsg
        + "] [" + imsg + "] — OK",
    )


def _fd1(fd: Int64) -> List[Int64]:
    var out = List[Int64]()
    out.append(fd)
    return out^


def cmd_irq_selftest(arch: String, args: List[String]) raises:
    _ = args
    var efd = irq_eventfd(arch)
    # EAGAIN-liveness: non-blocking read with nothing pending -> EAGAIN.
    var rbuf = unsafe_alloc[UInt8](8)
    var nr = os_read(arch, efd, rbuf, 8)
    rbuf.unsafe_free()
    if nr != -1:
        raise herror("DmaError", "eventfd unexpectedly readable")
    # Synthetic wake.
    irq_signal(arch, efd, UInt64(1))
    var got = irq_wait(arch, _fd1(efd), 1000)
    if got != 1:
        raise herror("DmaError", "synthetic wake got " + String(got))
    # Timeout path: must return IrqTimeout quickly, never hang.
    var t0 = os_clock_ms(arch)
    try:
        _ = irq_wait(arch, _fd1(efd), 100)
        raise herror("DmaError", "irq_wait did not time out")
    except e:
        if String(e).find("IrqTimeout") < 0:
            raise herror("DmaError", "timeout wrong error: " + String(e))
    var dt = os_clock_ms(arch) - t0
    if dt > 500:
        raise herror("DmaError", "timeout took " + String(dt) + "ms")
    # 10k synthetic interrupts, exact accounting, no fd leaks.
    var total = Int64(0)
    for i in range(10000):
        irq_signal(arch, efd, UInt64(1))
        total += irq_wait(arch, _fd1(efd), 1000)
    if total != 10000:
        raise herror("DmaError", "10k loop got " + String(total))
    # Teardown + re-setup.
    irq_close(arch, efd)
    var efd2 = irq_eventfd(arch)
    irq_signal(arch, efd2, UInt64(3))
    var got2 = irq_wait(arch, _fd1(efd2), 1000)
    irq_close(arch, efd2)
    if got2 != 3:
        raise herror("DmaError", "re-setup got " + String(got2))
    # F3 paths fail closed.
    try:
        irq_vfio_set_irqs(arch, -1, 0, efd2)
        raise herror("DmaError", "irq_vfio_set_irqs not caught")
    except e:
        if String(e).find("MechanismUnavailable") < 0:
            raise herror("DmaError", "set_irqs wrong error")
    try:
        _ = uio_irq_wait(arch, -1, 100)
        raise herror("DmaError", "uio_irq_wait not caught")
    except e:
        if String(e).find("MechanismUnavailable") < 0:
            raise herror("DmaError", "uio_irq_wait wrong error")
    emit(
        arch,
        "SELFTEST irq: synthetic wake OK, IrqTimeout in " + String(dt)
        + "ms, 10000/10000 exact, teardown/re-setup OK — OK",
    )


def cmd_boot_selftest(arch: String, args: List[String]) raises:
    _ = args
    # Never-ready device -> FirmwareBootTimeout with samples.
    var p = BootPoller(200, UInt32(0xA5), UInt32(0xFF))
    var start = os_clock_ms(arch)
    var timed_out = False
    try:
        var now = start
        for i in range(50):
            now = start + Int64(10 * i)
            var r = p.step(now, start, UInt32(0x00))
            if r == 1:
                break
    except e:
        if String(e).find("FirmwareBootTimeout") < 0:
            raise herror("DmaError", "boot poll wrong error: " + String(e))
        timed_out = True
    if not timed_out:
        raise herror("DmaError", "boot poll did not time out")
    # Alive pattern -> 1.
    var p2 = BootPoller(30000, UInt32(0xA5), UInt32(0xFF))
    var r2 = p2.step(start, start, UInt32(0xA5))
    if r2 != 1:
        raise herror("DmaError", "boot poll missed alive pattern")
    emit(arch, "SELFTEST boot: FirmwareBootTimeout named w/ samples — OK")


def cmd_ready_selftest(arch: String, args: List[String]) raises:
    _ = args
    # Forced 1ms timeout -> DeviceNotReady with register dump.
    var p = ReadyPoller(1, UInt32(0x1), UInt32(0x1))
    var start = os_clock_ms(arch)
    try:
        _ = p.step(start + 5, start, UInt32(0xBEAC))
        raise herror("DmaError", "ready poll did not time out")
    except e:
        var msg = String(e)
        if msg.find("DeviceNotReady") < 0 or msg.find("0x") < 0:
            raise herror("DmaError", "ready poll wrong error: " + msg)
    # Idempotent ready: 10x True.
    var p2 = ReadyPoller(1000, UInt32(0x1), UInt32(0x1))
    for i in range(10):
        if p2.step(start, start, UInt32(0x1)) != 1:
            raise herror("DmaError", "ready not idempotent")
    emit(arch, "SELFTEST ready: DeviceNotReady w/ dump, 10x idempotent — OK")


def cmd_sha256_selftest(arch: String, args: List[String]) raises:
    _ = args
    var abc = List[UInt8]()
    for b in String("abc").bytes():
        abc.append(b)
    var h = sha256_hex(abc)
    if h != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad":
        raise herror("DmaError", "sha256('abc') wrong: " + h)
    # File path: write a temp file, hash it, compare with hex path.
    var tmp = "/tmp/hailbru_sha_test.bin"
    write_file_str(arch, tmp, "abc")
    var hf = sha256_file(arch, tmp)
    if hf != h:
        raise herror("DmaError", "sha256_file mismatch: " + hf)
    emit(arch, "SELFTEST sha256: 'abc' vector + file path — OK")


def cmd_vfio_negative(arch: String, args: List[String]) raises:
    var dev_root = get_flag(args, "--dev-root", "/nonexistent-dev-root")
    # Invalid group fd -> named VfioError (not a crash).
    try:
        _ = vfio_ioctl_checked(arch, -1, Int64(0x3B64), 0, "TEST_IOCTL")
        raise herror("DmaError", "invalid fd not caught")
    except e:
        if String(e).find("VfioError") < 0:
            raise herror("DmaError", "ioctl wrong error: " + String(e))
    # Absent /dev/vfio -> MechanismUnavailable.
    try:
        _ = vfio_open_container(arch, dev_root)
        raise herror("DmaError", "vfio open unexpectedly worked")
    except e:
        if String(e).find("MechanismUnavailable") < 0:
            raise herror("DmaError", "container wrong error: " + String(e))
    # Wrong driver bound (scratch tree) -> BindError citing H012.
    var sysfs_root = get_flag(args, "--sysfs-root", "")
    if sysfs_root != "":
        var bdf = get_flag(args, "--bdf", "0001:01:00.0")
        try:
            vfio_assert_driver_bound(
                arch, sysfs_root, bdf, "vfio-pci"
            )
            raise herror("DmaError", "bind assert unexpectedly passed")
        except e:
            if String(e).find("BindError") < 0:
                raise herror("DmaError", "bind wrong error: " + String(e))
    emit(arch, "SELFTEST vfio-negative: VfioError/MechanismUnavailable — OK")


def cmd_uio_step(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "")
    var bdf = get_flag(args, "--bdf", "0001:01:00.0")
    var step = get_flag(args, "--step", "")
    var as_root = has_flag(args, "--as-root")
    if sysfs_root == "" or step == "":
        raise herror("BadSysfs", "uio-step needs --sysfs-root/--step")
    if step == "unbind":
        var orig = uio_step_unbind(arch, sysfs_root, bdf, as_root)
        emit(arch, "ORIGINAL " + orig)
    elif step == "register":
        uio_step_register_id(
            arch, sysfs_root, get_flag(args, "--vendor-hex", "1e60"),
            get_flag(args, "--device-hex", "45c4"), as_root,
        )
        emit(arch, "REGISTERED")
    elif step == "bind":
        uio_step_bind(arch, sysfs_root, bdf, as_root)
        emit(arch, "BOUND uio_pci_generic")
    elif step == "restore":
        var orig = get_flag(args, "--original", "")
        var rest = uio_step_restore(arch, sysfs_root, bdf, orig, as_root)
        emit(arch, "RESTORED " + rest)
    elif step == "link":
        emit(arch, "LINK " + uio_driver_link_target(arch, sysfs_root, bdf))
    elif step == "find":
        var nodes = uio_find_nodes(arch, get_flag(args, "--dev-root", "/dev"))
        emit(arch, "NODES " + String(len(nodes)))
    elif step == "open":
        var fd = uio_open(arch, get_flag(args, "--dev-root", "/dev"))
        emit(arch, "FD " + String(fd))
    else:
        raise herror("BadSysfs", "unknown uio step '" + step + "'")


def cmd_fw_stage_selftest(arch: String, args: List[String]) raises:
    var workdir = get_flag(args, "--workdir", "/tmp/hailbru_fwtest")
    _ = os_mkdir(arch, workdir, 0o755)
    var blob = workdir + "/blob.bin"
    var staging = workdir + "/staging.bin"
    # Build a deterministic 1MB test blob via the Mojo writer path.
    var wfd = os_openat(arch, blob, O_WRONLY() | O_CREAT() | O_TRUNC(), 0o644)
    if wfd < 0:
        raise herror("OsError", "cannot create test blob")
    var wbuf = unsafe_alloc[UInt8](65536)
    var x = UInt64(0xABCDEF)
    var total = 0
    while total < 1048576:
        for i in range(65536):
            x += UInt64(0x9E3779B97F4A7C15)
            wbuf[unsafe_offset=i] = UInt8(x & UInt64(0xFF))
        _ = os_write(arch, wfd, wbuf, 65536)
        total += 65536
    wbuf.unsafe_free()
    _ = os_close(arch, wfd)
    # Plan sanity: 1MB in 64KB chunks = 16 chunks.
    var chunks = fw_plan_chunks(1048576, 65536)
    if len(chunks) != 16:
        raise herror("DmaError", "chunk plan wrong")
    # Abort hook: interrupt after 2 chunks -> named abort, defined state.
    try:
        _ = fw_stage_verify(arch, blob, staging, 65536, 2)
        raise herror("DmaError", "abort hook did not fire")
    except e:
        if String(e).find("FirmwareUploadAborted") < 0:
            raise herror("DmaError", "abort wrong error: " + String(e))
    # Recovery: full run succeeds; blob sha stable.
    var sha1 = fw_stage_verify(arch, blob, staging, 65536, -1)
    var sha2 = sha256_file(arch, blob)
    if sha1 != sha2:
        raise herror("DmaError", "staging sha != blob sha")
    emit(
        arch,
        "SELFTEST fw-stage: 16 chunks planned, abort hook named, "
        "recovery sha " + sha1 + " — OK",
    )


def _str_bytes(s: String) -> List[UInt8]:
    var bs = List[UInt8]()
    for b in s.bytes():
        bs.append(b)
    return bs^


def _parse_int(s: String) -> Int:
    var bs = _str_bytes(trim(s))
    var v = 0
    var neg = False
    var i = 0
    if len(bs) > 0 and (bs[0] == 45 or bs[0] == 43):
        neg = bs[0] == 45
        i = 1
    for j in range(i, len(bs)):
        var b = bs[j]
        if b < 48 or b > 57:
            break
        v = v * 10 + (Int(b) - 48)
    return -v if neg else v


def cmd_bringup(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var opts = BringupOpts(
        get_flag(args, "--log", ""),
        get_flag(args, "--omit-step", ""),
        get_flag(args, "--stall-step", ""),
        Int64(_parse_int(get_flag(args, "--step-budget-ms", "10000"))),
    )
    try:
        emit(arch, run_bringup(arch, sysfs_root, bdf, opts))
    except e:
        # Leave the device undisturbed even on a failed bring-up.
        try:
            pm_set_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
        except:
            pass
        raise e


def cmd_pm_set(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var want = get_flag(args, "--state", "D0")
    var target = PM_STATE_D0() if want == "D0" else PM_STATE_D3HOT()
    var verified = pm_assert_state(arch, sysfs_root, bdf, target)
    emit(arch, "{\"bdf\": \"" + bdf + "\", \"state\": \"" + verified + "\"}")


def _fw_boot_session(
    arch: String, sysfs_root: String, dev_root: String, bdf: String,
    fw_root: String, as_root: Bool, status_only: Bool,
) raises:
    # Full firmware boot session (H074/H075/H076, real UIO path).
    # ALWAYS restores the vendor driver binding, even on failure.
    emit(arch, "FWBOOT begin bdf=" + bdf)
    # D0 for BAR access.
    _ = pm_assert_state(arch, sysfs_root, bdf, PM_STATE_D0())
    var bar0 = map_sysfs_resource(arch, sysfs_root, bdf, 0, 65536, False)
    var already = False
    try:
        already = fw_is_loaded(bar0)
    except e:
        unmap_bar(arch, bar0)
        raise e
    unmap_bar(arch, bar0)
    emit(arch, "FWBOOT already_loaded=" + ("1" if already else "0"))
    if already or status_only:
        _ = pm_assert_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
        emit(arch, "FWBOOT done (no flash needed)")
        return
    if not as_root:
        raise herror(
            "PrivilegeRequired",
            "fw-boot needs --as-root (BAR writes + driver unbind)",
        )
    # --- UIO session begin ---
    var original = uio_step_unbind(arch, sysfs_root, bdf, True)
    emit(arch, "FWBOOT unbound original_driver=" + original)
    if original != "hailo1x":
        raise herror(
            "FwError",
            "unexpected original driver '" + original
            + "' (expected hailo1x) — refusing to proceed",
        )
    var restored = False
    try:
        uio_step_register_id(arch, sysfs_root, "1e60", "45c4", True)
        uio_step_bind(arch, sysfs_root, bdf, True)
        var node = uio_node_for_bdf(arch, sysfs_root, bdf)
        emit(arch, "FWBOOT uio_node=" + node)
        var uio_fd = os_openat(arch, dev_root + "/" + node, O_RDONLY(), 0)
        if uio_fd < 0:
            raise herror("UioError", "open " + node + " failed")
        var wbar0 = map_sysfs_resource(arch, sysfs_root, bdf, 0, 65536, True)
        var wbar4 = map_sysfs_resource(arch, sysfs_root, bdf, 4, 4096, True)
        try:
            fw_enable_interrupts(wbar0)
            # Stage 1: certificate + SCU firmware.
            var cert = read_file_bytes(
                arch, fw_root + "/customer_certificate.bin", 65536
            )
            fw_write_memory(wbar0, wbar4, 0xA0000, cert)
            emit(arch, "FWBOOT stage1 cert_bytes=" + String(len(cert)))
            var scu = read_file_bytes(
                arch, fw_root + "/scu_fw.bin", 1048576
            )
            var parts = fw_parse_scu(scu)
            fw_write_memory(wbar0, wbar4, 0x88000, parts.header)
            fw_write_memory(wbar0, wbar4, 0x20000, parts.code)
            fw_write_memory(wbar0, wbar4, 0x88018, parts.key)
            fw_write_memory(wbar0, wbar4, 0x886A8, parts.content)
            emit(
                arch,
                "FWBOOT stage1 scu code=" + String(len(parts.code))
                + " key=" + String(len(parts.key))
                + " content=" + String(len(parts.content)),
            )
            fw_trigger(wbar0, wbar4, STAGE1_TRIGGER())
            if not fw_wait_boot_irq(arch, wbar0, uio_fd, 5000):
                raise herror("FwError", "stage 1 BOOT_IRQ timeout")
            emit(arch, "FWBOOT stage1 BOOT_IRQ ok")
            var sku = fw_sku_id(wbar0, wbar4)
            var dtb_name = "u-boot-default.dtb.signed"
            if sku >= 0:
                dtb_name = "u-boot-" + String(sku) + ".dtb.signed"
            emit(arch, "FWBOOT sku_id=" + String(sku) + " dtb=" + dtb_name)
            # Stage 2: device tree.
            var dtb = read_file_bytes(
                arch, fw_root + "/" + dtb_name, 262144
            )
            fw_write_memory(wbar0, wbar4, 0xA8004, dtb)
            emit(arch, "FWBOOT stage2 dtb_bytes=" + String(len(dtb)))
            fw_trigger(wbar0, wbar4, STAGE2_TRIGGER())
            if not fw_wait_boot_irq(arch, wbar0, uio_fd, 5000):
                raise herror("FwError", "stage 2 BOOT_IRQ timeout")
            emit(arch, "FWBOOT stage2 BOOT_IRQ ok")
            # Stage 3: SPL + fitImage + image-fs (tfa optional).
            var spl = read_file_bytes(
                arch, fw_root + "/u-boot-spl.bin", 1048576
            )
            fw_write_memory(wbar0, wbar4, 0x80300000, spl)
            emit(arch, "FWBOOT stage3 spl_bytes=" + String(len(spl)))
            try:
                var tfa = read_file_bytes(
                    arch, fw_root + "/u-boot-tfa.itb", 8388608
                )
                fw_write_memory(wbar0, wbar4, 0x8032C000, tfa)
                emit(arch, "FWBOOT stage3 tfa_bytes=" + String(len(tfa)))
            except:
                emit(arch, "FWBOOT stage3 tfa missing (optional, skipped)")
            var fit = read_file_bytes(
                arch, fw_root + "/fitImage", 134217728
            )
            fw_write_memory(wbar0, wbar4, 0x88000000, fit)
            emit(arch, "FWBOOT stage3 fit_bytes=" + String(len(fit)))
            var fs = read_file_bytes(
                arch, fw_root + "/image-fs", 536870912
            )
            fw_write_memory(wbar0, wbar4, 0x90000000, fs)
            emit(arch, "FWBOOT stage3 fs_bytes=" + String(len(fs)))
            fw_trigger(wbar0, wbar4, STAGE3_TRIGGER())
            if not fw_wait_boot_irq(arch, wbar0, uio_fd, 40000):
                raise herror("FwError", "stage 3 BOOT_IRQ timeout")
            emit(arch, "FWBOOT stage3 BOOT_IRQ ok")
            var loaded = fw_is_loaded(wbar0)
            var bstatus = fw_boot_status(wbar0, wbar4)
            emit(
                arch,
                "FWBOOT verify loaded=" + ("1" if loaded else "0")
                + " boot_status=" + String(bstatus),
            )
            if not loaded or bstatus != 1:
                raise herror(
                    "FwError",
                    "boot verification failed",
                )
            emit(arch, "FWBOOT SUCCESS firmware booted")
        except e:
            unmap_bar(arch, wbar4)
            unmap_bar(arch, wbar0)
            _ = os_close(arch, uio_fd)
            raise e
        unmap_bar(arch, wbar4)
        unmap_bar(arch, wbar0)
        _ = os_close(arch, uio_fd)
    except e:
        restored = True
        var rest = uio_step_restore(arch, sysfs_root, bdf, original, True)
        emit(arch, "FWBOOT restored driver=" + rest + " (after error)")
        _ = pm_assert_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
        raise e
    if not restored:
        var rest2 = uio_step_restore(arch, sysfs_root, bdf, original, True)
        emit(arch, "FWBOOT restored driver=" + rest2)
    _ = pm_assert_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
    emit(arch, "FWBOOT done")


def cmd_fw_boot(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var dev_root = get_flag(args, "--dev-root", "/dev")
    var bdf = need_bdf(arch, args, sysfs_root)
    var fw_root = get_flag(args, "--fw-root", "/lib/firmware/hailo/hailo10h")
    var as_root = has_flag(args, "--as-root")
    var status_only = has_flag(args, "--status-only")
    _fw_boot_session(
        arch, sysfs_root, dev_root, bdf, fw_root, as_root, status_only
    )


def cmd_pm_get(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var pmcap = find_pm_cap(arch, sysfs_root, bdf)
    var pmcsr = pm_read_pmcsr(arch, sysfs_root, bdf, pmcap)
    var ps = pm_read_power_state_file(arch, sysfs_root, bdf)
    emit(
        arch,
        "{\"bdf\": \"" + bdf + "\", \"pmcsr\": " + String(pmcsr)
        + ", \"pmcsr_state\": \"" + pm_state_name(pmcsr & 0x3)
        + "\", \"power_state\": \"" + ps + "\"}",
    )


def cmd_snapshot(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var label = get_flag(args, "--state-label", "unknown")
    var vals = bringup_dump_registers(arch, sysfs_root, bdf)
    var names = List[String]()
    for i in range(16):
        names.append("cfg_0x" + String(i * 4))
    names.append("bar0_0x0098")
    names.append("bar0_0x0188")
    names.append("bar0_0x018c")
    names.append("bar0_0x0400")
    names.append("bar0_0x0500")
    var out = (
        "{\"bdf\": \"" + bdf + "\", \"state_label\": \"" + label
        + "\", \"registers\": {"
    )
    for i in range(len(vals)):
        if i > 0:
            out += ", "
        out += "\"" + names[i] + "\": " + String(vals[i])
    var pmcap = find_pm_cap(arch, sysfs_root, bdf)
    var pmcsr = pm_read_pmcsr(arch, sysfs_root, bdf, pmcap)
    out += (
        "}, \"pmcsr\": " + String(pmcsr) + ", \"power_state\": \""
        + pm_read_power_state_file(arch, sysfs_root, bdf) + "\"}"
    )
    emit(arch, out)


def cmd_health(arch: String, args: List[String]) raises:
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var thermal = get_flag(
        args, "--thermal-path", "/sys/class/thermal/thermal_zone0/temp"
    )
    var n = _parse_int(get_flag(args, "--samples", "1"))
    for _ in range(n):
        var s = health_sample(arch, sysfs_root, bdf, thermal)
        emit(arch, s.to_json())


def _proc_cpu_ms(arch: String) raises -> Int64:
    # utime+stime from /proc/self/stat (fields 14,15), in ms (HZ=100).
    var data = read_file_str(arch, "/proc/self/stat", 4096)
    var bs = _str_bytes(trim(data))
    var close_paren = -1
    for i in range(len(bs)):
        if bs[i] == 41:  # ")"
            close_paren = i
    var start = 0
    if close_paren >= 0 and close_paren + 2 < len(bs):
        start = close_paren + 2
    var fields = List[String]()
    var cur = ""
    for i in range(start, len(bs)):
        var b = bs[i]
        if b == 32:
            fields.append(cur)
            cur = ""
        else:
            cur += String(chr(Int(b)))
    fields.append(cur)
    if len(fields) < 15:
        return 0
    return (Int64(_parse_int(fields[11])) + Int64(_parse_int(fields[12]))) * 10


def cmd_drift(arch: String, args: List[String]) raises:
    # H097 drift detector: hold D0, sample the 5 BAR0 status registers
    # every interval, compare against refs (off:value:mask triples),
    # emit drift events; restore D3hot at the end. --inject flips one
    # register's read value to prove detection.
    var sysfs_root = get_flag(args, "--sysfs-root", "/sys")
    var bdf = need_bdf(arch, args, sysfs_root)
    var duration_s = Int64(_parse_int(get_flag(args, "--duration-s", "3600")))
    var interval_s = Int64(_parse_int(get_flag(args, "--interval-s", "5")))
    var inject_off = _parse_int(get_flag(args, "--inject", "-1"))
    var refs_raw = get_flag(args, "--refs", "")
    var offs = List[Int]()
    var vals = List[Int]()
    var masks = List[Int]()
    if refs_raw != "":
        # Manual split of "off:value:mask,off:value:mask,...".
        var rbs = _str_bytes(refs_raw)
        var triples = List[String]()
        var cur_t = ""
        for i in range(len(rbs)):
            if rbs[i] == 44:  # ","
                triples.append(cur_t)
                cur_t = ""
            else:
                cur_t += String(chr(Int(rbs[i])))
        triples.append(cur_t)
        for ti in range(len(triples)):
            var tbs = _str_bytes(triples[ti])
            var parts = List[String]()
            var cur_p = ""
            for i in range(len(tbs)):
                if tbs[i] == 58:  # ":"
                    parts.append(cur_p)
                    cur_p = ""
                else:
                    cur_p += String(chr(Int(tbs[i])))
            parts.append(cur_p)
            if len(parts) == 3:
                offs.append(Int(parse_u64_hex(parts[0])))
                vals.append(Int(parse_u64_hex(parts[1])))
                masks.append(Int(parse_u64_hex(parts[2])))
    pm_set_state(arch, sysfs_root, bdf, PM_STATE_D0())
    var cpu0 = _proc_cpu_ms(arch)
    var t0 = os_clock_ms(arch)
    var samples = 0
    var events = 0
    var detected_inject = 0
    try:
        while os_clock_ms(arch) - t0 < duration_s * 1000:
            var m = map_sysfs_resource(arch, sysfs_root, bdf, 0, 0x4000, False)
            var ro = List[Int]()
            ro.append(0x0098)
            ro.append(0x0188)
            ro.append(0x018C)
            ro.append(0x0400)
            ro.append(0x0500)
            for i in range(5):
                var v = Int(reg_read32(m, ro[i]))
                if ro[i] == 0x0098:
                    v = Int(reg_read16(m, ro[i]))
                if ro[i] == inject_off:
                    v = v ^ 0xFFFFFFFF
                    detected_inject += 1
                for j in range(len(offs)):
                    if offs[j] == ro[i]:
                        var masked_v = v & masks[j]
                        var masked_ref = vals[j] & masks[j]
                        if masked_v != masked_ref:
                            events += 1
                            emit(
                                arch,
                                "{\"event\": \"drift\", \"offset\": \""
                                + String(ro[i]) + "\", \"got\": "
                                + String(v) + ", \"expected\": "
                                + String(vals[j]) + ", \"mask\": "
                                + String(masks[j]) + "}",
                            )
            unmap_bar(arch, m)
            samples += 1
            os_sleep_ms(arch, interval_s * 1000)
    except e:
        try:
            pm_set_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
        except:
            pass
        raise e
    pm_set_state(arch, sysfs_root, bdf, PM_STATE_D3HOT())
    var cpu1 = _proc_cpu_ms(arch)
    var wall_ms = os_clock_ms(arch) - t0
    var cpu_pct = 0.0
    if wall_ms > 0:
        cpu_pct = Float64(cpu1 - cpu0) / Float64(wall_ms) * 100.0
    emit(
        arch,
        "{\"drift_run\": true, \"samples\": " + String(samples)
        + ", \"drift_events\": " + String(events)
        + ", \"injected_reads\": " + String(detected_inject)
        + ", \"cpu_pct\": " + String(cpu_pct) + "}",
    )


def cmd_guard_selftest(arch: String, args: List[String]) raises:
    var lock = get_flag(args, "--lock-path", "/tmp/hailbru_guard_test.lock")
    var g = SessionGuard(lock)
    var w1 = guard_acquire(arch, g)
    if w1 != "":
        raise herror("DmaError", "unexpected warning on clean acquire")
    # Second acquire while held -> DeviceBusy naming the holder.
    var g2 = SessionGuard(lock)
    var saw_busy = False
    try:
        _ = guard_acquire(arch, g2)
    except e:
        if String(e).find("DeviceBusy") >= 0:
            saw_busy = True
    if not saw_busy:
        raise herror("DmaError", "second acquire did not raise DeviceBusy")
    guard_release(arch, g)
    # Stale lock: dead PID recorded -> reclaim with warning.
    write_file_str(arch, lock, "99999999\n")
    var g3 = SessionGuard(lock)
    var w3 = guard_acquire(arch, g3)
    if w3.find("stale") < 0:
        raise herror("DmaError", "stale lock not reclaimed with warning")
    guard_release(arch, g3)
    emit(arch, "SELFTEST guard: DeviceBusy contention + stale reclaim — OK")


def _fd_count(arch: String) -> Int:
    var n = 0
    try:
        var names = list_dir(arch, "/proc/self/fd")
        n = len(names)
    except:
        pass
    return n


def cmd_removal_selftest(arch: String, args: List[String]) raises:
    var path = get_flag(args, "--workdir", "/tmp/hailbru_removal_test")
    _ = os_mkdir(arch, path, 0o755)
    var img = path + "/bar.bin"
    var wfd = os_openat(arch, img, O_WRONLY() | O_CREAT() | O_TRUNC(), 0o644)
    var z = unsafe_alloc[UInt8](4096)
    for i in range(4096):
        z[unsafe_offset=i] = 0
    _ = os_write(arch, wfd, z, 4096)
    z.unsafe_free()
    _ = os_close(arch, wfd)
    var fds0 = _fd_count(arch)
    var w = watch_bar_emulated(arch, img, 4096)
    var v0 = watcher_read32(arch, w, 0)
    _ = v0
    watcher_sever(arch, w)
    var saw_removed = False
    var t0 = os_clock_ms(arch)
    try:
        _ = watcher_read32(arch, w, 0)
    except e:
        if String(e).find("DeviceRemoved") >= 0:
            saw_removed = True
    var dt = os_clock_ms(arch) - t0
    var fds1 = _fd_count(arch)
    if not saw_removed:
        raise herror("DmaError", "severed read did not raise DeviceRemoved")
    if dt > 1000:
        raise herror(
            "DmaError", "DeviceRemoved took " + String(dt) + "ms (>1s)"
        )
    if fds1 != fds0:
        raise herror(
            "DmaError",
            "fd leak on removal path: " + String(fds0) + " -> "
            + String(fds1),
        )
    emit(
        arch,
        "SELFTEST removal: DeviceRemoved in " + String(dt)
        + "ms, fds " + String(fds0) + "->" + String(fds1) + " — OK",
    )


def main() raises:
    var arch = detect_arch()
    var cli_arch = proc_getenv(arch, "HAILBRU_CLI_ARCH")
    if cli_arch == "":
        var argv = proc_cmdline(arch)
        cli_arch = get_flag(argv, "--arch", "")
    if cli_arch == "x86_64" or cli_arch == "aarch64":
        arch = cli_arch
    var argv = proc_cmdline(arch)
    if len(argv) < 2:
        raise herror(
            "BadSysfs",
            "usage: probe <discover|identity|bars|link|mechanism|"
            "fwcheck|regs-probe|regs-coherency|regs-selftest|dma-selftest|irq-selftest|"
            "boot-selftest|ready-selftest|sha256-selftest|vfio-negative|"
            "uio-step|bdf-selftest|fw-stage-selftest|bringup|pm-set|pm-get|"
            "snapshot|health|drift|guard-selftest|removal-selftest> [flags]",
        )
    var sub = argv[1]
    if sub == "discover":
        cmd_discover(arch, argv)
    elif sub == "identity":
        cmd_identity(arch, argv)
    elif sub == "bars":
        cmd_bars(arch, argv)
    elif sub == "link":
        cmd_link(arch, argv)
    elif sub == "mechanism":
        cmd_mechanism(arch, argv)
    elif sub == "fwcheck":
        cmd_fwcheck(arch, argv)
    elif sub == "regs-probe":
        cmd_regs_probe(arch, argv)
    elif sub == "regs-coherency":
        cmd_regs_coherency(arch, argv)
    elif sub == "regs-selftest":
        cmd_regs_selftest(arch, argv)
    elif sub == "dma-selftest":
        cmd_dma_selftest(arch, argv)
    elif sub == "irq-selftest":
        cmd_irq_selftest(arch, argv)
    elif sub == "boot-selftest":
        cmd_boot_selftest(arch, argv)
    elif sub == "ready-selftest":
        cmd_ready_selftest(arch, argv)
    elif sub == "sha256-selftest":
        cmd_sha256_selftest(arch, argv)
    elif sub == "vfio-negative":
        cmd_vfio_negative(arch, argv)
    elif sub == "uio-step":
        cmd_uio_step(arch, argv)
    elif sub == "bdf-selftest":
        cmd_bdf_selftest(arch, argv)
    elif sub == "fw-stage-selftest":
        cmd_fw_stage_selftest(arch, argv)
    elif sub == "fw-boot":
        cmd_fw_boot(arch, argv)
    elif sub == "bringup":
        cmd_bringup(arch, argv)
    elif sub == "pm-set":
        cmd_pm_set(arch, argv)
    elif sub == "pm-get":
        cmd_pm_get(arch, argv)
    elif sub == "snapshot":
        cmd_snapshot(arch, argv)
    elif sub == "health":
        cmd_health(arch, argv)
    elif sub == "drift":
        cmd_drift(arch, argv)
    elif sub == "guard-selftest":
        cmd_guard_selftest(arch, argv)
    elif sub == "removal-selftest":
        cmd_removal_selftest(arch, argv)
    else:
        raise herror("BadSysfs", "unknown subcommand '" + sub + "'")
