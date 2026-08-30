"""CPU packed GEMM against independent real GGUF oracle rows (opt-in)."""
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from cli.modelfile import parse_int, parse_float


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: test_cpu_packed_parity <model.gguf> <oracle.csv>")
    var model = PackedGGUF(args[1])
    var well = MimirWell(65536)
    var input = well.allocate(14336)
    for i in range(14336):
        input.unsafe_store(i, Float16(Float32((i * 7) % 29 - 14) / 16))
    var output = well.allocate(1)
    var count = 0
    var largest: Float32 = 0
    with open(args[2], "r") as source:
        var text = source.read()
        for line in text.split("\n"):
            if String(line) == "":
                continue
            var fields = line.split(",")
            if len(fields) != 3:
                raise Error("Malformed independent oracle")
            var tensor = model.tensors[String(fields[0])]
            if tensor.kind != 12 and tensor.kind != 14:
                continue
            var row = parse_int(String(fields[1]))
            var expected = parse_float(String(fields[2]))
            if row < 0 or row >= tensor.rows or tensor.columns > 14336:
                raise Error("Oracle shape exceeds test workspace")
            var base = model.source.mmap_ptr.unsafe_offset(tensor.offset + row * (tensor.byte_count // tensor.rows))
            var format = CompressedFormatType(CompressedFormatType.Q4_K_M if tensor.kind == 12 else CompressedFormatType.Q6_K)
            var A = RuneTensor[f16](1, tensor.columns, input, False)
            var B = RuneTensor[f16](1, tensor.columns, base.unsafe_bitcast[Float16](), True, format)
            var C = RuneTensor[f16](1, 1, output, False)
            gemm_f16(A, B, C)
            var actual = output.unsafe_load().cast[DType.float32]()
            var difference = abs(actual - expected)
            if difference > 0.0005 + 0.0005 * abs(expected):
                print(String(fields[0]), row, "actual", actual, "expected", expected, "kind", tensor.kind)
                raise Error("CPU packed GEMM differs from independent GGUF row oracle")
            largest = max(largest, difference)
            count += 1
    _ = well
    _ = model
    if count < 10:
        raise Error("Insufficient independent real-weight cases")
    print("CPU packed Q4_K/Q6_K real-weight parity: PASS; cases=", count, "max_absolute_error=", largest)
