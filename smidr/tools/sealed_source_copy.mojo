# Bounded ordinary byte input inspector. No model parsing or execution.
from std.sys import argv
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy, read_sealed_source_digest
from hailbru.syscall import os_host_architecture, os_openat, os_close_descriptor, os_fd_regular_size, O_RDONLY, O_CLOEXEC


def describe_sealed_source(owner: SealedSourceBytes, window_digest: String) -> String:
    return String("{\"schema_version\":1,\"scope\":\"owned_sealed_observed_source_bytes\",\"sealed_copy_bytes_verified\":true,\"atomic_original_snapshot_verified\":false,\"source_fingerprint_verified\":false,\"immutable_source_verified\":false,\"binding_identity_verified\":false,\"execution_tested\":false,\"device_access\":false,\"source_bytes\":") + String(owner.source_bytes) + ",\"source_read_calls\":" + String(owner.source_read_calls) + ",\"copy_write_calls\":" + String(owner.copy_write_calls) + ",\"digest_read_calls\":" + String(owner.digest_read_calls) + ",\"digest_hex\":\"" + owner.digest_hex + "\",\"window_digest_hex\":\"" + window_digest + "\"}"


def main() raises:
    var args = argv()
    if len(args) != 8:
        raise Error("usage: sealed_source_copy path first count byte_bound read_calls write_calls digest_calls")
    var path = String(args[1])
    var first = Int(args[2])
    var count = Int(args[3])
    var bound = Int(args[4])
    var reads = Int(args[5])
    var writes = Int(args[6])
    var digests = Int(args[7])
    if path.byte_length() == 0 or path.byte_length() >= 4096 or "\0" in path:
        raise Error("SourceSealedCopy: path requires 1..4095 non-NUL bytes")
    var arch = os_host_architecture()
    var fd = os_openat(arch, path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("SourceSealedCopy: source open failed")
    try:
        var source = seal_source_copy(arch, fd, os_fd_regular_size(arch, fd), bound, reads, writes, digests)
        var original = fd
        fd = -1
        if os_close_descriptor(original) != 0:
            raise Error("SourceSealedCopy: original close failed")
        var window = read_sealed_source_digest(source, first, count, bound, digests)
        var text = describe_sealed_source(source, window.digest_hex)
        source.close()
        print(text)
    except e:
        if fd >= 0:
            _ = os_close_descriptor(fd)
        raise e
