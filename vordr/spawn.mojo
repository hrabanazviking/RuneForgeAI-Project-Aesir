# VÖRÐR POSIX process primitives (H146).
#
# fork/waitpid via external_call (L1: POSIX via external_call only).
# spawn_process: fork; the child runs the command through
# /bin/sh -c "exec ..." so the shell replaces itself with the target
# (the supervised pid IS the target process). This avoids building
# argv pointer arrays, which Mojo 1.1.0's pointer model makes
# needlessly painful. kill/getpid/sleep live in hailbru.syscall.

from std.ffi import external_call
from std.memory.alloc import unsafe_alloc
from std.memory import UnsafePointer
from std.origin import MutUntrackedOrigin


def _fork() -> Int64:
    return external_call["fork", Int64]()


def _waitpid(
    pid: Int64, status: UnsafePointer[Int32, MutUntrackedOrigin], opts: Int32
) -> Int64:
    return external_call["waitpid", Int64](pid, status, opts)


def _exit(code: Int32):
    _ = external_call["_exit", Int64](Int64(code))


def _system(cmd: UnsafePointer[UInt8, MutUntrackedOrigin]) -> Int32:
    return external_call["system", Int32](cmd)


def _sh_quote(s: String) -> String:
    # Single-quote for sh, escaping embedded quotes as '\''.
    var out = String("'")
    for b in s.bytes():
        if Int(b) == 39:
            out += "'\\''"
        else:
            out += String(chr(Int(b)))
    out += "'"
    return out


def _to_cstr_raw(s: String) -> UnsafePointer[UInt8, MutUntrackedOrigin]:
    var p = unsafe_alloc[UInt8](s.byte_length() + 1)
    var i = 0
    for b in s.bytes():
        p[unsafe_offset=i] = b
        i += 1
    p[unsafe_offset=i] = 0
    return p


def spawn_process(
    prog: String, args: List[String]
) raises -> Int64:
    # fork; child execs the target via sh. Parent returns the child
    # pid; the child never returns (system() then _exit).
    from hailbru.syscall import errno_now, errno_name
    from hailbru.errors import herror

    var cmd = String("exec ") + _sh_quote(prog)
    for i in range(len(args)):
        cmd += String(" ") + _sh_quote(args[i])

    var pid = _fork()
    if pid < 0:
        raise herror(
            "SpawnFailed", "fork failed: " + errno_name(errno_now())
        )
    if pid > 0:
        return pid
    # --- child ---
    var c = _to_cstr_raw(cmd)
    var rc = _system(c)
    c.unsafe_free()
    # system() returns the wait-encoded status; propagate the exit
    # code when it exited normally.
    var code = Int32(127)
    if (Int(rc) & 0x7F) == 0:
        code = Int32((Int(rc) >> 8) & 0xFF)
    _exit(code)
    return Int64(-1)


def waitpid_nonblock(pid: Int64) -> Int:
    # Returns: -2 = still running (WNOHANG, no status), -1 = error/
    # no such child, else the raw wait status int.
    var status = unsafe_alloc[Int32](1)
    status[unsafe_offset=0] = Int32(0)
    var r = _waitpid(pid, status, 1)  # WNOHANG = 1
    var s = Int(status[unsafe_offset=0])
    status.unsafe_free()
    if r == 0:
        return -2
    if r < 0:
        return -1
    return s


def wifexited(status: Int) -> Bool:
    return (status & 0x7F) == 0


def wexitstatus(status: Int) -> Int:
    return (status >> 8) & 0xFF


def wifsignaled(status: Int) -> Bool:
    var sig = status & 0x7F
    return sig != 0 and sig != 0x7F


def wtermsig(status: Int) -> Int:
    return status & 0x7F


def describe_status(status: Int) -> String:
    if wifexited(status):
        return "exit(" + String(wexitstatus(status)) + ")"
    if wifsignaled(status):
        return "signal(" + String(wtermsig(status)) + ")"
    return "status(" + String(status) + ")"


def pid_alive(arch: String, pid: Int64) -> Bool:
    # kill(pid, 0) liveness probe. False when ESRCH/EPERM-denied-gone.
    from hailbru.syscall import os_kill, errno_now

    var r = os_kill(arch, pid, 0)
    if r == 0:
        return True
    var e = errno_now()
    # EPERM (1) means the process exists but we may not signal it.
    return e == 1
