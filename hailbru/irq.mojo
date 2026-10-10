# HAILBRU interrupt setup + handling loop (H069/H070).
#
# Per the H017 study: the device uses a SINGLE MSI vector (not MSI-X);
# acknowledgment is the BAR0+0x018C read-and-clear from userspace after
# wakeup. Fallback order: MSI -> legacy INTx (IRQ 37).
#
# Delivery primitives per mechanism (H017):
#  - VFIO: eventfd + VFIO_DEVICE_SET_IRQS ioctl, poll/read the eventfd.
#  - UIO: blocking read() on /dev/uioN returning the interrupt count.
#
# STATUS ON MIMIR (2026-10-10): the eventfd + ppoll PLUMBING is real and
# fully tested (synthetic interrupts, 10k-iteration loop, timeout path,
# teardown/re-setup). Device interrupt REGISTRATION is F3-BANKED: MSI
# vector allocation needs a kernel driver mechanism (VFIO/UIO), both
# absent per H004. The wait loop below is the completion-signaling path
# all future command submission will use.

from hailbru.errors import herror
from hailbru.syscall import (
    EFD_CLOEXEC,
    EFD_NONBLOCK,
    POLLIN,
    errno_name,
    errno_now,
    os_close,
    os_eventfd2,
    os_read,
    os_write,
    sc_nr,
    syscall6,
)
from hailbru.syscall import unsafe_alloc
from hailbru.vfio import VFIO_DEVICE_SET_IRQS


def irq_eventfd(arch: String) raises -> Int64:
    var fd = os_eventfd2(arch, 0, EFD_CLOEXEC() | EFD_NONBLOCK())
    if fd < 0:
        var e = errno_now()
        raise herror(
            "IrqSetupFailed", "eventfd2 failed: " + errno_name(e)
        )
    return fd


def irq_close(arch: String, fd: Int64):
    _ = os_close(arch, fd)


def irq_signal(arch: String, fd: Int64, count: UInt64) raises:
    # Synthetic interrupt: increment the eventfd counter (the test hook
    # H070 uses; the device would do this via VFIO_DEVICE_SET_IRQS).
    var buf = unsafe_alloc[UInt8](8)
    for i in range(8):
        buf[unsafe_offset=i] = UInt8(
            (count >> UInt64(8 * i)) & UInt64(0xFF)
        )
    var w = os_write(arch, fd, buf, 8)
    buf.unsafe_free()
    if w != 8:
        var e = errno_now()
        raise herror(
            "IrqSetupFailed",
            "eventfd write failed: " + errno_name(e),
        )


def irq_wait(
    arch: String, fds: List[Int64], timeout_ms: Int64
) raises -> Int64:
    # Poll the eventfds; on wake, read each ready counter and return the
    # TOTAL count (exact accounting — H070). Timeout -> named IrqTimeout
    # (never a hang). On EAGAIN-drained fds (non-blocking read returns
    # EAGAIN when no interrupt pending — H069 acceptance proves the fd
    # is live).
    var n = len(fds)
    if n == 0:
        raise herror("IrqSetupFailed", "irq_wait with zero eventfds")
    # struct pollfd { int fd; short events; short revents; } = 8 bytes.
    var pfds = unsafe_alloc[UInt8](8 * n)
    for i in range(n):
        var base = i * 8
        var fd = fds[i]
        for k in range(4):
            pfds[unsafe_offset=base + k] = UInt8(
                (UInt64(fd) >> UInt64(8 * k)) & UInt64(0xFF)
            )
        pfds[unsafe_offset=base + 4] = UInt8(1)  # POLLIN
        pfds[unsafe_offset=base + 5] = UInt8(0)
        pfds[unsafe_offset=base + 6] = UInt8(0)  # revents
        pfds[unsafe_offset=base + 7] = UInt8(0)
    var ts = unsafe_alloc[UInt8](16)
    for i in range(8):
        ts[unsafe_offset=i] = UInt8(
            (UInt64(timeout_ms // 1000) >> UInt64(8 * i)) & UInt64(0xFF)
        )
        ts[unsafe_offset=8 + i] = UInt8(
            (UInt64((timeout_ms % 1000) * 1000000) >> UInt64(8 * i))
            & UInt64(0xFF)
        )
    var pr = syscall6(
        sc_nr(arch, "ppoll"),
        Int64(Int(pfds)),
        Int64(n),
        Int64(Int(ts)),
        0,
        0,
        0,
    )
    ts.unsafe_free()
    if pr < 0:
        var e = errno_now()
        pfds.unsafe_free()
        raise herror(
            "IrqSetupFailed", "ppoll failed: " + errno_name(e)
        )
    if pr == 0:
        pfds.unsafe_free()
        raise herror(
            "IrqTimeout",
            "no interrupt within " + String(timeout_ms) + "ms",
        )
    var total = Int64(0)
    var rbuf = unsafe_alloc[UInt8](8)
    for i in range(n):
        var rev = Int(pfds[unsafe_offset=i * 8 + 6]) | (
            Int(pfds[unsafe_offset=i * 8 + 7]) << 8
        )
        if (rev & 1) != 0:
            var nr = os_read(arch, fds[i], rbuf, 8)
            if nr == 8:
                var c = UInt64(0)
                for k in range(8):
                    c |= UInt64(rbuf[unsafe_offset=k]) << UInt64(8 * k)
                total += Int64(c)
            elif nr < 0:
                var e = errno_now()
                if e != 11:  # EAGAIN: raced drain; not fatal
                    rbuf.unsafe_free()
                    pfds.unsafe_free()
                    raise herror(
                        "IrqSetupFailed",
                        "eventfd read failed: " + errno_name(e),
                    )
    rbuf.unsafe_free()
    pfds.unsafe_free()
    return total


def irq_vfio_set_irqs(
    arch: String, device_fd: Int64, vector: Int64, eventfd: Int64
) raises:
    # F3-BANKED: needs a VFIO device fd (no VFIO on this kernel).
    _ = VFIO_DEVICE_SET_IRQS()
    _ = vector
    raise herror(
        "MechanismUnavailable",
        "VFIO_DEVICE_SET_IRQS unavailable: no VFIO device fd "
        "(H004) — MSI vector registration F3-banked pending operator "
        "kernel rebuild; eventfd plumbing tested synthetically",
    )
    _ = arch
    _ = device_fd
    _ = eventfd


def uio_irq_wait(arch: String, uio_fd: Int64, timeout_ms: Int64) raises -> Int64:
    # UIO path: blocking read() on /dev/uioN returns the interrupt
    # count; F3-BANKED (no /dev/uio* on this kernel).
    _ = timeout_ms
    raise herror(
        "MechanismUnavailable",
        "UIO blocking interrupt read unavailable: no /dev/uio* "
        "(H004/H013) — F3-banked pending operator kernel rebuild",
    )
    _ = arch
    _ = uio_fd
