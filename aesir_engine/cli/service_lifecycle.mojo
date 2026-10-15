"""One foreground service per model store, with fail-closed process identity.

The locked owner-only record is an observation, not authority to send a raw
signal to a PID. Stop pins the process with pidfd, verifies its boot/start
identity, and only then signals that pinned instance.
"""
from std.ffi import external_call
from std.collections import InlineArray
from std.memory import Pointer
from aesir import bounded_decimal
from cli.storage import _cstring, _ensure_store_root, _lock_store_root, validate_store_root
from core.linux_cgroups import read_kernel_observation


comptime SERVICE_HEADER = "AESIR_SERVICE_V1"


struct ServiceOwner:
    var fd: Int32

    def __init__(out self, fd: Int32):
        self.fd = fd

    def __deinit__(deinit self):
        if self.fd >= 0:
            _ = external_call["close", Int32](self.fd)


struct ServiceSnapshot:
    var live: Bool
    var pid: Int32
    var boot: String
    var started: String
    var port: Int
    var model: String
    var digest: String
    var mode: String

    def __init__(out self, live: Bool = False, pid: Int32 = 0,
                 boot: String = "", started: String = "", port: Int = 0,
                 model: String = "", digest: String = "", mode: String = ""):
        self.live = live
        self.pid = pid
        self.boot = boot
        self.started = started
        self.port = port
        self.model = model
        self.digest = digest
        self.mode = mode


def _errno() -> Int32:
    return external_call[
        "__errno_location", Pointer[Int32, MutUntrackedOrigin]
    ]().unsafe_load()


def _hex(value: String) -> String:
    var digits = String("0123456789abcdef")
    var result = String("")
    for byte in value.as_bytes():
        var code = Int(byte)
        result += String(digits[byte=code >> 4:(code >> 4) + 1])
        result += String(digits[byte=code & 15:(code & 15) + 1])
    return result


def _unhex(value: String) raises -> String:
    if value.byte_length() % 2 != 0 or value.byte_length() > 8192:
        raise Error("invalid service record model encoding")
    var output = List[Int8]()
    var raw = value.as_bytes()
    for i in range(0, len(raw), 2):
        var hi = Int(raw[i])
        var lo = Int(raw[i + 1])
        hi = hi - 48 if hi >= 48 and hi <= 57 else (hi - 87 if hi >= 97 and hi <= 102 else -1)
        lo = lo - 48 if lo >= 48 and lo <= 57 else (lo - 87 if lo >= 97 and lo <= 102 else -1)
        if hi < 0 or lo < 0 or (hi == 0 and lo == 0):
            raise Error("invalid service record model encoding")
        output.append(Int8((hi << 4) | lo))
    output.append(0)
    return String(unsafe_from_utf8_ptr=output.unsafe_ptr())


def _boot_id() raises -> String:
    var boot = String(read_kernel_observation("/proc/sys/kernel/random/boot_id").strip())
    if boot.byte_length() != 36:
        raise Error("invalid kernel boot identity")
    return boot


def _process_start(pid: Int32) raises -> String:
    var observation = read_kernel_observation("/proc/" + String(pid) + "/stat")
    var close = -1
    for i in range(observation.byte_length()):
        if observation.as_bytes()[i] == 41:
            close = i
    if close < 0 or close + 2 >= observation.byte_length():
        raise Error("invalid kernel process identity")
    var columns = String(observation[byte=close + 2:]).split(" ")
    var index = 0
    for column in columns:
        if String(column) == "":
            continue
        if index == 19:
            var ticks = String(column.strip())
            if bounded_decimal(ticks) <= 0:
                raise Error("invalid kernel process start time")
            return ticks
        index += 1
    raise Error("incomplete kernel process identity")


def _checked_record_fd(fd: Int32) raises:
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0:
        raise Error("cannot inspect service ownership record")
    var mode = stat[3] & 4294967295
    var uid = stat[3] >> 32
    if (mode & 61440 != 32768 or mode & 511 != 384 or stat[2] != 1 or
            uid != UInt64(external_call["geteuid", UInt32]())):
        raise Error("service ownership record must be a private owner-only regular file")
    if stat[6] > 4096:
        raise Error("service ownership record exceeds 4 KiB")


