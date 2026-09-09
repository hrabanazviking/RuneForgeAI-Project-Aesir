"""Native loopback HTTP orchestration over the serialized CUDA contract."""
from std.ffi import external_call
from aesir import (Gemma4CUDASession, Llama3CUDASession, NativeModelPlan,
                   NativeSamplingConfig, ControlledTextSession, GenerationControl,
                   choose_native_cuda, bounded_decimal, monotonic_milliseconds)
from cli.hardware import parse_device_index, parse_reserve_bytes
from cli.sampling import with_sampling_option
from cli.interrupts import ChatInterrupts
from cli.storage import DurableModelStore
from cli.manifest import normalize_model_reference
from server.local_protocol import FlatJSON, LocalHTTPHead
from server.local_transport import (listen_local, accept_local, load_service_key,
                                    receive_head, receive_body, send_local)
from server.api import build_http_response, json_escape_string
from server.ollama import (OllamaRequest, OllamaModelInfo, ollama_version,
                           ollama_tags, ollama_show,
                           ollama_generate_response, ollama_chat_response)


struct GenerateRequest:
    var prompt: String
    var system: String
    var max_tokens: Int
    var timeout_ms: Int
    var sampling: NativeSamplingConfig

    def __init__(out self, body: String, token_limit: Int, timeout_limit: Int) raises:
        self.prompt = ""
        self.system = "You are a helpful assistant. Keep answers concise."
        self.max_tokens = min(256, token_limit)
        self.timeout_ms = timeout_limit
        self.sampling = NativeSamplingConfig()
        var parser = FlatJSON(body)
        var fields = parser.fields()
        for field in fields:
            if field.name == "prompt" or field.name == "system":
                if field.kind != "string" or field.value.byte_length() > 65536:
                    raise Error("Prompt/system must be strings within 64 KiB")
                if field.name == "prompt":
                    self.prompt = field.value
                else:
                    self.system = field.value
            else:
                if field.kind != "number":
                    raise Error("Generation controls must be JSON numbers")
                if field.name == "max_tokens":
                    self.max_tokens = bounded_decimal(field.value)
                elif field.name == "timeout_ms":
                    self.timeout_ms = bounded_decimal(field.value)
                elif field.name == "temperature" or field.name == "seed":
                    self.sampling = with_sampling_option(self.sampling, field.name, field.value)
                elif field.name == "top_k":
                    self.sampling = with_sampling_option(self.sampling, "top-k", field.value)
                elif field.name == "top_p":
                    self.sampling = with_sampling_option(self.sampling, "top-p", field.value)
                elif field.name == "min_p":
                    self.sampling = with_sampling_option(self.sampling, "min-p", field.value)
                elif field.name == "repeat_penalty":
                    self.sampling = with_sampling_option(self.sampling, "repeat-penalty", field.value)
                else:
                    raise Error("Unknown generation field")
        if self.prompt.byte_length() == 0:
            raise Error("Generation requires a nonempty prompt")
        if self.max_tokens < 1 or self.max_tokens > token_limit:
            raise Error("Generation token count exceeds service limit")
        if self.timeout_ms < 1 or self.timeout_ms > timeout_limit:
            raise Error("Generation deadline exceeds service limit")
        self.sampling.validate()


def local_response(code: Int, body: String, ollama: Bool = False) -> String:
    var reason = String("Error")
    if code == 200:
        reason = "OK"
    elif code == 400:
        reason = "Bad Request"
    elif code == 401:
        reason = "Unauthorized"
    elif code == 403:
        reason = "Forbidden"
    elif code == 404:
        reason = "Not Found"
    elif code == 405:
        reason = "Method Not Allowed"
    elif code == 408:
        reason = "Request Timeout"
    elif code == 411:
        reason = "Length Required"
    elif code == 413:
        reason = "Content Too Large"
    elif code == 415:
        reason = "Unsupported Media Type"
    elif code == 422:
        reason = "Unprocessable Content"
    elif code == 500:
        reason = "Internal Server Error"
    elif code == 504:
        reason = "Gateway Timeout"
    var payload = body
    if code != 200:
        if ollama:
            payload = "{\"error\":\"" + reason + "\"}"
        else:
            payload = "{\"error\":{\"code\":" + String(code) + ",\"message\":\"" + reason + "\"}}"
    var response = build_http_response(code, reason, "application/json", payload)
    var extra = String("Cache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n")
    if code == 401:
        extra += "WWW-Authenticate: Bearer\r\n"
    return response.replace("Connection: close\r\n", extra + "Connection: close\r\n")


def ollama_model_matches(requested: String, loaded: String) -> Bool:
    return requested == loaded or (":" not in requested and requested + ":latest" == loaded)


