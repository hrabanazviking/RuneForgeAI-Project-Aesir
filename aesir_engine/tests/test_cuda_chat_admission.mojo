"""Invalid CUDA chat requests must fail before opening a model or transcript."""
from cli.cuda_chat import (
    ChatTranscript,
    build_chat_model_switch_arguments,
    dispatch_cuda_chat,
    default_chat_max_tokens,
    parse_model_switch,
)
from core.sampling_config import NativeSamplingConfig
from core.sampling_options import sampling_decimal
from std.collections import InlineArray
from std.ffi import external_call


def test_cuda_model_switch_syntax() raises:
    if parse_model_switch("/model gemma") != "gemma":
        raise Error("model switch parser changed a valid alias")
    if parse_model_switch("/model /models/qwen.gguf") != "/models/qwen.gguf":
        raise Error("model switch parser changed a valid path")
    for invalid in ["/model", "/models gemma", "/model   "]:
        var rejected = False
        try:
            _ = parse_model_switch(invalid)
        except:
            rejected = True
        if not rejected:
            raise Error("model switch parser accepted malformed syntax")

    # Process-image handoff may inherit only an owner-held writable regular
    # transcript. In particular, a pipe must not become a trusted log sink.
    var descriptors = InlineArray[Int32, 2](fill=-1)
    if external_call["pipe2", Int32](descriptors.unsafe_ptr(), Int32(0)) != 0:
        raise Error("unable to create transcript descriptor test fixture")
    var descriptor_rejected = False
    try:
        _ = ChatTranscript("", Int(descriptors[1]))
    except error:
        descriptor_rejected = "writable regular file" in String(error)
    _ = external_call["close", Int32](descriptors[0])
    _ = external_call["close", Int32](descriptors[1])
    if not descriptor_rejected:
        raise Error("transcript handoff accepted a pipe descriptor")

    var sampling = NativeSamplingConfig(
        Float32(0.000001), 17, Float32(0.0000001), Float32(0.00000001),
        Float32(1.000001), 257, UInt64(18446744073709551615),
    )
    var handoff = build_chat_model_switch_arguments(
        "next", "private/models", 2, 536870912, 4096, 128, "", sampling,
        1234, True, Int32(9),
    )
    var names: List[String] = [
        "--temperature", "--top-p", "--min-p", "--repeat-penalty",
    ]
    var expected: List[Float32] = [
        sampling.temperature, sampling.top_p, sampling.min_p,
        sampling.repetition_penalty,
    ]
    for field in range(len(names)):
        var found = False
        for index in range(len(handoff) - 1):
            if handoff[index] == names[field]:
                found = True
                var text = handoff[index + 1]
                if "e" in text or "E" in text or sampling_decimal(text) != expected[field]:
                    raise Error("Model switch sampling handoff changed " + names[field])
        if not found:
            raise Error("Model switch omitted " + names[field])
    if ("--context" not in handoff or "--max-tokens" not in handoff
            or "--tui" not in handoff or "--resume-log-fd" not in handoff
            or handoff[1] != "chat" or handoff[2] != "next"):
        raise Error("Model switch lost non-sampling handoff settings")

def test_cuda_chat_admission() raises:
    if (default_chat_max_tokens("llama3", "llama3-8B", 8192) != 4096
            or default_chat_max_tokens("qwen3", "qwen3-0.6B", 2048) != 1024
            or default_chat_max_tokens("gemma4", "gemma4-E2B", 16384) != 4096
            or default_chat_max_tokens("gemma4", "gemma4-E4B", 32768) != 16384):
        raise Error("Automatic chat reply budget drifted")
    var cases: List[String] = [
        "chat missing.gguf --accel cpu",
        "chat missing.gguf --accel cuda --context 16384 --max-tokens 16384",
        "chat missing.gguf --accel cuda --max-tokens 0",
        "chat missing.gguf --accel cuda --log one --log two",
        "chat missing.gguf --accel cuda --unknown value",
        "chat missing.gguf --accel cuda --profile unknown",
        "chat missing.gguf --accel cuda --profile llama3 --context 8193",
        "chat missing.gguf --accel cuda --profile llama3 --max-tokens 8193",
        "chat missing.gguf --accel cuda --profile llama3 --context 1",
        "chat missing.gguf --accel cuda --temperature NaN",
        "chat missing.gguf --accel cuda --top-k 257",
        "chat missing.gguf --accel cuda --top-p 0",
        "chat missing.gguf --accel cuda --min-p 1.01",
        "chat missing.gguf --accel cuda --repeat-penalty 0",
        "chat missing.gguf --accel cuda --repeat-last-n 0",
        "chat missing.gguf --accel cuda --seed 18446744073709551616",
        "chat missing.gguf --accel cuda --temperature 0.8 --temperature 1",
        "chat missing.gguf --accel cuda --timeout-ms -1",
        "chat missing.gguf --accel cuda --timeout-ms 3600001",
        "chat missing.gguf --accel cuda --timeout-ms junk",
    ]
    for request in cases:
        var args = List[String]()
        for word in request.split(" "):
            args.append(String(word))
        var rejected = False
        try:
            dispatch_cuda_chat(args)
        except error:
            if "Failed to open GGUF" in String(error) or "Cannot create transcript" in String(error):
                raise Error("Invalid chat options reached file operations")
            rejected = True
        if not rejected:
            raise Error("Invalid CUDA chat request was accepted")
