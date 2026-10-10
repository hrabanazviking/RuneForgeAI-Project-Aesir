# HAILBRU single-owner device guard (H092, Campaign 5).
#
# A PID-recorded lock file so two Aesir processes cannot drive the
# device simultaneously. The lock path is a parameter (no absolute paths
# baked in). Semantics:
#   - acquire: atomic O_CREAT|O_EXCL take; on EEXIST read the recorded
#     PID — live holder -> DeviceBusy naming it; dead holder
#     (kill(pid,0) == ESRCH) -> reclaim with a warning.
#   - release: close + unlink the lock file.
# Tested with real subprocesses (H092 acceptance).

from std.memory.alloc import unsafe_alloc
from hailbru.syscall import (
    O_CREAT,
    O_EXCL,
    O_RDWR,
    errno_now,
    os_close,
    os_getpid,
    os_kill,
    os_openat,
    os_read,
    os_unlinkat,
    os_write,
    to_cstr,
)
from hailbru.errors import herror


def _parse_pid(s: String) -> Int:
    var v = 0
    var any = False
    for b in s.bytes():
        if b == 10 or b == 13 or b == 32:
            continue
        if b < 48 or b > 57:
            return -1
        v = v * 10 + (Int(b) - 48)
        any = True
    return v if any else -1


def _pid_alive(arch: String, pid: Int) -> Bool:
    # kill(pid, 0): 0 or EPERM -> alive; ESRCH -> dead.
    var rc = os_kill(arch, Int64(pid), 0)
    if rc == 0:
        return True
    var e = errno_now()
    return e == 1  # EPERM: exists, no permission to signal


struct SessionGuard:
    var lock_path: String
    var held: Bool

    def __init__(out self, lock_path: String):
        self.lock_path = lock_path
        self.held = False


def _write_own_pid(arch: String, path: String) raises:
    var me = String(os_getpid(arch)) + "\n"
    var fd = os_openat(arch, path, O_RDWR(), 0o644)
    if fd < 0:
        raise herror("OsError", "cannot open lock file " + path)
    var c = to_cstr(me)
    _ = os_write(arch, fd, c, Int64(me.byte_length()))
    c.unsafe_free()
    _ = os_close(arch, fd)


def guard_acquire(arch: String, mut g: SessionGuard) raises -> String:
    # Returns "" on clean acquire, or a warning string on stale reclaim.
    var fd = os_openat(
        arch, g.lock_path, O_RDWR() | O_CREAT() | O_EXCL(), 0o644
    )
    if fd >= 0:
        _ = os_close(arch, fd)
        _write_own_pid(arch, g.lock_path)
        g.held = True
        return ""
    var fd2 = os_openat(arch, g.lock_path, O_RDWR(), 0o644)
    if fd2 < 0:
        raise herror("OsError", "cannot open lock file " + g.lock_path)
    var buf = unsafe_alloc[UInt8](64)
    var n = os_read(arch, fd2, buf, 64)
    _ = os_close(arch, fd2)
    var warn = ""
    if n > 0:
        var s = ""
        for i in range(Int(n)):
            s += String(chr(Int(buf[i])))
        var pid = _parse_pid(s)
        if pid > 0 and _pid_alive(arch, pid):
            buf.unsafe_free()
            raise herror(
                "DeviceBusy",
                "device held by live process pid=" + String(pid)
                + " (lock " + g.lock_path + ")",
            )
        if pid > 0:
            warn = (
                "stale lock reclaimed: recorded pid=" + String(pid)
                + " is dead"
            )
    buf.unsafe_free()
    _write_own_pid(arch, g.lock_path)
    g.held = True
    return warn


def guard_release(arch: String, mut g: SessionGuard):
    if g.held:
        _ = os_unlinkat(arch, g.lock_path)
        g.held = False
