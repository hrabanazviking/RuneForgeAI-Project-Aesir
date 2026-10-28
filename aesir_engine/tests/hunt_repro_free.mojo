"""Repro round 3: WHO frees the arena at scope exit?
ST1: MimirWell only (no tensor). ST2: RuneTensor only (manual alloc).
ST3: well + tensor (like test_geglu). ST4: control (manual alloc, no structs).
After the helper dies, main allocates 49160 bytes (the string-buffer class)
and compares addresses. Select with REPRO_ST."""
from core.mimir_well import MimirWell, RuneTensor, f16
from std.memory.alloc import alloc, dealloc, Layout
from std.memory import Pointer, unsafe_memset_zero
from std.ffi import external_call


def _env_int(name: String, default: Int) -> Int:
    var buf = InlineArray[Int8, 32](fill=0)
    var bytes = name.as_bytes()
    if len(bytes) >= 32:
        return default
    for i in range(len(bytes)):
        buf[i] = Int8(bytes[i])
    var raw = external_call["getenv", Pointer[UInt8, MutUntrackedOrigin]](
        buf.unsafe_ptr()
    )
    if Int(raw) == 0:
        return default
    var value = 0
    var k = 0
    while raw.unsafe_load(k) != 0:
        value = value * 10 + Int(raw.unsafe_load(k)) - 48
        k += 1
    return value


def st1_well_only() raises -> Int:
    var well = MimirWell(1024 * 64)
    var p = well.allocate(70)
    p.unsafe_store(0, Float16(1.6826171875))
    return Int(p)


def st2_tensor_only() raises -> Int:
    var allocation = alloc(Layout[Scalar[f16]](count=32768))
    var base = allocation^.unsafe_leak()
    unsafe_memset_zero(base, 32768)
    var T = RuneTensor[f16](1, 70, base)
    T.data.unsafe_store(0, Float16(1.6826171875))
    return Int(T.data)


def st3_both() raises -> Int:
    var well = MimirWell(1024 * 64)
    var p = well.allocate(70)
    var T = RuneTensor[f16](1, 70, p)
    T.data.unsafe_store(0, Float16(1.6826171875))
    return Int(T.data)


def probe_alloc() raises -> Int:
    var a = alloc(Layout[UInt8](count=49160))
    var q = a^.unsafe_leak()
    q.unsafe_store(0, UInt8(0xAB))
    return Int(q)


def main() raises:
    var st = _env_int("REPRO_ST", 3)
    var arena = 0
    if st == 1:
        arena = st1_well_only()
    elif st == 2:
        arena = st2_tensor_only()
    elif st == 4:
        var allocation = alloc(Layout[Scalar[f16]](count=32768))
        var base = allocation^.unsafe_leak()
        unsafe_memset_zero(base, 32768)
        base.unsafe_store(0, Float16(1.6826171875))
        arena = Int(base)
    else:
        arena = st3_both()
    print("ST", st, "arena:", arena)
    var probe = probe_alloc()
    print("ST", st, "probe(49160):", probe, "SAME-AS-ARENA:", probe == arena)
    var probe2 = probe_alloc()
    print("ST", st, "probe2(49160):", probe2, "SAME-AS-ARENA:", probe2 == arena)
