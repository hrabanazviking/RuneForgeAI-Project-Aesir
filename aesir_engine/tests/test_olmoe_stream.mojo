"""Streamed-MoE proof vehicle (J-022): runs a prompt's token ids through
MoEStreamSession with a stated expert-cache budget and prints the
generated ids, the J-018 cache statistics, the J-019 reader counters,
and timings. Tokenization is external on purpose: OLMoE's 'olmo'
pre-tokenizer is not Aesir's (recorded gap, J-022 doc) -- the caller
supplies ids produced by the model's own tokenizer stack, and grading
compares these ids against the ggml CPU comparator (tf_oracle) under
the raw-oracle discipline.

Usage: test_olmoe_stream <model.gguf> <context> <cache_bytes> <tokens_csv> <gen_count>
"""
from std.sys import argv
from std.ffi import external_call
from core.moe_session import MoEStreamSession
from cli.modelfile import parse_int


def seconds() raises -> Float64:
    var stamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), stamp.unsafe_ptr()) != 0:
        raise Error("Cannot measure monotonic clock")
    return Float64(stamp[0]) + Float64(stamp[1]) / 1000000000.0


def parse_tokens(text: String) raises -> List[Int]:
    var tokens = List[Int]()
    var current = String("")
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        var b = bytes[i]
        if b == 44:  # ','
            if len(current.as_bytes()) > 0:
                tokens.append(parse_int(current))
                current = String("")
        else:
            current += chr(Int(b))
    if len(current.as_bytes()) > 0:
        tokens.append(parse_int(current))
    return tokens^


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error(
            "usage: test_olmoe_stream <model.gguf> <context> <cache_bytes>"
            " <tokens_csv> <gen_count>"
        )
    var session = MoEStreamSession(
        args[1], parse_int(args[2]), parse_int(args[3])
    )
    var tokens = parse_tokens(args[4])
    var gen_count = parse_int(args[5])
    print("Prompt IDs:", tokens)
    var t0 = seconds()
    var next_token = 0
    for i in range(len(tokens)):
        next_token = session.step(tokens[i])
    var t1 = seconds()
    var generated = List[Int]()
    for _ in range(gen_count):
        generated.append(next_token)
        if next_token == session.seer.config.eos_token_id:
            break
        next_token = session.step(next_token)
    var t2 = seconds()
    print("Generated IDs:", generated)
    var stats = session.cache_stats()
    print("[CACHE] " + stats.describe())
    print("[STREAM] " + session.describe_stream())
    print(
        "TIMING prompt_tokens=",
        len(tokens),
        " prefill_s=",
        t1 - t0,
        " generated=",
        len(generated),
        " decode_s=",
        t2 - t1,
    )
