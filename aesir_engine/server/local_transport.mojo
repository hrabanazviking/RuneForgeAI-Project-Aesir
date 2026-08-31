"""Linux x86-64 bounded loopback transport; no inference or compatibility routing."""
from std.collections import InlineArray
from std.ffi import external_call
from std.memory import Pointer
from core.generation_control import monotonic_milliseconds
from server.local_protocol import LocalHTTPHead


def io_errno() -> Int:
    return Int(external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load())


def c_path_bytes(path: String) raises -> List[Int8]:
    # Mojo String storage is not guaranteed to have a C NUL terminator.
    if path.byte_length() == 0 or path.byte_length() >= 4096:
        raise Error("Native path must contain 1..4095 UTF-8 bytes")
    var bytes = List[Int8]()
    for byte in path.as_bytes():
        if byte == 0:
            raise Error("Native path contains NUL")
        bytes.append(Int8(byte))
    bytes.append(0)
    return bytes^


struct OwnedFD:
    var fd: Int32

    def __init__(out self, fd: Int32) raises:
        if fd < 0:
            raise Error("Cannot open native service descriptor")
        self.fd = fd

    def __deinit__(deinit self):
        _ = external_call["close", Int32](self.fd)


def wait_io(fd: Int32, events: Int, deadline: Int, cancel_fd: Int) raises:
    while True:
        var left = 1000 if deadline == 0 else deadline - monotonic_milliseconds()
        if left <= 0:
            raise Error("Service I/O deadline exceeded")
        var descriptors = InlineArray[UInt64, 2](fill=0)
        descriptors[0] = UInt64(UInt32(fd)) | (UInt64(events) << 32)
        descriptors[1] = UInt64(UInt32(cancel_fd)) | (UInt64(1) << 32)
        var ready = external_call["poll", Int32](descriptors.unsafe_ptr(), UInt64(2), Int32(min(left, 1000)))
        if ready < 0:
            if io_errno() == 4:
                continue
            raise Error("Service poll failed")
        if descriptors[1] >> 48 != 0:
            raise Error("Service interrupted")
        if descriptors[0] >> 48 != 0:
            return


def load_service_key(path: String) raises -> String:
    if path.byte_length() == 0 or "\0" in path:
        raise Error("Service requires an API key file")
    # O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK; inspect the opened inode, not its path.
    var path_bytes = c_path_bytes(path)
    var file = OwnedFD(external_call["open64", Int32](path_bytes.unsafe_ptr(), Int32(657408), Int32(0)))
    _ = path_bytes
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](file.fd, stat.unsafe_ptr()) != 0:
        raise Error("Cannot inspect service key file")
    var mode = stat[3] & 4294967295
    var uid = stat[3] >> 32
    if mode & 61440 != 32768 or mode & 63 != 0 or uid != UInt64(external_call["geteuid", UInt32]()):
        raise Error("API key must be an owner-only regular file owned by the current user")
    if stat[6] < 32 or stat[6] > 257:
        raise Error("API key must contain 32..256 ASCII token characters")
    var buffer = InlineArray[Int8, 258](fill=0)
    var length = 0
    while True:
        var count = external_call["read", Int](Int(file.fd), buffer.unsafe_ptr().unsafe_offset(length), 258 - length)
        if count < 0:
            if io_errno() == 4:
                continue
            raise Error("Cannot read API key")
        if count == 0:
            break
        length += count
        if length >= 258:
            raise Error("API key changed or exceeds limit")
    _ = file
    if length > 0 and buffer[length - 1] == 10:
        length -= 1
    if length < 32 or length > 256:
        raise Error("API key length outside 32..256")
    for i in range(length):
        var byte = Int(buffer[i])
        if not ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57) or byte == 45 or byte == 95):
            raise Error("API key must use letters, digits, hyphen or underscore")
    buffer[length] = 0
    var result = String(unsafe_from_utf8_ptr=buffer.unsafe_ptr())
    _ = buffer
    return result


