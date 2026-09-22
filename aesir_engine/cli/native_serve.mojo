"""Native loopback HTTP orchestration over the serialized CUDA contract."""
from std.ffi import external_call
from aesir import (Gemma4CUDASession, Llama3CUDASession,
                   NativeSamplingConfig, ControlledTextSession, GenerationControl,
                   choose_native_cuda_plan, bounded_decimal, monotonic_milliseconds)
from cli.hardware import parse_device_index, parse_reserve_bytes
from core.sampling_options import with_sampling_option
from cli.sampling import sampling_option_name
from cli.native_settings import resolve_native_settings, native_settings_json, load_native_config, native_config_sampling
from cli.interrupts import ChatInterrupts
from cli.model_reference import resolve_model_reference
from cli.storage import DurableModelStore
from server.local_protocol import FlatJSON, LocalHTTPHead, resolve_request_token_limit, require_loaded_context
from server.local_transport import (listen_local, accept_local, load_service_key,
                                    receive_head, receive_body, send_local)
from server.api import build_http_response, json_escape_string
from server.ollama import (OllamaRequest, OllamaShowRequest, OllamaModelInfo, ollama_version,
                           ollama_catalog_tags, ollama_show, ollama_ps,
                           ollama_generate_response, ollama_chat_response,
                           ollama_done_reason)
from server.openai import OpenAIRequest, OpenAIGate, openai_created_unix


struct GenerateRequest:
    var prompt: String
    var system: String
    var max_tokens: Int
    var timeout_ms: Int
    var sampling: NativeSamplingConfig

    def __init__(out self, body: String, token_limit: Int, timeout_limit: Int,
                 defaults: NativeSamplingConfig = NativeSamplingConfig(),
                 default_system: String = "You are a helpful assistant. Keep answers concise.") raises:
        defaults.validate()
        if default_system.byte_length() > 65536:
            raise Error("Default system prompt exceeds 64 KiB")
        self.prompt = ""
        self.system = default_system
        self.max_tokens = resolve_request_token_limit(0, token_limit)
        self.timeout_ms = timeout_limit
        self.sampling = defaults
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
        if self.max_tokens < 1:
            raise Error("Generation token count must be positive")
        self.max_tokens = resolve_request_token_limit(self.max_tokens, token_limit)
        if self.timeout_ms < 1 or self.timeout_ms > timeout_limit:
            raise Error("Generation deadline exceeds service limit")
        self.sampling.validate()


def local_response(code: Int, body: String, ollama: Bool = False,
                   content_type: String = "application/json") -> String:
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
    var response = build_http_response(
        code, reason, content_type if code == 200 else "application/json", payload
    )
    var extra = String("Cache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n")
    if code == 401:
        extra += "WWW-Authenticate: Bearer\r\n"
    return response.replace("Connection: close\r\n", extra + "Connection: close\r\n")


def ollama_model_matches(requested: String, loaded: String) -> Bool:
    return requested == loaded or (":" not in requested and requested + ":latest" == loaded)


def ollama_catalog_models(model_store: String,
                          loaded: OllamaModelInfo) raises -> List[OllamaModelInfo]:
    """Lists runnable blob manifests while preserving exact loaded-model facts."""
    var models = List[OllamaModelInfo]()
    var found_loaded = False
    for manifest in DurableModelStore(model_store).list_models():
        var name = manifest.name + ":" + manifest.tag
        if name == loaded.name:
            models.append(loaded)
            found_loaded = True
        elif manifest.digest.startswith("sha256:") and manifest.size_bytes > 0:
            models.append(OllamaModelInfo(
                name, manifest.digest, manifest.size_bytes,
                manifest.quantization,
                manifest.modified_time if manifest.modified_time != "unknown"
                    else "1970-01-01T00:00:00Z",
                manifest.modelfile_content, "unknown", "unknown",
            ))
    if not found_loaded:
        models.append(loaded)
    return models^


def openai_catalog_names(catalog: List[OllamaModelInfo]) -> List[String]:
    var names = List[String]()
    for model in catalog:
        names.append(model.name)
    return names^


