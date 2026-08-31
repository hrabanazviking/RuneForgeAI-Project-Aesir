"""Invalid CUDA chat requests must fail before opening a model or transcript."""
from cli.cuda_chat import dispatch_cuda_chat

def test_cuda_chat_admission() raises:
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
