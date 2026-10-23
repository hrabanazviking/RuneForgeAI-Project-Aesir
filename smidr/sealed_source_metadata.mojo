# Original observed JSON input ownership; existing readers/parsers do all decoding.
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy, read_sealed_source_digest, _require_sealed_source
from hailbru.syscall import os_host_architecture, os_openat, os_fd_regular_size, os_close_descriptor, O_RDONLY, O_CLOEXEC
from smidr.source_metadata_file import _regular_bytes
from smidr.source_config import SourceConfigPolicy, SourceConfiguration, parse_source_config, _admit
from smidr.source_index import SourceIndexPolicy, SourceShardIndex, parse_source_index, _policy


@fieldwise_init
struct SealedSourceConfig(Movable):
    var source: SealedSourceBytes
    var config: SourceConfiguration
    var digest_hex: String
    var label: String

    def close(mut self) raises:
        self.source.close()


@fieldwise_init
struct SealedSourceIndex(Movable):
    var source: SealedSourceBytes
    var index: SourceShardIndex
    var digest_hex: String
    var label: String

    def close(mut self) raises:
        self.source.close()


def _validated_extent(source: SealedSourceBytes) raises -> Int:
    var arch = os_host_architecture()
    if arch != source.arch:
        raise Error("SealedSourceMetadata: actual host differs from source owner")
    _require_sealed_source(arch, source.fd, source.source_bytes)
    if source.source_bytes >= 9223372036854775807:
        raise Error("SealedSourceMetadata: exact source/lookahead extent required")
    return Int(source.source_bytes)


def read_sealed_metadata_bytes(source: SealedSourceBytes, byte_bound: Int) raises -> List[UInt8]:
    if byte_bound <= 0:
        raise Error("SealedSourceMetadata: explicit positive metadata byte bound required")
    var size = _validated_extent(source)
    if size > byte_bound:
        raise Error("SealedSourceMetadata: metadata extent exceeds byte bound")
    # Borrow the live exclusive byte owner. The existing helper owns scratch
    # bytes only and retains its8192-byte requests/single EOF lookahead.
    var data = _regular_bytes(source.arch, source.fd, size, True)
    _ = _validated_extent(source)
    return data^


def parse_sealed_source_config(var source: SealedSourceBytes, label: String,
        policy: SourceConfigPolicy, digest_call_bound: Int) raises -> SealedSourceConfig:
    var size = _validated_extent(source)
    _ = _admit(policy, size)
    if digest_call_bound <= 0:
        raise Error("SealedSourceMetadata: explicit positive digest-call bound required")
    var digest = read_sealed_source_digest(source, 0, size, max(1, size), digest_call_bound)
    var data = read_sealed_metadata_bytes(source, policy.bytes)
    var config = parse_source_config(data, policy)
    config.source_path = label
    return SealedSourceConfig(source^, config^, digest.digest_hex, label)


def parse_sealed_source_index(var source: SealedSourceBytes, label: String,
        policy: SourceIndexPolicy, digest_call_bound: Int) raises -> SealedSourceIndex:
    var size = _validated_extent(source)
    _ = _policy(policy, size)
    if digest_call_bound <= 0:
        raise Error("SealedSourceMetadata: explicit positive digest-call bound required")
    var digest = read_sealed_source_digest(source, 0, size, max(1, size), digest_call_bound)
    var data = read_sealed_metadata_bytes(source, policy.bytes)
    var index = parse_source_index(data, policy)
    index.source_path = label
    return SealedSourceIndex(source^, index^, digest.digest_hex, label)


def _copy_path(path: String, source_byte_bound: Int, read_call_bound: Int,
        write_call_bound: Int, digest_call_bound: Int) raises -> SealedSourceBytes:
    if path.byte_length() == 0 or path.byte_length() >= 4096 or "\0" in path:
        raise Error("SealedSourceMetadata: path requires1..4095 non-NUL bytes")
    var arch = os_host_architecture()
    if arch != "aarch64":
        raise Error("SealedSourceMetadata: ARM64 Linux required")
    var fd = os_openat(arch, path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("SealedSourceMetadata: original open failed")
    try:
        var bytes = seal_source_copy(arch, fd, os_fd_regular_size(arch, fd),
            source_byte_bound, read_call_bound, write_call_bound, digest_call_bound)
        var original = fd
        fd = -1
        if os_close_descriptor(original) != 0:
            raise Error("SealedSourceMetadata: original close failed")
        return bytes^
    except e:
        if fd >= 0:
            _ = os_close_descriptor(fd)
        raise e


def load_sealed_source_config(path: String, source_byte_bound: Int,
        read_call_bound: Int, write_call_bound: Int, digest_call_bound: Int,
        policy: SourceConfigPolicy) raises -> SealedSourceConfig:
    _ = _admit(policy, 0)
    var bytes = _copy_path(path, source_byte_bound, read_call_bound, write_call_bound, digest_call_bound)
    return parse_sealed_source_config(bytes^, path, policy, digest_call_bound)


def load_sealed_source_index(path: String, source_byte_bound: Int,
        read_call_bound: Int, write_call_bound: Int, digest_call_bound: Int,
        policy: SourceIndexPolicy) raises -> SealedSourceIndex:
    _ = _policy(policy, 0)
    var bytes = _copy_path(path, source_byte_bound, read_call_bound, write_call_bound, digest_call_bound)
    return parse_sealed_source_index(bytes^, path, policy, digest_call_bound)
