"""Native loopback HTTP orchestration over the serialized CUDA contract."""
from std.ffi import external_call
from aesir import (Gemma4CUDASession, Llama3CUDASession,
                   NativeSamplingConfig, ControlledTextSession, GenerationControl,
                   choose_native_cuda_plan, bounded_decimal, monotonic_milliseconds,
                   llama3_memory_plan)
from cli.hardware import parse_device_index, parse_reserve_bytes
from core.sampling_options import with_sampling_option
from core.tool_use import parse_gemma_zero_arg_call
from cli.sampling import sampling_option_name
from cli.native_settings import resolve_native_settings, native_settings_json, load_native_config, native_config_sampling
from cli.interrupts import ChatInterrupts
from cli.model_reference import resolve_model_reference, lease_resolved_model
from cli.storage import DurableModelStore
from cli.service_lifecycle import register_service
from server.local_protocol import FlatJSON, LocalHTTPHead, resolve_request_token_limit, require_loaded_context
from server.local_transport import (OwnedFD, listen_local, accept_local,
                                    accept_local_ready, client_disconnected,
                                    discard_available_input, load_service_key,
                                    receive_head, receive_body, send_local,
                                    send_native_stream_head, send_stream_head)
from server.api import build_http_response, json_escape_string
from server.service_status import service_liveness, model_readiness
from server.ollama import (OllamaRequest, OllamaShowRequest, OllamaModelInfo, ollama_version,
                           ollama_catalog_tags, ollama_show, ollama_ps,
                           ollama_generate_response, ollama_chat_response,
                           ollama_generate_chunk, ollama_chat_chunk,
                           ollama_done_reason)
from server.openai import OpenAIRequest, OpenAIGate, openai_created_unix
from core.openai_audit import ROUTE_REFUSED_501, route_verdict, unsupported_route_body
from core.stream_progress import (STREAM_NATIVE_NDJSON, STREAM_OLLAMA_NDJSON,
                                  STREAM_OPENAI_SSE, progress_frames,
                                  stream_usage_requested)
from core.browser_page import browser_page_html, browser_page_content_type
from core.code_completion import cc_plan, cc_trim_overlap


struct GenerateRequest:
    var prompt: String
    var system: String
    var max_tokens: Int
    var timeout_ms: Int
    var stream: Bool
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
        self.stream = False
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
            elif field.name == "stream":
                if field.kind != "boolean":
                    raise Error("Generation stream must be a JSON boolean")
                self.stream = field.value == "true"
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
                   content_type: String = "application/json",
                   preserve_body: Bool = False) -> String:
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
    elif code == 501:
        reason = "Not Implemented"
    elif code == 503:
        reason = "Service Unavailable"
    elif code == 504:
        reason = "Gateway Timeout"
    var payload = body
    if code != 200 and not preserve_body:
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
    elif code == 503:
        extra += "Retry-After: 1\r\n"
    return response.replace("Connection: close\r\n", extra + "Connection: close\r\n")


struct PendingClient:
    var client: OwnedFD
    var admitted_ms: Int

    def __init__(out self, var owned: OwnedFD, admitted_ms: Int):
        self.client = owned^
        self.admitted_ms = admitted_ms

    def detach(mut self) raises -> OwnedFD:
        var fd = self.client.fd
        self.client.fd = -1
        return OwnedFD(fd)


