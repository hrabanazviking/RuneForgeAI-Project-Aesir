"""Native CUDA chat orchestration and durable, exclusive transcript output."""
from std.ffi import external_call
from aesir import Gemma4CUDASession, Llama3CUDASession, NativeModelPlan, choose_native_cuda, NativeSamplingConfig, GenerationControl, bounded_decimal, monotonic_milliseconds
from cli.hardware import parse_device_index, parse_reserve_bytes
from cli.sampling import with_sampling_option, sampling_option_name
from cli.interrupts import ChatInterrupts, consume_interrupts, read_interruptible_line
from cli.tui import AesirTUIDashboard
from cli.model_reference import resolve_model_reference
from cli.model_selector import choose_installed_model
from core.inference_memory import gemma4_profile_memory_plan, llama3_memory_plan


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


def read_chat_line(interrupt_fd: Int = -1) raises -> String:
    return read_interruptible_line(interrupt_fd)


def cuda_chat_turn(mut session: Gemma4CUDASession, prompt: String, system: String, max_tokens: Int, number: Int, transcript: ChatTranscript) raises -> Float64:
    session.begin_turn(prompt, system, max_tokens)
    var started_at = monotonic_milliseconds()
    transcript.emit("\n## Turn " + String(number) + "\n\nUser: " + prompt + "\n\nAssistant: ")
    while session.generating:
        transcript.emit(session.next_chunk())
    transcript.emit("\n\n[turn=" + String(number) + " prompt_tokens=" + String(session.prompt_tokens) + " generated_tokens=" + String(session.generated_tokens) + " context_used=" + String(session.position) + " max_new_tokens=" + String(session.max_new_tokens) + " finish=" + session.finish_reason + " backend=cuda cpu_offload=0]\n")
    transcript.flush()
    var elapsed_ms = monotonic_milliseconds() - started_at
    if elapsed_ms < 1:
        elapsed_ms = 1
    return Float64(session.generated_tokens) * 1000.0 / Float64(elapsed_ms)


def render_tui(mut dashboard: AesirTUIDashboard, session: Gemma4CUDASession, model: String, speed: Float64, transcript: ChatTranscript) raises:
    var memory = gemma4_profile_memory_plan(Int(session.model.source.file_size), session.context_length, session.profile)
    dashboard.update_observation(
        model, "Gemma 4 " + session.profile.name + " / CUDA", Float64(memory.device_bytes) / 1048576.0,
        speed, 1, "native explicit buffers + session counters", monotonic_milliseconds(), session.position, session.context_length,
    )
    transcript.emit("\n" + dashboard.render_frame())


