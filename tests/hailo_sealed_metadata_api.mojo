# Test-only observed JSON ownership and copied values; no model or device work.
from std.sys import argv
from std.ffi import external_call
from hailbru.source_sealed_copy import SealedSourceBytes
from hailbru.syscall import os_close_descriptor, os_openat, os_fd_regular_size, O_RDONLY, O_CLOEXEC
from smidr.sealed_source_metadata import SealedSourceConfig, SealedSourceIndex, _copy_path, read_sealed_metadata_bytes, parse_sealed_source_config, parse_sealed_source_index, load_sealed_source_config, load_sealed_source_index
from smidr.source_config import SourceConfigPolicy, parse_source_config
from smidr.source_index import SourceIndexPolicy, parse_source_index
from smidr.tools.source_config import describe_source_config
from smidr.tools.source_index import describe_source_index
from smidr.tools.hrpc_frame import _to_hex


def _move_config(var owner: SealedSourceConfig) -> SealedSourceConfig:
    return owner^


def _move_index(var owner: SealedSourceIndex) -> SealedSourceIndex:
    return owner^


def _prepare(path: String, mode: String) raises -> SealedSourceBytes:
    var bytes = _copy_path(path, 16777216, 16384, 16384, 16384)
    bytes.digest_hex = String("forged writable digest claim")
    if mode == "truncate" or mode == "mutate" or mode == "replace":
        if mode == "replace":
            if external_call["unlink", Int32](path.unsafe_ptr()) != 0:
                raise Error("test: original unlink failed")
            var fd = os_openat("aarch64", path, 2 | 64 | O_CLOEXEC(), 384)
            if fd < 0:
                raise Error("test: replacement open failed")
            _ = os_close_descriptor(fd)
        else:
            var fd = os_openat("aarch64", path, 2 | O_CLOEXEC(), 0)
            if fd < 0:
                raise Error("test: original mutation open failed")
            if external_call["ftruncate", Int32](Int32(fd), Int64(1) if mode == "truncate" else Int64(0)) != 0:
                _ = os_close_descriptor(fd)
                raise Error("test: original truncate failed")
            _ = os_close_descriptor(fd)
    elif mode == "bad_size":
        bytes.source_bytes -= 1
    elif mode == "bad_arch":
        bytes.arch = String("x86_64")
    elif mode == "bad_fd":
        var fd = bytes.take_fd()
        _ = os_close_descriptor(fd)
    elif mode == "unsealed":
        bytes.close()
        bytes.fd = os_openat("aarch64", path, O_RDONLY() | O_CLOEXEC(), 0)
        if bytes.fd < 0:
            raise Error("test: ordinary unsealed open failed")
        bytes.source_bytes = os_fd_regular_size("aarch64", bytes.fd)
    return bytes^


def _emit(digest: String, parsed: String, data: List[UInt8]):
    print(digest)
    print(parsed)
    print(_to_hex(data))


def _config(var bytes: SealedSourceBytes, path: String, label: String, mode: String,
        byte_bound: Int, digest_bound: Int, policy: SourceConfigPolicy) raises:
    if mode == "recover":
        var refused = False
        try:
            _ = parse_sealed_source_config(bytes^, label, SourceConfigPolicy(0, policy.fields, policy.work, policy.depth), digest_bound)
        except:
            refused = True
        if not refused:
            raise Error("test: invalid config policy accepted")
        var fresh = load_sealed_source_config(path, 16777216, 16384, 16384, 16384, policy)
        fresh.config.source_path = label
        var data = read_sealed_metadata_bytes(fresh.source, byte_bound)
        _emit(fresh.digest_hex, describe_source_config(fresh.config), data)
        return
    var owner = parse_sealed_source_config(bytes^, label, policy, digest_bound)
    if mode == "move":
        owner = _move_config(owner^)
    if mode == "closed":
        owner.close()
    if mode == "cache":
        owner.config.fields["forged-cache"] = String("not original bytes")
        var data = read_sealed_metadata_bytes(owner.source, byte_bound)
        var restored = parse_source_config(data, policy)
        restored.source_path = label
        _emit(owner.digest_hex, describe_source_config(restored), data)
        return
    var data = read_sealed_metadata_bytes(owner.source, byte_bound)
    var parsed = describe_source_config(owner.config)
    if mode == "retained":
        var other = read_sealed_metadata_bytes(owner.source, byte_bound)
        owner.close()
        owner.close()
        if len(other) > 0:
            other[0] ^= 1
        if describe_source_config(owner.config) != parsed:
            raise Error("test: config fields borrow closed bytes")
        var refused = False
        try:
            _ = read_sealed_metadata_bytes(owner.source, byte_bound)
        except:
            refused = True
        if not refused:
            raise Error("test: closed config source read accepted")
    _emit(owner.digest_hex, parsed, data)


