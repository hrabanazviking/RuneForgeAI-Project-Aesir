"""Physical CUDA versus independently dequantized real-weight dot products."""
from std.sys import argv
from core.gemma4_cuda import Gemma4CUDASession, LOGITS, SCORES
from cli.modelfile import parse_int, parse_float

def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: test_gemma4_quant_parity <model.gguf> <oracle.csv>")
    var session = Gemma4CUDASession(args[1], 512)
    var staging = session.context.enqueue_create_host_buffer[DType.float32](SCORES + 8 * 512)
    for i in range(10752):
        staging[i] = Float32((i * 7) % 29 - 14) / 16.0
    session.context.enqueue_copy(session.activations, staging)
    session.context.synchronize()
    var previous = String("")
    var count = 0
    var largest: Float32 = 0
    with open(args[2], "r") as file:
        var text = file.read()
        for line in text.split("\n"):
            if line == "":
                continue
            var fields = line.split(",")
            if len(fields) != 3:
                raise Error("Malformed parity oracle")
            var name = String(fields[0])
            var row = parse_int(String(fields[1]))
            var expected = parse_float(String(fields[2]))
            if name != previous:
                session.matvec(name, 0, LOGITS)
                session.context.enqueue_copy(staging, session.activations)
                session.context.synchronize()
                previous = name
            if row < 0 or row >= session.model.tensors[name].rows:
                raise Error("Parity oracle row out of range")
            var actual = staging[LOGITS + row]
            var difference = abs(actual - expected)
            largest = max(largest, difference)
            if difference > 0.0002 + 0.00002 * abs(expected):
                print(name, row, "actual", actual, "expected", expected)
                raise Error("Native CUDA packed matvec differs from independent GGUF oracle")
            count += 1
    if count != 35:
        raise Error("Expected all 35 real-weight parity checks")
    print("CUDA packed Q4_K/Q5_K/Q6_K/BF16/F32 parity: PASS; cases=", count, "max_absolute_error=", largest)
