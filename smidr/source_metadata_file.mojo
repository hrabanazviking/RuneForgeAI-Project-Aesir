# Exact bounded Linux regular-file bytes. No format/parser/model/device work.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import (
    os_host_architecture, os_openat, os_close, os_read,
    os_fd_regular_size, O_RDONLY, O_CLOEXEC, errno_now,
    os_pread_metadata, os_close_descriptor,
)


def read_source_metadata_bytes(path: String, byte_bound: Int) raises -> List[UInt8]:
    if byte_bound <= 0:
        raise Error("SourceMetadataFile: positive representable byte bound required")
    if path.byte_length() == 0 or path.byte_length() >= 4096 or "\0" in path:
        raise Error("SourceMetadataFile: path requires 1..4095 non-NUL bytes")
    var arch = os_host_architecture()
    # Linux O_NONBLOCK is 0x800 on both admitted architectures. Final symlinks
    # may resolve to regular files; all subsequent checks/reads use this same fd.
    var fd = os_openat(arch, path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("SourceMetadataFile: open failed: " + String(errno_now()))
    try:
        var size = Int(os_fd_regular_size(arch, fd))
        if size > byte_bound or size >= 9223372036854775807:
            raise Error("SourceMetadataFile: source exceeds byte bound")
        var bytes = _regular_bytes(arch, fd, size, False)
        if Int(os_fd_regular_size(arch, fd)) != size:
            raise Error("SourceMetadataFile: source extent changed during read")
        var result = os_close(arch, fd)
        fd = -1
        if result != 0:
            raise Error("SourceMetadataFile: close failed")
        return bytes^
    except e:
        if fd >= 0:
            _ = os_close(arch, fd)
        raise e


def read_source_metadata_owned_fd(owned_fd: Int64, byte_bound: Int) raises -> List[UInt8]:
    # Exclusive ownership is consumed on entry, including bad policy/host errors.
    var fd = owned_fd
    try:
        if fd < 0 or fd > 2147483647 or byte_bound <= 0:
            raise Error("SourceMetadataFile: invalid owned descriptor or byte bound")
        var arch = os_host_architecture()
        if arch != "aarch64":
            raise Error("SourceMetadataFile: positional owned reader currently requires ARM64 Linux")
        var size = Int(os_fd_regular_size(arch, fd))
        if size > byte_bound or size >= 9223372036854775807:
            raise Error("SourceMetadataFile: source exceeds byte/lookahead extent bound")
        var data = _regular_bytes(arch, fd, size, True)
        if os_fd_regular_size(arch, fd) != Int64(size):
            raise Error("SourceMetadataFile: exact owned source extent changed")
        var closed = os_close_descriptor(fd)
        fd = -1
        if closed != 0:
            raise Error("SourceMetadataFile: owned descriptor close failed")
        return data^
    except e:
        if fd >= 0:
            _ = os_close_descriptor(fd)
        raise e


def _regular_bytes(arch: String, fd: Int64, size: Int,
                    positional: Bool) raises -> List[UInt8]:
    if size < 0 or size >= 9223372036854775807:
        raise Error("SourceMetadataFile: invalid exact-read/lookahead size")
    var data = List[UInt8]()
    data.reserve(size + 1)
    var chunk = List[UInt8](length=8192, fill=0)
    var target = size + 1
    while len(data) < target:
        var want = min(8192, target - len(data))
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(chunk.unsafe_ptr()))
        var n: Int64
        if positional:
            n = os_pread_metadata(arch, fd, pointer, Int64(want), Int64(len(data)))
        else:
            n = os_read(arch, fd, pointer, Int64(want))
        if n < 0:
            raise Error("SourceMetadataFile: read failed: " + String(errno_now()))
        if n == 0:
            break
        if n > Int64(want):
            raise Error("SourceMetadataFile: invalid read count")
        for i in range(Int(n)):
            data.append(chunk[i])
    if len(data) != size:
        raise Error("SourceMetadataFile: source extent changed during read")
    return data^
