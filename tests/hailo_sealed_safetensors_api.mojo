# Test-only descriptor/map ownership and representation windows. No forwards.
from std.sys import argv
from std.ffi import external_call
from armvegr.safetensors import SafetensorsLoader
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy
from hailbru.syscall import os_openat, os_close_descriptor, os_fd_regular_size, O_RDONLY, O_CLOEXEC
from smidr.sealed_safetensors_source import SealedSafetensors, parse_sealed_safetensors, load_sealed_safetensors, read_sealed_safetensors_constants
from smidr.safetensors_constants import SafetensorsConstantWindow, read_safetensors_constants
from smidr.safetensors_inventory import _project_inventory
from smidr.tools.safetensors_inventory import describe_safetensors_inventory, _string_hex
from smidr.tools.program_integrity import _hex


def _copy(path: String) raises -> SealedSourceBytes:
    var fd = os_openat("aarch64", path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("test: original open failed")
    try:
        var bytes = seal_source_copy("aarch64", fd, os_fd_regular_size("aarch64", fd), 16777216, 16384, 16384, 16384)
        var original = fd
        fd = -1
        if os_close_descriptor(original) != 0:
            raise Error("test: original close failed")
        return bytes^
    except e:
        if fd >= 0:
            _ = os_close_descriptor(fd)
        raise e


def _move(var owner: SealedSafetensors) -> SealedSafetensors:
    return owner^


def _window(w: SafetensorsConstantWindow) -> String:
    var text = String("{\"name_utf8_hex\":\"") + _string_hex(w.binding.name) + "\",\"dtype\":" + String(w.binding.dtype)
    text += ",\"source_bytes\":" + String(w.source_bytes) + ",\"data_offset\":" + String(w.data_offset)
    text += ",\"elements\":" + String(w.binding.elements) + ",\"file_offset\":" + String(w.binding.file_offset) + ",\"byte_count\":" + String(w.binding.byte_count)
    text += ",\"first\":" + String(w.first) + ",\"count\":" + String(w.count) + ",\"shape\":["
    for i in range(len(w.binding.shape)):
        if i != 0:
            text += ","
        text += String(w.binding.shape[i])
    text += "],\"raw_words\":["
    for i in range(len(w.raw_words)):
        if i != 0:
            text += ","
        text += String(w.raw_words[i])
    text += "],\"binary32_words\":["
    for i in range(len(w.binary32_words)):
        if i != 0:
            text += ","
        text += String(w.binary32_words[i])
    return text + "],\"device_access\":false,\"model_evaluated\":false,\"execution_tested\":false}"


def _snapshot(source: SafetensorsLoader) raises:
    var inventory = _project_inventory(source.file_size, source.header_size, source.descs, source.metadata)
    print(describe_safetensors_inventory(inventory))
    var text = String("")
    var digits = "0123456789abcdef"
    source._req(0, source.file_size)
    for i in range(Int(source.file_size)):
        var b = source.map.unsafe_offset(i).unsafe_load()
        text += String(chr(Int(digits.as_bytes()[Int(b >> 4)])))
        text += String(chr(Int(digits.as_bytes()[Int(b & 15)])))
    print(text)


def main() raises:
    var args = argv()
    if len(args) != 12:
        raise Error("usage: hailo_sealed_safetensors_api mode path namehex first count bound header tensors rank work depth")
    var mode = String(args[1])
    var path = String(args[2])
    var name = String(from_utf8=_hex(args[3]))
    var first = Int(args[4])
    var count = Int(args[5])
    var bound = Int(args[6])
    var header = Int(args[7])
    var tensors = Int(args[8])
    var rank = Int(args[9])
    var work = Int(args[10])
    var depth = Int(args[11])
    if mode == "path" or mode == "path_snapshot" or mode == "path_capacity" or mode == "path_reopen":
        var source = SafetensorsLoader()
        source.open(path, header, tensors, rank, work, depth)
        try:
            if mode == "path_capacity":
                var extent = source.file_size
                source.file_size = 9223372036854775807
                var refused = False
                try:
                    source._req(extent, 1)
                except:
                    refused = True
                if not refused:
                    raise Error("test: old path capacity bypass")
                source.file_size = 1
                source.close()
                source.close()
                print("bounded")
            elif mode == "path_reopen":
                source.close()
                source.open(path, header, tensors, rank, work, depth)
                _snapshot(source)
            elif mode == "path_snapshot":
                _snapshot(source)
            else:
                var window = read_safetensors_constants(source, name, first, count, bound)
                print(_window(window))
            source.close()
        except e:
            source.close()
            raise e
        return
    if mode == "recover":
        var bad = _copy(path)
        var refused = False
        try:
            _ = parse_sealed_safetensors(bad^, "not-a-source-path", 0, tensors, rank, work, depth, 16384)
        except:
            refused = True
        if not refused:
            raise Error("test: invalid parser policy accepted")
        var recovered = load_sealed_safetensors(path, 16777216, 16384, 16384, 16384, header, tensors, rank, work, depth)
        var window = read_sealed_safetensors_constants(recovered, name, first, count, bound)
        print(_window(window))
        return
    var bytes = _copy(path)
    bytes.digest_hex = String("writable forged hash claim")
    if mode == "truncate" or mode == "mutate" or mode == "replace":
        if mode == "replace":
            if external_call["unlink", Int32](path.unsafe_ptr()) != 0:
                raise Error("test: unlink failed")
            var fd = os_openat("aarch64", path, 2 | 64 | O_CLOEXEC(), 384)
            if fd < 0:
                raise Error("test: replacement open failed")
            _ = os_close_descriptor(fd)
        else:
            var fd = os_openat("aarch64", path, 2 | O_CLOEXEC(), 0)
            if fd < 0:
                raise Error("test: mutation open failed")
            if external_call["ftruncate", Int32](Int32(fd), Int64(1) if mode == "truncate" else Int64(0)) != 0:
                _ = os_close_descriptor(fd)
                raise Error("test: mutation truncate failed")
            _ = os_close_descriptor(fd)
    if mode == "adopt_unsealed" or mode == "adopt_size" or mode == "adopt_closed" or mode == "adopt_negative" or mode == "adopt_large":
        var source = SafetensorsLoader()
        var fd = bytes.take_fd()
        if mode == "adopt_unsealed":
            _ = os_close_descriptor(fd)
            fd = os_openat("aarch64", path, O_RDONLY() | O_CLOEXEC(), 0)
        elif mode == "adopt_closed":
            _ = os_close_descriptor(fd)
        elif mode == "adopt_negative" or mode == "adopt_large":
            _ = os_close_descriptor(fd)
            fd = -1 if mode == "adopt_negative" else 4294967296
        var refused = False
        try:
            source._adopt_owned_sealed_fd(fd, bytes.source_bytes + Int64(1 if mode == "adopt_size" else 0), header, tensors, rank, work, depth)
        except:
            refused = True
        source.close()
        if not refused:
            raise Error("test: invalid sealed admission accepted")
        print("refused")
        return
    if mode == "size_before":
        bytes.source_bytes -= 1
    var owner = parse_sealed_safetensors(bytes^, "/aesir-provenance-only-must-not-open", header, tensors, rank, work, depth, 0 if mode == "digest_zero" else 1 if mode == "digest_short" else 16384)
    if mode == "move":
        owner = _move(owner^)
    if mode == "busy_alias" or mode == "busy_distinct":
        var fd = Int64(owner.source.fd)
        if mode == "busy_distinct":
            var other = _copy(path)
            fd = other.take_fd()
        var refused = False
        try:
            owner.source._adopt_owned_sealed_fd(fd, owner.source_bytes, header, tensors, rank, work, depth)
        except:
            refused = True
        if not refused:
            raise Error("test: busy admission accepted")
    if mode == "capacity" or mode == "cleanup_capacity":
        var extent = owner.source.file_size
        owner.source.file_size = 9223372036854775807
        var refused = False
        try:
            owner.source._req(extent, 1)
        except:
            refused = True
        if not refused:
            raise Error("test: sealed mapping capacity bypass")
        owner.source.file_size = 1
        owner.close()
        owner.close()
        print("bounded")
        return
    if mode == "reopen":
        owner.close()
        var refused = False
        try:
            owner.source.open(path, header, tensors, rank, work, depth)
        except:
            refused = True
        if not refused:
            raise Error("test: closed sealed source reopened")
        print("refused")
        return
    if mode == "snapshot" or mode == "move" or mode == "truncate" or mode == "mutate" or mode == "replace":
        print(owner.digest_hex)
        _snapshot(owner.source)
        return
    if mode == "retained":
        var one = read_sealed_safetensors_constants(owner, name, first, count, bound)
        var two = read_sealed_safetensors_constants(owner, name, first, count, bound)
        owner.close()
        owner.close()
        if len(one.raw_words) > 0:
            one.raw_words[0] ^= 1
            one.binary32_words[0] ^= 1
        if len(one.binding.shape) > 0:
            one.binding.shape[0] = -1
        var refused = False
        try:
            _ = read_sealed_safetensors_constants(owner, name, first, count, bound)
        except:
            refused = True
        if not refused:
            raise Error("test: closed source reader accepted")
        print(_window(two))
        return
    if mode == "closed":
        owner.close()
    elif mode == "owner_size":
        owner.source_bytes -= 1
    elif mode == "declared":
        owner.source.file_size -= 1
    elif mode == "read_capacity":
        var saved = owner.source._mapping_extent
        owner.source._mapping_extent -= 1
        var refused = False
        try:
            _ = read_sealed_safetensors_constants(owner, name, first, count, bound)
        except:
            refused = True
        owner.source._mapping_extent = saved
        if not refused:
            raise Error("test: read mapping capacity accepted")
        print("refused")
        return
    var window = read_sealed_safetensors_constants(owner, name, first, count, bound)
    print(_window(window))