def dispatch_cuda_chat(args: List[String]) raises:
    var model_reference = String("")
    var prompts_path = String("")
    var log_path = String("")
    var system = String("You are a helpful assistant. Keep answers concise and remember the conversation accurately.")
    var max_tokens = 0
    var context_length = 0
    var acceleration = String("")
    var profile = String("auto")
    var device_index = -1
    var reserve_bytes = 268435456
    var sampling = NativeSamplingConfig()
    var timeout_ms = 0
    var tui = False
    var model_store = String(".aesir/models")
    var seen = List[String]()
    var i = 1
    if i < len(args) and not args[i].startswith("-"):
        model_reference = args[i]
        i += 1
    while i < len(args):
        var flag = args[i]
        for old in seen:
            if old == flag:
                raise Error("Duplicate chat option: " + flag)
        seen.append(flag)
        if flag == "--tui":
            tui = True
            i += 1
            continue
        if i + 1 == len(args):
            raise Error("Missing chat option value: " + flag)
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
        elif flag == "--timeout-ms":
            timeout_ms = bounded_decimal(value)
            _ = GenerationControl(timeout_ms)
        elif flag == "--accel":
            acceleration = value
        elif flag == "--profile":
            profile = value
        elif flag == "--device":
            device_index = parse_device_index(value)
        elif flag == "--reserve-mib":
            reserve_bytes = parse_reserve_bytes(value)
        elif flag == "--model-store":
            model_store = value
        elif sampling_option_name(flag) != "":
            sampling = with_sampling_option(sampling, sampling_option_name(flag), value)
        else:
            raise Error("Unknown chat option: " + flag)
        i += 2
    sampling.validate()
    if acceleration != "cuda":
        raise Error("Native chat requires explicit --accel cuda; CPU fallback is disabled")
    if profile != "gemma4" and profile != "llama3" and profile != "qwen3" and profile != "auto":
        raise Error("Unsupported CUDA chat profile")
    if "--context" in seen and "--max-tokens" in seen and max_tokens >= context_length:
        raise Error("Chat context must leave room for input as well as max-tokens")
    if profile == "llama3":
        if "--context" in seen and (context_length < 2 or context_length > 8192):
            raise Error("Llama 3 context must be within 2..8192")
        if "--max-tokens" in seen and max_tokens > 8192:
            raise Error("Llama 3 completion limit must be within 1..8192")
    elif profile == "qwen3":
        if "--context" in seen and (context_length < 2 or context_length > 32768):
            raise Error("Qwen 3 context must be within 2..32768")
        if "--max-tokens" in seen and max_tokens > 32768:
            raise Error("Qwen 3 completion limit must be within 1..32768")
    var interrupts = ChatInterrupts()
    var interrupt_fd = interrupts.fd
    if model_reference == "":
        model_reference = choose_installed_model(model_store, interrupt_fd)
    var resolved = resolve_model_reference(model_reference, model_store)
    var model_path = resolved.path
    var requested_context = context_length if "--context" in seen else 0
    var detected = NativeModelPlan(model_path, profile, requested_context)
    profile = detected.profile
    context_length = detected.context_length
    if profile == "llama3":
        if "--max-tokens" not in seen:
            max_tokens = 8192
        if context_length > 8192 or max_tokens > 8192 or context_length < 2:
            raise Error("Llama 3 context and completion limits must be within 2..8192 and 1..8192")
    elif profile == "qwen3":
        if "--max-tokens" not in seen:
            max_tokens = min(4096, context_length - 1)
        if context_length > 32768 or max_tokens >= context_length or context_length < 2:
            raise Error("Qwen 3 context must leave room for input and completion")
    else:
        if "--max-tokens" not in seen:
            max_tokens = 4096 if detected.variant == "gemma4-E2B" else 16384
        if max_tokens >= context_length:
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
    var plan = NativeModelPlan(model_path, profile, context_length)
    device_index = choose_native_cuda(plan.memory, device_index, reserve_bytes)
    var transcript = ChatTranscript(log_path)
    if profile == "llama3" or profile == "qwen3":
        run_llama_chat(model_path, context_length, max_tokens, system, prompts, prompts_path != "", transcript, device_index, reserve_bytes, sampling, interrupt_fd, timeout_ms, tui)
        _ = interrupts
        return
    var session = Gemma4CUDASession(model_path, context_length, device_index, reserve_bytes, sampling)
    session.configure_control(timeout_ms, interrupt_fd)
    transcript.emit("# Aesir native CUDA conversation\n\nModel: " + resolved.requested + "\n\nbackend=cuda; model=gemma4-" + session.profile.name + "; layers=" + String(session.profile.layer_count) + "/" + String(session.profile.layer_count) + "; cpu_offload=0; context=" + String(context_length) + "; max_new_tokens=" + String(max_tokens) + "; sampling=" + sampling.description() + "; timeout_ms=" + String(timeout_ms) + "\n\nSystem: " + system + "\n")
    var dashboard = AesirTUIDashboard()
    if tui:
        render_tui(dashboard, session, resolved.requested, 0.0, transcript)
    var turns = 0
    if prompts_path != "":
        for prompt in prompts:
            turns += 1
            var speed = cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
            if tui:
                render_tui(dashboard, session, resolved.requested, speed, transcript)
            if consume_interrupts(interrupt_fd):
                break
    else:
        print("Enter a message; /help lists chat controls. Blank input/EOF ends the session.")
        _ = external_call["fflush", Int32](Int(0))
        while True:
            print("You> ", end="")
            _ = external_call["fflush", Int32](Int(0))
            var prompt = read_chat_line(interrupt_fd)
            if prompt == "" or prompt == "/bye":
                break
            if prompt.startswith("/"):
                try:
                    chat_control(session, prompt, transcript)
                except error:
                    if not session.healthy:
                        raise
                    transcript.emit("\n[control rejected: " + String(error) + "]\n")
                continue
            try:
                var speed = cuda_chat_turn(session, prompt, system, max_tokens, turns + 1, transcript)
                turns += 1
                if tui:
                    render_tui(dashboard, session, resolved.requested, speed, transcript)
            except error:
                if not session.healthy or session.generating:
                    raise
                transcript.emit("\n[turn rejected: " + String(error) + "]\n")
            _ = consume_interrupts(interrupt_fd)
    transcript.emit("\nCompleted turns: " + String(turns) + "\n")
    transcript.flush()
    _ = interrupts


