# H015 SPIKE — Mojo POSIX syscall baseline (pure Mojo).
#
# Proves pure Mojo on the Pi 5 can perform the exact POSIX syscalls the
# HAILBRU driver will need: openat, mmap, ioctl, read, write, eventfd, poll.
# Runs NATIVELY on Mimir. This is a measurement spike, not shipped code.
#
# Design: a single `syscall()` gateway via std.ffi external_call. This
# avoids redeclaring libc symbols (read/write/fclose/...) that the Mojo
# stdlib's std.io already declares via external_call with conflicting
# signatures — a hard compiler error, not something to work around by
# shadowing. glibc's syscall() wrapper converts the raw -errno return into
# -1 and stashes errno, so every call site checks for -1 and reads the
# errno back via __errno_location, mapping it to a named error — no silent
# failures. Syscall numbers are AArch64 Linux (asm-generic).
#
# Exercises:
#   1. openat(AT_FDCWD) + read on the Hailo-10 sysfs vendor file
#   2. openat on a nonexistent path -> -ENOENT (error path)
#   3. anonymous mmap: write pattern through the pointer, read back, munmap
#   4. eventfd2: write counter, ppoll (ready), read back, ppoll (timeout)
#   5. pipe2 + ioctl(FIONREAD): real successful ioctl
#   6. openat + write + read on a regular tmp file

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin


def syscall6(
    nr: Int64, a: Int64, b: Int64, c: Int64, d: Int64, e: Int64, f: Int64
) -> Int64:
    return external_call[
        "syscall",
        Int64,
        Int64,
        Int64,
        Int64,
        Int64,
        Int64,
        Int64,
        Int64,
    ](nr, a, b, c, d, e, f)


def ptr_addr(p: Pointer[UInt8, MutUntrackedOrigin]) -> Int64:
    return Int64(Int(p))


def errno_via_location() -> Int64:
    # glibc's syscall() wrapper converts the raw -errno return into -1 and
    # stashes the errno; read it back via __errno_location.
    var loc = external_call[
        "__errno_location", Pointer[Int32, MutUntrackedOrigin]
    ]()
    return Int64(loc[unsafe_offset=0])


def to_cstr(s: String) -> Pointer[UInt8, MutUntrackedOrigin]:
    var n = s.byte_length()
    var cstr = unsafe_alloc[UInt8](n + 1)
    var i = 0
    for byte in s.bytes():
        cstr[unsafe_offset=i] = byte
        i += 1
    cstr[unsafe_offset=n] = 0
    return cstr


def errno_name(e: Int64) -> String:
    if e == 1:
        return "EPERM"
    if e == 2:
        return "ENOENT"
    if e == 9:
        return "EBADF"
    if e == 11:
        return "EAGAIN"
    if e == 13:
        return "EACCES"
    if e == 14:
        return "EFAULT"
    if e == 22:
        return "EINVAL"
    if e == 25:
        return "ENOTTY"
    if e == 38:
        return "ENOSYS"
    return "UNKNOWN_ERRNO"


def store_u32(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int, v: UInt32):
    for i in range(4):
        buf[unsafe_offset=off + i] = UInt8((v >> UInt32(8 * i)) & UInt32(0xFF))


def store_u16(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int, v: UInt16):
    for i in range(2):
        buf[unsafe_offset=off + i] = UInt8((v >> UInt16(8 * i)) & UInt16(0xFF))


def load_u16(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int) -> UInt16:
    return UInt16(buf[unsafe_offset=off]) | (
        UInt16(buf[unsafe_offset=off + 1]) << UInt16(8)
    )


def load_u64(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int) -> UInt64:
    var v = UInt64(0)
    for i in range(8):
        v |= UInt64(buf[unsafe_offset=off + i]) << UInt64(8 * i)
    return v


def store_u64(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int, v: UInt64):
    for i in range(8):
        buf[unsafe_offset=off + i] = UInt8((v >> UInt64(8 * i)) & UInt64(0xFF))


def store_i64(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int, v: Int64):
    store_u64(buf, off, UInt64(v))


def bytes_to_str(buf: Pointer[UInt8, MutUntrackedOrigin], n: Int) -> String:
    var s = String()
    for i in range(n):
        var b = buf[unsafe_offset=i]
        if b == 0:
            break
        s += chr(Int(b))
    return s


