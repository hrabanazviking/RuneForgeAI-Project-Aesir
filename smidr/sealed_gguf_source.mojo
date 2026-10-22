# Own one sealed source for the existing GGUF parser and constant readers.
# Host parsing only. No model execution or device configuration.
from loader.packed_gguf import PackedGGUF
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy, read_sealed_source_digest
from hailbru.syscall import os_host_architecture, os_openat, os_close_descriptor, os_fd_regular_size, O_RDONLY, O_CLOEXEC


@fieldwise_init
struct SealedPackedGGUF(Movable):
    var source: PackedGGUF
    var source_bytes: Int64
    var digest_hex: String


def parse_sealed_packed_gguf(var bytes: SealedSourceBytes, label: String,
        digest_call_bound: Int) raises -> SealedPackedGGUF:
    if digest_call_bound <= 0:
        raise Error("SealedGGUF: explicit positive digest-call bound required")
    # The borrowed digest reader checks actual seals and exact extent first.
    # Ignore the owner's mutable claimed digest and recompute the whole file.
    var digest = read_sealed_source_digest(bytes, 0, Int(bytes.source_bytes),
        max(1, Int(bytes.source_bytes)), digest_call_bound)
    var extent = bytes.source_bytes
    var fd = bytes.take_fd()
    # PackedGGUF consumes fd, including every admission/header/table failure.
    var source = PackedGGUF(label, fd, extent)
    return SealedPackedGGUF(source^, extent, digest.digest_hex)


def load_sealed_packed_gguf(path: String, source_byte_bound: Int,
        read_call_bound: Int, write_call_bound: Int,
        digest_call_bound: Int) raises -> SealedPackedGGUF:
    if path.byte_length() == 0 or path.byte_length() >= 4096 or "\0" in path:
        raise Error("SealedGGUF: path requires 1..4095 non-NUL bytes")
    var arch = os_host_architecture()
    var fd = os_openat(arch, path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("SealedGGUF: source open failed")
    try:
        var bytes = seal_source_copy(arch, fd, os_fd_regular_size(arch, fd),
            source_byte_bound, read_call_bound, write_call_bound, digest_call_bound)
        var original = fd
        fd = -1
        if os_close_descriptor(original) != 0:
            raise Error("SealedGGUF: original close failed")
        return parse_sealed_packed_gguf(bytes^, path, digest_call_bound)
    except e:
        if fd >= 0:
            _ = os_close_descriptor(fd)
        raise e
