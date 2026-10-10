# HAILBRU syscall gateway (H061 foundation; H015-proven design).
#
# Every OS interaction in HAILBRU goes through this module (L12: no other
# domain opens /dev nodes, mmaps PCI BARs, or issues ioctls — and inside
# HAILBRU, every one of those passes through here).
#
# Arch-parameterized at RUNTIME: every function takes `arch: String`
# ("aarch64" or "x86_64"). The real device is aarch64; the PRÓF suite
# (H078) selects x86_64 so the same sources build a host test binary.
# Mojo 1.x has no mutable module globals, so the arch is threaded
# explicitly — no hidden state.
#
# Design: a single `syscall()` gateway via std.ffi external_call (avoids
# redeclaring libc symbols that std.io already declares — hard compiler
# error per H015). glibc's syscall() wrapper converts raw -errno into -1
# and stashes errno; every call site checks for -1 and reads errno back
# via __errno_location, mapping it to a named error. No silent failures.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin


# --- raw gateway -----------------------------------------------------------
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


def sc_nr(arch: String, name: String) -> Int64:
    var aarch = arch == "aarch64"
    if name == "openat":
        return Int64(56) if aarch else Int64(257)
    if name == "close":
        return Int64(57) if aarch else Int64(3)
    if name == "read":
        return Int64(63) if aarch else Int64(0)
    if name == "write":
        return Int64(64) if aarch else Int64(1)
    if name == "mmap":
        return Int64(222) if aarch else Int64(9)
    if name == "munmap":
        return Int64(215) if aarch else Int64(11)
    if name == "eventfd2":
        return Int64(19) if aarch else Int64(290)
    if name == "ppoll":
        return Int64(73) if aarch else Int64(271)
    if name == "getdents64":
        return Int64(61) if aarch else Int64(217)
    if name == "readlinkat":
        return Int64(78) if aarch else Int64(89)
    if name == "mlock":
        return Int64(228) if aarch else Int64(149)
    if name == "ioctl":
        return Int64(29) if aarch else Int64(16)
    if name == "clock_gettime":
        return Int64(113) if aarch else Int64(228)
    if name == "mkdirat":
        return Int64(34) if aarch else Int64(258)
    if name == "pwrite64":
        return Int64(68) if aarch else Int64(18)
    if name == "getpid":
        return Int64(172) if aarch else Int64(39)
    if name == "kill":
        return Int64(129) if aarch else Int64(62)
    if name == "unlinkat":
        return Int64(35) if aarch else Int64(263)
    if name == "nanosleep":
        return Int64(101) if aarch else Int64(35)
    return Int64(-1)


# --- errno -----------------------------------------------------------------
def errno_now() -> Int64:
    var loc = external_call[
        "__errno_location", Pointer[Int32, MutUntrackedOrigin]
    ]()
    return Int64(loc[unsafe_offset=0])


def errno_name(e: Int64) -> String:
    if e == 1:
        return "EPERM"
    if e == 2:
        return "ENOENT"
    if e == 4:
        return "EINTR"
    if e == 5:
        return "EIO"
    if e == 9:
        return "EBADF"
    if e == 11:
        return "EAGAIN"
    if e == 12:
        return "ENOMEM"
    if e == 13:
        return "EACCES"
    if e == 14:
        return "EFAULT"
    if e == 19:
        return "ENODEV"
    if e == 22:
        return "EINVAL"
    if e == 25:
        return "ENOTTY"
    if e == 38:
        return "ENOSYS"
    return "UNKNOWN_ERRNO"


# --- c-string helpers -------------------------------------------------------
def to_cstr(s: String) -> Pointer[UInt8, MutUntrackedOrigin]:
    var n = s.byte_length()
    var cstr = unsafe_alloc[UInt8](n + 1)
    var i = 0
    for byte in s.bytes():
        cstr[unsafe_offset=i] = byte
        i += 1
    cstr[unsafe_offset=n] = 0
    return cstr


def cstr_to_string(p: Pointer[UInt8, MutUntrackedOrigin], n: Int) -> String:
    var s = String("")
    for i in range(n):
        var b = p[unsafe_offset=i]
        if b == 0:
            break
        s += String(chr(Int(b)))
    return s


# --- flag constants (Linux UAPI, arch-independent values) -------------------
def O_RDONLY() -> Int64:
    return Int64(0)


def O_WRONLY() -> Int64:
    return Int64(1)


def O_RDWR() -> Int64:
    return Int64(2)


