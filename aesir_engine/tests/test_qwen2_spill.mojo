"""Opt-in physical split execution: Qwen 2 front layers on CUDA, tail
layers on the CPU path, one hidden-state crossing per token.

GPU-line spill proof vehicle (platform/gpu-2060-verification): runs the
same fixed greedy ChatML prompt as test_qwen2_cuda through a
Llama3SpillSession admitted by the qwen2 profile, at a context length
whose whole-model admission is refused, so the split run can be compared
token-for-token with the whole-GPU baseline.
Usage: test_qwen2_spill <model.gguf> <context> <exec_layers>
"""
from std.sys import argv
from std.ffi import external_call
from core.llama3_spill import Llama3SpillSession
from loader.tokenizer import RuneStreamDecoder
from cli.modelfile import parse_int


def seconds() raises -> Float64:
    var stamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), stamp.unsafe_ptr()) != 0:
        raise Error("Cannot measure monotonic clock")
    return Float64(stamp[0]) + Float64(stamp[1]) / 1000000000.0


def main() raises:
    var args = argv()
    if len(args) != 4:
        raise Error("usage: test_qwen2_spill <model.gguf> <context> <exec_layers>")
    var session = Llama3SpillSession(args[1], parse_int(args[2]), parse_int(args[3]))
    var tokens = List[Int]()
    session.front.tokenizer.append_message(tokens, "user", "What is two plus two? Answer in one short sentence.")
    session.front.tokenizer.append_header(tokens, "assistant")
    print("Prompt IDs:", tokens)
    var t0 = seconds()
    var next_token = -1
    for i in range(len(tokens)):
        next_token = session.step(tokens[i])
    var t1 = seconds()
    var decoder = RuneStreamDecoder()
    var generated = 0
    for _ in range(64):
        if next_token == 151645 or next_token == 151643:
            print("\nEOS", next_token)
            break
        print(session.front.tokenizer.decode(next_token, decoder), end="")
        _ = external_call["fflush", Int32](Int(0))
        generated += 1
        next_token = session.step(next_token)
    var t2 = seconds()
    print("\nTIMING prompt_tokens=", len(tokens), " prefill_s=", t1 - t0, " generated=", generated, " decode_s=", t2 - t1)