def cuda_single_shot(path: String, prompt: String, max_tokens: Int) raises:
    var transcript = ChatTranscript("")
    var plan = NativeModelPlan(path)
    var device_index = choose_native_cuda(plan.memory)
    if plan.profile == "llama3" or plan.profile == "qwen3":
        var session = Llama3CUDASession(path, plan.context_length, device_index)
        _ = cuda_chat_turn(session, prompt, "", max_tokens, 1, transcript)
    else:
        var session = Gemma4CUDASession(path, plan.context_length, device_index)
        _ = cuda_chat_turn(session, prompt, "", max_tokens, 1, transcript)


def cuda_chat_turn(mut session: Llama3CUDASession, prompt: String, system: String, max_tokens: Int, number: Int, transcript: ChatTranscript) raises -> Float64:
    session.begin_turn(prompt, system, max_tokens)
    var started_at = monotonic_milliseconds()
    transcript.emit("\n## Turn " + String(number) + "\n\nUser: " + prompt + "\n\nAssistant: ")
    while session.generating:
        transcript.emit(session.next_chunk())
    transcript.emit("\n\n[turn=" + String(number) + " prompt_tokens=" + String(session.prompt_tokens) + " generated_tokens=" + String(session.generated_tokens) + " context_used=" + String(session.position) + " max_new_tokens=" + String(session.max_new_tokens) + " finish=" + session.finish_reason + " backend=cuda cpu_offload=0]\n")
    transcript.flush()
    var elapsed_ms = monotonic_milliseconds() - started_at
    if elapsed_ms < 1:
        elapsed_ms = 1
    return Float64(session.generated_tokens) * 1000.0 / Float64(elapsed_ms)


def render_tui(mut dashboard: AesirTUIDashboard, session: Llama3CUDASession, model: String, speed: Float64, transcript: ChatTranscript) raises:
    var memory = llama3_memory_plan(Int(session.model.source.file_size), session.context_length, session.profile)
    dashboard.update_observation(
        model, session.profile.label() + " / CUDA", Float64(memory.device_bytes) / 1048576.0,
        speed, 1, "native explicit buffers + session counters", monotonic_milliseconds(), session.position, session.context_length,
    )
    transcript.emit("\n" + dashboard.render_frame())


def run_llama_chat(path: String, context_length: Int, max_tokens: Int, system: String, prompts: List[String], from_file: Bool, transcript: ChatTranscript, device_index: Int = 0, reserve_bytes: Int = 268435456, sampling: NativeSamplingConfig = NativeSamplingConfig(), interrupt_fd: Int = -1, timeout_ms: Int = 0, tui: Bool = False) raises:
    # Emit the admitted backend claim only after model validation and upload.
    var session = Llama3CUDASession(path, context_length, device_index, reserve_bytes, sampling)
    session.configure_control(timeout_ms, interrupt_fd)
    transcript.emit("# Aesir native CUDA conversation\n\nModel: " + path + "\n\nbackend=cuda; model=" + session.profile.architecture + "-" + session.profile.name + "; layers=" + String(session.profile.layer_count) + "/" + String(session.profile.layer_count) + "; cpu_offload=0; context=" + String(context_length) + "; max_new_tokens=" + String(max_tokens) + "; kv=f16; sampling=" + sampling.description() + "; timeout_ms=" + String(timeout_ms) + "\n\nSystem: " + system + "\n")
    var dashboard = AesirTUIDashboard()
    if tui:
        render_tui(dashboard, session, path, 0.0, transcript)
    var turns = 0
    if from_file:
        for prompt in prompts:
            turns += 1
            var speed = cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
            if tui:
                render_tui(dashboard, session, path, speed, transcript)
            if consume_interrupts(interrupt_fd):
                break
    else:
        print("Enter a message; /help lists chat controls. Blank input/EOF ends the session.")
        _ = external_call["fflush", Int32](Int(0))
        while True:
            print("You> ", end="")
            _ = external_call["fflush", Int32](Int(0))
            var prompt = read_chat_line(interrupt_fd)
            if prompt == "" or prompt == "/bye":
                break
            if prompt.startswith("/"):
                try:
                    chat_control(session, prompt, transcript)
                except error:
                    if not session.healthy:
                        raise
                    transcript.emit("\n[control rejected: " + String(error) + "]\n")
                continue
            try:
                var speed = cuda_chat_turn(session, prompt, system, max_tokens, turns + 1, transcript)
                turns += 1
                if tui:
                    render_tui(dashboard, session, path, speed, transcript)
            except error:
                if not session.healthy or session.generating:
                    raise
                transcript.emit("\n[turn rejected: " + String(error) + "]\n")
            _ = consume_interrupts(interrupt_fd)
    transcript.emit("\nCompleted turns: " + String(turns) + "\n")
    transcript.flush()