def O_TRUNC() -> Int64:
    return Int64(0o1000)


def O_EXCL() -> Int64:
    return Int64(128)


def O_CREAT() -> Int64:
    return Int64(0o100)


def O_CLOEXEC() -> Int64:
    return Int64(0o2000000)


def O_APPEND() -> Int64:
    # Linux O_APPEND (0x400). Added in H141 for VÖRÐR's append-only
    # event/restart logs.
    return Int64(1024)


def AT_FDCWD() -> Int64:
    return Int64(-100)


def PROT_READ() -> Int64:
    return Int64(0x1)


def PROT_WRITE() -> Int64:
    return Int64(0x2)


def MAP_SHARED() -> Int64:
    return Int64(0x01)


def MAP_PRIVATE() -> Int64:
    return Int64(0x02)


def MAP_ANONYMOUS() -> Int64:
    return Int64(0x20)


def EFD_CLOEXEC() -> Int64:
    return Int64(0o2000000)


def EFD_NONBLOCK() -> Int64:
    return Int64(0o4000)


def POLLIN() -> Int64:
    return Int64(0x1)


def CLOCK_MONOTONIC() -> Int64:
    return Int64(1)


# --- thin wrappers (return raw values; callers map errors) -------------------
def os_openat(
    arch: String, path: String, flags: Int64, mode: Int64
) -> Int64:
    var c = to_cstr(path)
    var fd = syscall6(
        sc_nr(arch, "openat"), AT_FDCWD(), Int64(Int(c)), flags, mode, 0, 0
    )
    c.unsafe_free()
    return fd


def os_close(arch: String, fd: Int64) -> Int64:
    return syscall6(sc_nr(arch, "close"), fd, 0, 0, 0, 0, 0)


def os_read(
    arch: String, fd: Int64, buf: Pointer[UInt8, MutUntrackedOrigin], n: Int64
) -> Int64:
    return syscall6(
        sc_nr(arch, "read"), fd, Int64(Int(buf)), n, 0, 0, 0
    )


def os_write(
    arch: String, fd: Int64, buf: Pointer[UInt8, MutUntrackedOrigin], n: Int64
) -> Int64:
    return syscall6(
        sc_nr(arch, "write"), fd, Int64(Int(buf)), n, 0, 0, 0
    )


def os_mmap(
    arch: String,
    length: Int64,
    prot: Int64,
    flags: Int64,
    fd: Int64,
    offset: Int64,
) -> Int64:
    return syscall6(
        sc_nr(arch, "mmap"), 0, length, prot, flags, fd, offset
    )


def os_munmap(arch: String, addr: Int64, length: Int64) -> Int64:
    return syscall6(sc_nr(arch, "munmap"), addr, length, 0, 0, 0, 0)


def os_eventfd2(arch: String, init: Int64, flags: Int64) -> Int64:
    return syscall6(sc_nr(arch, "eventfd2"), init, flags, 0, 0, 0, 0)


def os_mlock(arch: String, addr: Int64, length: Int64) -> Int64:
    return syscall6(sc_nr(arch, "mlock"), addr, length, 0, 0, 0, 0)


def os_ioctl(arch: String, fd: Int64, req: Int64, arg: Int64) -> Int64:
    return syscall6(sc_nr(arch, "ioctl"), fd, req, arg, 0, 0, 0)


def os_readlinkat(
    arch: String,
    path: String,
    buf: Pointer[UInt8, MutUntrackedOrigin],
    cap: Int64,
) -> Int64:
    var c = to_cstr(path)
    var n = syscall6(
        sc_nr(arch, "readlinkat"),
        AT_FDCWD(),
        Int64(Int(c)),
        Int64(Int(buf)),
        cap,
        0,
        0,
    )
    c.unsafe_free()
    return n


def os_pwrite(
    arch: String,
    fd: Int64,
    buf: Pointer[UInt8, MutUntrackedOrigin],
    n: Int64,
    offset: Int64,
) -> Int64:
    return syscall6(
        sc_nr(arch, "pwrite64"), fd, Int64(Int(buf)), n, offset, 0, 0
    )


def os_getpid(arch: String) -> Int64:
    return syscall6(sc_nr(arch, "getpid"), 0, 0, 0, 0, 0, 0)


def os_kill(arch: String, pid: Int64, sig: Int64) -> Int64:
    return syscall6(sc_nr(arch, "kill"), pid, sig, 0, 0, 0, 0)


