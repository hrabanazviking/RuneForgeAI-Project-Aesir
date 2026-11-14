# tests/test_gguf_writer_streaming_qc_3b.mojo
# QC-3b stage 1 proof: the streaming emission path of
# loader/gguf_writer.mojo (GGUFStreamWriter) emits byte-identical
# output to the QC-1 in-memory path while never holding the file
# in memory.
#
# Modes:
#   synth              synthetic 3-tensor model: streamed bytes ==
#                      build_gguf_bytes bytes exactly, with payloads
#                      fed in awkward 7-byte chunks; stream refusals
#                      (overrun / short / out-of-order) fire.
#   stories <src> <out>  stories260K copy through the streaming path
#                      is byte-identical to BOTH the in-memory
#                      emission and the source file itself (the
#                      QC-1 byte-identity class check).
#   gemma-mem <src> <out>    gemma-4-E2B header copy + in-memory
#                      emission (the RSS baseline; run under
#                      /usr/bin/time -v by the slice script).
#   gemma-stream <src> <out> gemma-4-E2B copy through the streaming
#                      path, payloads lifted from the source mmap
#                      in 64 KiB chunks (the RSS candidate).

from std.ffi import external_call
from std.sys import argv

from core.mimir_well import MimirWell  # anchor import (QC-1 build gotcha: an entry file importing loader.gguf must name a core.* module first)
from loader.gguf import GGUFSeer
from loader.gguf_writer import (
    GGUFModelDesc,
    GGUFWriterTensor,
    GGUFWriterTensorMeta,
    build_gguf_bytes,
    copy_gguf_model,
    gguf_kv_string,
    gguf_kv_u32,
    open_gguf_stream,
    read_gguf_header_copy,
    write_gguf_file,
)


def check(condition: Bool, label: String) raises:
    if not condition:
        raise Error("QC-3b streaming check failed: " + label)


def read_file_bytes(path: String) raises -> List[UInt8]:
    var path_bytes = List[Int8]()
    for byte in path.as_bytes():
        path_bytes.append(Int8(byte))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](path_bytes.unsafe_ptr(), Int32(0), Int32(0))
    if fd < 0:
        raise Error("failed to open file for readback: " + path)
    var out = List[UInt8]()
    var buffer = List[UInt8]()
    buffer.resize(65536, UInt8(0))
    while True:
        var got = external_call["read", Int](Int(fd), buffer.unsafe_ptr(), 65536)
        if got < 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to read file: " + path)
        if got == 0:
            break
        for i in range(got):
            out.append(buffer[i])
    _ = external_call["close", Int32](fd)
    return out^


