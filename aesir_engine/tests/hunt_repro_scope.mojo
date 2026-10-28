"""Repro round 2: real MimirWell + real geglu, well scoped inside a helper
(exactly like test_geglu), raw arena address escapes; then case-59-style
string growth in main. Question: does well scope-exit free the arena?"""
from core.mimir_well import MimirWell, RuneTensor, f16
from core.compute import geglu
from std.memory import Pointer


def run_geglu_like_the_test() raises -> Int:
    var well = MimirWell(1024 * 64)
    var half = 35
    var total = half * 2
    var t_ptr = well.allocate(total)
    var T = RuneTensor[f16](1, total, t_ptr)
    for i in range(half):
        T.data.unsafe_store(i, 2.0)
    for i in range(half, total):
        T.data.unsafe_store(i, 1.0)
    geglu(T)
    print("inside: head =", T.data.unsafe_load(0))
    return Int(T.data)


def main() raises:
    var arena = run_geglu_like_the_test()
    print("arena:", arena)
    var probe = Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=arena)
    print("head after scope exit:", probe.unsafe_load(0))
    var s = String("")
    for _ in range(1048576):
        s += "x"
        var n = s.byte_length()
        if n == 49152:
            print("strbuf at len 49152:", Int(s.unsafe_ptr()))
    print("strbuf final:", Int(s.unsafe_ptr()))
    print("head after string:", probe.unsafe_load(0))
    print("head[4] after string:", probe.unsafe_load(4))