def os_unlinkat(arch: String, path: String) -> Int64:
    var c = to_cstr(path)
    var rc = syscall6(
        sc_nr(arch, "unlinkat"), AT_FDCWD(), Int64(Int(c)), 0, 0, 0, 0
    )
    c.unsafe_free()
    return rc


def os_sleep_ms(arch: String, ms: Int64):
    # Real sleep via nanosleep(2) — yields the CPU (the old busy-wait
    # burned 100% CPU and broke the H097 <1% overhead budget).
    if ms <= 0:
        return
    var ts = unsafe_alloc[UInt8](16)
    var sec = ms // 1000
    var nsec = (ms % 1000) * 1000000
    for i in range(8):
        var sh = Int64(i * 8)
        ts[unsafe_offset=i] = UInt8((sec >> sh) & 0xFF)
        ts[unsafe_offset=8 + i] = UInt8((nsec >> sh) & 0xFF)
    _ = syscall6(sc_nr(arch, "nanosleep"), Int64(Int(ts)), 0, 0, 0, 0, 0)
    ts.unsafe_free()


def os_mkdir(arch: String, path: String, mode: Int64) -> Int64:
    var c = to_cstr(path)
    var r = syscall6(
        sc_nr(arch, "mkdirat"), AT_FDCWD(), Int64(Int(c)), mode, 0, 0, 0
    )
    c.unsafe_free()
    return r


def os_clock_ms(arch: String) -> Int64:
    # Monotonic milliseconds via clock_gettime(CLOCK_MONOTONIC).
    var ts = unsafe_alloc[UInt8](16)
    var r = syscall6(
        sc_nr(arch, "clock_gettime"),
        CLOCK_MONOTONIC(),
        Int64(Int(ts)),
        0,
        0,
        0,
        0,
    )
    var ms = Int64(-1)
    if r == 0:
        var sec = Int64(0)
        var nsec = Int64(0)
        for i in range(8):
            sec |= Int64(ts[unsafe_offset=i]) << Int64(8 * i)
            nsec |= Int64(ts[unsafe_offset=8 + i]) << Int64(8 * i)
        ms = sec * Int64(1000) + nsec // Int64(1000000)
    ts.unsafe_free()
    return ms


# --- file helpers ------------------------------------------------------------
def file_exists(arch: String, path: String) -> Bool:
    var fd = os_openat(arch, path, O_RDONLY(), 0)
    if fd < 0:
        return False
    _ = os_close(arch, fd)
    return True


def read_file_bytes(
    arch: String, path: String, cap: Int64
) raises -> List[UInt8]:
    # Raises OsError on open failure. Returns bytes read (may be short).
    var out = List[UInt8]()
    var fd = os_openat(arch, path, O_RDONLY(), 0)
    if fd < 0:
        var e = errno_now()
        raise Error(
            "HailbruError[OsError]: open " + path + " failed: "
            + errno_name(e) + " (" + String(e) + ")"
        )
    var chunk = unsafe_alloc[UInt8](8192)
    var total = Int64(0)
    while total < cap:
        var want = cap - total
        if want > 8192:
            want = 8192
        var n = os_read(arch, fd, chunk, want)
        if n < 0:
            var e = errno_now()
            chunk.unsafe_free()
            _ = os_close(arch, fd)
            raise Error(
                "HailbruError[OsError]: read " + path + " failed: "
                + errno_name(e) + " (" + String(e) + ")"
            )
        if n == 0:
            break
        for i in range(Int(n)):
            out.append(chunk[unsafe_offset=i])
        total += n
    chunk.unsafe_free()
    _ = os_close(arch, fd)
    return out^


def read_file_str(arch: String, path: String, cap: Int64) raises -> String:
    var data = read_file_bytes(arch, path, cap)
    var s = String("")
    for i in range(len(data)):
        s += String(chr(Int(data[i])))
    return s


def write_file_str(arch: String, path: String, content: String) raises:
    # Raises OsError / PrivilegeRequired on failure. No partial writes
    # hidden: short write raises.
    var fd = os_openat(arch, path, O_WRONLY() | O_CREAT() | O_TRUNC(), 0o644)
    if fd < 0:
        var e = errno_now()
        var code = "OsError"
        if e == 13 or e == 1:
            code = "PrivilegeRequired"
        raise Error(
            "HailbruError[" + code + "]: open for write " + path
            + " failed: " + errno_name(e) + " (" + String(e) + ")"
        )
    var n = content.byte_length()
    var c = to_cstr(content)
    var w = os_write(arch, fd, c, Int64(n))
    var we = errno_now()
    c.unsafe_free()
    _ = os_close(arch, fd)
    if w != Int64(n):
        raise Error(
            "HailbruError[OsError]: short write to " + path + ": wrote "
            + String(w) + " of " + String(n) + " errno=" + errno_name(we)
            + " (" + String(we) + ")"
        )


