# Original observed input ownership for the existing Safetensors parser/readers.
from armvegr.safetensors import SafetensorsLoader
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy, read_sealed_source_digest, _require_sealed_source
from hailbru.syscall import os_host_architecture, os_openat, os_fd_regular_size, os_close_descriptor, O_RDONLY, O_CLOEXEC
from smidr.safetensors_constants import SafetensorsConstantWindow, read_safetensors_constants


@fieldwise_init
struct SealedSafetensors(Movable):
    var source: SafetensorsLoader
    var source_bytes: Int64
    var digest_hex: String
    var label: String

    def __deinit__(deinit self):
        self.source.close()

    def close(mut self):
        self.source.close()


def parse_sealed_safetensors(var bytes: SealedSourceBytes, label: String,
        header_bound: Int, tensor_bound: Int, rank_bound: Int, work_bound: Int,
        depth_bound: Int, digest_call_bound: Int) raises -> SealedSafetensors:
    if digest_call_bound <= 0:
        raise Error("SealedSafetensors: explicit positive digest-call bound required")
    var digest = read_sealed_source_digest(bytes, 0, Int(bytes.source_bytes),
        max(1, Int(bytes.source_bytes)), digest_call_bound)
    var extent = bytes.source_bytes
    var fd = bytes.take_fd()
    var source = SafetensorsLoader()
    # Admission consumes fd and cleans every partial map/parser failure.
    source._adopt_owned_sealed_fd(fd, extent, header_bound, tensor_bound,
        rank_bound, work_bound, depth_bound)
    return SealedSafetensors(source^, extent, digest.digest_hex, label)


def load_sealed_safetensors(path: String, source_byte_bound: Int,
        read_call_bound: Int, write_call_bound: Int, digest_call_bound: Int,
        header_bound: Int, tensor_bound: Int, rank_bound: Int, work_bound: Int,
        depth_bound: Int) raises -> SealedSafetensors:
    if path.byte_length() == 0 or path.byte_length() >= 4096 or "\0" in path:
        raise Error("SealedSafetensors: path requires 1..4095 non-NUL bytes")
    var arch = os_host_architecture()
    var fd = os_openat(arch, path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("SealedSafetensors: source open failed")
    try:
        var bytes = seal_source_copy(arch, fd, os_fd_regular_size(arch, fd),
            source_byte_bound, read_call_bound, write_call_bound, digest_call_bound)
        var original = fd
        fd = -1
        if os_close_descriptor(original) != 0:
            raise Error("SealedSafetensors: original close failed")
        return parse_sealed_safetensors(bytes^, path, header_bound, tensor_bound,
            rank_bound, work_bound, depth_bound, digest_call_bound)
    except e:
        if fd >= 0:
            _ = os_close_descriptor(fd)
        raise e


def read_sealed_safetensors_constants(owner: SealedSafetensors, name: String,
        first: Int, count: Int, element_bound: Int) raises -> SafetensorsConstantWindow:
    if not owner.source._sealed_route or not owner.source.opened or owner.source.fd < 0 or owner.source_bytes < 8 or owner.source.file_size != owner.source_bytes or owner.source._mapping_extent != owner.source_bytes:
        raise Error("SealedSafetensors: live exact sealed mapping required")
    _require_sealed_source(os_host_architecture(), Int64(owner.source.fd), owner.source_bytes)
    return read_safetensors_constants(owner.source, name, first, count, element_bound)