def bytes_equal(a: List[UInt8], b: List[UInt8]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def test_synth() raises:
    var desc = GGUFModelDesc()
    desc.add_kv(gguf_kv_string("general.architecture", String("llama")))
    desc.add_kv(gguf_kv_u32("general.file_type", UInt32(7)))
    var norm = List[UInt8]()
    for i in range(128):
        norm.append(UInt8(i % 251))
    var dims_norm = List[UInt64]()
    dims_norm.append(32)
    desc.add_tensor(GGUFWriterTensor(String("norm.weight"), dims_norm, UInt32(0), norm))
    var mat = List[UInt8]()
    for i in range(544):
        mat.append(UInt8((i * 3) % 256))
    var dims_mat = List[UInt64]()
    dims_mat.append(64)
    dims_mat.append(8)
    desc.add_tensor(GGUFWriterTensor(String("mat.weight"), dims_mat, UInt32(8), mat))
    var expected = build_gguf_bytes(desc)
    var metas = List[GGUFWriterTensorMeta]()
    for tensor in desc.tensors:
        metas.append(GGUFWriterTensorMeta(tensor.name, tensor.dims, tensor.tensor_type))
    var out_path = String("/tmp/qc3b-stream-synth.gguf")
    var writer = open_gguf_stream(out_path, desc.kvs, metas, desc.alignment)
    for i in range(len(desc.tensors)):
        writer.begin_tensor(i)
        var payload = desc.tensors[i].payload.copy()
        var done = 0
        while done < len(payload):
            var n = len(payload) - done
            if n > 7:
                n = 7
            var chunk = List[UInt8]()
            for k in range(n):
                chunk.append(payload[done + k])
            writer.write_chunk(chunk)
            done += n
        writer.end_tensor()
    var total = writer.finish()
    check(total == len(expected), "synthetic streamed size == in-memory size")
    var streamed = read_file_bytes(out_path)
    check(bytes_equal(streamed, expected), "synthetic streamed bytes == build_gguf_bytes bytes")
    print("PASS: synthetic streaming emission byte-identical to in-memory emission (", total, " bytes, 7-byte chunks)")
    # Refusals: overrun, short, out-of-order.
    var path2 = String("/tmp/qc3b-stream-refuse.gguf")
    var overrun = False
    try:
        var w = open_gguf_stream(path2, desc.kvs, metas, desc.alignment)
        w.begin_tensor(0)
        var big = List[UInt8]()
        big.resize(129, UInt8(0))
        w.write_chunk(big)
    except:
        overrun = True
    check(overrun, "write_chunk overrun refused")
    var short = False
    try:
        var w = open_gguf_stream(path2, desc.kvs, metas, desc.alignment)
        w.begin_tensor(0)
        var small = List[UInt8]()
        small.resize(3, UInt8(0))
        w.write_chunk(small)
        w.end_tensor()
    except:
        short = True
    check(short, "short tensor refused at end_tensor")
    var order = False
    try:
        var w = open_gguf_stream(path2, desc.kvs, metas, desc.alignment)
        w.begin_tensor(1)
    except:
        order = True
    check(order, "out-of-order begin_tensor refused")
    print("PASS: stream refusals fire (chunk overrun / short tensor / out-of-order)")


def stream_copy(source: String, output: String) raises -> Int:
    # The streaming copy path shared by stories/gemma modes:
    # header copy + per-tensor payload lift in 64 KiB chunks.
    var head = read_gguf_header_copy(source)
    var seer = GGUFSeer(source)
    seer._open_and_map()
    seer._parse_header()
    var metas = List[GGUFWriterTensorMeta]()
    for entry in head.directory:
        metas.append(GGUFWriterTensorMeta(entry.name, entry.dims, entry.tensor_type))
    var writer = open_gguf_stream(output, head.kvs, metas, head.alignment)
    for i in range(len(head.directory)):
        ref entry = head.directory[i]
        var base = head.data_offset + entry.relative_offset
        seer._require_range(base, entry.byte_size)
        writer.begin_tensor(i)
        var done = 0
        while done < entry.byte_size:
            var n = entry.byte_size - done
            if n > 65536:
                n = 65536
            var chunk = List[UInt8]()
            chunk.resize(n, UInt8(0))
            for k in range(n):
                chunk[k] = UInt8(seer.mmap_ptr.unsafe_offset(base + done + k).unsafe_load())
            writer.write_chunk(chunk)
            done += n
        writer.end_tensor()
    return writer.finish()


def test_stories(source: String, output: String) raises:
    var desc = copy_gguf_model(source)
    var expected = build_gguf_bytes(desc)
    var total = stream_copy(source, output)
    check(total == len(expected), "stories streamed size == in-memory size")
    var streamed = read_file_bytes(output)
    check(bytes_equal(streamed, expected), "stories streamed bytes == in-memory emission")
    var source_bytes = read_file_bytes(source)
    check(bytes_equal(streamed, source_bytes), "stories streamed bytes == source file bytes")
    print("PASS: stories260K streaming copy byte-identical to in-memory emission AND to the source file (", total, " bytes)")


def run_gemma_mem(source: String, output: String) raises:
    var desc = copy_gguf_model(source)
    var total = write_gguf_file(output, desc)
    print("GEMMA_MEM_WROTE", total, "bytes to", output)


def run_gemma_stream(source: String, output: String) raises:
    var total = stream_copy(source, output)
    print("GEMMA_STREAM_WROTE", total, "bytes to", output)


def main() raises:
    var arguments = argv()
    if len(arguments) < 2:
        raise Error("usage: test_gguf_writer_streaming_qc_3b <synth|stories|gemma-mem|gemma-stream> [src] [out]")
    var mode = arguments[1]
    if mode == "synth":
        test_synth()
    elif mode == "stories":
        test_stories(arguments[2], arguments[3])
    elif mode == "gemma-mem":
        run_gemma_mem(arguments[2], arguments[3])
    elif mode == "gemma-stream":
        run_gemma_stream(arguments[2], arguments[3])
    else:
        raise Error("unknown mode: " + mode)
    print("QC-3b streaming writer proof (" + mode + "): DONE")
