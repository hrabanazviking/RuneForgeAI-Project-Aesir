# First source-owner adapter for format-neutral source-byte hashing.
from loader.packed_gguf import PackedGGUF
from hailbru.source_digest import digest_borrowed_regular_window
from hailbru.syscall import os_host_architecture


@fieldwise_init
struct SourceByteDigest(Movable):
    var source_bytes: Int64
    var first: Int
    var count: Int
    var read_calls: Int
    var digest_hex: String


def read_source_byte_digest(source: PackedGGUF, first: Int, count: Int,
        read_byte_bound: Int, read_call_bound: Int) raises -> SourceByteDigest:
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceByteDigest: live mapped source owner required")
    var size = source.source.file_size
    if size < 0 or source.data_offset < 0 or Int64(source.data_offset) > size:
        raise Error("SourceByteDigest: invalid source size/data origin")
    var result = digest_borrowed_regular_window(os_host_architecture(),
        Int64(source.source.fd), size, first, count, read_byte_bound, read_call_bound)
    return SourceByteDigest(result.source_bytes, result.first, result.count,
        result.read_calls, result.digest_hex)


def read_source_byte_digest_window(path: String, first: Int, count: Int,
        read_byte_bound: Int, read_call_bound: Int) raises -> SourceByteDigest:
    var source = PackedGGUF(path)
    return read_source_byte_digest(source, first, count, read_byte_bound, read_call_bound)
