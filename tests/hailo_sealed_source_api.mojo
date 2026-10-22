# Test-only byte, kernel refusal and mutable-owner seams. No model computation.
from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.source_sealed_copy import SealedSourceBytes, seal_source_copy, read_sealed_source_digest
from hailbru.syscall import os_openat, os_close_descriptor, os_pread_metadata, os_pwrite, syscall6, errno_now, O_RDONLY, O_CLOEXEC


def _hex_bytes(fd: Int64, size: Int) raises -> String:
    var buffer = List[UInt8](length=min(4096, size), fill=0)
    var text = String("")
    var digits = "0123456789abcdef"
    var done = 0
    while done < size:
        var want = min(4096, size - done)
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(buffer.unsafe_ptr()))
        var n = os_pread_metadata("aarch64", fd, pointer, Int64(want), Int64(done))
        _ = buffer
        if n <= 0 or n > Int64(want):
            raise Error("test: final byte read failed")
        for i in range(Int(n)):
            text += String(chr(Int(digits.as_bytes()[Int(buffer[i] >> 4)])))
            text += String(chr(Int(digits.as_bytes()[Int(buffer[i] & 15)])))
        done += Int(n)
    return text


def _protect(owner: SealedSourceBytes) raises:
    var byte = List[UInt8](length=1, fill=173)
    var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(byte.unsafe_ptr()))
    var result = os_pwrite("aarch64", owner.fd, pointer, 1, 0)
    _ = byte
    if result != -1 or errno_now() != 1:
        raise Error("test: sealed write was not refused")
    if external_call["ftruncate", Int32](Int32(owner.fd), owner.source_bytes + 1) != -1 or errno_now() != 1:
        raise Error("test: sealed growth was not refused")
    if owner.source_bytes > 0:
        if external_call["ftruncate", Int32](Int32(owner.fd), owner.source_bytes - 1) != -1 or errno_now() != 1:
            raise Error("test: sealed shrink was not refused")
        var map = syscall6(222, 0, owner.source_bytes, 3, 1, owner.fd, 0)
        if map != -1:
            _ = syscall6(215, map, owner.source_bytes, 0, 0, 0, 0)
            raise Error("test: sealed shared writable mapping was admitted")
        if errno_now() != 1:
            raise Error("test: unexpected writable mapping refusal")


def _owner_refusal(mut owner: SealedSourceBytes, original_fd: Int64, mode: String) raises:
    var saved_fd = owner.fd
    var saved_size = owner.source_bytes
    var saved_arch = owner.arch
    if mode == "closed":
        owner.close()
        saved_fd = -1
    elif mode == "size":
        owner.source_bytes += 1
    elif mode == "negative_size":
        owner.source_bytes = -1
    elif mode == "arch":
        owner.arch = "x86_64"
    elif mode == "fd":
        owner.fd = 2147483648
    elif mode == "unsealed":
        owner.fd = original_fd
    else:
        raise Error("test: unknown owner mutation")
    var refused = False
    try:
        _ = read_sealed_source_digest(owner, 0, 0, 1, 1)
    except:
        refused = True
    owner.fd = saved_fd
    owner.source_bytes = saved_size
    owner.arch = saved_arch
    if not refused:
        raise Error("test: mutable/default owner guard failed")
    if saved_fd >= 0:
        _ = read_sealed_source_digest(owner, 0, Int(saved_size), max(1, Int(saved_size)), 1048576)


