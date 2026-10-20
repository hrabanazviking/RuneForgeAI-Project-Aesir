# Own exactly one fd and copy only prefix/header bytes. No mmap or tensor reads.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import (
    os_host_architecture, os_fd_regular_size, os_pread_metadata,
    os_close_descriptor, errno_now,
)
from armvegr.safetensors import decode_safetensors_header, safetensors_header_length
from smidr.safetensors_inventory import SafetensorsInventory, safetensors_inventory_from_header


@fieldwise_init
struct SafetensorsFdPolicy(Copyable, Movable):
    var header_bytes: Int
    var tensors: Int
    var rank: Int
    var work: Int
    var depth: Int
    var read_bytes: Int


def _policy(policy: SafetensorsFdPolicy) raises:
    if policy.header_bytes <= 0 or policy.tensors <= 0 or policy.rank <= 0 or policy.work <= 0 or policy.depth <= 0 or policy.depth > 64 or policy.read_bytes <= 0:
        raise Error("SafetensorsFd: positive policies and depth at most64 required")


def _append_range(arch: String, fd: Int64, offset: Int, count: Int,
                  mut data: List[UInt8]) raises:
    var chunk = List[UInt8](length=8192, fill=0)
    var copied = 0
    while copied < count:
        var want = min(8192, count - copied)
        var n = os_pread_metadata(arch, fd, Pointer[UInt8, MutUntrackedOrigin](
            unsafe_from_address=Int(chunk.unsafe_ptr())), Int64(want), Int64(offset + copied))
        if n < 0:
            raise Error("SafetensorsFd: positional read failed: " + String(errno_now()))
        if n == 0 or n > Int64(want):
            raise Error("SafetensorsFd: early EOF or invalid positional-read count")
        for i in range(Int(n)):
            data.append(chunk[i])
        copied += Int(n)


def read_safetensors_owned_fd(owned_fd: Int64, policy: SafetensorsFdPolicy) raises -> SafetensorsInventory:
    # Ownership is consumed on entry, including host/policy/parse failure.
    # The native close gateway never relies on a caller-supplied architecture.
    var fd = owned_fd
    try:
        if fd < 0 or fd > 2147483647:
            raise Error("SafetensorsFd: invalid consumed descriptor")
        _policy(policy)
        var arch = os_host_architecture()
        if arch != "aarch64":
            raise Error("SafetensorsFd: positional reader currently requires ARM64 Linux")
        var size = os_fd_regular_size(arch, fd)
        if size < 8 or policy.read_bytes < 8:
            raise Error("SafetensorsFd: prefix extent/read policy refusal")
        var data = List[UInt8]()
        data.reserve(8)
        _append_range(arch, fd, 0, 8, data)
        var header_size = safetensors_header_length(data, size, policy.header_bytes)
        if header_size > policy.read_bytes - 8:
            raise Error("SafetensorsFd: exact header read byte policy exceeded")
        data.reserve(8 + header_size)
        _append_range(arch, fd, 8, header_size, data)
        var header = decode_safetensors_header(data, size, policy.header_bytes,
            policy.tensors, policy.rank, policy.work, policy.depth)
        if os_fd_regular_size(arch, fd) != size:
            raise Error("SafetensorsFd: source extent changed during header read")
        var result = safetensors_inventory_from_header(header)
        var closed = os_close_descriptor(fd)
        fd = -1
        if closed != 0:
            raise Error("SafetensorsFd: consumed descriptor close failed")
        return result^
    except e:
        if fd >= 0:
            _ = os_close_descriptor(fd)
        raise e
