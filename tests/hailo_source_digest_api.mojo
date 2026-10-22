# Test-only byte/state/fd seams. No model or device operations.
from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.source_digest import SourceSha256State, source_sha256_update, source_sha256_finish, sha256_source_bytes, digest_borrowed_regular_window
from hailbru.fw import sha256_hex
from hailbru.syscall import os_host_architecture, os_openat, os_close, os_fd_regular_size, os_pwrite, O_RDONLY, O_CLOEXEC
from loader.packed_gguf import PackedGGUF
from smidr.source_byte_digest import read_source_byte_digest
from smidr.tools.source_byte_digest import describe_source_digest


def hex_bytes(value: String) raises -> List[UInt8]:
    if value.byte_length() % 2 != 0:
        raise Error("test: odd hex")
    var result = List[UInt8]()
    var digits = "0123456789abcdef"
    for i in range(value.byte_length() // 2):
        var byte = 0
        for j in range(2):
            var found = False
            for k in range(16):
                if value.as_bytes()[2 * i + j] == digits.as_bytes()[k]:
                    byte = byte * 16 + k
                    found = True
                    break
            if not found:
                raise Error("test: bad hex")
        result.append(UInt8(byte))
    return result^


def state_test(mode: Int) raises:
    var state = SourceSha256State()
    var data = List[UInt8](length=1, fill=97)
    var shape_mode = mode - 10 if mode >= 10 else mode
    if shape_mode == 0:
        state.chain.clear()
    elif shape_mode == 1:
        state.pending = List[UInt8](length=64, fill=0)
    elif shape_mode == 2:
        state.byte_count = 1
    elif shape_mode == 3:
        state.byte_count = UInt64(2305843009213693952)
    elif mode == 4:
        state.byte_count = UInt64(2305843009213693951)
        state.pending = List[UInt8](length=63, fill=7)
    elif mode == 5 or mode == 6:
        _ = source_sha256_finish(state)
    else:
        raise Error("test: bad state mode")
    var saved_count = state.byte_count
    var saved_pending = state.pending.copy()
    var saved_chain = state.chain.copy()
    var saved_sealed = state.sealed
    var refused = False
    try:
        if mode == 6 or mode == 3 or mode >= 10:
            _ = source_sha256_finish(state)
        else:
            source_sha256_update(state, data)
    except:
        refused = True
    if not refused or state.byte_count != saved_count or state.pending != saved_pending or state.chain != saved_chain or state.sealed != saved_sealed:
        raise Error("test: guard failed or mutated invalid state")
    print("refused")
    print(sha256_source_bytes(List[UInt8]()))


def borrowed_test() raises:
    var args = argv()
    var arch = os_host_architecture()
    var fd = os_openat(arch, args[2], O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("test: open failed")
    try:
        var expected = Int64(Int(args[3]))
        _ = external_call["lseek", Int64](Int32(fd), Int64(7), Int32(0))
        var before = external_call["lseek", Int64](Int32(fd), Int64(0), Int32(1))
        try:
            var result = digest_borrowed_regular_window(args[8], fd, expected,
                Int(args[4]), Int(args[5]), Int(args[6]), Int(args[7]))
            if external_call["lseek", Int64](Int32(fd), Int64(0), Int32(1)) != before or os_fd_regular_size(arch, fd) < 0:
                raise Error("test: borrowed descriptor changed")
            print(result.digest_hex)
            print(result.read_calls)
        except e:
            if external_call["lseek", Int64](Int32(fd), Int64(0), Int32(1)) != before:
                raise Error("test: failed read changed fd position")
            # Directory/nonregular refusals still retain a live descriptor.
            if external_call["fcntl", Int32](Int32(fd), Int32(1)) < 0:
                raise Error("test: failed read closed borrowed fd")
            raise e
        _ = os_close(arch, fd)
    except e:
        if fd >= 0:
            _ = os_close(arch, fd)
        raise e


def owner_test(path: String, mode: String) raises:
    var source = PackedGGUF(path)
    var saved_size = source.source.file_size
    var saved_origin = source.data_offset
    if mode == "closed":
        source.source.close()
    elif mode == "size":
        source.source.file_size += 1
    elif mode == "negative_size":
        source.source.file_size = -1
    elif mode == "origin":
        source.data_offset = -1
    elif mode == "tail_origin":
        source.data_offset = Int(saved_size) + 1
    elif mode == "truncate" or mode == "same_size":
        var arch = os_host_architecture()
        var write_fd = os_openat(arch, path, 2 | O_CLOEXEC(), 0)
        if write_fd < 0:
            raise Error("test: mutation open failed")
        var changed: Int64
        if mode == "truncate":
            changed = Int64(external_call["ftruncate", Int32](Int32(write_fd), Int64(1)))
        else:
            var original = read_source_byte_digest(source, 0, Int(saved_size), Int(saved_size), 1024)
            print(original.digest_hex)
            var byte = List[UInt8](length=1, fill=173)
            var ptr = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(byte.unsafe_ptr()))
            changed = os_pwrite(arch, write_fd, ptr, 1, saved_size - 1) - 1
            _ = byte  # Retain the unsafe pointer's owner through the write.
        _ = os_close(arch, write_fd)
        if changed != 0:
            raise Error("test: mutation failed")
    elif mode != "owned":
        raise Error("test: unknown owner mode")
    try:
        var result = read_source_byte_digest(source, 0, Int(saved_size), Int(saved_size), 1024)
        source.source.file_size = saved_size
        source.data_offset = saved_origin
        source.source.close()
        print(describe_source_digest(result))
    except e:
        source.source.file_size = saved_size
        source.data_offset = saved_origin
        raise e


def main() raises:
    var args = argv()
    if len(args) == 4 and args[1] == "hash":
        var data = hex_bytes(args[2])
        var chunk_size = Int(args[3])
        if chunk_size <= 0:
            raise Error("test: chunk must be positive")
        var legacy = sha256_hex(data)
        var single = sha256_source_bytes(data)
        var state = SourceSha256State()
        var offset = 0
        source_sha256_update(state, List[UInt8]())
        while offset < len(data):
            var chunk = List[UInt8]()
            for i in range(min(chunk_size, len(data) - offset)):
                chunk.append(data[offset + i])
            source_sha256_update(state, chunk)
            offset += len(chunk)
            # Caller owns/reuses its input; pending bytes must be independent.
            chunk.clear()
            source_sha256_update(state, chunk)
        data.clear()
        print(source_sha256_finish(state))
        print(single)
        print(legacy)
    elif len(args) == 3 and args[1] == "state":
        state_test(Int(args[2]))
    elif len(args) == 9 and args[1] == "borrow":
        borrowed_test()
    elif len(args) == 5 and args[1] == "bad_fd":
        _ = digest_borrowed_regular_window(args[2], Int64(Int(args[3])), Int64(Int(args[4])), 0, 0, 1, 1)
        raise Error("test: invalid fd accepted")
    elif len(args) == 4 and args[1] == "owner":
        owner_test(args[2], args[3])
    else:
        raise Error("usage: source_digest_api hash|state|borrow|bad_fd|owner arguments")
