# Original owned host-byte copy. No model parsing, inference or device access.
# Public Linux fields qualified in HAILO10H_SEALED_SOURCE_COPY_CONTRACT.md.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import syscall6, to_cstr, errno_now, os_close_descriptor, os_fd_regular_size, os_pread_metadata, os_pwrite
from hailbru.source_digest import BorrowedSourceDigest, digest_borrowed_regular_window


struct SealedSourceBytes(Movable):
    var arch: String
    var fd: Int64
    var source_bytes: Int64
    var digest_hex: String
    var source_read_calls: Int
    var copy_write_calls: Int
    var digest_read_calls: Int

    def __init__(out self):
        self.arch = String("")
        self.fd = -1
        self.source_bytes = 0
        self.digest_hex = String("")
        self.source_read_calls = 0
        self.copy_write_calls = 0
        self.digest_read_calls = 0

    def __deinit__(deinit self):
        if self.fd >= 0:
            if os_close_descriptor(self.fd) != 0:
                print("SourceSealedCopy: implicit descriptor close failed")

    def close(mut self) raises:
        if self.fd < 0:
            return
        var owned = self.fd
        self.fd = -1
        if os_close_descriptor(owned) != 0:
            raise Error("SourceSealedCopy: descriptor close failed")


@fieldwise_init
struct _CopyCalls(ImplicitlyCopyable, Movable):
    var reads: Int
    var writes: Int


def _copy_source_bytes(arch: String, source: Int64, destination: Int64,
        size: Int, read_bound: Int, write_bound: Int) raises -> _CopyCalls:
    # This helper's sole scratch owner is destroyed before sealed digest reads.
    var scratch = List[UInt8](length=min(4096, size), fill=0)
    var done = 0
    var reads = 0
    var writes = 0
    while done < size:
        if reads >= read_bound:
            raise Error("SourceSealedCopy: source read-call bound exhausted")
        var want = min(4096, size - done)
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(scratch.unsafe_ptr()))
        reads += 1
        var n = os_pread_metadata(arch, source, pointer, Int64(want), Int64(done))
        _ = scratch
        if n < 0:
            if errno_now() == 4:
                continue
            raise Error("SourceSealedCopy: source positional read failed")
        if n == 0 or n > Int64(want):
            raise Error("SourceSealedCopy: source read made invalid progress")
        var sent = 0
        while sent < Int(n):
            if writes >= write_bound:
                raise Error("SourceSealedCopy: copy write-call bound exhausted")
            var from_byte = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(scratch.unsafe_ptr()) + sent)
            writes += 1
            var wrote = os_pwrite(arch, destination, from_byte, n - Int64(sent), Int64(done + sent))
            _ = scratch
            if wrote < 0:
                if errno_now() == 4:
                    continue
                raise Error("SourceSealedCopy: destination positional write failed")
            if wrote == 0 or wrote > n - Int64(sent):
                raise Error("SourceSealedCopy: destination write made invalid progress")
            sent += Int(wrote)
        done += Int(n)
    return _CopyCalls(reads, writes)


def _require_sealed_source(arch: String, fd: Int64, size: Int64) raises:
    if arch != "aarch64" or fd < 0 or fd > 2147483647 or size < 0 or UInt64(size) > UInt64(2305843009213693951):
        raise Error("SourceSealedCopy: invalid live host/descriptor/extent")
    var seals = syscall6(25, fd, 1034, 0, 0, 0, 0)
    if seals < 0 or (seals & 15) != 15:
        raise Error("SourceSealedCopy: required kernel seals are missing")
    if os_fd_regular_size(arch, fd) != size:
        raise Error("SourceSealedCopy: sealed extent differs from owner")


def seal_source_copy(arch: String, source_fd: Int64, expected_size: Int64,
        source_byte_bound: Int, read_call_bound: Int, write_call_bound: Int,
        digest_call_bound: Int) raises -> SealedSourceBytes:
    if arch != "aarch64" or source_fd < 0 or source_fd > 2147483647:
        raise Error("SourceSealedCopy: ARM64 Linux and exact source fd required")
    if expected_size < 0 or UInt64(expected_size) > UInt64(2305843009213693951):
        raise Error("SourceSealedCopy: invalid source byte size")
    if source_byte_bound <= 0 or expected_size > Int64(source_byte_bound) or read_call_bound <= 0 or write_call_bound <= 0 or digest_call_bound <= 0:
        raise Error("SourceSealedCopy: explicit positive byte/read/write/digest bounds required")
    if os_fd_regular_size(arch, source_fd) != expected_size:
        raise Error("SourceSealedCopy: source extent differs before copy")
    var name = to_cstr("aesir-source-copy")
    var fd = syscall6(279, Int64(Int(name)), 3, 0, 0, 0, 0)
    name.unsafe_free()
    if fd < 0 or fd > 2147483647 or fd == source_fd:
        raise Error("SourceSealedCopy: creation did not return a new exact descriptor")
    var result = SealedSourceBytes()
    result.arch = arch
    result.fd = fd
    result.source_bytes = expected_size
    var calls = _copy_source_bytes(arch, source_fd, fd, Int(expected_size), read_call_bound, write_call_bound)
    result.source_read_calls = calls.reads
    result.copy_write_calls = calls.writes
    if os_fd_regular_size(arch, source_fd) != expected_size:
        raise Error("SourceSealedCopy: source extent differs after copy")
    if os_fd_regular_size(arch, fd) != expected_size:
        raise Error("SourceSealedCopy: copied extent differs from source size")
    if syscall6(25, fd, 1033, 15, 0, 0, 0) != 0:
        raise Error("SourceSealedCopy: kernel sealing failed")
    _require_sealed_source(arch, fd, expected_size)
    var digest = digest_borrowed_regular_window(arch, fd, expected_size, 0,
        Int(expected_size), source_byte_bound, digest_call_bound)
    result.digest_hex = digest.digest_hex
    result.digest_read_calls = digest.read_calls
    return result^


def read_sealed_source_digest(owner: SealedSourceBytes, first: Int, count: Int,
        read_byte_bound: Int, read_call_bound: Int) raises -> BorrowedSourceDigest:
    _require_sealed_source(owner.arch, owner.fd, owner.source_bytes)
    return digest_borrowed_regular_window(owner.arch, owner.fd, owner.source_bytes,
        first, count, read_byte_bound, read_call_bound)
