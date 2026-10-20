# Exact bounded Linux regular-file bytes. No format/parser/model/device work.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import (
    os_host_architecture, os_openat, os_close, os_read,
    os_fd_regular_size, O_RDONLY, O_CLOEXEC, errno_now,
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
        var bytes = List[UInt8]()
        bytes.reserve(Int(size) + 1)
        var chunk = List[UInt8](length=8192, fill=0)
        var target = Int(size) + 1
        while len(bytes) < target:
            var want = min(8192, target - len(bytes))
            var n = os_read(arch, fd, Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=Int(chunk.unsafe_ptr())), Int64(want))
            if n < 0:
                raise Error("SourceMetadataFile: read failed: " + String(errno_now()))
            if n == 0:
                break
            if n > Int64(want):
                raise Error("SourceMetadataFile: invalid read count")
            for i in range(Int(n)):
                bytes.append(chunk[i])
        if len(bytes) != size or Int(os_fd_regular_size(arch, fd)) != size:
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