def admit_pending(listener: Int32, mut pending: List[PendingClient],
                  queue_limit: Int, queue_timeout_ms: Int, io_timeout_ms: Int,
                  interrupt_fd: Int, ollama: Bool,
                  expired_undelivered: Int = 0) raises -> Int:
    """FIFO admission at decoder boundaries, with bounded work per probe.

    Counts expired-slot 503 sends that fail to deliver and reports
    "[queue expired_undelivered=N]" after the sweep when N > 0. The running
    count is returned so callers may thread it back in across sweeps; the
    default keeps all existing call sites compatible.
    """
    var undelivered = expired_undelivered
    var index = 0
    while index < len(pending):
        if client_disconnected(pending[index].client.fd):
            print("[queue cancelled slot=" + String(index) + "]")
            _ = pending.pop(index)
        elif monotonic_milliseconds() - pending[index].admitted_ms >= queue_timeout_ms:
            try:
                discard_available_input(pending[index].client.fd)
                send_local(pending[index].client.fd, local_response(503, "", ollama),
                           min(io_timeout_ms, 500), interrupt_fd)
            except:
                undelivered += 1
            _ = pending.pop(index)
            print("[queue expired]")
        else:
            index += 1
    if undelivered > 0:
        print("[queue expired_undelivered=" + String(undelivered) + "]")
    for _ in range(16):
        var fd = accept_local_ready(listener)
        if fd < 0:
            break
        if len(pending) >= queue_limit:
            try:
                discard_available_input(fd)
                send_local(fd, local_response(503, "", ollama),
                           min(io_timeout_ms, 500), interrupt_fd)
                print("[queue rejected status=503]")
            except:
                print("[queue rejection_not_delivered]")
            _ = external_call["close", Int32](fd)
        else:
            var incoming = OwnedFD(fd)
            pending.append(PendingClient(incoming^, monotonic_milliseconds()))
            print("[queue admitted depth=" + String(len(pending)) + "]")
        _ = external_call["fflush", Int32](Int(0))
    return undelivered


def next_client(listener: Int32, mut pending: List[PendingClient],
                interrupt_fd: Int) raises -> PendingClient:
    if len(pending) > 0:
        return pending.pop(0)
    return PendingClient(accept_local(listener, interrupt_fd), monotonic_milliseconds())


def ollama_model_matches(requested: String, loaded: String) -> Bool:
    return requested == loaded or (":" not in requested and requested + ":latest" == loaded)


def ollama_catalog_models(model_store: String,
                          loaded: OllamaModelInfo) raises -> List[OllamaModelInfo]:
    """Read the current registered weight manifests, not a startup snapshot."""
    var models = List[OllamaModelInfo]()
    for manifest in DurableModelStore(model_store).list_models():
        var name = manifest.name + ":" + manifest.tag
        if manifest.digest.startswith("sha256:") and manifest.size_bytes > 0:
            var same_resident_blob = (name == loaded.name and
                                      manifest.digest == loaded.digest and
                                      manifest.size_bytes == loaded.size_bytes)
            models.append(OllamaModelInfo(
                name, manifest.digest, manifest.size_bytes,
                manifest.quantization,
                manifest.modified_time if manifest.modified_time != "unknown"
                    else "1970-01-01T00:00:00Z",
                manifest.modelfile_content,
                loaded.family if same_resident_blob else "unknown",
                loaded.parameter_size if same_resident_blob else "unknown",
            ))
    return models^


def openai_catalog_names(catalog: List[OllamaModelInfo]) -> List[String]:
    var names = List[String]()
    for model in catalog:
        names.append(model.name)
    return names^


# Long-prompt watching (Janas road J-059) + server streaming
# (J-107) -- host contract for this server surface, as wired
# by J-107. The progress account lives in
# core/prompt_progress.mojo (the pre-registered discipline:
# watched iff >= 1024 prompt tokens AND >= 4 chunks;
# boundary-only records; a 10% step throttle, at most 10
# records per read; the final 100% record exactly once);
# the stream protocol lives in core/stream_progress.mojo
# (framing per stream kind, the read's whole framed
# sequence, the streaming-usage decision). On every
# streaming generation route serve_loaded now: (1) sends
# the stream head BEFORE begin_turn (the OpenAI chat
# route's role chunk follows the head, also before
# begin_turn), with response_started / stream_kind set
# first so a failed read is answered by the streamed-error
# path; (2) after begin_turn returns, sends the read's
# progress_frames(...) -- total from session.status(),
# width from the serve's prefill_batch, the final frame
# carrying the route's measured prefill ms -- BEFORE the
# decode loop; a silent read sends zero frames; (3) on
# the OpenAI routes, when stream_options.include_usage
# was set, sends the Gate's usage chunk after the finish
# chunk and before data: [DONE]. Honesty, per the J-107
# protocol: the frames are the read's true record emitted
# batched after the blocking read (the streaming form of
# the native route's after-the-fact timings_ms); they do
# NOT arrive spread across the read. Arrival during the
# read needs J-059's W1 (a progress sink inside the CUDA
# sessions' begin_turn loops), deferred with its recipe
# in docs/janas/J107_SERVER_STREAMING_PROGRESS.md
# sections 0.4/5, re-cited at the J-118 gate.
#
# The browser page (Janas road J-108) -- host contract.
# GET / answers the try-it chat page (core/browser_page
# .mojo: one self-contained HTML document, no external
# references, no model name or key baked in) as
# text/html, in both modes -- the chat route it calls
# exists in both. The page document itself is exempt
# from the Bearer rule in LocalHTTPHead (a browser
# navigation cannot present one; the page is a constant
# with no secrets, the Host check still applies, and
# every data route keeps the rule; the page's API calls
# present the key the operator types into it). The head
# layer's browser-header discipline (T16) refuses
# Origin / Referer / Sec-Fetch-Site by VALUE through the
# page layer's rules: exactly the serving origin is
# allowed, cross-site values stay 403. The decision and
# its price are recorded in docs/janas/
# J108_SERVER_BROWSER_PAGE.md section 0.2.