def chat_control(mut session: Gemma4CUDASession, command: String, transcript: ChatTranscript) raises:
    if command == "/show":
        transcript.emit("\n[context_used=" + String(session.position) + "; context_limit=" + String(session.context_length) + "; timeout_ms=" + String(session.control.timeout_ms) + "; reset_required=" + String(session.reset_required) + "; sampling=" + session.sampler.config.description() + "]\n")
    elif command == "/clear":
        session.reset()
        transcript.emit("\n[conversation cleared; context/history/seed sequence reset; model remains loaded]\n")
    elif command == "/help":
        transcript.emit("\n/help /show /clear /bye; /set <temperature|top-k|top-p|min-p|repeat-penalty|seed|timeout-ms> <value>. Repetition window is fixed at session creation.\n")
    elif command.startswith("/set "):
        var words = command.split(" ")
        if len(words) != 3:
            raise Error("Usage: /set <sampling-setting> <value>")
        if String(words[1]) == "timeout-ms":
            session.configure_control(bounded_decimal(String(words[2])), session.control.cancel_fd)
            transcript.emit("\n[timeout_ms=" + String(session.control.timeout_ms) + "]\n")
            transcript.flush()
            return
        var config = with_sampling_option(session.sampler.config, String(words[1]), String(words[2]))
        session.configure_sampling(config)
        transcript.emit("\n[sampling=" + session.sampler.config.description() + "]\n")
    else:
        raise Error("Unknown chat command; use /help")
    transcript.flush()


def chat_control(mut session: Llama3CUDASession, command: String, transcript: ChatTranscript) raises:
    if command == "/show":
        transcript.emit("\n[context_used=" + String(session.position) + "; context_limit=" + String(session.context_length) + "; timeout_ms=" + String(session.control.timeout_ms) + "; reset_required=" + String(session.reset_required) + "; sampling=" + session.sampler.config.description() + "]\n")
    elif command == "/clear":
        session.reset()
        transcript.emit("\n[conversation cleared; context/history/seed sequence reset; model remains loaded]\n")
    elif command == "/help":
        transcript.emit("\n/help /show /clear /bye; /set <temperature|top-k|top-p|min-p|repeat-penalty|seed|timeout-ms> <value>. Repetition window is fixed at session creation.\n")
    elif command.startswith("/set "):
        var words = command.split(" ")
        if len(words) != 3:
            raise Error("Usage: /set <sampling-setting> <value>")
        if String(words[1]) == "timeout-ms":
            session.configure_control(bounded_decimal(String(words[2])), session.control.cancel_fd)
            transcript.emit("\n[timeout_ms=" + String(session.control.timeout_ms) + "]\n")
            transcript.flush()
            return
        var config = with_sampling_option(session.sampler.config, String(words[1]), String(words[2]))
        session.configure_sampling(config)
        transcript.emit("\n[sampling=" + session.sampler.config.description() + "]\n")
    else:
        raise Error("Unknown chat command; use /help")
    transcript.flush()
