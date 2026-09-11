"""Bounded Ollama request subset and response serialization.

Only the non-streaming endpoints implemented by the native single-session
service are represented here. Unknown request fields and options fail closed.
"""
from aesir import NativeSamplingConfig, bounded_decimal
from std.collections import InlineArray
from std.ffi import external_call
from cli.sampling import with_sampling_option
from server.api import json_escape_string
from server.local_protocol import FlatJSON


struct OllamaRequest:
    var model: String
    var prompt: String
    var system: String
    var chat_prompt: String
    var stream: Bool
    var num_ctx: Int
    var sampling: NativeSamplingConfig
    var has_prompt: Bool
    var has_messages: Bool

    def __init__(out self, body: String) raises:
        self.model = ""
        self.prompt = ""
        self.system = ""
        self.chat_prompt = ""
        self.stream = True
        self.num_ctx = 0
        self.sampling = NativeSamplingConfig()
        self.has_prompt = False
        self.has_messages = False
        var parser = FlatJSON(body)
        parser.take(123)
        parser.space()
        var seen = List[String]()
        if parser.peek() != 125:
            while True:
                var name = parser.string()
                if name in seen or len(seen) >= 16:
                    raise Error("Duplicate or excessive Ollama request field")
                seen.append(name)
                parser.take(58)
                if name == "model" or name == "name":
                    if self.model != "":
                        raise Error("Duplicate Ollama model identity")
                    self.model = parser.string()
                elif name == "prompt":
                    self.prompt = parser.string()
                    self.has_prompt = True
                elif name == "system":
                    self.system = parser.string()
                elif name == "stream":
                    self.stream = parser.boolean()
                elif name == "options":
                    self._parse_options(parser)
                elif name == "messages":
                    self._parse_messages(parser)
                    self.has_messages = True
                else:
                    raise Error("Unsupported Ollama request field: " + name)
                parser.space()
                if parser.peek() != 44:
                    break
                parser.position += 1
        parser.take(125)
        parser.space()
        if parser.peek() != -1:
            raise Error("Trailing Ollama JSON content")
        if self.model.byte_length() == 0 or self.model.byte_length() > 256:
            raise Error("Ollama request requires a bounded model name")
        if self.prompt.byte_length() > 65536 or self.system.byte_length() > 65536 or self.chat_prompt.byte_length() > 65536:
            raise Error("Ollama request text exceeds 64 KiB")
        self.sampling.validate()

    def _parse_options(mut self, mut parser: FlatJSON) raises:
        parser.take(123)
        parser.space()
        var seen = List[String]()
        if parser.peek() != 125:
            while True:
                var name = parser.string()
                if name in seen or len(seen) >= 16:
                    raise Error("Duplicate or excessive Ollama option")
                seen.append(name)
                parser.take(58)
                var value = parser.number()
                if name == "num_ctx":
                    self.num_ctx = bounded_decimal(value)
                elif name == "temperature" or name == "seed":
                    self.sampling = with_sampling_option(self.sampling, name, value)
                elif name == "top_k":
                    self.sampling = with_sampling_option(self.sampling, "top-k", value)
                elif name == "top_p":
                    self.sampling = with_sampling_option(self.sampling, "top-p", value)
                elif name == "min_p":
                    self.sampling = with_sampling_option(self.sampling, "min-p", value)
                elif name == "repeat_penalty":
                    self.sampling = with_sampling_option(self.sampling, "repeat-penalty", value)
                else:
                    raise Error("Unsupported Ollama generation option: " + name)
                parser.space()
                if parser.peek() != 44:
                    break
                parser.position += 1
        parser.take(125)

    def _parse_messages(mut self, mut parser: FlatJSON) raises:
        parser.take(91)
        parser.space()
        var count = 0
        var last_role = String("")
        if parser.peek() != 93:
            while True:
                if count >= 128:
                    raise Error("Ollama chat exceeds 128 messages")
                parser.take(123)
                parser.space()
                var role = String("")
                var content = String("")
                var seen = List[String]()
                if parser.peek() != 125:
                    while True:
                        var name = parser.string()
                        if name in seen:
                            raise Error("Duplicate Ollama message field")
                        seen.append(name)
                        parser.take(58)
                        if name == "role":
                            role = parser.string()
                        elif name == "content":
                            content = parser.string()
                        else:
                            raise Error("Unsupported Ollama message field: " + name)
                        parser.space()
                        if parser.peek() != 44:
                            break
                        parser.position += 1
                parser.take(125)
                if content.byte_length() == 0 or content.byte_length() > 65536:
                    raise Error("Ollama chat message content must be bounded and nonempty")
                if role == "system":
                    if self.system != "":
                        self.system += "\n"
                    self.system += content
                elif role == "user" or role == "assistant":
                    self.chat_prompt += ("User: " if role == "user" else "Assistant: ") + content + "\n"
                else:
                    raise Error("Ollama chat supports system, user, and assistant roles")
                last_role = role
                count += 1
                parser.space()
                if parser.peek() != 44:
                    break
                parser.position += 1
        parser.take(93)
        if count == 0 or last_role != "user":
            raise Error("Ollama chat requires a final user message")


struct OllamaModelInfo(Copyable, ImplicitlyCopyable):
    var name: String
    var digest: String
    var size_bytes: Int64
    var quantization: String
    var modified_at: String
    var modelfile: String
    var family: String
    var parameter_size: String

    def __init__(out self, name: String, digest: String, size_bytes: Int64,
                 quantization: String, modified_at: String, modelfile: String,
                 family: String, parameter_size: String):
        self.name = name
        self.digest = digest
        self.size_bytes = size_bytes
        self.quantization = quantization
        self.modified_at = modified_at
        self.modelfile = modelfile
        self.family = family
        self.parameter_size = parameter_size