def send_progress_frames(fd: Int32, kind: Int, prompt_tokens: Int,
                         chunk_width: Int, final_elapsed_ms: Int,
                         io_timeout_ms: Int, interrupt_fd: Int) raises:
    """Send one completed read's framed progress sequence
    (core/stream_progress), in order. A silent read's
    sequence is empty and nothing is sent."""
    var width = chunk_width if chunk_width >= 1 else 1
    var frames = progress_frames(kind, prompt_tokens, width, final_elapsed_ms)
    for i in range(len(frames)):
        send_local(fd, frames[i], io_timeout_ms, interrupt_fd)


def serve_loaded[T: ControlledTextSession](mut session: T, port: Int, key: String,
        profile: String, context: Int, token_limit: Int, timeout_ms: Int,
        io_timeout_ms: Int, interrupt_fd: Int, ollama: Bool,
        model: OllamaModelInfo, model_store: String, loaded_from_catalog: Bool,
        device_bytes: Int, sampling_defaults: NativeSamplingConfig = NativeSamplingConfig(),
        system_defaults: String = "", has_system_defaults: Bool = False,
        queue_limit: Int = 4, queue_timeout_ms: Int = 30000,
        prefix_cache: Bool = False, prefill_batch: Int = 1) raises:
    sampling_defaults.validate()
    var listener = listen_local(port)
    var owner = register_service(model_store, port, model.name, model.digest,
                                 "ollama" if ollama else "native")
    var stop = GenerationControl(0, interrupt_fd)
    var sequence = 0
    var pending = List[PendingClient]()
    print(("Ollama-compatible" if ollama else "Native") + " inference ready at http://127.0.0.1:" + String(port) +
          "; authentication=" + ("none-loopback-only" if ollama else "required") + "; backend=cuda; profile=" + profile +
          "; concurrency=1; queue_limit=" + String(queue_limit) +
          "; queue_timeout_ms=" + String(queue_timeout_ms) +
          "; context=" + String(context) + "; max_tokens=" + String(token_limit))
    _ = external_call["fflush", Int32](Int(0))
    while stop.stop_reason() == "":
        try:
            var next = next_client(listener.fd, pending, interrupt_fd)
            var queued_ms = monotonic_milliseconds() - next.admitted_ms
            var client = next.detach()
            if queued_ms >= queue_timeout_ms:
                try:
                    discard_available_input(client.fd)
                    send_local(client.fd, local_response(503, "", ollama),
                               min(io_timeout_ms, 500), interrupt_fd)
                except:
                    pass
                continue
            sequence += 1
            var start = monotonic_milliseconds()
            var status = 400
            var body = String("")
            var content_type = String("application/json")
            var receiving = True
            var generation_started = False
            var response_started = False
            var preserve_status_body = False
            var stream_kind = String("")
            try:
                var deadline = start + io_timeout_ms
                var head = LocalHTTPHead(receive_head(client.fd, deadline, interrupt_fd), port, key, not ollama)
                status = head.status
                if status == 200:
                    if ollama and head.method == "GET" and head.path == "/api/version":
                        body = ollama_version()
                    elif ollama and head.method == "GET" and head.path == "/api/tags":
                        status = 503
                        body = ollama_catalog_tags(ollama_catalog_models(model_store, model))
                        status = 200
                    elif ollama and head.method == "GET" and head.path == "/api/ps":
                        body = ollama_ps(model, device_bytes, context)
                    elif ollama and head.method == "POST" and head.path == "/api/show":
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = OllamaShowRequest(raw)
                        status = 503
                        var shown = False
                        for listed in ollama_catalog_models(model_store, model):
                            if ollama_model_matches(request.model, listed.name):
                                var resident = (listed.name == model.name and
                                                listed.digest == model.digest and
                                                listed.size_bytes == model.size_bytes)
                                body = ollama_show(listed, context if resident else 0, resident)
                                status = 200
                                shown = True
                                break
                        if not shown:
                            status = 404
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
                            if request.stream:
                                response_started = True
                                stream_kind = "ollama"
                                send_stream_head(client.fd, "application/x-ndjson", io_timeout_ms, interrupt_fd)
                            var ollama_prefill_started_ms = monotonic_milliseconds()
                            session.begin_turn(prompt, request.system, request_tokens)
                            var ollama_prefill_elapsed_ms = monotonic_milliseconds() - ollama_prefill_started_ms
                            print("[request=" + String(sequence) + " phase=generation]")
                            _ = external_call["fflush", Int32](Int(0))
                            var answer = String("")
                            status = 500
                            if request.stream:
                                send_progress_frames(client.fd, STREAM_OLLAMA_NDJSON, session.status().prompt_tokens, prefill_batch, ollama_prefill_elapsed_ms, io_timeout_ms, interrupt_fd)
                            while session.status().generating:
                                var chunk = session.next_chunk()
                                _ = admit_pending(listener.fd, pending, queue_limit, queue_timeout_ms, io_timeout_ms, interrupt_fd, ollama)
                                answer += chunk
                                if answer.byte_length() > 1048576:
                                    _ = session.cancel()
                                    status = 413
                                    raise Error("Native response exceeded 1 MiB")
                                if request.stream and chunk.byte_length() > 0:
                                    send_local(client.fd,
                                        ollama_generate_chunk(model.name, chunk)
                                        if head.path == "/api/generate"
                                        else ollama_chat_chunk(model.name, chunk),
                                        io_timeout_ms, interrupt_fd)
                            var state = session.status()
                            if state.finish_reason == "timeout":
                                raise Error("Ollama generation deadline exceeded")
                            var elapsed = monotonic_milliseconds() - start
                            if head.path == "/api/generate":
                                body = ollama_generate_response(model.name, "" if request.stream else answer, state.finish_reason, state.prompt_tokens, state.generated_tokens, elapsed)
                            else:
                                body = ollama_chat_response(model.name, "" if request.stream else answer, state.finish_reason, state.prompt_tokens, state.generated_tokens, elapsed)
                            if request.stream:
                                send_local(client.fd, body + "\n", io_timeout_ms, interrupt_fd)
                            status = 200
                    elif head.method == "GET" and head.path == "/":
                        # The browser page (J-108, T15): the one
                        # non-JSON route, served in both modes.
                        status = 200
                        body = browser_page_html()
                        content_type = browser_page_content_type()
                    elif head.method == "GET" and head.path == "/v1/models":
                        status = 503
                        var current_catalog = ollama_catalog_models(model_store, model)
                        var names = openai_catalog_names(current_catalog)
                        if not loaded_from_catalog and model.name not in names:
                            names.append(model.name)
                        body = OpenAIGate.format_model_catalog(
                            names, openai_created_unix()
                        )
                        status = 200
                    elif head.method == "GET" and head.path.startswith("/v1/models/"):
                        status = 404
                        var wanted = String(head.path[byte=11:])
                        if "/" not in wanted:
                            var retrieve_catalog = ollama_catalog_models(model_store, model)
                            for listed in retrieve_catalog:
                                if ollama_model_matches(wanted, listed.name):
                                    body = OpenAIGate.format_model_object(
                                        listed.name, openai_created_unix()
                                    )
                                    status = 200
                                    break
                            if status != 200 and ollama_model_matches(wanted, model.name):
                                body = OpenAIGate.format_model_object(
                                    model.name, openai_created_unix()
                                )
                                status = 200
                    elif head.method == "POST" and (head.path == "/v1/chat/completions" or head.path == "/v1/completions"):
                        status = 400
                        var raw = receive_body(client.fd, head.length, deadline, interrupt_fd)
                        receiving = False
                        var request = OpenAIRequest(raw, sampling_defaults, system_defaults)
                        if not ollama_model_matches(request.model, model.name):
                            status = 404
                        elif head.path == "/v1/chat/completions" and request.has_prompt:
                            status = 400
                        elif head.path == "/v1/chat/completions" and request.has_suffix:
                            # Code completion is a raw-completions shape
                            # (J-111): a chat body carrying a cursor
                            # suffix is refused, never reinterpreted.
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
                            session.configure_output(request.output_mode)
                            session.configure_tool(request.tool_name, request.tool_description)
                            session.configure_control(timeout_ms, interrupt_fd)
                            status = 422
                            generation_started = True
                            # Code completion (J-111): a completions
                            # request carrying a suffix is planned
                            # through the pure completion layer for the
                            # resident profile's arch, and generation
                            # runs from the plan's generation prompt
                            # (the prefix exactly; the suffix is never
                            # part of it -- no arch here carries FIM).
                            var completion_prompt = request.prompt
                            if request.has_suffix:
                                var completion_arch = (
                                    "llama" if profile == "llama3" else profile
                                )
                                var completion_plan = cc_plan(
                                    completion_arch, request.prompt,
                                    request.suffix)
                                completion_prompt = (
                                    completion_plan.generation_prompt)
                            var prompt = (
                                request.chat_prompt
                                if head.path == "/v1/chat/completions"
                                else completion_prompt
                            )
                            var created = openai_created_unix()
                            var request_id = (
                                "chatcmpl-aesir-" + String(sequence)
                                if head.path == "/v1/chat/completions"
                                else "cmpl-aesir-" + String(sequence)
                            )
                            if request.stream:
                                response_started = True
                                stream_kind = "openai"
                                send_stream_head(client.fd, "text/event-stream", io_timeout_ms, interrupt_fd)
                                if head.path == "/v1/chat/completions":
                                    send_local(client.fd, OpenAIGate.format_chat_role_chunk(
                                        request_id, created, model.name), io_timeout_ms, interrupt_fd)
                            var openai_prefill_started_ms = monotonic_milliseconds()
                            session.begin_turn(prompt, request.system, request_tokens)
                            var openai_prefill_elapsed_ms = monotonic_milliseconds() - openai_prefill_started_ms
                            print("[request=" + String(sequence) + " phase=generation]")
                            _ = external_call["fflush", Int32](Int(0))
                            var answer = String("")
                            var tool_block_complete = False
                            status = 500
                            if request.stream:
                                send_progress_frames(client.fd, STREAM_OPENAI_SSE, session.status().prompt_tokens, prefill_batch, openai_prefill_elapsed_ms, io_timeout_ms, interrupt_fd)
                            while session.status().generating:
                                var chunk = session.next_chunk()
                                _ = admit_pending(listener.fd, pending, queue_limit, queue_timeout_ms, io_timeout_ms, interrupt_fd, ollama)
                                answer += chunk
                                if answer.byte_length() > 1048576:
                                    _ = session.cancel()
                                    status = 413
                                    raise Error("Native response exceeded 1 MiB")
                                if request.tool_name != "" and "<tool_call|>" in answer:
                                    if not answer.endswith("<tool_call|>"):
                                        _ = session.cancel()
                                        raise Error("Gemma tool-call terminator has trailing output")
                                    answer += session.cancel()
                                    tool_block_complete = True
                                    break
                                if request.stream and chunk.byte_length() > 0:
                                    send_local(client.fd,
                                        OpenAIGate.format_chat_chunk(request_id, created, model.name, chunk)
                                        if head.path == "/v1/chat/completions"
                                        else OpenAIGate.format_completion_chunk(request_id, created, model.name, chunk, ""),
                                        io_timeout_ms, interrupt_fd)
                            var state = session.status()
                            if state.finish_reason == "timeout":
                                raise Error("OpenAI generation deadline exceeded")
                            if request.output_mode == "json_boolean" and (
                                    state.finish_reason != "eos" or
                                    (answer != "true" and answer != "false")):
                                raise Error("Structured output ended without a complete JSON boolean")
                            if request.tool_name != "" and (
                                    "<|tool_call>" in answer or "<tool_call|>" in answer):
                                if not tool_block_complete:
                                    raise Error("Gemma tool-call block is incomplete")
                                var tool_call = parse_gemma_zero_arg_call(answer, request.tool_name)
                                body = OpenAIGate.format_chat_tool_completion(
                                    request_id, created, model.name,
                                    "call-aesir-" + String(created) + "-" + String(sequence) + "-0",
                                    tool_call.name, tool_call.arguments_json,
                                    state.prompt_tokens, state.generated_tokens,
                                    state.cached_tokens)
                            else:
                                # Code completion (J-111): the finished
                                # non-streamed answer is overlap-trimmed
                                # against the suffix so it does not
                                # duplicate the code after the cursor.
                                # Streamed chunks were sent as generated
                                # and are not trimmed (an overlap is
                                # knowable only at the end).
                                if request.has_suffix and not request.stream:
                                    answer = cc_trim_overlap(
                                        answer, request.suffix)
                                var finish = ollama_done_reason(state.finish_reason)
                                if request.stream:
                                    send_local(client.fd,
                                        OpenAIGate.format_chat_chunk(request_id, created, model.name, "", finish)
                                        if head.path == "/v1/chat/completions"
                                        else OpenAIGate.format_completion_chunk(request_id, created, model.name, "", finish),
                                        io_timeout_ms, interrupt_fd)
                                    if stream_usage_requested(request.stream, request.include_usage):
                                        send_local(client.fd,
                                            OpenAIGate.format_chat_usage_chunk(request_id, created, model.name, state.prompt_tokens, state.generated_tokens, state.cached_tokens)
                                            if head.path == "/v1/chat/completions"
                                            else OpenAIGate.format_completion_usage_chunk(request_id, created, model.name, state.prompt_tokens, state.generated_tokens, state.cached_tokens),
                                            io_timeout_ms, interrupt_fd)
                                    send_local(client.fd, "data: [DONE]\n\n", io_timeout_ms, interrupt_fd)
                                elif head.path == "/v1/chat/completions":
                                    body = OpenAIGate.format_chat_completion(
                                        request_id, created, model.name, answer, finish,
                                        state.prompt_tokens, state.generated_tokens,
                                        state.cached_tokens,
                                    )
                                else:
                                    body = OpenAIGate.format_completion(
                                        request_id, created, model.name, answer, finish,
                                        state.prompt_tokens, state.generated_tokens,
                                        state.cached_tokens,
                                    )
                            status = 200
                    elif not ollama and head.method == "GET" and head.path == "/health":
                        body = "{\"status\":\"" + ("ready" if session.status().healthy else "failed") + "\",\"backend\":\"cuda\",\"cpu_offload\":0,\"profile\":\"" + profile + "\",\"context\":" + String(context)
                        body += ",\"model\":\"" + json_escape_string(model.name) + "\",\"model_digest\":\"" + json_escape_string(model.digest) + "\",\"max_tokens\":" + String(token_limit)
                        body += ",\"generation_timeout_ms\":" + String(timeout_ms) + ",\"capabilities\":{\"text_generation\":true,\"embeddings\":false,\"exact_prefix_reuse\":" + ("true" if prefix_cache else "false") + "},\"prefill_batch\":" + String(prefill_batch) + ",\"queue_limit\":" + String(queue_limit) + "}"
                    elif not ollama and head.method == "GET" and head.path == "/health/live":
                        body = service_liveness()
                    elif not ollama and head.method == "GET" and head.path == "/health/ready":
                        var ready = session.status().healthy
                        body = model_readiness(ready, model.name, model.digest, profile, context)
                        status = 200 if ready else 503
                        preserve_status_body = True
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
                        if request.stream:
                            response_started = True
                            stream_kind = "native"
                            send_native_stream_head(client.fd, io_timeout_ms, interrupt_fd)
                        var prefill_started_ms = monotonic_milliseconds()
                        session.begin_turn(request.prompt, request.system, request.max_tokens)
                        var prefill_elapsed_ms = monotonic_milliseconds() - prefill_started_ms
                        print("[request=" + String(sequence) + " phase=generation]")
                        _ = external_call["fflush", Int32](Int(0))
                        var answer = String("")
                        status = 500
                        if request.stream:
                            send_progress_frames(client.fd, STREAM_NATIVE_NDJSON, session.status().prompt_tokens, prefill_batch, prefill_elapsed_ms, io_timeout_ms, interrupt_fd)
                        var decode_started_ms = monotonic_milliseconds()
                        while session.status().generating:
                            var chunk = session.next_chunk()
                            _ = admit_pending(listener.fd, pending, queue_limit, queue_timeout_ms, io_timeout_ms, interrupt_fd, ollama)
                            answer += chunk
                            if answer.byte_length() > 1048576:
                                _ = session.cancel()
                                status = 413
                                raise Error("Native response exceeded 1 MiB")
                            if request.stream and chunk.byte_length() > 0:
                                send_local(client.fd, "{\"text\":\"" + json_escape_string(chunk) + "\",\"done\":false}\n", io_timeout_ms, interrupt_fd)
                        var decode_elapsed_ms = monotonic_milliseconds() - decode_started_ms
                        var state = session.status()
                        if request.stream:
                            send_local(client.fd, "{\"text\":\"\",\"done\":true,\"finish_reason\":\"" + state.finish_reason + "\",\"prompt_tokens\":" + String(state.prompt_tokens) + ",\"generated_tokens\":" + String(state.generated_tokens) + ",\"context_used\":" + String(state.position) + ",\"backend\":\"cuda\",\"cpu_offload\":0,\"model\":\"" + json_escape_string(model.name) + "\",\"model_digest\":\"" + json_escape_string(model.digest) + "\",\"timings_ms\":{\"prefill\":" + String(prefill_elapsed_ms) + ",\"decode\":" + String(decode_elapsed_ms) + "}}\n", io_timeout_ms, interrupt_fd)
                        else:
                            body = "{\"text\":\"" + json_escape_string(answer) + "\",\"finish_reason\":\"" + state.finish_reason + "\",\"prompt_tokens\":" + String(state.prompt_tokens) + ",\"generated_tokens\":" + String(state.generated_tokens) + ",\"context_used\":" + String(state.position) + ",\"backend\":\"cuda\",\"cpu_offload\":0,\"model\":\"" + json_escape_string(model.name) + "\",\"model_digest\":\"" + json_escape_string(model.digest) + "\",\"timings_ms\":{\"prefill\":" + String(prefill_elapsed_ms) + ",\"decode\":" + String(decode_elapsed_ms) + "}}"
                        status = 200
                    elif route_verdict(head.method, head.path) == ROUTE_REFUSED_501:
                        # The honest refusal class (J-106): known
                        # OpenAI-shape operations this service does
                        # not run answer 501 with their reason,
                        # never an indistinguishable 404.
                        status = 501
                        body = unsupported_route_body(head.method, head.path)
                        preserve_status_body = True
                    else:
                        status = 404
            except error:
                if response_started and session.status().generating:
                    try:
                        _ = session.cancel()
                    except:
                        pass
                # Never echo credentials, request contents, paths or driver errors.
                if receiving and "deadline" in String(error):
                    status = 408
                elif not session.status().healthy or session.status().generating:
                    status = 500
                elif generation_started and session.status().finish_reason == "timeout":
                    status = 504
                if response_started:
                    try:
                        var message = "Gateway Timeout" if status == 504 else ("Content Too Large" if status == 413 else "Internal Server Error")
                        if stream_kind == "openai":
                            var kind = "timeout_error" if status == 504 else ("response_limit_error" if status == 413 else "server_error")
                            send_local(client.fd, "data: {\"error\":{\"message\":\"" + message + "\",\"type\":\"" + kind + "\"}}\n\n", io_timeout_ms, interrupt_fd)
                        elif stream_kind == "ollama":
                            send_local(client.fd, "{\"error\":\"" + message + "\"}\n", io_timeout_ms, interrupt_fd)
                        elif stream_kind == "native":
                            send_local(client.fd, "{\"error\":{\"code\":" + String(status) + ",\"message\":\"" + message + "\"}}\n", io_timeout_ms, interrupt_fd)
                    except:
                        pass
            if not response_started:
                try:
                    send_local(client.fd, local_response(status, body, ollama, content_type, preserve_status_body), io_timeout_ms, interrupt_fd)
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
    _ = owner


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
    var queue_limit = 4
    var queue_timeout_ms = 30000
    var ollama = False
    var prefix_cache = True
    var prefill_batch = 0
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
        if flag == "--no-prefix-cache":
            prefix_cache = False
            i += 1
            continue
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
            try:
                port = bounded_decimal(value)
            except:
                raise Error("Invalid --port value '" + value + "': expected an unsigned decimal integer")
            if port < 1 or port > 65535:
                raise Error("Invalid --port value: port must be within the valid range 1..65535")
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
        elif flag == "--prefill-batch":
            prefill_batch = bounded_decimal(value)
            if prefill_batch != 1 and prefill_batch != 4:
                raise Error("Native prefill batch must be one or four")
        elif flag == "--queue-limit":
            queue_limit = bounded_decimal(value)
        elif flag == "--queue-timeout-ms":
            queue_timeout_ms = bounded_decimal(value)
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
    if queue_limit < 1 or queue_limit > 8 or queue_timeout_ms < 100 or queue_timeout_ms > 60000:
        raise Error("Invalid native service queue limit or deadline")
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
    var blob_lease = lease_resolved_model(resolved, model_store)
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
    if prefill_batch == 4 and (plan.profile != "llama3" or plan.variant != "llama3-3B"):
        raise Error("Four-token prefill is admitted only for the exercised 3B profile")
    if token_limit >= plan.context_length:
        raise Error("Service token limit must leave context for the prompt")
    device = selection.device_index
    if not ollama:
        model_size = Int64(plan.memory.weights_bytes)
    var family = "llama" if plan.profile == "llama3" else ("qwen3" if plan.profile == "qwen3" else "gemma4")
    var parameter_size = ("3B" if plan.variant == "llama3-3B" else "8B") if plan.profile == "llama3" else ("0.6B" if plan.profile == "qwen3" else ("2B" if plan.variant == "gemma4-E2B" else "4B"))
    var quantization = "Q4_K_M" if ("Q4_K_M" in model_path or "Q4_K_M" in modelfile) else "unknown"
    var model_info = OllamaModelInfo(model_name, digest, model_size, quantization, modified_at, modelfile, family, parameter_size)
    if plan.profile == "llama3" or plan.profile == "qwen3":
        var session = Llama3CUDASession(model_path, plan.context_length, device, reserve, sampling, prefix_cache, prefill_batch)
        serve_loaded(session, port, key, plan.profile, plan.context_length, token_limit, timeout_ms, io_timeout_ms, interrupts.fd, ollama, model_info, model_store, resolved.from_catalog, llama3_memory_plan(Int(model_size), plan.context_length, session.profile, session.prefill_batch).device_bytes, sampling, effective.system, effective.has_system, queue_limit, queue_timeout_ms, prefix_cache, session.prefill_batch)
    else:
        var session = Gemma4CUDASession(model_path, plan.context_length, device, reserve, sampling)
        serve_loaded(session, port, key, plan.profile, plan.context_length, token_limit, timeout_ms, io_timeout_ms, interrupts.fd, ollama, model_info, model_store, resolved.from_catalog, plan.memory.device_bytes, sampling, effective.system, effective.has_system, queue_limit, queue_timeout_ms)
    _ = interrupts
    _ = blob_lease