def serve_loaded[T: ControlledTextSession](mut session: T, port: Int, key: String,
        profile: String, context: Int, token_limit: Int, timeout_ms: Int,
        io_timeout_ms: Int, interrupt_fd: Int, ollama: Bool,
        model: OllamaModelInfo, catalog: List[OllamaModelInfo],
        device_bytes: Int, sampling_defaults: NativeSamplingConfig = NativeSamplingConfig(),
        system_defaults: String = "", has_system_defaults: Bool = False) raises:
    sampling_defaults.validate()
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
            var content_type = String("application/json")
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
                        body = ollama_catalog_tags(catalog)
                    elif ollama and head.method == "GET" and head.path == "/api/ps":
                        body = ollama_ps(model, device_bytes, context)
                    elif ollama and head.method == "POST" and head.path == "/api/show":
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = OllamaShowRequest(raw)
                        if not ollama_model_matches(request.model, model.name):
                            status = 404
                        else:
                            body = ollama_show(model, context)
                            status = 200
                    elif ollama and head.method == "POST" and (head.path == "/api/generate" or head.path == "/api/chat"):
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = OllamaRequest(raw, sampling_defaults, system_defaults)
                        if not ollama_model_matches(request.model, model.name):
                            status = 404
                        elif head.path == "/api/generate" and request.has_messages:
                            status = 400
                        elif head.path == "/api/chat" and request.has_prompt:
                            status = 400
                        elif head.path == "/api/generate" and (not request.has_prompt or request.prompt.byte_length() == 0):
                            status = 400
                        elif head.path == "/api/chat" and not request.has_messages:
                            status = 400
                        else:
                            require_loaded_context(request.num_ctx, context)
                            var request_tokens = resolve_request_token_limit(request.num_predict, token_limit)
                            session.reset()
                            session.configure_sampling(request.sampling)
                            session.configure_control(timeout_ms, interrupt_fd)
                            status = 422
                            generation_started = True
                            var prompt = request.prompt if head.path == "/api/generate" else request.chat_prompt
                            session.begin_turn(prompt, request.system, request_tokens)
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
                            if request.stream:
                                body += "\n"
                                content_type = "application/x-ndjson"
                            status = 200
                    elif head.method == "GET" and head.path == "/v1/models":
                        body = OpenAIGate.format_model_catalog(
                            openai_catalog_names(catalog), openai_created_unix()
                        )
                    elif head.method == "POST" and (head.path == "/v1/chat/completions" or head.path == "/v1/completions"):
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = OpenAIRequest(raw, sampling_defaults, system_defaults)
                        if not ollama_model_matches(request.model, model.name):
                            status = 404
                        elif head.path == "/v1/chat/completions" and request.has_prompt:
                            status = 400
                        elif head.path == "/v1/completions" and request.has_messages:
                            status = 400
                        elif head.path == "/v1/chat/completions" and not request.has_messages:
                            status = 400
                        elif head.path == "/v1/completions" and request.prompt.byte_length() == 0:
                            status = 400
                        else:
                            var request_tokens = resolve_request_token_limit(request.max_tokens, token_limit)
                            session.reset()
                            session.configure_sampling(request.sampling)
                            session.configure_control(timeout_ms, interrupt_fd)
                            status = 422
                            generation_started = True
                            var prompt = (
                                request.chat_prompt
                                if head.path == "/v1/chat/completions"
                                else request.prompt
                            )
                            session.begin_turn(prompt, request.system, request_tokens)
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
                            var created = openai_created_unix()
                            var finish = ollama_done_reason(state.finish_reason)
                            var request_id = "cmpl-aesir-" + String(sequence)
                            if head.path == "/v1/chat/completions":
                                body = OpenAIGate.format_chat_completion(
                                    request_id, created, model.name, answer, finish,
                                    state.prompt_tokens, state.generated_tokens,
                                )
                            else:
                                body = OpenAIGate.format_completion(
                                    request_id, created, model.name, answer, finish,
                                    state.prompt_tokens, state.generated_tokens,
                                )
                            if request.stream:
                                if head.path == "/v1/chat/completions":
                                    body = OpenAIGate.format_chat_chunk(
                                        request_id, created, model.name, answer, finish
                                    )
                                else:
                                    body = OpenAIGate.format_completion_chunk(
                                        request_id, created, model.name, answer, finish
                                    )
                                body += "data: [DONE]\n\n"
                                content_type = "text/event-stream"
                            status = 200
                    elif not ollama and head.method == "GET" and head.path == "/health":
                        body = "{\"status\":\"ready\",\"backend\":\"cuda\",\"cpu_offload\":0,\"profile\":\"" + profile + "\",\"context\":" + String(context) + "}"
                    elif not ollama and head.method == "POST" and head.path == "/v1/generate":
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = GenerateRequest(raw, token_limit, timeout_ms, sampling_defaults,
                            system_defaults if has_system_defaults else "You are a helpful assistant. Keep answers concise.")
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
                send_local(client.fd, local_response(status, body, ollama, content_type), io_timeout_ms, interrupt_fd)
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
        raise Error("Usage: aesir serve <model> --accel cuda --api-key-file <private-file> | aesir serve <model-name> --accel cuda --ollama")
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
    var sampling = NativeSamplingConfig()
    var system = String("")
    var show_settings = False
    var config_path = String("")
    var seen = List[String]()
    var i = 2
    while i < len(args):
        var flag = args[i]
        if flag == "-c":
            flag = "--config"
        if flag in seen:
            raise Error("Missing or duplicate service option")
        seen.append(flag)
        if flag == "--show-settings":
            show_settings = True
            i += 1
            continue
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
        elif flag == "--config":
            config_path = value
        elif flag == "--system":
            system = value
        elif sampling_option_name(flag) != "":
            sampling = with_sampling_option(sampling, sampling_option_name(flag), value)
        else:
            raise Error("Unsupported service option")
        i += 2
    if acceleration != "cuda" or (profile != "auto" and profile != "llama3" and profile != "qwen3" and profile != "gemma4"):
        raise Error("Native service requires a supported CUDA profile; no CPU fallback")
    if ollama and "--port" not in seen:
        port = 11434
    if (not show_settings and not ollama and key_path == "") or (ollama and key_path != "") or port < 1024 or port > 65535 or context < 0 or context > 32768:
        raise Error("Native service requires valid authentication mode, port, and context")
    if timeout_ms < 1 or timeout_ms > 3600000 or io_timeout_ms < 1 or io_timeout_ms > 30000 or token_limit < 1 or token_limit > 32768:
        raise Error("Invalid native service deadline or token limit")
    var config = load_native_config(config_path, seen)
    var config_sampling = native_config_sampling(config)
    if "--config" in seen:
        model_store = config.model_store_path
    var key = String("")
    if not ollama and not show_settings:
        key = load_service_key(key_path)
    var resolved = resolve_model_reference(args[1], model_store)
    if ollama and not resolved.from_catalog:
        raise Error("Ollama service requires a registered model name")
    var effective = resolve_native_settings(resolved.modelfile_content,
        sampling, seen, context, token_limit, system, config_sampling)
    if show_settings:
        print(native_settings_json(effective))
        return
    sampling = effective.sampling
    context = effective.context
    token_limit = effective.max_tokens
    var model_path = resolved.path
    var model_name = resolved.catalog_name if resolved.from_catalog else args[1]
    var digest = resolved.digest
    var model_size: Int64 = resolved.size_bytes
    var modified_at = String("1970-01-01T00:00:00Z")
    var modelfile = resolved.modelfile_content
    var interrupts = ChatInterrupts(True)
    var selection = choose_native_cuda_plan(
        model_path, profile, context, device, reserve
    )
    var plan = selection.plan.copy()
    if token_limit >= plan.context_length:
        raise Error("Service token limit must leave context for the prompt")
    device = selection.device_index
    if not ollama:
        model_size = Int64(plan.memory.weights_bytes)
    var family = "llama" if plan.profile == "llama3" else ("qwen3" if plan.profile == "qwen3" else "gemma4")
    var parameter_size = "8B" if plan.profile == "llama3" else ("0.6B" if plan.profile == "qwen3" else ("2B" if plan.variant == "gemma4-E2B" else "4B"))
    var quantization = "Q4_K_M" if ("Q4_K_M" in model_path or "Q4_K_M" in modelfile) else "unknown"
    var model_info = OllamaModelInfo(model_name, digest, model_size, quantization, modified_at, modelfile, family, parameter_size)
    var catalog = List[OllamaModelInfo]()
    if ollama:
        catalog = ollama_catalog_models(model_store, model_info)
    else:
        catalog.append(model_info)
    if plan.profile == "llama3" or plan.profile == "qwen3":
        var session = Llama3CUDASession(model_path, plan.context_length, device, reserve, sampling)
        serve_loaded(session, port, key, plan.profile, plan.context_length, token_limit, timeout_ms, io_timeout_ms, interrupts.fd, ollama, model_info, catalog, plan.memory.device_bytes, sampling, effective.system, effective.has_system)
    else:
        var session = Gemma4CUDASession(model_path, plan.context_length, device, reserve, sampling)
        serve_loaded(session, port, key, plan.profile, plan.context_length, token_limit, timeout_ms, io_timeout_ms, interrupts.fd, ollama, model_info, catalog, plan.memory.device_bytes, sampling, effective.system, effective.has_system)
    _ = interrupts
