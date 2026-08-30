"""Native CUDA chat orchestration and durable, exclusive transcript output."""
from std.ffi import external_call
from aesir import Gemma4CUDASession, Llama3CUDASession


struct ChatTranscript:
    var fd: Int32

    def __init__(out self, path: String) raises:
        self.fd = -1
        if path != "":
            var bytes = List[Int8]()
            for byte in path.as_bytes():
                if byte == 0:
                    raise Error("Transcript path contains NUL")
                bytes.append(Int8(byte))
            bytes.append(0)
            self.fd = external_call["open64", Int32](bytes.unsafe_ptr(), Int32(193), Int32(384))
            _ = bytes
            if self.fd < 0:
                raise Error("Cannot create transcript; parent must exist and output must not exist: " + path)

    def emit(self, text: String) raises:
        print(text, end="")
        _ = external_call["fflush", Int32](Int(0))
        if self.fd >= 0:
            var bytes = text.as_bytes()
            var offset = 0
            while offset < len(bytes):
                var wrote = external_call["write", Int](Int(self.fd), bytes.unsafe_ptr().unsafe_offset(offset), len(bytes) - offset)
                if wrote <= 0:
                    raise Error("Transcript write failed")
                offset += wrote

    def flush(self) raises:
        if self.fd >= 0 and external_call["fsync", Int32](self.fd) != 0:
            raise Error("Transcript synchronization failed")

    def __deinit__(deinit self):
        if self.fd >= 0:
            _ = external_call["close", Int32](self.fd)


def chat_positive_int(text: String) raises -> Int:
    var result = 0
    if text.byte_length() == 0:
        raise Error("Chat option requires a positive integer")
    for byte in text.as_bytes():
        if byte < 48 or byte > 57 or result > 32768:
            raise Error("Invalid chat integer option")
        result = result * 10 + Int(byte - 48)
    if result <= 0 or result > 32768:
        raise Error("Chat integer option must be in 1..32768")
    return result


def read_chat_line() raises -> String:
    var bytes = List[Int8]()
    while True:
        var ch = external_call["getchar", Int32]()
        if ch < 0 or ch == 10:
            break
        if ch != 13:
            bytes.append(Int8(ch))
        if len(bytes) > 65536:
            raise Error("Chat input line exceeds 64 KiB")
    bytes.append(0)
    return String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())


def cuda_chat_turn(mut session: Gemma4CUDASession, prompt: String, system: String, max_tokens: Int, number: Int, transcript: ChatTranscript) raises:
    transcript.emit("\n## Turn " + String(number) + "\n\nUser: " + prompt + "\n\nAssistant: ")
    session.begin_turn(prompt, system, max_tokens)
    while session.generating:
        transcript.emit(session.next_chunk())
    transcript.emit("\n\n[turn=" + String(number) + " prompt_tokens=" + String(session.prompt_tokens) + " generated_tokens=" + String(session.generated_tokens) + " context_used=" + String(session.position) + " max_new_tokens=" + String(session.max_new_tokens) + " finish=" + session.finish_reason + " backend=cuda cpu_offload=0]\n")
    transcript.flush()