def ollama_details(model: OllamaModelInfo) -> String:
    return "{\"parent_model\":\"\",\"format\":\"gguf\",\"family\":\"" + json_escape_string(model.family) + "\",\"families\":[\"" + json_escape_string(model.family) + "\"],\"parameter_size\":\"" + json_escape_string(model.parameter_size) + "\",\"quantization_level\":\"" + json_escape_string(model.quantization) + "\"}"


def ollama_version() -> String:
    return "{\"version\":\"0.1.0-aesir\"}"


def ollama_tags(model: OllamaModelInfo) -> String:
    return "{\"models\":[{\"name\":\"" + json_escape_string(model.name) + "\",\"model\":\"" + json_escape_string(model.name) + "\",\"modified_at\":\"" + json_escape_string(model.modified_at) + "\",\"size\":" + String(model.size_bytes) + ",\"digest\":\"" + json_escape_string(model.digest) + "\",\"details\":" + ollama_details(model) + "}]}"


def ollama_catalog_tags(models: List[OllamaModelInfo]) -> String:
    var body = String("{\"models\":[")
    for index in range(len(models)):
        if index != 0:
            body += ","
        var model = models[index]
        body += "{\"name\":\"" + json_escape_string(model.name) + "\",\"model\":\"" + json_escape_string(model.name) + "\",\"modified_at\":\"" + json_escape_string(model.modified_at) + "\",\"size\":" + String(model.size_bytes) + ",\"digest\":\"" + json_escape_string(model.digest) + "\",\"details\":" + ollama_details(model) + "}"
    return body + "]}"


def ollama_show(model: OllamaModelInfo, context: Int) -> String:
    return "{\"license\":\"\",\"modelfile\":\"" + json_escape_string(model.modelfile) + "\",\"parameters\":\"num_ctx " + String(context) + "\",\"template\":\"\",\"details\":" + ollama_details(model) + ",\"model_info\":{\"general.architecture\":\"" + json_escape_string(model.family) + "\",\"aesir.context_length\":" + String(context) + "}}"


def ollama_ps(model: OllamaModelInfo, size_vram: Int,
              context_length: Int) raises -> String:
    if size_vram <= 0 or context_length < 2:
        raise Error("Ollama running-model metrics must be positive")
    return "{\"models\":[{\"name\":\"" + json_escape_string(model.name) + "\",\"model\":\"" + json_escape_string(model.name) + "\",\"size\":" + String(model.size_bytes) + ",\"digest\":\"" + json_escape_string(model.digest) + "\",\"details\":" + ollama_details(model) + ",\"expires_at\":\"9999-12-31T23:59:59Z\",\"size_vram\":" + String(size_vram) + ",\"context_length\":" + String(context_length) + "}]}"


def ollama_done_reason(reason: String) -> String:
    if reason == "eos":
        return "stop"
    return reason


def ollama_created_at() raises -> String:
    """Returns the current UTC wall clock in Ollama's RFC3339 shape."""
    var timestamp = InlineArray[Int64, 1](fill=0)
    if external_call["time", Int64](timestamp.unsafe_ptr()) < 0:
        raise Error("Cannot observe response wall clock")
    # glibc x86-64 struct tm is 56 bytes; seven Int64 slots preserve alignment.
    var utc = InlineArray[Int64, 7](fill=0)
    if external_call["gmtime_r", Int](timestamp.unsafe_ptr(), utc.unsafe_ptr()) == 0:
        raise Error("Cannot convert response wall clock to UTC")
    var output = InlineArray[Int8, 32](fill=0)
    var format = String("%Y-%m-%dT%H:%M:%SZ")
    if external_call["strftime", Int](output.unsafe_ptr(), 32, format.as_bytes().unsafe_ptr(), utc.unsafe_ptr()) != 20:
        raise Error("Cannot format response wall clock")
    return String(unsafe_from_utf8_ptr=output.unsafe_ptr())


def ollama_generate_response(model: String, answer: String, finish_reason: String,
                             prompt_tokens: Int, generated_tokens: Int,
                             elapsed_ms: Int) raises -> String:
    return "{\"model\":\"" + json_escape_string(model) + "\",\"created_at\":\"" + ollama_created_at() + "\",\"response\":\"" + json_escape_string(answer) + "\",\"done\":true,\"done_reason\":\"" + json_escape_string(ollama_done_reason(finish_reason)) + "\",\"context\":[],\"total_duration\":" + String(elapsed_ms * 1000000) + ",\"load_duration\":0,\"prompt_eval_count\":" + String(prompt_tokens) + ",\"prompt_eval_duration\":0,\"eval_count\":" + String(generated_tokens) + ",\"eval_duration\":" + String(elapsed_ms * 1000000) + "}"


def ollama_chat_response(model: String, answer: String, finish_reason: String,
                         prompt_tokens: Int, generated_tokens: Int,
                         elapsed_ms: Int) raises -> String:
    return "{\"model\":\"" + json_escape_string(model) + "\",\"created_at\":\"" + ollama_created_at() + "\",\"message\":{\"role\":\"assistant\",\"content\":\"" + json_escape_string(answer) + "\",\"images\":null},\"done\":true,\"done_reason\":\"" + json_escape_string(ollama_done_reason(finish_reason)) + "\",\"total_duration\":" + String(elapsed_ms * 1000000) + ",\"load_duration\":0,\"prompt_eval_count\":" + String(prompt_tokens) + ",\"prompt_eval_duration\":0,\"eval_count\":" + String(generated_tokens) + ",\"eval_duration\":" + String(elapsed_ms * 1000000) + "}"