def serve_loaded[T: ControlledTextSession](mut session: T, port: Int, key: String,
        profile: String, context: Int, token_limit: Int, timeout_ms: Int,
        io_timeout_ms: Int, interrupt_fd: Int, ollama: Bool,
        model: OllamaModelInfo) raises:
    var listener = listen_local(port)
    var stop = GenerationControl(0, interrupt_fd)
    var sequence = 0
    print(("Ollama-compatible" if ollama else "Native") + " inference ready at http://127.0.0.1:" + String(port) +
          "; authentication=" + ("none-loopback-only" if ollama else "required") + "; backend=cuda; profile=" + profile +
          "; concurrency=1; context=" + String(context) + "; max_tokens=" + String(token_limit))
    _ = external_call["fflush", Int32](Int(0))
    while stop.stop_reason() == "":
        try:
            var client = accept_local(listener.fd, interrupt_fd)
            sequence += 1
            var start = monotonic_milliseconds()
            var status = 400
            var body = String("")
            var receiving = True
            var generation_started = False
            try:
                var deadline = start + io_timeout_ms
                var head = LocalHTTPHead(receive_head(client.fd, deadline, interrupt_fd), port, key, not ollama)
                status = head.status
                if status == 200:
                    if ollama and head.method == "GET" and head.path == "/api/version":
                        body = ollama_version()
                    elif ollama and head.method == "GET" and head.path == "/api/tags":
                        body = ollama_tags(model)
                    elif ollama and head.method == "POST" and head.path == "/api/show":
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = OllamaRequest(raw)
                        if not ollama_model_matches(request.model, model.name):
                            status = 404
                        else:
                            body = ollama_show(model, context)
                            status = 200
                    elif ollama and head.method == "POST" and (head.path == "/api/generate" or head.path == "/api/chat"):
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = OllamaRequest(raw)
                        if not ollama_model_matches(request.model, model.name):
                            status = 404
                        elif request.stream:
                            status = 400
                        elif request.num_ctx != 0 and (request.num_ctx < 2 or request.num_ctx > context):
                            status = 400
                        elif head.path == "/api/generate" and (not request.has_prompt or request.prompt.byte_length() == 0):
                            status = 400
                        elif head.path == "/api/chat" and not request.has_messages:
                            status = 400
                        else:
                            session.reset()
                            session.configure_sampling(request.sampling)
                            session.configure_control(timeout_ms, interrupt_fd)
                            status = 422
                            generation_started = True
                            var prompt = request.prompt if head.path == "/api/generate" else request.chat_prompt
                            session.begin_turn(prompt, request.system, token_limit)
                            print("[request=" + String(sequence) + " phase=generation]")
                            _ = external_call["fflush", Int32](Int(0))
                            var answer = String("")
                            status = 500
                            while session.status().generating:
                                answer += session.next_chunk()
                                if answer.byte_length() > 1048576:
                                    _ = session.cancel()
                                    status = 413
                                    raise Error("Native response exceeded 1 MiB")
                            var state = session.status()
                            var elapsed = monotonic_milliseconds() - start
                            if head.path == "/api/generate":
                                body = ollama_generate_response(model.name, answer, state.finish_reason, state.prompt_tokens, state.generated_tokens, elapsed)
                            else:
                                body = ollama_chat_response(model.name, answer, state.finish_reason, state.prompt_tokens, state.generated_tokens, elapsed)
                            status = 200
                    elif not ollama and head.method == "GET" and head.path == "/health":
                        body = "{\"status\":\"ready\",\"backend\":\"cuda\",\"cpu_offload\":0,\"profile\":\"" + profile + "\",\"context\":" + String(context) + "}"
                    elif not ollama and head.method == "POST" and head.path == "/v1/generate":
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = GenerateRequest(raw, token_limit, timeout_ms)
                        session.reset()
                        session.configure_sampling(request.sampling)
                        session.configure_control(request.timeout_ms, interrupt_fd)
                        status = 422
                        generation_started = True
                        session.begin_turn(request.prompt, request.system, request.max_tokens)
                        print("[request=" + String(sequence) + " phase=generation]")
                        _ = external_call["fflush", Int32](Int(0))
                        var answer = String("")
                        status = 500
                        while session.status().generating:
                            answer += session.next_chunk()
                            if answer.byte_length() > 1048576:
                                _ = session.cancel()
                                status = 413
                                raise Error("Native response exceeded 1 MiB")
                        var state = session.status()
                        body = "{\"text\":\"" + json_escape_string(answer) + "\",\"finish_reason\":\"" + state.finish_reason + "\",\"prompt_tokens\":" + String(state.prompt_tokens) + ",\"generated_tokens\":" + String(state.generated_tokens) + ",\"context_used\":" + String(state.position) + ",\"backend\":\"cuda\",\"cpu_offload\":0}"
                        status = 200
                    else:
                        status = 404
            except error:
                # Never echo credentials, request contents, paths or driver errors.
                if receiving and "deadline" in String(error):
                    status = 408
                elif not session.status().healthy or session.status().generating:
                    status = 500
                elif generation_started and session.status().finish_reason == "timeout":
                    status = 504
            try:
                send_local(client.fd, local_response(status, body, ollama), io_timeout_ms, interrupt_fd)
            except:
                # Disconnects/slow readers cannot poison a healthy session.
                print("[request=" + String(sequence) + " response=not_delivered]")
            print("[request=" + String(sequence) + " status=" + String(status) +
                  " elapsed_ms=" + String(monotonic_milliseconds() - start) + "]")
            _ = external_call["fflush", Int32](Int(0))
            _ = client
            if not session.status().healthy or session.status().generating:
                raise Error("Native session failed; service stopped")
        except:
            if stop.stop_reason() != "":
                break
            raise
    print("Native inference service stopped")
    _ = listener


