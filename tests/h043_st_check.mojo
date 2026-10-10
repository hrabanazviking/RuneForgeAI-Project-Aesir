# tests/h043_st_check.mojo
# H043/H044 — safetensors check harness (TEST-ONLY driver, not shipped).
#
# Prints the canonical descriptor list for a safetensors file:
#   name=<name> dtype=<F16|BF16|F32> shape=<d0>,<d1> start=<abs> end=<abs>
# (one line per tensor, sorted by name via insertion sort).
# Corrupt input prints "REJECT: <error>" and exits 0 (fail-closed contract).
#
# H044 mode: with a third argument "load", also loads every tensor to FP16
# and prints "cksum <name> <fnv1a64-hex> <sum_f64>" per tensor.
#
# Usage: h043_st_check <path-to-st> [load]

from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.safetensors import SafetensorsLoader


def dtype_str(dt: UInt8) -> String:
    if dt == UInt8(0):
        return "F16"
    if dt == UInt8(1):
        return "BF16"
    return "F32"


def main() raises:
    var args = argv()
    if len(args) < 2 or len(args) > 3:
        raise Error("usage: h043_st_check <path-to-st> [load]")
    var do_load = len(args) == 3 and args[2] == "load"
    var loader = SafetensorsLoader()
    try:
        loader.open(args[1])
    except e:
        print("REJECT: " + String(e))
        return
    # insertion sort of indices by name
    var order = List[Int]()
    for i in range(loader.tensor_count()):
        order.append(i)
    for i in range(1, len(order)):
        var key = order[i]
        var j = i - 1
        while j >= 0 and loader.descs[order[j]].name > loader.descs[key].name:
            order[j + 1] = order[j]
            j -= 1
        order[j + 1] = key
    for oi in range(len(order)):
        ref d = loader.descs[order[oi]]
        var shape_s = String("")
        for k in range(len(d.shape)):
            if k > 0:
                shape_s += ","
            shape_s += String(d.shape[k])
        print(
            "name=" + d.name + " dtype=" + dtype_str(d.dtype)
            + " shape=" + shape_s + " start=" + String(d.data_start)
            + " end=" + String(d.data_end)
        )
        if do_load:
            var n = Int(d.element_count())
            var buf = unsafe_alloc[Float16](n)
            loader.load_fp16(d.name, buf)
            var h = UInt64(14695981039346656037)
            var s = Float64(0)
            var bp = buf.unsafe_bitcast[UInt8]()
            for b in range(2 * n):
                h = (h ^ UInt64(bp.unsafe_offset(b).unsafe_load())) * UInt64(1099511628211)
            for k in range(n):
                s += Float64(buf[unsafe_offset=k])
            # NaN-safe sum print: NaN sums print as-is; both arches use IEEE.
            print("cksum " + d.name + " " + String(h) + " " + String(s))
            buf.unsafe_free()
    loader.close()
    print("ST-CHECK-DONE")