def append_file_str(arch: String, path: String, content: String) raises:
    # Append-only write (O_APPEND), for VÖRÐR event/restart logs (H141).
    # Same fail-closed contract as write_file_str.
    var fd = os_openat(
        arch, path, O_WRONLY() | O_CREAT() | O_APPEND(), Int64(0o644)
    )
    if fd < 0:
        var e = errno_now()
        var code = "OsError"
        if e == 13 or e == 1:
            code = "PrivilegeRequired"
        raise Error(
            "HailbruError[" + code + "]: open for append " + path
            + " failed: " + errno_name(e) + " (" + String(e) + ")"
        )
    var n = content.byte_length()
    var c = to_cstr(content)
    var w = os_write(arch, fd, c, Int64(n))
    var we = errno_now()
    c.unsafe_free()
    _ = os_close(arch, fd)
    if w != Int64(n):
        raise Error(
            "HailbruError[OsError]: short append to " + path + ": wrote "
            + String(w) + " of " + String(n) + " errno=" + errno_name(we)
            + " (" + String(we) + ")"
        )


def list_dir(arch: String, path: String) raises -> List[String]:
    # getdents64 loop; returns entry names (skips "." and "..").
    # Raises OsError when the directory cannot be opened.
    var out = List[String]()
    var fd = os_openat(arch, path, O_RDONLY(), 0)
    if fd < 0:
        var e = errno_now()
        raise Error(
            "HailbruError[OsError]: opendir " + path + " failed: "
            + errno_name(e) + " (" + String(e) + ")"
        )
    var buf = unsafe_alloc[UInt8](8192)
    while True:
        var n = syscall6(
            sc_nr(arch, "getdents64"), fd, Int64(Int(buf)), 8192, 0, 0, 0
        )
        if n < 0:
            var e = errno_now()
            buf.unsafe_free()
            _ = os_close(arch, fd)
            raise Error(
                "HailbruError[OsError]: getdents64 " + path + " failed: "
                + errno_name(e) + " (" + String(e) + ")"
            )
        if n == 0:
            break
        var pos = 0
        while pos < Int(n):
            var reclen = Int(buf[unsafe_offset=pos + 16]) | (
                Int(buf[unsafe_offset=pos + 17]) << 8
            )
            if reclen <= 0:
                break
            var name = String("")
            var np = pos + 19
            while True:
                var b = buf[unsafe_offset=np]
                if b == 0:
                    break
                name += String(chr(Int(b)))
                np += 1
            if name != "." and name != "..":
                out.append(name)
            pos += reclen
    buf.unsafe_free()
    _ = os_close(arch, fd)
    return out^


def proc_cmdline(arch: String) raises -> List[String]:
    # argv via /proc/self/cmdline (NUL-separated). Version-proof: no
    # stdlib argv dependency.
    var out = List[String]()
    var data = read_file_bytes(arch, "/proc/self/cmdline", 65536)
    var cur = String("")
    for i in range(len(data)):
        var b = data[i]
        if b == 0:
            out.append(cur)
            cur = String("")
        else:
            cur += String(chr(Int(b)))
    return out^


def proc_getenv(arch: String, name: String) raises -> String:
    # Environment via /proc/self/environ. Returns "" when unset.
    # Implemented purely on bytes (no String indexing — version-proof).
    var data = read_file_bytes(arch, "/proc/self/environ", 131072)
    var prefix = List[UInt8]()
    for b in name.bytes():
        prefix.append(b)
    prefix.append(UInt8(61))  # '='
    var i = 0
    var n = len(data)
    while i < n:
        var j = i
        while j < n and data[j] != 0:
            j += 1
        # entry is data[i:j]; check prefix
        var is_match = True
        if j - i < len(prefix):
            is_match = False
        else:
            for k in range(len(prefix)):
                if data[i + k] != prefix[k]:
                    is_match = False
                    break
        if is_match:
            var val = String("")
            for k in range(i + len(prefix), j):
                val += String(chr(Int(data[k])))
            return val
        i = j + 1
    return ""
