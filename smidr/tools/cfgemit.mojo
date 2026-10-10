# H104 emitter: generates the vecadd config for a seed, writes the
# fp16 .bin payloads + vecadd_config.json into the output dir.
# Usage: cfgemit <seed-decimal> <out_dir>

from hailbru.errors import herror
from hailbru.syscall import (
    O_CREAT,
    O_TRUNC,
    O_WRONLY,
    os_close,
    os_openat,
    os_write,
    proc_cmdline,
    write_file_str,
)
from smidr.config_gen import config_json, gen_vecadd
from std.memory.alloc import unsafe_alloc


def parse_u64_dec(s: String) raises -> UInt64:
    var v = UInt64(0)
    var any = False
    for b in s.bytes():
        var c = Int(b)
        if c < 48 or c > 57:
            raise herror("BadArgs", "seed must be decimal, got '" + s + "'")
        v = v * UInt64(10) + UInt64(c - 48)
        any = True
    if not any:
        raise herror("BadArgs", "empty seed")
    return v


def write_file_bytes(arch: String, path: String, data: List[UInt8]) raises:
    var fd = os_openat(arch, path, O_WRONLY() | O_CREAT() | O_TRUNC(), 0o644)
    if fd < 0:
        raise herror("OsError", "open for write failed: " + path)
    var n = len(data)
    var p = unsafe_alloc[UInt8](n)
    for i in range(n):
        p[unsafe_offset=i] = data[i]
    var w = os_write(arch, fd, p, Int64(n))
    p.unsafe_free()
    _ = os_close(arch, fd)
    if w != Int64(n):
        raise herror("OsError", "short write: " + path)


def main() raises:
    var args = proc_cmdline("aarch64")
    if len(args) < 3:
        raise herror("BadArgs", "usage: cfgemit <seed> <out_dir>")
    var seed = parse_u64_dec(args[1])
    var outdir = args[2]
    var a_bin = List[UInt8]()
    var b_bin = List[UInt8]()
    var e_bin = List[UInt8]()
    gen_vecadd(seed, a_bin, b_bin, e_bin)
    write_file_bytes("aarch64", outdir + "/vecadd_a.bin", a_bin)
    write_file_bytes("aarch64", outdir + "/vecadd_b.bin", b_bin)
    write_file_bytes("aarch64", outdir + "/vecadd_expected.bin", e_bin)
    write_file_str("aarch64", outdir + "/vecadd_config.json", config_json(seed))
    print(
        "CFGEMIT OK seed=" + String(seed)
        + " a=" + String(len(a_bin))
        + " b=" + String(len(b_bin))
        + " e=" + String(len(e_bin))
    )
