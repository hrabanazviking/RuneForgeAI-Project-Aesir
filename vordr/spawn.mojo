# VÖRÐR POSIX process primitives (H146).
#
# fork/execve/waitpid via external_call (L1: POSIX via external_call
# only). Used by the watchdog supervisor to spawn and reap the
# inference process. kill/getpid/sleep live in hailbru.syscall already.

from memory import UnsafePointer
from sys.ffi import external_call


fn _fork() -> Int64:
    return external_call["fork", Int64]()


fn _execve(
    path: UnsafePointer[UInt8], argv: UnsafePointer[UnsafePointer[UInt8]],
    envp: UnsafePointer[UnsafePointer[UInt8]],
) -> Int64:
    return external_call["execve", Int64](path, argv, envp)


fn _waitpid(pid: Int64, status: UnsafePointer[Int32], opts: Int32) -> Int64:
    return external_call["waitpid", Int64](pid, status, opts)


fn _exit(code: Int32):
    _ = external_call["_exit", Int64](Int64(code))


fn _strlen(p: UnsafePointer[UInt8]) -> Int:
    var n = 0
    while p[n] != 0:
        n += 1
    return n


def spawn_process(
    prog: String, args: List[String]
) raises -> Int64:
    # fork + execve. Parent returns the child pid; the child never
    # returns (execve or _exit(127)). argv[0] = prog.
    from hailbru.syscall import to_cstr, errno_now, errno_name
    from hailbru.errors import herror

    var pid = _fork()
    if pid < 0:
        raise herror(
            "SpawnFailed", "fork failed: " + errno_name(errno_now())
        )
    if pid > 0:
        return pid
    # --- child ---
    var argc = len(args) + 1
    var argv = UnsafePointer[UnsafePointer[UInt8]].alloc(argc + 1)
    var cstrs = List[UnsafePointer[UInt8]]()
    var p0 = to_cstr(prog)
    cstrs.append(p0)
    argv[0] = p0
    for i in range(len(args)):
        var pa = to_cstr(args[i])
        cstrs.append(pa)
        argv[i + 1] = pa
    argv[argc] = UnsafePointer[UInt8]()
    var null_env = UnsafePointer[UnsafePointer[UInt8]]()
    _ = _execve(p0, argv, null_env)
    # execve only returns on failure.
    _exit(127)
    return Int64(-1)


def waitpid_nonblock(pid: Int64) -> Int:
    # Returns: -2 = still running (WNOHANG, no status), -1 = error/
    # no such child, else the raw wait status int.
    var status = UnsafePointer[Int32].alloc(1)
    status[0] = 0
    var r = _waitpid(pid, status, 1)  # WNOHANG = 1
    var s = Int(status[0])
    status.free()
    if r == 0:
        return -2
    if r < 0:
        return -1
    return s


fn wifexited(status: Int) -> Bool:
    return (status & 0x7F) == 0


fn wexitstatus(status: Int) -> Int:
    return (status >> 8) & 0xFF


fn wifsignaled(status: Int) -> Bool:
    var sig = status & 0x7F
    return sig != 0 and sig != 0x7F


fn wtermsig(status: Int) -> Int:
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
