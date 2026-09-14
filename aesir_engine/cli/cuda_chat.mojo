"""Native CUDA chat orchestration and durable, exclusive transcript output."""
from std.ffi import external_call
from std.collections import InlineArray
from aesir import Gemma4CUDASession, Llama3CUDASession, NativeModelPlan, choose_native_cuda_plan, NativeSamplingConfig, GenerationControl, bounded_decimal, monotonic_milliseconds
from cli.hardware import parse_device_index, parse_reserve_bytes
from cli.sampling import with_sampling_option, sampling_option_name
from cli.native_settings import resolve_native_settings, native_settings_json, load_native_config, native_config_sampling
from cli.interrupts import ChatInterrupts, consume_interrupts, read_interruptible_line
from cli.tui import AesirTUIDashboard
from cli.model_reference import resolve_model_reference
from cli.model_selector import choose_installed_model
from cli.storage import digest_open_fd
from core.inference_memory import gemma4_profile_memory_plan, llama3_memory_plan
from cli.conversation import (
    ConversationState,
    export_conversation,
    load_conversation,
    require_conversation_compatible,
    save_conversation,
)
from loader.packed_gguf import PackedGGUF
from core.model_registry import ModelArchitectureRegistry


struct ChatTranscript:
    var fd: Int32

    def __init__(out self, path: String, inherited_fd: Int = -1) raises:
        self.fd = -1
        if inherited_fd >= 0:
            var stat = InlineArray[UInt64, 18](fill=0)
            if external_call["fstat", Int32](Int32(inherited_fd), stat.unsafe_ptr()) != 0:
                raise Error("Cannot inspect resumed transcript descriptor")
            var mode = stat[3] & 4294967295
            var flags = external_call["fcntl", Int32](
                Int32(inherited_fd), Int32(3), Int64(0)
            )
            if (mode & 61440 != 32768
                    or stat[3] >> 32 != UInt64(external_call["geteuid", UInt32]())
                    or flags < 0 or flags & 3 == 0):
                raise Error("Resumed transcript must be an owner-held writable regular file")
            if external_call["lseek64", Int64](
                Int32(inherited_fd), Int64(0), Int32(2)
            ) < 0:
                raise Error("Cannot seek resumed transcript to its append position")
            self.fd = Int32(inherited_fd)
            return
        if path != "":
            if path.byte_length() >= 4096:
                raise Error("Transcript path must contain at most 4095 bytes")
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


struct ChatTurnResult(Copyable):
    var tokens_per_second: Float64
    var assistant: String

    def __init__(out self, tokens_per_second: Float64, assistant: String):
        self.tokens_per_second = tokens_per_second
        self.assistant = assistant

    def __copyinit__(out self, existing: Self):
        self.tokens_per_second = existing.tokens_per_second
        self.assistant = existing.assistant


struct ChatSwitchRequest(Copyable):
    var target: String
    var sampling: NativeSamplingConfig
    var timeout_ms: Int

    def __init__(
        out self, target: String, sampling: NativeSamplingConfig,
        timeout_ms: Int,
    ):
        self.target = target
        self.sampling = sampling
        self.timeout_ms = timeout_ms

    def __copyinit__(out self, existing: Self):
        self.target = existing.target
        self.sampling = existing.sampling
        self.timeout_ms = existing.timeout_ms


def requested_model_switch(
    command: String, current_path: String, model_store: String
) raises -> String:
    """Validates a switch target without allocating its CUDA session."""
    var target = parse_model_switch(command)
    var resolved = resolve_model_reference(target, model_store)
    if resolved.path == current_path:
        raise Error("Requested model is already loaded")
    # Reject unsupported/malformed recipe intent while the current session is
    # still alive. Context/reply combination depends on retained explicit flags
    # and is checked by the next outer launch, as is hardware fit.
    var retained_limits: List[String] = ["--context", "--max-tokens"]
    _ = resolve_native_settings(resolved.modelfile_content, NativeSamplingConfig(),
        retained_limits, 0, 0, "")
    var model = PackedGGUF(resolved.path)
    var compatibility = ModelArchitectureRegistry.inspect(model)
    if compatibility.status != "READY" or not compatibility.cuda_support:
        raise Error(compatibility.friendly_error())
    return target


