# VÖRÐR POSIX process primitives (H146).
#
# fork/execve/waitpid via external_call (L1: POSIX via external_call
# only). Used by the watchdog supervisor to spawn and reap the
# inference process. kill/getpid/sleep live in hailbru.syscall already.

from std.ffi import external_call
from std.memory.alloc import unsafe_alloc
from std.memory import UnsafePointer
from std.origin import MutUntrackedOrigin

alias CU8 = UnsafePointer[UInt8, MutUntrackedOrigin]
alias CArgv = UnsafePointer[CU8, MutUntrackedOrigin]


def _fork() -> Int64:
    return external_call["fork", Int64]()


def _execve(path: CU8, argv: CArgv, envp: CArgv) -> Int64:
    return external_call["execve", Int64](path, argv, envp)


def _waitpid(pid: Int64, status: UnsafePointer[Int32, MutUntrackedOrigin], opts: Int32) -> Int64:
    return external_call["waitpid", Int64](pid, status, opts)


def _exit(code: Int32):
    _ = external_call["_exit", Int64](Int64(code))


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
    var argv = unsafe_alloc[CU8](argc + 1)
    var p0 = to_cstr(prog)
    argv[unsafe_offset=0] = p0
    for i in range(len(args)):
        argv[unsafe_offset=i + 1] = to_cstr(args[i])
    argv[unsafe_offset=argc] = CU8()
    var null_env = CArgv()
    _ = _execve(p0, argv, null_env)
    # execve only returns on failure.
    _exit(127)
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
