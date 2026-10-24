# New host-only consumer derived from our preserved worker probe.
# pthread join and bounded post-join procfs census are distinct observations.
from std.sys import argv
from hailbru.blocking_call import BlockingCall
from hailbru.syscall import os_host_architecture, os_blocking_pipe, os_close, os_write, unsafe_alloc, os_fail_closed, list_dir, os_clock_ms, os_sleep_ms


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: worker <normal|timeout|abandon>")
    var arch = os_host_architecture()
    var pipe = os_blocking_pipe()
    var thread_count = len(list_dir(arch, "/proc/self/task"))
    var worker = BlockingCall()
    try:
        worker.start_read(arch, Int64(999999) if args[1] == "read-error" else pipe[0])
    except error:
        _ = os_close(arch, pipe[0])
        _ = os_close(arch, pipe[1])
        raise error
    if args[1] == "abandon":
        # Destructor must terminate before List storage or fds can be released.
        return
    try:
        var refused = False
        try:
            _ = worker.result()
        except error:
            if String(error).find("WorkerState") < 0:
                raise error
            refused = True
        if not refused:
            raise Error("live worker result became visible")
        if args[1] == "timeout":
            if worker.join(25) or not worker.active:
                raise Error("blocked read failed to preserve live ownership on deadline")
        elif args[1] == "duplicate":
            var duplicate_refused = False
            try:
                worker.start_read(arch, pipe[0])
            except error:
                if String(error).find("WorkerState") < 0:
                    raise error
                duplicate_refused = True
            if not duplicate_refused:
                raise Error("duplicate worker start accepted")
        elif args[1] == "invalid-deadline":
            var invalid_refused = False
            try:
                _ = worker.join(0)
            except error:
                if String(error).find("BadDeadline") < 0:
                    raise error
                invalid_refused = True
            if not invalid_refused or not worker.active:
                raise Error("bad deadline lost active ownership")
        elif args[1] == "unwind":
            raise Error("ExpectedWorkerUnwind")
        elif args[1] != "normal" and args[1] != "read-error":
            raise Error("unknown mode")
    except error:
        # Closing our pipe writer wakes this test-only read with EOF.
        _ = os_close(arch, pipe[1])
        if not worker.join(1000):
            os_fail_closed(arch, 123)
        _ = os_close(arch, pipe[0])
        raise error
    var bytes = unsafe_alloc[UInt8](1)
    bytes[unsafe_offset=0] = 0xA5
    var wrote = os_write(arch, pipe[1], bytes, 1)
    bytes.unsafe_free()
    if wrote != 1:
        _ = os_close(arch, pipe[1])
        if not worker.join(1000):
            os_fail_closed(arch, 123)
        _ = os_close(arch, pipe[0])
        raise Error("pipe wake failed")
    if not worker.join(1000):
        os_fail_closed(arch, 123)
    _ = os_close(arch, pipe[0])
    _ = os_close(arch, pipe[1])
    var result = worker.result()
    var expected_result = Int64(-1) if args[1] == "read-error" else Int64(1)
    var expected_errno = Int64(9) if args[1] == "read-error" else Int64(0)
    var expected_payload = UInt8(0) if args[1] == "read-error" else UInt8(0xA5)
    if result[0] != expected_result or result[1] != expected_errno or worker.payload()[0] != expected_payload:
        raise Error("native callback result/errno/payload mismatch")
    var repeat_refused = False
    try:
        _ = worker.join(1)
    except error:
        if String(error).find("WorkerState") < 0:
            raise error
        repeat_refused = True
    if not repeat_refused:
        raise Error("joined worker admitted repeated join")
    var start = os_clock_ms(arch)
    if start < 0:
        raise Error("post-join census clock failed")
    var last = start
    var quiescent = False
    for _ in range(128):
        var now = os_clock_ms(arch)
        if now < last or now - start >= 200:
            raise Error("post-join census exceeded its monotonic budget")
        var observed = len(list_dir(arch, "/proc/self/task"))
        var after = os_clock_ms(arch)
        if after < now or after - start >= 200:
            raise Error("post-join census returned after its monotonic budget")
        last = after
        if observed == thread_count:
            quiescent = True
            break
        os_sleep_ms(arch, 1)
    if not quiescent:
        raise Error("post-join census exhausted its bounded observations")
    print("{\"joined\":true,\"result\":" + String(result[0]) + ",\"errno\":" + String(result[1]) + ",\"payload\":" + String(expected_payload) + ",\"repeat_join_refused\":true,\"worker_threads_remaining\":0}")
