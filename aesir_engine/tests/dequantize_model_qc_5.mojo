# QC-5 stage 3c grading tool: materialize the dequantized weight set
# of a K-quant GGUF as an F16 GGUF.
#
# Why this exists: AesirEngine's llama forward dispatches Q4_K/Q6_K
# tensors to the fused K GEMM, which addresses blocks per row and
# refuses contraction dims that are not multiples of 256 -- so the
# emitted stories260K.Q4_K_M.gguf cannot be graded through the stock
# forward (the model test asserts that refusal as a named finding).
# The quantity a quantization grade measures is the end-to-end effect
# of the dequantized weights; this tool writes exactly those weights
# (the engine's own flat dequantizer, core/dequantize_input) into an
# F16 GGUF with the source's metadata (general.file_type restored
# from the source), so the unmodified QC-3a grade driver can grade
# the weight set our Q4_K_M file encodes.
#
# Usage: dequantize_model_qc_5 <quant.gguf> <source.gguf> <out.gguf>

from std.ffi import external_call
from std.memory import bitcast
from std.sys import argv
from core.dequantize_input import dequantize_range_f32
from core.mimir_well import MimirWell, f16
from loader.gguf_writer import (
    GGUFModelDesc,
    GGUFWriterTensor,
    gguf_kv_u32,
    read_gguf_header_copy,
    write_gguf_file,
)


def read_file_bytes(path: String) raises -> List[UInt8]:
    var path_bytes = List[Int8]()
    for byte in path.as_bytes():
        path_bytes.append(Int8(byte))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(0), Int32(0)
    )
    if fd < 0:
        raise Error("failed to open file: " + path)
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


def main() raises:
    var arguments = argv()
    if len(arguments) != 4:
        raise Error(
            "usage: dequantize_model_qc_5 <quant.gguf> <source.gguf>"
            " <out.gguf>"
        )
    var quant_path = arguments[1]
    var source_path = arguments[2]
    var out_path = arguments[3]

    var q_head = read_gguf_header_copy(quant_path)
    var src_head = read_gguf_header_copy(source_path)
    var buf = read_file_bytes(quant_path)
    var well = MimirWell(1048576)
    var wptr = well.allocate((len(buf) + 1) // 2 + 16).unsafe_bitcast[UInt8]()
    for i in range(len(buf)):
        wptr.unsafe_store(i, buf[i])

    var src_file_type = UInt32(1)
    for kv in src_head.kvs:
        if kv.key == "general.file_type":
            src_file_type = kv.value.as_u32()

    var desc = GGUFModelDesc()
    desc.alignment = q_head.alignment
    for kv in q_head.kvs:
        if kv.key == "general.file_type":
            desc.add_kv(gguf_kv_u32("general.file_type", src_file_type))
        else:
            desc.add_kv(kv)

    var dequantized = 0
    var copied = 0
    for entry in q_head.directory:
        var base = q_head.data_offset + entry.relative_offset
        var count = 1
        for dim in entry.dims:
            count *= Int(dim)
        if entry.tensor_type == UInt32(12) or entry.tensor_type == UInt32(14):
            var values = dequantize_range_f32(
                wptr, base, Int(entry.tensor_type), 0, count
            )
            if len(values) != count:
                raise Error("dequant count mismatch for " + entry.name)
            var payload = List[UInt8]()
            payload.reserve(count * 2)
            for v in values:
                var bits = bitcast[DType.uint16](v.cast[f16]())
                payload.append(UInt8(bits & 0xFF))
                payload.append(UInt8((bits >> 8) & 0xFF))
            desc.add_tensor(
                GGUFWriterTensor(entry.name, entry.dims, UInt32(1), payload)
            )
            dequantized += 1
        else:
            var payload = List[UInt8]()
            payload.reserve(entry.byte_size)
            for index in range(entry.byte_size):
                payload.append(buf[base + index])
            desc.add_tensor(
                GGUFWriterTensor(
                    entry.name, entry.dims, entry.tensor_type, payload
                )
            )
            copied += 1
    var written = write_gguf_file(out_path, desc)
    print(
        "WROTE",
        out_path,
        written,
        "bytes; dequantized",
        dequantized,
        "tensors, copied",
        copied,
    )