def _open_record(store: String, create: Bool) raises -> Int32:
    var root = validate_store_root(store)
    if create:
        _ensure_store_root(root)
    var root_bytes = _cstring(root)
    if not create and external_call["access", Int32](root_bytes.unsafe_ptr(), 0) != 0:
        return -1
    var root_fd = _lock_store_root(root)
    var root_stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](root_fd, root_stat.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](root_fd)
        raise Error("cannot identify model store for service ownership")
    _ = external_call["close", Int32](root_fd)
    # DrvFS/NTFS can report mode 0777 for model-store files even when created
    # with 0600. Keep process-control identity only on Linux's private /tmp.
    var temp_name = _cstring("/tmp")
    var temp_fd = external_call["open64", Int32](temp_name.unsafe_ptr(), Int32(720896), Int32(0))
    if temp_fd < 0:
        raise Error("cannot open Linux runtime directory")
    var runtime_name = _cstring("aesir-runtime-" + String(external_call["geteuid", UInt32]()))
    if external_call["mkdirat", Int32](temp_fd, runtime_name.unsafe_ptr(), Int32(448)) != 0 and _errno() != 17:
        _ = external_call["close", Int32](temp_fd)
        raise Error("cannot create private service runtime directory")
    var runtime_fd = external_call["openat", Int32](temp_fd, runtime_name.unsafe_ptr(), Int32(720896), Int32(0))
    _ = external_call["close", Int32](temp_fd)
    if runtime_fd < 0:
        raise Error("cannot open private service runtime directory")
    var runtime_stat = InlineArray[UInt64, 18](fill=0)
    if (external_call["fstat", Int32](runtime_fd, runtime_stat.unsafe_ptr()) != 0 or
            runtime_stat[3] & 61440 != 16384 or runtime_stat[3] & 511 != 448 or
            runtime_stat[3] >> 32 != UInt64(external_call["geteuid", UInt32]())):
        _ = external_call["close", Int32](runtime_fd)
        raise Error("service runtime directory is not private to this user")
    var name = _cstring("service-" + String(root_stat[0]) + "-" + String(root_stat[1]) + ".v1")
    var flags = 655426 if create else 655362  # O_RDWR/CREAT/NOFOLLOW/CLOEXEC
    var fd = external_call["openat", Int32](runtime_fd, name.unsafe_ptr(), Int32(flags), Int32(384))
    var open_error = _errno() if fd < 0 else 0
    _ = external_call["close", Int32](runtime_fd)
    if fd < 0:
        if not create and open_error == 2:
            return -1
        raise Error("cannot open service ownership record")
    try:
        _checked_record_fd(fd)
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    return fd


def _read_record(fd: Int32) raises -> String:
    if external_call["lseek", Int64](fd, Int64(0), Int32(0)) != 0:
        raise Error("cannot seek service ownership record")
    var buffer = InlineArray[Int8, 4097](fill=0)
    var count = external_call["read", Int](Int(fd), buffer.unsafe_ptr(), Int(4097))
    if count <= 0 or count > 4096:
        raise Error("invalid service ownership record length")
    for i in range(count):
        if buffer[i] == 0:
            raise Error("invalid service ownership record content")
    buffer[count] = 0
    return String(unsafe_from_utf8_ptr=buffer.unsafe_ptr())


def _parse_record(raw: String) raises -> ServiceSnapshot:
    var lines = raw.split("\n")
    if len(lines) != 9 or String(lines[0]) != SERVICE_HEADER or String(lines[8]) != "":
        raise Error("invalid service ownership record schema")
    var pid = bounded_decimal(String(lines[1]))
    var boot = String(lines[2])
    var started = String(lines[3])
    var port = bounded_decimal(String(lines[4]))
    var mode = String(lines[5])
    var digest = String(lines[6])
    var model = _unhex(String(lines[7]))
    if (pid <= 0 or pid > 2147483647 or boot.byte_length() != 36 or
            bounded_decimal(started) <= 0 or port < 1024 or port > 65535 or
            (mode != "native" and mode != "ollama") or
            model.byte_length() == 0 or model.byte_length() > 4096 or
            digest.byte_length() > 96):
        raise Error("invalid service ownership record fields")
    return ServiceSnapshot(True, Int32(pid), boot, started, port, model, digest, mode)


def _live_record(fd: Int32) raises -> ServiceSnapshot:
    # A stale record is not a live service. The owner holds LOCK_EX until exit.
    if external_call["flock", Int32](fd, 5) == 0:
        _ = external_call["close", Int32](fd)
        return ServiceSnapshot()
    if _errno() != 11:
        _ = external_call["close", Int32](fd)
        raise Error("cannot inspect service ownership lock")
    var snapshot: ServiceSnapshot
    try:
        snapshot = _parse_record(_read_record(fd))
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    _ = external_call["close", Int32](fd)
    return snapshot^

