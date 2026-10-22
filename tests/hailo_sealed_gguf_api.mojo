# Test-only parser ownership seams, original constants and byte tiles. No forwards.
from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from loader.gguf import GGUFSeer
from loader.packed_gguf import PackedGGUF
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy, read_sealed_source_digest
from hailbru.syscall import os_openat, os_close_descriptor, os_fd_regular_size, os_pwrite, syscall6, O_RDONLY, O_CLOEXEC
from smidr.sealed_gguf_source import parse_sealed_packed_gguf, load_sealed_packed_gguf
from smidr.source_inventory import inventory_from_source
from smidr.matrix_tiles import MatrixSchedule, MatrixTilePolicy
from smidr.source_weight_tiles import read_source_weight_tile
from smidr.tools.source_weight_tiles import describe_source_weight_tile
from smidr.source_float_constants import read_floating_constants
from smidr.source_classic32_constants import read_classic32_constants
from smidr.source_q8_constants import read_q8_constants
from smidr.source_q2q3_constants import read_q2q3_constants
from smidr.source_q4k_constants import read_q4k_constants
from smidr.source_q5q6_constants import read_q5k_constants, read_q6k_constants
from smidr.source_iq4_constants import read_iq4_constants
from smidr.tools.source_classic32_constants import describe_classic32
from smidr.tools.source_q8_constants import describe_q8
from smidr.tools.source_q2q3_constants import describe_q2q3
from smidr.tools.source_q5q6_constants import describe_q5k, describe_q6k
from smidr.tools.source_iq4_constants import describe_iq4


def _hex(source: PackedGGUF, first: Int, count: Int) raises -> String:
    source.source._require_range(first, count)
    var text = String("")
    var digits = "0123456789abcdef"
    for i in range(first, first + count):
        var b = UInt8(source.source.mmap_ptr.unsafe_load(i))
        text += String(chr(Int(digits.as_bytes()[Int(b >> 4)])))
        text += String(chr(Int(digits.as_bytes()[Int(b & 15)])))
    return text


def _snapshot(source: PackedGGUF) raises:
    print("header", source.source.version, source.source.tensor_count, source.source.kv_count, source.data_offset, source.source.file_size)
    for key in source.fields:
        var start = source.fields[key]
        var kind = source.field_types[key]
        var end = source.source.skip_value(UInt32(kind), start)
        # Length and UTF8 hex permit exact embedded NUL/Unicode comparisons.
        var name = String("")
        for b in key.as_bytes():
            name += String(Int(b)) + ","
        print("field", name, kind, start, end, _hex(source, start, end - start))
    for name in source.tensors:
        var t = source.tensors[name]
        var axes = source.tensor_shape(name)
        var shape = String("")
        for axis in axes:
            shape += String(axis) + ","
        print("tensor", name, shape, t.kind, t.offset, t.byte_count, _hex(source, t.offset, t.byte_count))
    print("bytes", _hex(source, 0, Int(source.source.file_size)))
    print("default", source.integer("absent-default", 97))


def _constants(source: PackedGGUF, name: String) raises:
    var t = source.tensors[name]
    var n = t.columns * t.rows
    if t.kind == 0 or t.kind == 1 or t.kind == 30:
        var w = read_floating_constants(source, name, 0, n, 4096)
        var text = String("[")
        for i in range(len(w.bits)):
            if i != 0:
                text += ","
            text += String(w.bits[i])
        print(text + "]")
    elif t.kind == 2 or t.kind == 3 or t.kind == 6 or t.kind == 7:
        var w = read_classic32_constants(source, name, 0, n, 4096)
        print(describe_classic32(w))
    elif t.kind == 8:
        var w = read_q8_constants(source, name, 0, n, 4096)
        print(describe_q8(w))
    elif t.kind == 10 or t.kind == 11:
        var w = read_q2q3_constants(source, name, 0, n, 4096)
        print(describe_q2q3(w))
    elif t.kind == 12:
        var w = read_q4k_constants(source, name, 0, n, 4096)
        var text = String("[")
        for i in range(len(w.components)):
            if i != 0:
                text += ","
            var c = w.components[i]
            text += "[" + String(c.d_bits) + "," + String(c.dmin_bits) + "," + String(c.d_binary32_bits) + "," + String(c.dmin_binary32_bits) + "," + String(c.q) + "," + String(c.scale_factor) + "," + String(c.min_factor) + "]"
        print(text + "]")
    elif t.kind == 13:
        var w = read_q5k_constants(source, name, 0, n, 4096)
        print(describe_q5k(w))
    elif t.kind == 14:
        var w = read_q6k_constants(source, name, 0, n, 4096)
        print(describe_q6k(w))
    else:
        var w = read_iq4_constants(source, name, 0, n, 4096)
        print(describe_iq4(w))