def main() raises:
    var args = argv()
    if len(args) == 2 and args[1] == "default":
        var owner = SealedSourceBytes()
        var refused = False
        try:
            _ = read_sealed_source_digest(owner, 0, 0, 1, 1)
        except:
            refused = True
        owner.close()
        owner.close()
        if not refused:
            raise Error("test: default owner admitted")
        print("refused")
        return
    if len(args) == 4 and args[1] == "bad_fd":
        _ = seal_source_copy(args[2], Int64(Int(args[3])), 0, 1, 1, 1, 1)
        raise Error("test: bad fd admitted")
    if len(args) != 10 or args[1] != "copy":
        raise Error("usage: sealed_api copy path expected byte_bound reads writes digests arch mode")
    var path = String(args[2])
    var fd = os_openat("aarch64", path, O_RDONLY() | O_CLOEXEC() | 0x800, 0)
    if fd < 0:
        raise Error("test: source open failed")
    _ = external_call["lseek", Int64](Int32(fd), Int64(7), Int32(0))
    var position = external_call["lseek", Int64](Int32(fd), Int64(0), Int32(1))
    try:
        var mode = String(args[9])
        var owner = seal_source_copy(args[8], fd, Int64(Int(args[3])), Int(args[4]), Int(args[5]), Int(args[6]), Int(args[7]))
        if external_call["lseek", Int64](Int32(fd), Int64(0), Int32(1)) != position:
            raise Error("test: borrowed source position changed")
        if syscall6(25, fd, 1, 0, 0, 0, 0) < 0:
            raise Error("test: borrowed source was closed")
        if mode == "closed" or mode == "size" or mode == "negative_size" or mode == "arch" or mode == "fd" or mode == "unsealed":
            _owner_refusal(owner, fd, mode)
            owner.close()
            _ = os_close_descriptor(fd)
            print("refused_and_recovered")
            return
        var original = fd
        fd = -1
        if os_close_descriptor(original) != 0:
            raise Error("test: original close failed")
        if mode == "mutate":
            var write_fd = os_openat("aarch64", path, 2 | O_CLOEXEC(), 0)
            if write_fd < 0:
                raise Error("test: mutation open failed")
            var byte = List[UInt8](length=1, fill=173)
            var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(byte.unsafe_ptr()))
            var wrote = os_pwrite("aarch64", write_fd, pointer, 1, max(Int64(0), owner.source_bytes - 1))
            _ = byte
            _ = os_close_descriptor(write_fd)
            if wrote != 1:
                raise Error("test: mutation failed")
        elif mode == "protect":
            _protect(owner)
        elif mode == "digest_field":
            owner.digest_hex = "untrusted-public-field"
        elif mode != "bytes" and mode != "implicit" and mode != "close_error":
            raise Error("test: unknown byte mode")
        var actual = read_sealed_source_digest(owner, 0, Int(owner.source_bytes), max(1, Int(owner.source_bytes)), 1048576)
        var bytes = _hex_bytes(owner.fd, Int(owner.source_bytes))
        var seals = syscall6(25, owner.fd, 1034, 0, 0, 0, 0)
        var flags = syscall6(25, owner.fd, 1, 0, 0, 0, 0)
        if seals < 0 or (seals & 15) != 15 or flags < 0 or (flags & 1) != 1:
            raise Error("test: actual kernel seals/CLOEXEC failed")
        var text = String("{\"source_bytes\":") + String(owner.source_bytes) + ",\"digest_hex\":\"" + actual.digest_hex + "\",\"reported_digest\":\"" + owner.digest_hex + "\",\"hex\":\"" + bytes + "\",\"seals\":" + String(seals) + ",\"fd_flags\":" + String(flags) + ",\"source_read_calls\":" + String(owner.source_read_calls) + ",\"copy_write_calls\":" + String(owner.copy_write_calls) + ",\"digest_read_calls\":" + String(owner.digest_read_calls) + "}"
        if mode == "close_error":
            var refused = False
            try:
                owner.close()
            except:
                refused = True
            if not refused or owner.fd != -1:
                raise Error("test: close error retained ownership")
            owner.close()
        elif mode != "implicit":
            owner.close()
            owner.close()
        print(text)
    except e:
        if fd >= 0:
            if external_call["lseek", Int64](Int32(fd), Int64(0), Int32(1)) != position or syscall6(25, fd, 1, 0, 0, 0, 0) < 0:
                _ = os_close_descriptor(fd)
                raise Error("test: failure changed borrowed source ownership/position")
            _ = os_close_descriptor(fd)
        raise e