def register_service(store: String, port: Int, model: String,
                     digest: String, mode: String) raises -> ServiceOwner:
    """Publish an owner-locked record only after the listener and model exist."""
    if (port < 1024 or port > 65535 or model.byte_length() == 0 or
            model.byte_length() > 2048 or (mode != "native" and mode != "ollama") or
            digest.byte_length() > 96):
        raise Error("invalid service ownership metadata")
    var fd = _open_record(store, True)
    if external_call["flock", Int32](fd, 6) != 0:
        _ = external_call["close", Int32](fd)
        raise Error("a foreground service already owns this model store")
    try:
        var pid = external_call["getpid", Int32]()
        var raw = (SERVICE_HEADER + "\n" + String(pid) + "\n" + _boot_id() +
                   "\n" + _process_start(pid) + "\n" + String(port) + "\n" +
                   mode + "\n" + digest + "\n" + _hex(model) + "\n")
        if raw.byte_length() > 4096 or external_call["ftruncate", Int32](fd, Int64(0)) != 0 or external_call["lseek", Int64](fd, Int64(0), Int32(0)) != 0:
            raise Error("cannot prepare service ownership record")
        var raw_bytes = raw.as_bytes()
        var written = 0
        while written < len(raw_bytes):
            var count = external_call["write", Int](Int(fd), raw_bytes.unsafe_ptr().unsafe_offset(written), len(raw_bytes) - written)
            if count < 0 and _errno() == 4:
                continue
            if count <= 0:
                raise Error("cannot write service ownership record")
            written += count
        if external_call["fsync", Int32](fd) != 0:
            raise Error("cannot synchronize service ownership record")
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    return ServiceOwner(fd)


def service_snapshot(store: String) raises -> ServiceSnapshot:
    var fd = _open_record(store, False)
    if fd < 0:
        return ServiceSnapshot()
    var snapshot = _live_record(fd)
    if not snapshot.live:
        return snapshot^
    # ps must not report a stale PID merely because some process holds the file.
    var handle = external_call["pidfd_open", Int32](snapshot.pid, UInt32(0))
    if handle < 0:
        return ServiceSnapshot()
    var matches = False
    try:
        matches = (_boot_id() == snapshot.boot and
                   _process_start(snapshot.pid) == snapshot.started)
    except:
        pass
    _ = external_call["close", Int32](handle)
    if not matches:
        return ServiceSnapshot()
    return snapshot^


def stop_service(store: String, requested_model: String) raises -> ServiceSnapshot:
    """Signal only the pidfd-pinned process that still owns this record."""
    var fd = _open_record(store, False)
    if fd < 0:
        raise Error("no live service owns this model store")
    # Keep this descriptor open across both identity checks and signaling.
    if external_call["flock", Int32](fd, 5) == 0:
        _ = external_call["close", Int32](fd)
        raise Error("no live service owns this model store")
    if _errno() != 11:
        _ = external_call["close", Int32](fd)
        raise Error("cannot inspect service ownership lock")
    var raw: String
    var snapshot: ServiceSnapshot
    try:
        raw = _read_record(fd)
        snapshot = _parse_record(raw)
    except error:
        _ = external_call["close", Int32](fd)
        raise error
    if requested_model != snapshot.model:
        _ = external_call["close", Int32](fd)
        raise Error("requested model is not the owned resident service")
    var handle = external_call["pidfd_open", Int32](snapshot.pid, UInt32(0))
    if handle < 0:
        _ = external_call["close", Int32](fd)
        raise Error("service process identity is stale or pidfd is unavailable")
    try:
        if (_boot_id() != snapshot.boot or
                _process_start(snapshot.pid) != snapshot.started or
                _read_record(fd) != raw):
            raise Error("service process identity changed; refusing stop")
        # An exited owner releases LOCK_EX; a replacement record must not be
        # treated as authority for this pinned handle.
        if external_call["flock", Int32](fd, 5) == 0:
            raise Error("service exited before stop; refusing stale identity")
        if _errno() != 11:
            raise Error("cannot recheck service ownership lock")
        if external_call["pidfd_send_signal", Int32](handle, Int32(15), Int(0), UInt32(0)) != 0:
            raise Error("cannot stop the pinned service process")
    except error:
        _ = external_call["close", Int32](handle)
        _ = external_call["close", Int32](fd)
        raise error
    _ = external_call["close", Int32](handle)
    _ = external_call["close", Int32](fd)
    return snapshot^