def dispatch_cuda_chat(args: List[String]) raises:
    if len(args) < 2:
        raise Error("usage: aesir chat <model.gguf> --accel cuda [--profile gemma4|llama3] [--prompts file] [--log file] [--max-tokens N] [--context N] [--system text]")
    var prompts_path = String("")
    var log_path = String("")
    var system = String("You are a helpful assistant. Keep answers concise and remember the conversation accurately.")
    var max_tokens = 16384
    var context_length = 32768
    var acceleration = String("")
    var profile = String("gemma4")
    var seen = List[String]()
    var i = 2
    while i < len(args):
        var flag = args[i]
        if i + 1 == len(args):
            raise Error("Missing chat option value: " + flag)
        for old in seen:
            if old == flag:
                raise Error("Duplicate chat option: " + flag)
        seen.append(flag)
        var value = args[i + 1]
        if flag == "--prompts":
            prompts_path = value
        elif flag == "--log":
            log_path = value
        elif flag == "--system":
            system = value
        elif flag == "--max-tokens":
            max_tokens = chat_positive_int(value)
        elif flag == "--context":
            context_length = chat_positive_int(value)
        elif flag == "--accel":
            acceleration = value
        elif flag == "--profile":
            profile = value
        else:
            raise Error("Unknown chat option: " + flag)
        i += 2
    if acceleration != "cuda":
        raise Error("Native chat requires explicit --accel cuda; CPU fallback is disabled")
    if profile != "gemma4" and profile != "llama3":
        raise Error("Unsupported CUDA chat profile")
    if profile == "llama3":
        if "--context" not in seen:
            context_length = 8192
        if "--max-tokens" not in seen:
            max_tokens = 8192
        if context_length > 8192 or max_tokens > 8192 or context_length < 2:
            raise Error("Llama 3 context and completion limits must be within 2..8192 and 1..8192")
    elif max_tokens >= context_length:
        raise Error("Chat context must leave room for input as well as max-tokens")
    var prompts = List[String]()
    if prompts_path != "":
        with open(prompts_path, "r") as source:
            var text = source.read()
            if text.byte_length() > 1048576:
                raise Error("Chat prompt file exceeds 1 MiB")
            for line in text.split("\n"):
                var prompt = String(line.strip())
                if prompt != "":
                    prompts.append(prompt)
        if len(prompts) == 0:
            raise Error("Chat prompt file has no turns")
    var transcript = ChatTranscript(log_path)
    if profile == "llama3":
        run_llama_chat(args[1], context_length, max_tokens, system, prompts, prompts_path != "", transcript)
        return
    transcript.emit("# Aesir native CUDA conversation\n\nModel: " + args[1] + "\n\nbackend=cuda; model=gemma4-E4B; layers=42/42; cpu_offload=0; context=" + String(context_length) + "; max_new_tokens=" + String(max_tokens) + "; sampling=greedy\n\nSystem: " + system + "\n")
    var session = Gemma4CUDASession(args[1], context_length)
    var turns = 0
    if prompts_path != "":
        for prompt in prompts:
            turns += 1
            cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
    else:
        print("Enter a message, or /bye to exit. Blank input/EOF ends the session.")
        while True:
            var prompt = read_chat_line()
            if prompt == "" or prompt == "/bye":
                break
            turns += 1
            cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
    transcript.emit("\nCompleted turns: " + String(turns) + "\n")
    transcript.flush()


def cuda_single_shot(path: String, prompt: String, max_tokens: Int) raises:
    var transcript = ChatTranscript("")
    var session = Gemma4CUDASession(path)
    cuda_chat_turn(session, prompt, "", max_tokens, 1, transcript)


def cuda_chat_turn(mut session: Llama3CUDASession, prompt: String, system: String, max_tokens: Int, number: Int, transcript: ChatTranscript) raises:
    transcript.emit("\n## Turn " + String(number) + "\n\nUser: " + prompt + "\n\nAssistant: ")
    session.begin_turn(prompt, system, max_tokens)
    while session.generating:
        transcript.emit(session.next_chunk())
    transcript.emit("\n\n[turn=" + String(number) + " prompt_tokens=" + String(session.prompt_tokens) + " generated_tokens=" + String(session.generated_tokens) + " context_used=" + String(session.position) + " max_new_tokens=" + String(session.max_new_tokens) + " finish=" + session.finish_reason + " backend=cuda cpu_offload=0]\n")
    transcript.flush()


def run_llama_chat(path: String, context_length: Int, max_tokens: Int, system: String, prompts: List[String], from_file: Bool, transcript: ChatTranscript) raises:
    # Emit the admitted backend claim only after model validation and upload.
    var session = Llama3CUDASession(path, context_length)
    transcript.emit("# Aesir native CUDA conversation\n\nModel: " + path + "\n\nbackend=cuda; model=llama3-8B; layers=32/32; cpu_offload=0; context=" + String(context_length) + "; max_new_tokens=" + String(max_tokens) + "; kv=f16; sampling=greedy\n\nSystem: " + system + "\n")
    var turns = 0
    if from_file:
        for prompt in prompts:
            turns += 1
            cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
    else:
        print("Enter a message, or /bye to exit. Blank input/EOF ends the session.")
        while True:
            var prompt = read_chat_line()
            if prompt == "" or prompt == "/bye":
                break
            turns += 1
            cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
    transcript.emit("\nCompleted turns: " + String(turns) + "\n")
    transcript.flush()
