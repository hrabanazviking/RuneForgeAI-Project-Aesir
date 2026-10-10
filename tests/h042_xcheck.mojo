# tests/h042_xcheck.mojo
# H042 — GGUF loader cross-architecture check (TEST-ONLY driver, not shipped).
#
# Dequantizes every tensor of a GGUF file to FP16 with armvegr/gguf_loader.mojo
# and writes each tensor's raw FP16 bytes to <outdir>/<tensor>.f16.
# Run the same binary built for x86_64 (forge) and for ARM64 (Mimir) over the
# same corpus; the .f16 files must be byte-identical (sha256 compared).
# Corrupt input prints "REJECT: <error>" and exits 0 (fail-closed contract).
#
# Usage: h042_xcheck <path-to-gguf> <outdir>

from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.gguf_loader import GGUFLoader


def write_bytes(path: String, data: Pointer[UInt8, MutUntrackedOrigin], n: Int) raises:
    var path_bytes = List[Int8]()
    var source = path.as_bytes()
    for i in range(len(source)):
        path_bytes.append(Int8(source[i]))
    path_bytes.append(0)
    # O_WRONLY | O_CREAT | O_TRUNC = 577, mode 0o644.
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(577), Int32(416)
    )
    _ = path_bytes
    if fd < 0:
        raise Error("h042_xcheck: cannot open output file " + path)
    var written = 0
    while written < n:
        var w = external_call["write", Int](
            Int(fd), data.unsafe_offset(written), n - written
        )
        if w <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("h042_xcheck: write failed on " + path)
        written += Int(w)
    _ = external_call["close", Int32](fd)


def safe_name(name: String) -> String:
    var out = String("")
    for i in range(len(name.as_bytes())):
        var c = name[byte=i]
        if c == "/":
            out += "_"
        else:
            out += c
    return out


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: h042_xcheck <path-to-gguf> <outdir>")
    var loader = GGUFLoader()
    try:
        loader.open(args[1])
    except e:
        print("REJECT: " + String(e))
        return
    print("tensors: " + String(loader.tensor_count()))
    for i in range(loader.tensor_count()):
        ref d = loader.descs[i]
        var n = d.element_count()
        print(
            "tensor " + d.name + " " + String(d.rows) + "x" + String(d.cols)
            + " type=" + String(d.ggml_type) + " n=" + String(n)
        )
        var buf = unsafe_alloc[Float16](n)
        try:
            loader.dequantize(d.name, buf)
        except e:
            buf.unsafe_free()
            print("REJECT-TENSOR " + d.name + ": " + String(e))
            continue
        var sum = Float64(0)
        for k in range(n):
            sum += Float64(buf[unsafe_offset=k])
        print("  sum_f64=" + String(sum))
        write_bytes(
            args[2] + "/" + safe_name(d.name) + ".f16",
            buf.unsafe_bitcast[UInt8](),
            2 * n,
        )
        buf.unsafe_free()
    loader.close()
    print("H042-XCHECK-DONE")