def dispatch_native_serve(args: List[String]) raises:
    if len(args) < 2:
        raise Error("Usage: aesir serve <model.gguf> --accel cuda --api-key-file <private-file> | aesir serve <model-name> --accel cuda --ollama")
    var key_path = String("")
    var acceleration = String("")
    var profile = String("auto")
    var port = 18434
    var context = 0
    var device = -1
    var reserve = 268435456
    var timeout_ms = 30000
    var io_timeout_ms = 5000
    var token_limit = 256
    var ollama = False
    var model_store = String(".aesir/models")
    var seen = List[String]()
    var i = 2
    while i < len(args):
        var flag = args[i]
        if flag in seen:
            raise Error("Missing or duplicate service option")
        seen.append(flag)
        if flag == "--ollama":
            ollama = True
            i += 1
            continue
        if i + 1 >= len(args):
            raise Error("Missing or duplicate service option")
        var value = args[i + 1]
        if flag == "--api-key-file":
            key_path = value
        elif flag == "--accel":
            acceleration = value
        elif flag == "--profile":
            profile = value
        elif flag == "--port":
            port = bounded_decimal(value)
        elif flag == "--context":
            context = bounded_decimal(value)
        elif flag == "--device":
            device = parse_device_index(value)
        elif flag == "--reserve-mib":
            reserve = parse_reserve_bytes(value)
        elif flag == "--timeout-ms":
            timeout_ms = bounded_decimal(value)
        elif flag == "--io-timeout-ms":
            io_timeout_ms = bounded_decimal(value)
        elif flag == "--max-tokens":
            token_limit = bounded_decimal(value)
        elif flag == "--model-store":
            model_store = value
        else:
            raise Error("Unsupported service option")
        i += 2
    if acceleration != "cuda" or (profile != "auto" and profile != "llama3" and profile != "qwen3" and profile != "gemma4"):
        raise Error("Native service requires a supported CUDA profile; no CPU fallback")
    if ollama and "--port" not in seen:
        port = 11434
    if (not ollama and key_path == "") or (ollama and key_path != "") or port < 1024 or port > 65535 or context < 0 or context > 32768:
        raise Error("Native service requires valid authentication mode, port, and context")
    if timeout_ms < 1 or timeout_ms > 3600000 or io_timeout_ms < 1 or io_timeout_ms > 30000 or token_limit < 1 or token_limit > 32768:
        raise Error("Invalid native service deadline or token limit")
    var key = String("")
    if not ollama:
        key = load_service_key(key_path)
    var model_path = args[1]
    var model_name = args[1]
    var digest = String("")
    var model_size: Int64 = 0
    var modified_at = String("1970-01-01T00:00:00Z")
    var modelfile = String("")
    if ollama:
        var durable = DurableModelStore(model_store)
        var manifest = durable.get_model(args[1])
        model_name = normalize_model_reference(args[1])
        model_path = durable.resolve_model_path(model_name)
        digest = manifest.digest
        model_size = manifest.size_bytes
        modelfile = manifest.modelfile_content
    var interrupts = ChatInterrupts(True)
    var plan = NativeModelPlan(model_path, profile, context)
    if token_limit >= plan.context_length:
        raise Error("Service token limit must leave context for the prompt")
    device = choose_native_cuda(plan.memory, device, reserve)
    if not ollama:
        model_size = Int64(plan.memory.weights_bytes)
    var family = "llama" if plan.profile == "llama3" else ("qwen3" if plan.profile == "qwen3" else "gemma4")
    var parameter_size = "8B" if plan.profile == "llama3" else ("0.6B" if plan.profile == "qwen3" else ("2B" if plan.variant == "gemma4-E2B" else "4B"))
    var quantization = "Q4_K_M" if ("Q4_K_M" in model_path or "Q4_K_M" in modelfile) else "unknown"
    var model_info = OllamaModelInfo(model_name, digest, model_size, quantization, modified_at, modelfile, family, parameter_size)
    if plan.profile == "llama3" or plan.profile == "qwen3":
        var session = Llama3CUDASession(model_path, plan.context_length, device, reserve)
        serve_loaded(session, port, key, plan.profile, plan.context_length, token_limit, timeout_ms, io_timeout_ms, interrupts.fd, ollama, model_info)
    else:
        var session = Gemma4CUDASession(model_path, plan.context_length, device, reserve)
        serve_loaded(session, port, key, plan.profile, plan.context_length, token_limit, timeout_ms, io_timeout_ms, interrupts.fd, ollama, model_info)
    _ = interrupts