def _index(var bytes: SealedSourceBytes, path: String, label: String, mode: String,
        byte_bound: Int, digest_bound: Int, policy: SourceIndexPolicy) raises:
    if mode == "recover":
        var refused = False
        try:
            _ = parse_sealed_source_index(bytes^, label, SourceIndexPolicy(0, policy.tensors, policy.fields, policy.work, policy.depth), digest_bound)
        except:
            refused = True
        if not refused:
            raise Error("test: invalid index policy accepted")
        var fresh = load_sealed_source_index(path, 16777216, 16384, 16384, 16384, policy)
        fresh.index.source_path = label
        var data = read_sealed_metadata_bytes(fresh.source, byte_bound)
        _emit(fresh.digest_hex, describe_source_index(fresh.index), data)
        return
    var owner = parse_sealed_source_index(bytes^, label, policy, digest_bound)
    if mode == "move":
        owner = _move_index(owner^)
    if mode == "closed":
        owner.close()
    if mode == "cache":
        owner.index.weight_map["forged-cache"] = String("not-source.safetensors")
        var data = read_sealed_metadata_bytes(owner.source, byte_bound)
        var restored = parse_source_index(data, policy)
        restored.source_path = label
        _emit(owner.digest_hex, describe_source_index(restored), data)
        return
    var data = read_sealed_metadata_bytes(owner.source, byte_bound)
    var parsed = describe_source_index(owner.index)
    if mode == "retained":
        var other = read_sealed_metadata_bytes(owner.source, byte_bound)
        owner.close()
        owner.close()
        if len(other) > 0:
            other[0] ^= 1
        if describe_source_index(owner.index) != parsed:
            raise Error("test: index fields borrow closed bytes")
        var refused = False
        try:
            _ = read_sealed_metadata_bytes(owner.source, byte_bound)
        except:
            refused = True
        if not refused:
            raise Error("test: closed index source read accepted")
    _emit(owner.digest_hex, parsed, data)


def main() raises:
    var args = argv()
    if (len(args) != 11 or args[1] != "config") and (len(args) != 12 or args[1] != "index"):
        raise Error("usage: hailo_sealed_metadata_api config|index mode path label bytes digests parser_bounds")
    var kind = String(args[1])
    var mode = String(args[2])
    var path = String(args[3])
    var bytes = _prepare(path, mode)
    if mode == "closed_fd" or mode == "large_fd":
        var fd = bytes.fd
        if os_close_descriptor(fd) != 0:
            raise Error("test: fixture descriptor close failed")
        if mode == "large_fd":
            bytes.fd = 4294967296
        var refused = False
        try:
            _ = read_sealed_metadata_bytes(bytes, Int(args[5]))
        except:
            refused = True
        bytes.fd = -1
        if not refused:
            raise Error("test: invalid borrowed descriptor accepted")
        print("refused")
        return
    if kind == "config":
        var policy = SourceConfigPolicy(Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]))
        _config(bytes^, path, args[4], mode, Int(args[5]), Int(args[6]), policy)
    else:
        var policy = SourceIndexPolicy(Int(args[7]), Int(args[8]), Int(args[9]), Int(args[10]), Int(args[11]))
        _index(bytes^, path, args[4], mode, Int(args[5]), Int(args[6]), policy)