def main() raises:
    # AArch64 Linux syscall numbers (asm-generic/unistd.h).
    var SYS_read = Int64(63)
    var SYS_write = Int64(64)
    var SYS_openat = Int64(56)
    var SYS_close = Int64(57)
    var SYS_mmap = Int64(222)
    var SYS_munmap = Int64(215)
    var SYS_ioctl = Int64(29)
    var SYS_ppoll = Int64(73)
    var SYS_eventfd2 = Int64(19)
    var SYS_pipe2 = Int64(59)
    var AT_FDCWD = Int64(-100)
    var fails = 0

    # --- 1. openat + read on the Hailo-10 sysfs vendor file ---
    var vend_path = to_cstr("/sys/bus/pci/devices/0001:01:00.0/vendor")
    var fd = syscall6(
        SYS_openat, AT_FDCWD, ptr_addr(vend_path), 0, 0, 0, 0
    )
    if fd < 0:
        print("FAIL openat vendor: -errno", -fd, errno_name(errno_via_location()))
        fails += 1
    else:
        var rbuf = unsafe_alloc[UInt8](16)
        var n = syscall6(SYS_read, fd, ptr_addr(rbuf), 16, 0, 0, 0)
        if n < 0:
            print("FAIL read vendor: -errno", -n, errno_name(errno_via_location()))
            fails += 1
        else:
            var vend = bytes_to_str(rbuf, Int(n))
            print("OK openat+read vendor ->", vend)
            if vend != "0x1e60\n":
                print("FAIL vendor mismatch, expected 0x1e60")
                fails += 1
        _ = syscall6(SYS_close, fd, 0, 0, 0, 0, 0)

    # --- 2. openat on nonexistent path -> -ENOENT ---
    # NOTE: /sys returns EPERM (not ENOENT) for nonexistent top-level entries
    # (sysfs quirk, verified 2026-10-10); /tmp gives the canonical ENOENT.
    var bad_path = to_cstr("/tmp/h015_nonexistent_xyz")
    var bad_fd = syscall6(
        SYS_openat, AT_FDCWD, ptr_addr(bad_path), 0, 0, 0, 0
    )
    if bad_fd >= 0:
        print("FAIL openat nonexistent unexpectedly succeeded")
        fails += 1
    else:
        var be = errno_via_location()
        print("OK openat nonexistent -> errno", be, errno_name(be))
        if be != 2:
            print("FAIL expected ENOENT(2)")
            fails += 1

    # --- 3. anonymous mmap / munmap ---
    var m_addr = syscall6(SYS_mmap, 0, 4096, 3, 34, -1, 0)
    if m_addr == -1:
        print("FAIL mmap: errno", errno_via_location(), errno_name(errno_via_location()))
        fails += 1
    else:
        var m = Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=Int(m_addr)
        )
        for i in range(0, 4096, 8):
            store_u64(m, i, UInt64(0xDEADBEEF00000000 + UInt64(i)))
        var ok = True
        for i in range(0, 4096, 8):
            if load_u64(m, i) != UInt64(0xDEADBEEF00000000 + UInt64(i)):
                ok = False
        print("OK mmap pattern verify:", ok)
        if not ok:
            fails += 1
        var mr = syscall6(SYS_munmap, m_addr, 4096, 0, 0, 0, 0)
        if mr != 0:
            print("FAIL munmap: -errno", -mr, errno_name(errno_via_location()))
            fails += 1
        else:
            print("OK munmap")

    # --- 4. eventfd2 + ppoll ---
    var efd = syscall6(SYS_eventfd2, 0, 0, 0, 0, 0, 0)
    if efd < 0:
        print("FAIL eventfd2: -errno", -efd, errno_name(errno_via_location()))
        fails += 1
    else:
        print("OK eventfd2 fd:", efd)
        var ebuf = unsafe_alloc[UInt8](8)
        store_u64(ebuf, 0, UInt64(7))
        var w = syscall6(SYS_write, efd, ptr_addr(ebuf), 8, 0, 0, 0)
        if w != 8:
            print("FAIL eventfd write: -errno", -w, errno_name(errno_via_location()))
            fails += 1
        else:
            print("OK eventfd write 7")
        # struct pollfd { int fd; short events; short revents; } = 8 bytes
        var pfd = unsafe_alloc[UInt8](8)
        store_u32(pfd, 0, UInt32(efd))
        store_u16(pfd, 4, UInt16(1))
        store_u16(pfd, 6, UInt16(0))
        var pr = syscall6(SYS_ppoll, ptr_addr(pfd), 1, 0, 0, 0, 0)
        var rev = load_u16(pfd, 6)
        print("OK ppoll ready ->", pr, "revents", rev)
        if pr != 1 or (rev & UInt16(1)) == 0:
            print("FAIL ppoll should report POLLIN")
            fails += 1
        var rbuf2 = unsafe_alloc[UInt8](8)
        var nr = syscall6(SYS_read, efd, ptr_addr(rbuf2), 8, 0, 0, 0)
        var cv = load_u64(rbuf2, 0)
        print("OK eventfd read ->", cv)
        if nr != 8 or cv != 7:
            print("FAIL eventfd counter mismatch")
            fails += 1
        # 100ms timeout via struct timespec { tv_sec: i64, tv_nsec: i64 }
        var ts = unsafe_alloc[UInt8](16)
        store_i64(ts, 0, 0)
        store_i64(ts, 8, 100_000_000)
        store_u16(pfd, 6, UInt16(0))
        var pr2 = syscall6(SYS_ppoll, ptr_addr(pfd), 1, ptr_addr(ts), 0, 0, 0)
        print("OK ppoll drained timeout ->", pr2, "(expect 0)")
        if pr2 != 0:
            print("FAIL ppoll should time out")
            fails += 1
        _ = syscall6(SYS_close, efd, 0, 0, 0, 0, 0)

    # --- 5. pipe2 + ioctl(FIONREAD) ---
    var pipefds = unsafe_alloc[UInt8](8)
    var piper = syscall6(SYS_pipe2, ptr_addr(pipefds), 0, 0, 0, 0, 0)
    if piper != 0:
        print("FAIL pipe2: -errno", -piper, errno_name(errno_via_location()))
        fails += 1
    else:
        var rfd = Int64(load_u32(pipefds, 0))
        var wfd = Int64(load_u32(pipefds, 4))
        var msg = to_cstr("hailo")
        var pw = syscall6(SYS_write, wfd, ptr_addr(msg), 5, 0, 0, 0)
        if pw != 5:
            print("FAIL pipe write: -errno", -pw, errno_name(errno_via_location()))
            fails += 1
        var avail_buf = unsafe_alloc[UInt8](4)
        var ior = syscall6(
            SYS_ioctl, rfd, Int64(0x541B), ptr_addr(avail_buf), 0, 0, 0
        )
        var avail = load_u32(avail_buf, 0)
        print("OK ioctl FIONREAD ->", ior, "avail", avail)
        if ior != 0 or avail != 5:
            print("FAIL ioctl should report 5 bytes available")
            fails += 1
        var pbuf = unsafe_alloc[UInt8](8)
        var prd = syscall6(SYS_read, rfd, ptr_addr(pbuf), 8, 0, 0, 0)
        var got_msg = bytes_to_str(pbuf, Int(prd))
        print("OK pipe read ->", got_msg)
        if got_msg != "hailo":
            print("FAIL pipe data mismatch")
            fails += 1
        _ = syscall6(SYS_close, rfd, 0, 0, 0, 0, 0)
        _ = syscall6(SYS_close, wfd, 0, 0, 0, 0, 0)

    # --- 6. openat + write + read on a regular file ---
    var tmpp = to_cstr("/tmp/mimisbrunnr/h015/write_test.bin")
    var wfd2 = syscall6(
        SYS_openat, AT_FDCWD, ptr_addr(tmpp), 577, 384, 0, 0
    )
    if wfd2 < 0:
        print("FAIL openat create: -errno", -wfd2, errno_name(errno_via_location()))
        fails += 1
    else:
        var wdata = to_cstr("mimisbrunnr-h015")
        var wlen = Int64(16)
        var ww = syscall6(SYS_write, wfd2, ptr_addr(wdata), wlen, 0, 0, 0)
        _ = syscall6(SYS_close, wfd2, 0, 0, 0, 0, 0)
        if ww != wlen:
            print("FAIL file write: -errno", -ww, errno_name(errno_via_location()))
            fails += 1
        else:
            var rfd2 = syscall6(
                SYS_openat, AT_FDCWD, ptr_addr(tmpp), 0, 0, 0, 0
            )
            var fbuf = unsafe_alloc[UInt8](16)
            var fr = syscall6(SYS_read, rfd2, ptr_addr(fbuf), 16, 0, 0, 0)
            var back = bytes_to_str(fbuf, Int(fr))
            print("OK file write+read ->", back)
            if back != "mimisbrunnr-h015":
                print("FAIL file roundtrip mismatch")
                fails += 1
            _ = syscall6(SYS_close, rfd2, 0, 0, 0, 0, 0)

    if fails == 0:
        print("H015_ALL_SYSCALLS_OK")
    else:
        print("H015_FAILURES", fails)
        raise Error("POSIX baseline had failures")
