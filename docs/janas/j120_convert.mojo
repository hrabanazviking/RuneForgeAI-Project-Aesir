# J-120 convert driver: the host for
# core/lora_convert.mojo over real files.
#
# Reads the synthetic HF checkpoint written by
# j120_fixtures.py (base model.safetensors, PEFT
# adapter_model.safetensors, adapter_config.json)
# from the fixed work directory, merges the adapter
# at conversion, writes merged.gguf, then runs the
# C10 from-gguf mode over the result (plain
# re-emission, which must come back byte-identical)
# and demonstrates the C05 quantize refusal.
# Prints the emitted census. The independent
# verifier is j120_verify.py; the loader-machinery
# re-read is j120_reread.mojo.
#
# File I/O is byte-faithful via the same syscall
# shape loader/gguf.mojo uses (open64/fstat plus
# pread/pwrite through external_call -- plain
# "read"/"write" external names are claimed by
# std.io in this toolchain); the text-mode
# FileHandle read is not used for binary formats.
# The geometry below is the fixture's own (stated
# in j120_fixtures.py): a synthetic 1-layer llama,
# vocab 8, hidden 8, ffn 16, heads 2, KV heads 1.
# No inference runs in this driver.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc

from core.lora_convert import (
    LcAdapterConfig,
    LcGeometry,
    LcTensor,
    lc_convert_base,
    lc_convert_from_gguf,
    lc_merge_model,
    lc_parse_adapter_config,
    lc_parse_safetensors,
    lc_refuse_quantize,
)

comptime WORK_DIR = "/tmp/j120/work/"


def _path_bytes(path: String) raises -> List[Int8]:
    var source = path.as_bytes()
    if len(source) == 0 or len(source) >= 4096:
        raise Error("path length out of range: " + path)
    var out = List[Int8]()
    for i in range(len(source)):
        out.append(Int8(source[i]))
    out.append(Int8(0))
    return out^


def read_file_bytes(path: String) raises -> List[Byte]:
    var path_bytes = _path_bytes(path)
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(526336), Int32(0)
    )
    _ = path_bytes
    if fd < 0:
        raise Error("failed to open for reading: " + path)
    var stat = unsafe_alloc[UInt64](18)
    for si in range(18):
        stat[unsafe_offset=si] = 0
    if external_call["fstat", Int32](fd, stat) != 0:
        stat.unsafe_free()
        _ = external_call["close", Int32](fd)
        raise Error("failed to stat: " + path)
    var size = Int(stat[unsafe_offset=6])
    stat.unsafe_free()
    if size < 0:
        _ = external_call["close", Int32](fd)
        raise Error("negative file size: " + path)
    var buf = unsafe_alloc[UInt8](size if size > 0 else 1)
    var got = 0
    while got < size:
        var n = external_call["pread", Int](
            fd, buf.unsafe_offset(got), size - got, got
        )
        if n <= 0:
            buf.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("short read on: " + path)
        got += n
    _ = external_call["close", Int32](fd)
    var out = List[Byte]()
    for i in range(size):
        out.append(buf.unsafe_load(i))
    buf.unsafe_free()
    return out^


def write_file_bytes(path: String, data: List[Byte]) raises:
    var path_bytes = _path_bytes(path)
    # O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, mode 0644.
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(524865), Int32(420)
    )
    _ = path_bytes
    if fd < 0:
        raise Error("failed to open for writing: " + path)
    var buf = unsafe_alloc[UInt8](len(data) if len(data) > 0 else 1)
    for i in range(len(data)):
        buf.unsafe_store(i, data[i])
    var put = 0
    while put < len(data):
        var n = external_call["pwrite", Int](
            fd, buf.unsafe_offset(put), len(data) - put, put
        )
        if n <= 0:
            buf.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("short write on: " + path)
        put += n
    buf.unsafe_free()
    if external_call["close", Int32](fd) != 0:
        raise Error("failed to close after writing: " + path)


def bytes_to_string(data: List[Byte]) -> String:
    var terminated = List[Byte]()
    for b in data:
        terminated.append(b)
    terminated.append(Byte(0))
    return String(unsafe_from_utf8_ptr=terminated.unsafe_ptr())


def main() raises:
    var base = lc_parse_safetensors(
        read_file_bytes(WORK_DIR + "model.safetensors"))
    var adapter = lc_parse_safetensors(
        read_file_bytes(WORK_DIR + "adapter_model.safetensors"))
    var cfg = lc_parse_adapter_config(
        bytes_to_string(read_file_bytes(WORK_DIR + "adapter_config.json")))
    print(
        "BASE TENSORS:", len(base), " ADAPTER TENSORS:", len(adapter),
        " RANK:", cfg.rank, " ALPHA:", cfg.alpha)
    var merged = lc_merge_model(base, adapter, cfg)
    var report = merged[1].copy()
    for name in report.merged_names:
        print("MERGED:", name)
    for name in report.passed_names:
        print("PASSTHROUGH:", name)
    var tokens = List[String]()
    for t in ["<unk>", "<s>", "</s>", "a", "b", "c", "d", "e"]:
        tokens.append(String(t))
    var geom = LcGeometry(
        "llama", "j120-synthetic", 128, 8, 16, 1, 2, 1, 4,
        Float32(10000.0), Float32(0.00001), tokens)
    var conv = lc_convert_base(merged[0].copy(), geom)
    write_file_bytes(WORK_DIR + "merged.gguf", conv.bytes)
    print("GGUF BYTES:", len(conv.bytes), " DATA OFFSET:", conv.data_offset)
    for e in conv.census:
        var dims = String("[")
        for di in range(len(e.dims)):
            if di > 0:
                dims += ","
            dims += String(e.dims[di])
        dims += "]"
        print(
            "TENSOR", e.name, "dims", dims, "type", e.ggml_type,
            "offset", e.offset, "bytes", e.byte_count)
    # C10: plain re-emission of the file just written
    # must be byte-identical (deterministic writer).
    var back = read_file_bytes(WORK_DIR + "merged.gguf")
    var plain = lc_convert_from_gguf(back, List[LcTensor](), cfg, False)
    var remitted = plain[0].copy()
    if len(remitted.bytes) != len(conv.bytes):
        raise Error("from-gguf re-emission size differs")
    for i in range(len(conv.bytes)):
        if remitted.bytes[i] != conv.bytes[i]:
            raise Error("from-gguf re-emission differs at byte " + String(i))
    write_file_bytes(WORK_DIR + "remitted.gguf", remitted.bytes)
    print("FROM-GGUF RE-EMISSION: BYTE-IDENTICAL (", len(conv.bytes), "bytes )")
    var refused = False
    try:
        lc_refuse_quantize("q4_k_m")
    except:
        refused = True
    if not refused:
        raise Error("quantize request was not refused")
    print("QUANTIZE REQUEST REFUSED: q4_k_m (C05 BF16-only scope)")
    print("CONVERT DRIVER: ALL PASS")
