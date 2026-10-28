"""Opt-in physical Llama 3 CUDA execution; no synthetic model substitution.

GPU-line baseline vehicle (platform/gpu-2060-verification): runs one fixed
greedy prompt through a real Llama3CUDASession and reports prefill/decode
timing so second-site GPU baselines carry the same numbers everywhere.
"""
from std.sys import argv
from std.ffi import external_call
from core.llama3_cuda import Llama3CUDASession
from loader.tokenizer import RuneStreamDecoder
from cli.modelfile import parse_int


def seconds() raises -> Float64:
    var stamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), stamp.unsafe_ptr()) != 0:
        raise Error("Cannot measure monotonic clock")
    return Float64(stamp[0]) + Float64(stamp[1]) / 1000000000.0


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: test_llama3_cuda <model.gguf> <context>")
    var session = Llama3CUDASession(args[1], parse_int(args[2]))
    var tokens: List[Int] = [128000]
    session.tokenizer.append_message(tokens, "user", "What is two plus two? Answer in one short sentence.")
    session.tokenizer.append_header(tokens, "assistant")
    print("Prompt IDs:", tokens)
    var t0 = seconds()
    var next_token = -1
    for i in range(len(tokens)):
        next_token = session.forward(tokens[i], i == len(tokens) - 1)
    var t1 = seconds()
    var decoder = RuneStreamDecoder()
    var generated = 0
    for _ in range(64):
        if next_token == 128001 or next_token == 128009:
            print("\nEOS", next_token)
            break
        print(session.tokenizer.decode(next_token, decoder), end="")
        _ = external_call["fflush", Int32](Int(0))
        generated += 1
        next_token = session.forward(next_token)
    var t2 = seconds()
    print("\nTIMING prompt_tokens=", len(tokens), " prefill_s=", t1 - t0, " generated=", generated, " decode_s=", t2 - t1)