def _tiles(source: PackedGGUF, name: String) raises:
    var inventory = inventory_from_source(source)
    var binding = inventory.bindings[name]
    var storage = inventory.storage[name].copy()
    var input_shape = List[Int]()
    input_shape.append(1)
    input_shape.append(binding.columns)
    var output_shape = List[Int]()
    output_shape.append(1)
    output_shape.append(binding.rows)
    var policy = MatrixTilePolicy(1, 1, 17, 2, 2, 4, 8, 1048576, "synthetic byte selection")
    var schedule = MatrixSchedule(0, 0, 1, name, binding, Int(source.source.file_size), source.data_offset, storage^, input_shape^, output_shape^, 1, binding.rows, binding.columns, policy^)
    var count = ((binding.columns - 1) // 17 + 1) * binding.rows
    for i in range(count):
        var tile = read_source_weight_tile(source, schedule, i, 1048576)
        print(describe_source_weight_tile(tile))


def _range_refused(source: PackedGGUF, first: Int, count: Int) raises:
    var refused = False
    try:
        source.source._require_range(first, count)
    except:
        refused = True
    if not refused:
        raise Error("test: unsafe range admitted")


def _copy(path: String) raises -> SealedSourceBytes:
    var original = os_openat("aarch64", path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if original < 0:
        raise Error("test: source open failed")
    try:
        var bytes = seal_source_copy("aarch64", original, os_fd_regular_size("aarch64", original), 1048576, 4096, 4096, 4096)
        _ = os_close_descriptor(original)
        return bytes^
    except e:
        _ = os_close_descriptor(original)
        raise e


def main() raises:
    var args = argv()
    if len(args) == 2 and args[1] == "default":
        var bytes = SealedSourceBytes()
        var refused = False
        try:
            _ = bytes.take_fd()
        except:
            refused = True
        if not refused or bytes.fd != -1:
            raise Error("test: default transfer admitted")
        print("refused")
        return
    if len(args) != 4:
        raise Error("usage: hailo_sealed_gguf_api mode path label_or_tensor")
    var mode = String(args[1])
    var path = String(args[2])
    var label = String(args[3])
    if mode == "path":
        var source = PackedGGUF(path)
        _snapshot(source)
        return
    if mode == "path_constants":
        var source = PackedGGUF(path)
        _constants(source, label)
        return
    if mode == "path_tiles":
        var source = PackedGGUF(path)
        _tiles(source, label)
        return
    var bytes = _copy(path)
    if mode == "transfer" or mode == "size_transfer" or mode == "unsealed_transfer" or mode == "fd_transfer" or mode == "arch_transfer":
        var saved_fd = bytes.fd
        var saved_size = bytes.source_bytes
        var saved_arch = bytes.arch
        if mode == "size_transfer":
            bytes.source_bytes += 1
        elif mode == "fd_transfer":
            bytes.fd = 2147483648
        elif mode == "arch_transfer":
            bytes.arch = "x86_64"
        elif mode == "unsealed_transfer":
            bytes.fd = os_openat("aarch64", path, O_RDONLY() | O_CLOEXEC(), 0)
        var invalid = mode != "transfer"
        var refused = False
        var transferred = Int64(-1)
        try:
            transferred = bytes.take_fd()
        except e:
            if not invalid:
                raise e
            refused = True
        if invalid and not refused:
            _ = os_close_descriptor(transferred)
            raise Error("test: invalid transfer admitted")
        if not invalid:
            if bytes.fd != -1 or transferred != saved_fd:
                raise Error("test: ownership not transferred")
            var second_refused = False
            try:
                _ = bytes.take_fd()
            except:
                second_refused = True
            var read_refused = False
            try:
                _ = read_sealed_source_digest(bytes, 0, 0, 1, 1)
            except:
                read_refused = True
            if not read_refused:
                raise Error("test: released owner read admitted")
            if not second_refused:
                raise Error("test: repeated transfer admitted")
            var seer = GGUFSeer(label)
            seer._adopt_owned_sealed_fd(transferred, saved_size)
            seer._parse_header()
            print("transferred")
        if mode == "unsealed_transfer":
            _ = os_close_descriptor(bytes.fd)
        if invalid:
            bytes.fd = saved_fd
            bytes.source_bytes = saved_size
            bytes.arch = saved_arch
            _ = read_sealed_source_digest(bytes, 0, Int(saved_size), 1048576, 4096)
            if not refused:
                raise Error("test: expected transfer refusal")
            print("refused")
        return
    if mode == "adopt_size" or mode == "adopt_closed" or mode == "adopt_unsealed" or mode == "adopt_negative" or mode == "adopt_large":
        var extent = bytes.source_bytes
        var incoming = bytes.take_fd()
        if mode == "adopt_size":
            extent += 1
        elif mode == "adopt_closed":
            _ = os_close_descriptor(incoming)
        elif mode == "adopt_unsealed":
            _ = os_close_descriptor(incoming)
            incoming = os_openat("aarch64", path, O_RDONLY() | O_CLOEXEC(), 0)
        elif mode == "adopt_negative" or mode == "adopt_large":
            _ = os_close_descriptor(incoming)
            incoming = -1 if mode == "adopt_negative" else Int64(2147483648)
        var seer = GGUFSeer(label)
        var refused = False
        try:
            seer._adopt_owned_sealed_fd(incoming, extent)
        except:
            refused = True
        if not refused or seer.fd != -1 or seer.is_mapped:
            raise Error("test: invalid adopt admitted or retained")
        if incoming >= 0 and incoming <= 2147483647 and syscall6(25, incoming, 1, 0, 0, 0, 0) != -1:
            raise Error("test: refused incoming descriptor leaked")
        # A fresh independent owner recovers after every refusal.
        var recovery = load_sealed_packed_gguf(path, 1048576, 4096, 4096, 4096)
        recovery.source.source.close()
        print("refused")
        return
    if mode == "digest_zero":
        _ = parse_sealed_packed_gguf(bytes^, label, 0)
        raise Error("test: zero parser hash permit admitted")
    if mode == "truncate" or mode == "mutate":
        var fd = os_openat("aarch64", path, 2 | O_CLOEXEC(), 0)
        if fd < 0:
            raise Error("test: mutation open failed")
        if mode == "truncate":
            if external_call["ftruncate", Int32](Int32(fd), Int64(1)) != 0:
                raise Error("test: truncate failed")
        else:
            var buffer = List[UInt8](length=1, fill=173)
            var ptr = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(buffer.unsafe_ptr()))
            var n = os_pwrite("aarch64", fd, ptr, 1, bytes.source_bytes - 1)
            _ = buffer
            if n != 1:
                raise Error("test: mutation failed")
        _ = os_close_descriptor(fd)
    elif mode == "replace":
        if external_call["unlink", Int32](path.unsafe_ptr()) != 0:
            raise Error("test: unlink failed")
        var fd = os_openat("aarch64", path, 1 | 64 | O_CLOEXEC(), 384)
        if fd < 0:
            raise Error("test: replacement failed")
        _ = os_close_descriptor(fd)
    bytes.digest_hex = "forged claimed digest"
    var owned = parse_sealed_packed_gguf(bytes^, label, 4096)
    if syscall6(25, Int64(owned.source.source.fd), 1034, 0, 0, 0, 0) & 15 != 15:
        raise Error("test: parser descriptor is not sealed")
    if mode == "constants":
        _constants(owned.source, label)
    elif mode == "tiles":
        _tiles(owned.source, label)
    elif mode == "capacity" or mode == "cleanup_capacity":
        var extent = owned.source.source.file_size
        owned.source.source.file_size = 9223372036854775807
        _range_refused(owned.source, Int(extent), 1)
        _range_refused(owned.source, 9223372036854775807, 1)
        _range_refused(owned.source, -1, 0)
        _range_refused(owned.source, 0, -1)
        owned.source.source.file_size = 1
        _range_refused(owned.source, 1, 1)
        owned.source.source.file_size = extent if mode == "capacity" else Int64(1)
        owned.source.source.close()
        _range_refused(owned.source, 0, 1)
        var refused = False
        try:
            owned.source.source._open_and_map()
        except:
            refused = True
        if not refused:
            raise Error("test: closed sealed label reopened")
        owned.source.source.close()
        print("bounded")
    elif mode == "busy_distinct":
        var other = _copy(path)
        var incoming = other.take_fd()
        var live = owned.source.source.fd
        var refused = False
        try:
            owned.source.source._adopt_owned_sealed_fd(incoming, owned.source_bytes)
        except:
            refused = True
        if not refused or syscall6(25, incoming, 1, 0, 0, 0, 0) != -1 or syscall6(25, Int64(live), 1034, 0, 0, 0, 0) & 15 != 15:
            raise Error("test: busy distinct descriptor ownership failed")
        _snapshot(owned.source)
    elif mode == "busy_alias":
        var live = owned.source.source.fd
        var refused = False
        try:
            owned.source.source._adopt_owned_sealed_fd(Int64(live), owned.source_bytes)
        except:
            refused = True
        if not refused or syscall6(25, Int64(live), 1034, 0, 0, 0, 0) & 15 != 15:
            raise Error("test: busy alias closed live owner")
        owned.source.source._open_and_map()
        _snapshot(owned.source)
    else:
        print("digest", owned.digest_hex)
        _snapshot(owned.source)