def exec_chat_model_switch(
    target: String, model_store: String, device_index: Int,
    reserve_bytes: Int, requested_context: Int, requested_max_tokens: Int,
    system: String, sampling: NativeSamplingConfig, timeout_ms: Int,
    tui: Bool, transcript_fd: Int32,
) raises:
    """Replaces this process image so MAX CUDA starts from a clean runtime."""
    var arguments = List[String]()
    arguments.append("aesir")
    arguments.append("chat")
    arguments.append(target)
    arguments.append("--accel")
    arguments.append("cuda")
    arguments.append("--profile")
    arguments.append("auto")
    arguments.append("--device")
    arguments.append(String(device_index))
    arguments.append("--reserve-mib")
    arguments.append(String(reserve_bytes // 1048576))
    arguments.append("--model-store")
    arguments.append(model_store)
    arguments.append("--system")
    arguments.append(system)
    arguments.append("--temperature")
    arguments.append(String(sampling.temperature))
    arguments.append("--top-k")
    arguments.append(String(sampling.top_k))
    arguments.append("--top-p")
    arguments.append(String(sampling.top_p))
    arguments.append("--min-p")
    arguments.append(String(sampling.min_p))
    arguments.append("--repeat-penalty")
    arguments.append(String(sampling.repetition_penalty))
    arguments.append("--repeat-last-n")
    arguments.append(String(sampling.repeat_last_n))
    arguments.append("--seed")
    arguments.append(String(sampling.seed))
    arguments.append("--timeout-ms")
    arguments.append(String(timeout_ms))
    if requested_context > 0:
        arguments.append("--context")
        arguments.append(String(requested_context))
    if requested_max_tokens > 0:
        arguments.append("--max-tokens")
        arguments.append(String(requested_max_tokens))
    if tui:
        arguments.append("--tui")
    if transcript_fd >= 0:
        arguments.append("--resume-log-fd")
        arguments.append(String(transcript_fd))
    var bytes = List[List[Int8]]()
    for argument in arguments:
        var encoded = List[Int8]()
        for byte in argument.as_bytes():
            encoded.append(Int8(byte))
        encoded.append(0)
        bytes.append(encoded^)
    var pointers = List[Int]()
    for index in range(len(bytes)):
        pointers.append(Int(bytes[index].unsafe_ptr()))
    pointers.append(0)
    var executable = List[Int8]()
    for byte in String("/proc/self/exe").as_bytes():
        executable.append(Int8(byte))
    executable.append(0)
    _ = external_call["execv", Int32](
        executable.unsafe_ptr(), pointers.unsafe_ptr()
    )
    _ = bytes
    _ = executable
    raise Error("Unable to replace the CUDA runtime for model switching")


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


def default_chat_max_tokens(profile: String, variant: String,
                            context_length: Int) raises -> Int:
    """Keeps at least half of an automatic context available for prompt/history."""
    if context_length < 2:
        raise Error("Chat context must contain at least two tokens")
    var family_cap = 4096
    if profile == "gemma4" and variant != "gemma4-E2B":
        family_cap = 16384
    return min(family_cap, context_length // 2)


def read_chat_line(interrupt_fd: Int = -1) raises -> String:
    return read_interruptible_line(interrupt_fd)


def cuda_chat_turn(mut session: Gemma4CUDASession, prompt: String, system: String, max_tokens: Int, number: Int, transcript: ChatTranscript) raises -> ChatTurnResult:
    session.begin_turn(prompt, system, max_tokens)
    var started_at = monotonic_milliseconds()
    transcript.emit("\n## Turn " + String(number) + "\n\nUser: " + prompt + "\n\nAssistant: ")
    var assistant = String("")
    while session.generating:
        var chunk = session.next_chunk()
        assistant += chunk
        transcript.emit(chunk)
    transcript.emit("\n\n[turn=" + String(number) + " prompt_tokens=" + String(session.prompt_tokens) + " generated_tokens=" + String(session.generated_tokens) + " context_used=" + String(session.position) + " max_new_tokens=" + String(session.max_new_tokens) + " finish=" + session.finish_reason + " backend=cuda cpu_offload=0]\n")
    transcript.flush()
    var elapsed_ms = monotonic_milliseconds() - started_at
    if elapsed_ms < 1:
        elapsed_ms = 1
    return ChatTurnResult(
        Float64(session.generated_tokens) * 1000.0 / Float64(elapsed_ms),
        assistant,
    )


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
    var show_settings = False
    var config_path = String("")
    var model_store = String(".aesir/models")
    var inherited_log_fd = -1
    var seen = List[String]()
    var i = 1
    if i < len(args) and not args[i].startswith("-"):
        model_reference = args[i]
        i += 1
    while i < len(args):
        var flag = args[i]
        if flag == "-c":
            flag = "--config"
        for old in seen:
            if old == flag:
                raise Error("Duplicate chat option: " + flag)
        seen.append(flag)
        if flag == "--tui":
            tui = True
            i += 1
            continue
        if flag == "--show-settings":
            show_settings = True
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
        elif flag == "--config":
            config_path = value
        elif flag == "--resume-log-fd":
            inherited_log_fd = bounded_decimal(value)
            if inherited_log_fd < 3:
                raise Error("Internal resumed log descriptor is invalid")
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
    var config = load_native_config(config_path, seen)
    var config_sampling = native_config_sampling(config)
    if "--config" in seen:
        model_store = config.model_store_path
    if show_settings:
        if model_reference == "":
            raise Error("Settings preview requires an explicit model reference")
        var resolved = resolve_model_reference(model_reference, model_store)
        print(native_settings_json(resolve_native_settings(resolved.modelfile_content,
            sampling, seen, context_length, max_tokens, system, config_sampling)))
        return
    var interrupts = ChatInterrupts()
    var interrupt_fd = interrupts.fd
    if model_reference == "":
        model_reference = choose_installed_model(model_store, interrupt_fd)
    var requested_context = context_length if "--context" in seen else 0
    var requested_max_tokens = max_tokens if "--max-tokens" in seen else 0
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
    if inherited_log_fd >= 0 and log_path != "":
        raise Error("Internal resumed log descriptor conflicts with --log")
    var transcript = ChatTranscript(log_path, inherited_log_fd)
    var selection_profile = profile
    while True:
        var resolved = resolve_model_reference(model_reference, model_store)
        var effective = resolve_native_settings(resolved.modelfile_content,
            sampling, seen, requested_context, requested_max_tokens, system, config_sampling)
        var selection = choose_native_cuda_plan(
            resolved.path, selection_profile, effective.context,
            device_index, reserve_bytes,
        )
        var detected = selection.plan.copy()
        device_index = selection.device_index
        context_length = detected.context_length
        max_tokens = effective.max_tokens
        if effective.max_tokens == 0:
            max_tokens = default_chat_max_tokens(
                detected.profile, detected.variant, context_length
            )
        if detected.profile == "llama3":
            if context_length > 8192 or max_tokens >= context_length or context_length < 2:
                raise Error("Llama 3 context must leave room for input and completion")
        elif detected.profile == "qwen3":
            if context_length > 32768 or max_tokens >= context_length or context_length < 2:
                raise Error("Qwen 3 context must leave room for input and completion")
        elif max_tokens >= context_length:
            raise Error("Chat context must leave room for input as well as max-tokens")

        var switch: ChatSwitchRequest
        if detected.profile == "llama3" or detected.profile == "qwen3":
            switch = run_llama_chat(
                resolved.path, context_length, max_tokens, effective.system, prompts,
                prompts_path != "", transcript, device_index, reserve_bytes,
                effective.sampling, interrupt_fd, timeout_ms, tui, resolved.digest,
                resolved.requested, model_store,
            )
        else:
            switch = run_gemma_chat(
                resolved.path, context_length, max_tokens, effective.system, prompts,
                prompts_path != "", transcript, device_index, reserve_bytes,
                effective.sampling, interrupt_fd, timeout_ms, tui, resolved.digest,
                resolved.requested, model_store,
            )
        if switch.target == "":
            break
        transcript.emit("\n[previous model unloaded; switching to " + switch.target + "]\n")
        transcript.flush()
        exec_chat_model_switch(
            switch.target, model_store, device_index, reserve_bytes,
            requested_context, requested_max_tokens, effective.system, switch.sampling,
            switch.timeout_ms, tui, transcript.fd,
        )
    _ = interrupts


def run_gemma_chat(
    model_path: String, context_length: Int, max_tokens: Int, system: String,
    prompts: List[String], from_file: Bool, transcript: ChatTranscript,
    device_index: Int, reserve_bytes: Int, sampling: NativeSamplingConfig,
    interrupt_fd: Int, timeout_ms: Int, tui: Bool, known_digest: String,
    model_label: String, model_store: String,
) raises -> ChatSwitchRequest:
    var session = Gemma4CUDASession(model_path, context_length, device_index, reserve_bytes, sampling)
    session.configure_control(timeout_ms, interrupt_fd)
    var conversation_identity = known_digest
    if conversation_identity == "":
        conversation_identity = "path:" + model_path
    var conversation = ConversationState(
        conversation_identity, "gemma4", context_length, system,
        session.sampler.config.description(),
    )
    transcript.emit("# Aesir native CUDA conversation\n\nModel: " + model_label + "\n\nbackend=cuda; model=gemma4-" + session.profile.name + "; layers=" + String(session.profile.layer_count) + "/" + String(session.profile.layer_count) + "; cpu_offload=0; context=" + String(context_length) + "; max_new_tokens=" + String(max_tokens) + "; sampling=" + sampling.description() + "; timeout_ms=" + String(timeout_ms) + "\n\nSystem: " + system + "\n")
    var dashboard = AesirTUIDashboard()
    if tui:
        render_tui(dashboard, session, model_label, 0.0, transcript)
    var turns = 0
    if from_file:
        for prompt in prompts:
            turns += 1
            var result = cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
            conversation.append_turn(prompt, result.assistant)
            if tui:
                render_tui(dashboard, session, model_label, result.tokens_per_second, transcript)
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
                    if prompt.startswith("/model"):
                        var next_model = requested_model_switch(
                            prompt, model_path, model_store
                        )
                        transcript.emit("\n[model switch requested: " + next_model + "; conversation will reset]\n")
                        transcript.emit("\nCompleted turns: " + String(turns) + "\n")
                        transcript.flush()
                        return ChatSwitchRequest(
                            next_model, session.sampler.config,
                            session.control.timeout_ms,
                        )
                    chat_control(session, prompt, transcript, conversation)
                except error:
                    if not session.healthy:
                        raise
                    transcript.emit("\n[control rejected: " + String(error) + "]\n")
                continue
            try:
                var result = cuda_chat_turn(session, prompt, system, max_tokens, len(conversation.turns) + 1, transcript)
                conversation.append_turn(prompt, result.assistant)
                turns += 1
                if tui:
                    render_tui(dashboard, session, model_label, result.tokens_per_second, transcript)
            except error:
                if not session.healthy or session.generating:
                    raise
                transcript.emit("\n[turn rejected: " + String(error) + "]\n")
            _ = consume_interrupts(interrupt_fd)
    transcript.emit("\nCompleted turns: " + String(turns) + "\n")
    transcript.flush()
    return ChatSwitchRequest(
        "", session.sampler.config, session.control.timeout_ms
    )


def cuda_single_shot(path: String, prompt: String, max_tokens: Int) raises:
    var transcript = ChatTranscript("")
    var selection = choose_native_cuda_plan(path)
    var plan = selection.plan.copy()
    var device_index = selection.device_index
    if plan.profile == "llama3" or plan.profile == "qwen3":
        var session = Llama3CUDASession(path, plan.context_length, device_index)
        _ = cuda_chat_turn(session, prompt, "", max_tokens, 1, transcript)
    else:
        var session = Gemma4CUDASession(path, plan.context_length, device_index)
        _ = cuda_chat_turn(session, prompt, "", max_tokens, 1, transcript)


def cuda_chat_turn(mut session: Llama3CUDASession, prompt: String, system: String, max_tokens: Int, number: Int, transcript: ChatTranscript) raises -> ChatTurnResult:
    session.begin_turn(prompt, system, max_tokens)
    var started_at = monotonic_milliseconds()
    transcript.emit("\n## Turn " + String(number) + "\n\nUser: " + prompt + "\n\nAssistant: ")
    var assistant = String("")
    while session.generating:
        var chunk = session.next_chunk()
        assistant += chunk
        transcript.emit(chunk)
    transcript.emit("\n\n[turn=" + String(number) + " prompt_tokens=" + String(session.prompt_tokens) + " generated_tokens=" + String(session.generated_tokens) + " context_used=" + String(session.position) + " max_new_tokens=" + String(session.max_new_tokens) + " finish=" + session.finish_reason + " backend=cuda cpu_offload=0]\n")
    transcript.flush()
    var elapsed_ms = monotonic_milliseconds() - started_at
    if elapsed_ms < 1:
        elapsed_ms = 1
    return ChatTurnResult(
        Float64(session.generated_tokens) * 1000.0 / Float64(elapsed_ms),
        assistant,
    )


def render_tui(mut dashboard: AesirTUIDashboard, session: Llama3CUDASession, model: String, speed: Float64, transcript: ChatTranscript) raises:
    var memory = llama3_memory_plan(Int(session.model.source.file_size), session.context_length, session.profile)
    dashboard.update_observation(
        model, session.profile.label() + " / CUDA", Float64(memory.device_bytes) / 1048576.0,
        speed, 1, "native explicit buffers + session counters", monotonic_milliseconds(), session.position, session.context_length,
    )
    transcript.emit("\n" + dashboard.render_frame())


def run_llama_chat(
    path: String, context_length: Int, max_tokens: Int, system: String,
    prompts: List[String], from_file: Bool, transcript: ChatTranscript,
    device_index: Int = 0, reserve_bytes: Int = 268435456,
    sampling: NativeSamplingConfig = NativeSamplingConfig(),
    interrupt_fd: Int = -1, timeout_ms: Int = 0, tui: Bool = False,
    known_digest: String = String(""), model_label: String = String(""),
    model_store: String = String(".aesir/models"),
) raises -> ChatSwitchRequest:
    # Emit the admitted backend claim only after model validation and upload.
    var session = Llama3CUDASession(path, context_length, device_index, reserve_bytes, sampling)
    session.configure_control(timeout_ms, interrupt_fd)
    var conversation_identity = known_digest
    if conversation_identity == "":
        conversation_identity = "path:" + path
    var conversation = ConversationState(
        conversation_identity, session.profile.architecture, context_length, system,
        session.sampler.config.description(),
    )
    var display_model = model_label if model_label != "" else path
    transcript.emit("# Aesir native CUDA conversation\n\nModel: " + display_model + "\n\nbackend=cuda; model=" + session.profile.architecture + "-" + session.profile.name + "; layers=" + String(session.profile.layer_count) + "/" + String(session.profile.layer_count) + "; cpu_offload=0; context=" + String(context_length) + "; max_new_tokens=" + String(max_tokens) + "; kv=f16; sampling=" + sampling.description() + "; timeout_ms=" + String(timeout_ms) + "\n\nSystem: " + system + "\n")
    var dashboard = AesirTUIDashboard()
    if tui:
        render_tui(dashboard, session, display_model, 0.0, transcript)
    var turns = 0
    if from_file:
        for prompt in prompts:
            turns += 1
            var result = cuda_chat_turn(session, prompt, system, max_tokens, turns, transcript)
            conversation.append_turn(prompt, result.assistant)
            if tui:
                render_tui(dashboard, session, display_model, result.tokens_per_second, transcript)
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
                    if prompt.startswith("/model"):
                        var next_model = requested_model_switch(
                            prompt, path, model_store
                        )
                        transcript.emit("\n[model switch requested: " + next_model + "; conversation will reset]\n")
                        transcript.emit("\nCompleted turns: " + String(turns) + "\n")
                        transcript.flush()
                        return ChatSwitchRequest(
                            next_model, session.sampler.config,
                            session.control.timeout_ms,
                        )
                    chat_control(session, prompt, transcript, conversation)
                except error:
                    if not session.healthy:
                        raise
                    transcript.emit("\n[control rejected: " + String(error) + "]\n")
                continue
            try:
                var result = cuda_chat_turn(session, prompt, system, max_tokens, len(conversation.turns) + 1, transcript)
                conversation.append_turn(prompt, result.assistant)
                turns += 1
                if tui:
                    render_tui(dashboard, session, display_model, result.tokens_per_second, transcript)
            except error:
                if not session.healthy or session.generating:
                    raise
                transcript.emit("\n[turn rejected: " + String(error) + "]\n")
            _ = consume_interrupts(interrupt_fd)
    transcript.emit("\nCompleted turns: " + String(turns) + "\n")
    transcript.flush()
    return ChatSwitchRequest(
        "", session.sampler.config, session.control.timeout_ms
    )


def _chat_command_path(command: String, prefix: String) raises -> String:
    if not command.startswith(prefix + " "):
        raise Error("Usage: " + prefix + " <new-path>")
    var path = String(command[byte=len(prefix.bytes()) + 1:]).strip()
    if path == "":
        raise Error("Usage: " + prefix + " <new-path>")
    return String(path)


def parse_model_switch(command: String) raises -> String:
    return _chat_command_path(command, "/model")


def chat_control(mut session: Gemma4CUDASession, command: String, transcript: ChatTranscript, mut conversation: ConversationState) raises:
    if command == "/show":
        transcript.emit("\n[context_used=" + String(session.position) + "; context_limit=" + String(session.context_length) + "; turns=" + String(len(conversation.turns)) + "; timeout_ms=" + String(session.control.timeout_ms) + "; reset_required=" + String(session.reset_required) + "; sampling=" + session.sampler.config.description() + "]\n")
    elif command == "/clear" or command == "/new":
        session.reset()
        conversation.clear()
        transcript.emit("\n[conversation cleared; context/history/seed sequence reset; model remains loaded]\n")
    elif command == "/help":
        transcript.emit("\n/help /show /clear /new /bye; /model <name-or-alias>; /save <new-file> /load <file> /export <new-markdown>; /set <temperature|top-k|top-p|min-p|repeat-penalty|seed|timeout-ms> <value>. Repetition window is fixed at session creation.\n")
    elif command.startswith("/save"):
        var path = _chat_command_path(command, "/save")
        conversation.model_identity = digest_open_fd(session.model.source.fd)
        conversation.tokens = session.conversation_tokens()
        conversation.sampler_draws = Int(session.sampler.draws)
        conversation.sampling_identity = session.sampler.config.description()
        save_conversation(path, conversation)
        transcript.emit("\n[conversation saved: " + path + "]\n")
    elif command.startswith("/load"):
        var path = _chat_command_path(command, "/load")
        var loaded = load_conversation(path)
        conversation.model_identity = digest_open_fd(session.model.source.fd)
        conversation.sampling_identity = session.sampler.config.description()
        require_conversation_compatible(loaded, conversation)
        session.reset()
        session.restore_conversation(loaded.tokens, loaded.sampler_draws)
        conversation = loaded^
        transcript.emit("\n[conversation loaded: " + path + "; turns=" + String(len(conversation.turns)) + "; context_used=" + String(session.position) + "]\n")
    elif command.startswith("/export"):
        var path = _chat_command_path(command, "/export")
        export_conversation(path, conversation)
        transcript.emit("\n[conversation exported: " + path + "]\n")
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
        conversation.sampling_identity = session.sampler.config.description()
        transcript.emit("\n[sampling=" + session.sampler.config.description() + "]\n")
    else:
        raise Error("Unknown chat command; use /help")
    transcript.flush()


def chat_control(mut session: Llama3CUDASession, command: String, transcript: ChatTranscript, mut conversation: ConversationState) raises:
    if command == "/show":
        transcript.emit("\n[context_used=" + String(session.position) + "; context_limit=" + String(session.context_length) + "; turns=" + String(len(conversation.turns)) + "; timeout_ms=" + String(session.control.timeout_ms) + "; reset_required=" + String(session.reset_required) + "; sampling=" + session.sampler.config.description() + "]\n")
    elif command == "/clear" or command == "/new":
        session.reset()
        conversation.clear()
        transcript.emit("\n[conversation cleared; context/history/seed sequence reset; model remains loaded]\n")
    elif command == "/help":
        transcript.emit("\n/help /show /clear /new /bye; /model <name-or-alias>; /save <new-file> /load <file> /export <new-markdown>; /set <temperature|top-k|top-p|min-p|repeat-penalty|seed|timeout-ms> <value>. Repetition window is fixed at session creation.\n")
    elif command.startswith("/save"):
        var path = _chat_command_path(command, "/save")
        conversation.model_identity = digest_open_fd(session.model.source.fd)
        conversation.tokens = session.conversation_tokens()
        conversation.sampler_draws = Int(session.sampler.draws)
        conversation.sampling_identity = session.sampler.config.description()
        save_conversation(path, conversation)
        transcript.emit("\n[conversation saved: " + path + "]\n")
    elif command.startswith("/load"):
        var path = _chat_command_path(command, "/load")
        var loaded = load_conversation(path)
        conversation.model_identity = digest_open_fd(session.model.source.fd)
        conversation.sampling_identity = session.sampler.config.description()
        require_conversation_compatible(loaded, conversation)
        session.reset()
        session.restore_conversation(loaded.tokens, loaded.sampler_draws)
        conversation = loaded^
        transcript.emit("\n[conversation loaded: " + path + "; turns=" + String(len(conversation.turns)) + "; context_used=" + String(session.position) + "]\n")
    elif command.startswith("/export"):
        var path = _chat_command_path(command, "/export")
        export_conversation(path, conversation)
        transcript.emit("\n[conversation exported: " + path + "]\n")
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
        conversation.sampling_identity = session.sampler.config.description()
        transcript.emit("\n[sampling=" + session.sampler.config.description() + "]\n")
    else:
        raise Error("Unknown chat command; use /help")
    transcript.flush()
