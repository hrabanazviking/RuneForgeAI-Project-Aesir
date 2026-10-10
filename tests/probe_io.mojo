# Probe: POSIX file IO + String -> C string on Mojo 1.1.0.
from std.ffi import external_call
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc


def to_cstr(s: String) -> Pointer[UInt8, MutUntrackedOrigin]:
    var n = len(s)
    var buf = unsafe_alloc[UInt8](n + 1)
    var bytes = s.as_bytes()
    for i in range(n):
        buf[unsafe_offset=i] = bytes[unsafe_offset=i]
    buf[unsafe_offset=n] = UInt8(0)
    return buf


def main():
    # write 8 bytes
    var wbuf = unsafe_alloc[UInt8](8)
    for i in range(8):
        wbuf[unsafe_offset=i] = UInt8(i + 65)
    var path = to_cstr("/tmp/probe/io_test.bin")
    var fd = external_call["open", Int32, Pointer[UInt8, MutUntrackedOrigin], Int32, Int32](
        path, Int32(577), Int32(0o644)
    )
    print("open_w fd =", fd)
    var nw = external_call["write", Int64, Int32, Pointer[UInt8, MutUntrackedOrigin], Int64](
        fd, wbuf, Int64(8)
    )
    print("wrote =", nw)
    _ = external_call["close", Int32, Int32](fd)
    # read back
    var fd2 = external_call["open", Int32, Pointer[UInt8, MutUntrackedOrigin], Int32, Int32](
        path, Int32(0), Int32(0)
    )
    print("open_r fd =", fd2)
    var rbuf = unsafe_alloc[UInt8](8)
    var nr = external_call["read", Int64, Int32, Pointer[UInt8, MutUntrackedOrigin], Int64](
        fd2, rbuf, Int64(8)
    )
    print("read =", nr)
    _ = external_call["close", Int32, Int32](fd2)
    var ok = True
    for i in range(8):
        if rbuf[unsafe_offset=i] != UInt8(i + 65):
            ok = False
    print("roundtrip ok =", ok)
