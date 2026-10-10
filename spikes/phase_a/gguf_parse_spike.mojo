# H008 SPIKE — standalone GGUF header parser (pure Mojo).
#
# Parse-only GGUF v3 header reader used for the ARM64 port check. This is a
# measurement spike, NOT shipped engine code, and does NOT import
# loader/gguf.mojo (GGUFSeer cannot compile under Mojo 1.1.0 — see
# docs/phase_a/LOADER_PORT_ISSUES.md).
#
# Reads the file with fread via std.ffi external_call (pure Mojo + OS
# interface, no libraries), decodes all header integers with EXPLICIT
# little-endian byte assembly, and prints a canonical text form. The x86_64
# and ARM64 outputs are diffed byte-for-byte: any endianness, alignment, or
# struct-layout divergence on ARM64 shows up here.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin
from std.sys import argv


def to_cstr(s: String) -> Pointer[UInt8, MutUntrackedOrigin]:
    var n = s.byte_length()
    var cstr = unsafe_alloc[UInt8](n + 1)
    var i = 0
    for byte in s.bytes():
        cstr[unsafe_offset=i] = byte
        i += 1
    cstr[unsafe_offset=n] = 0
    return cstr


def read_u32(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int) -> UInt32:
    var v = UInt32(0)
    for i in range(4):
        v |= UInt32(buf[unsafe_offset=off + i]) << UInt32(8 * i)
    return v


def read_u64(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int) -> UInt64:
    var v = UInt64(0)
    for i in range(8):
        v |= UInt64(buf[unsafe_offset=off + i]) << UInt64(8 * i)
    return v


def read_str(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int, n: Int) -> String:
    var s = String()
    for i in range(n):
        s += chr(Int(buf[unsafe_offset=off + i]))
    return s


def scalar_size(vt: Int) -> Int:
    if vt == 0 or vt == 1 or vt == 7:
        return 1
    if vt == 2 or vt == 3:
        return 2
    if vt == 4 or vt == 5 or vt == 6:
        return 4
    return 8


def skip_value(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int, vt: Int) -> Int:
    if vt == 8:
        var n = Int(read_u64(buf, off))
        return off + 8 + n
    if vt == 9:
        var et = Int(read_u32(buf, off))
        var n = Int(read_u64(buf, off + 4))
        var o = off + 12
        for _ in range(n):
            if et == 8:
                var slen = Int(read_u64(buf, o))
                o += 8 + slen
            else:
                o += scalar_size(et)
        return o
    return off + scalar_size(vt)


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: gguf_parse_spike <model.gguf>")
    var cstr = to_cstr(args[1])
    var mode = to_cstr("rb")
    var fp = external_call[
        "fopen",
        Pointer[UInt8, MutUntrackedOrigin],
        Pointer[UInt8, MutUntrackedOrigin],
        Pointer[UInt8, MutUntrackedOrigin],
    ](cstr, mode)
    _ = external_call["fseek", Int32, Pointer[UInt8, MutUntrackedOrigin], Int64, Int32](fp, 0, 2)
    var size = external_call["ftell", Int64, Pointer[UInt8, MutUntrackedOrigin]](fp)
    _ = external_call["fseek", Int32, Pointer[UInt8, MutUntrackedOrigin], Int64, Int32](fp, 0, 0)
    var buf = unsafe_alloc[UInt8](Int(size))
    var got = external_call[
        "fread",
        UInt64,
        Pointer[UInt8, MutUntrackedOrigin],
        UInt64,
        UInt64,
        Pointer[UInt8, MutUntrackedOrigin],
    ](buf, 1, UInt64(size), fp)
    # NOTE: fclose omitted — std.io already declares fclose via external_call
    # with a conflicting signature; the spike exits immediately and the OS
    # reclaims the fd.
    print("FILE_SIZE", size, "READ", got)

    var magic_ok = (
        buf[unsafe_offset=0] == 0x47
        and buf[unsafe_offset=1] == 0x47
        and buf[unsafe_offset=2] == 0x55
        and buf[unsafe_offset=3] == 0x46
    )
    print("MAGIC_OK", magic_ok)
    print("VERSION", read_u32(buf, 4))
    var n_t = Int(read_u64(buf, 8))
    var n_kv = Int(read_u64(buf, 16))
    print("TENSOR_COUNT", n_t)
    print("KV_COUNT", n_kv)
    var off = 24
    for _ in range(n_kv):
        var klen = Int(read_u64(buf, off))
        off += 8
        var key = read_str(buf, off, klen)
        off += klen
        var vt = Int(read_u32(buf, off))
        off += 4
        print("KV", key, vt)
        off = skip_value(buf, off, vt)
    for _ in range(n_t):
        var nlen = Int(read_u64(buf, off))
        off += 8
        var name = read_str(buf, off, nlen)
        off += nlen
        var nd = Int(read_u32(buf, off))
        off += 4
        var dims = String()
        for d in range(nd):
            if d > 0:
                dims += "x"
            dims += String(read_u64(buf, off))
            off += 8
        var tt = read_u32(buf, off)
        off += 4
        var toff = read_u64(buf, off)
        off += 8
        print("TENSOR", name, dims, tt, toff)
    print("PARSE_DONE")