def listen_local(port: Int) raises -> OwnedFD:
    if port < 1024 or port > 65535:
        raise Error("Native service port must be in 1024..65535")
    var listener = OwnedFD(external_call["socket", Int32](2, 526337, 0))
    var address = InlineArray[UInt16, 8](fill=0)
    address[0] = 2
    address[1] = UInt16((port >> 8) | ((port & 255) << 8))
    address[2] = 127
    address[3] = 256  # network bytes 127.0.0.1, never INADDR_ANY
    var reuse = InlineArray[Int32, 1](fill=1)
    if external_call["setsockopt", Int32](listener.fd, Int32(1), Int32(2), reuse.unsafe_ptr().unsafe_bitcast[Int8](), 4) != 0:
        raise Error("Cannot configure service listener")
    if external_call["bind", Int32](listener.fd, address.unsafe_ptr().unsafe_bitcast[Int8](), 16) != 0:
        raise Error("Cannot bind native loopback service")
    if external_call["listen", Int32](listener.fd, 8) != 0:
        raise Error("Cannot listen for local inference requests")
    return listener^


def accept_local(listener: Int32, cancel_fd: Int) raises -> OwnedFD:
    while True:
        wait_io(listener, 1, 0, cancel_fd)
        # No address is needed: the listener only binds IPv4 loopback.
        var fd = external_call["accept4", Int32](listener, Int(0), Int(0), Int32(526336))
        if fd >= 0:
            return OwnedFD(fd)
        if io_errno() != 4 and io_errno() != 11:
            raise Error("Cannot accept native service client")


def receive_head(fd: Int32, deadline: Int, cancel_fd: Int) raises -> String:
    # One-byte reads avoid accidentally consuming a body before authentication.
    # Headers are capped at 8 KiB and local service concurrency is one.
    var bytes = List[Int8]()
    var byte = InlineArray[Int8, 1](fill=0)
    while len(bytes) < 8192:
        wait_io(fd, 1, deadline, cancel_fd)
        var count = external_call["recv", Int64](fd, byte.unsafe_ptr(), Int(1), 0)
        if count < 0 and (io_errno() == 4 or io_errno() == 11):
            continue
        if count <= 0:
            raise Error("Client closed during HTTP headers")
        if byte[0] == 0:
            raise Error("NUL in HTTP headers")
        bytes.append(byte[0])
        var size = len(bytes)
        if size >= 4 and bytes[size - 4] == 13 and bytes[size - 3] == 10 and bytes[size - 2] == 13 and bytes[size - 1] == 10:
            bytes.append(0)
            var result = String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())
            _ = bytes
            return result
    raise Error("HTTP headers exceed 8 KiB")


def receive_body(fd: Int32, length: Int, deadline: Int, cancel_fd: Int) raises -> String:
    if length < 0 or length > 131072:
        raise Error("HTTP body exceeds limit")
    var bytes = List[Int8](capacity=length + 1)
    for _ in range(length + 1):
        bytes.append(0)
    var offset = 0
    while offset < length:
        wait_io(fd, 1, deadline, cancel_fd)
        var count = external_call["recv", Int64](fd, bytes.unsafe_ptr().unsafe_offset(offset), length - offset, 0)
        if count < 0 and (io_errno() == 4 or io_errno() == 11):
            continue
        if count <= 0:
            raise Error("Client closed during HTTP body")
        offset += Int(count)
    for i in range(length):
        if bytes[i] == 0:
            raise Error("NUL in HTTP body")
    var result = String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())
    _ = bytes
    return result


def send_local(fd: Int32, data: String, timeout_ms: Int, cancel_fd: Int) raises:
    var deadline = monotonic_milliseconds() + timeout_ms
    var offset = 0
    var bytes = data.as_bytes()
    while offset < len(bytes):
        wait_io(fd, 4, deadline, cancel_fd)
        var count = external_call["send", Int64](fd, bytes.unsafe_ptr().unsafe_offset(offset).unsafe_bitcast[Int8](), len(bytes) - offset, 16384)
        if count < 0 and (io_errno() == 4 or io_errno() == 11):
            continue
        if count <= 0:
            raise Error("Client closed during HTTP response")
        offset += Int(count)
    _ = bytes
