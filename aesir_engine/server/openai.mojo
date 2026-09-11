# server/openai.mojo
# Bounded OpenAI-compatible text request parsing and observed response serialization

from server.api import json_escape_string
from server.local_protocol import FlatJSON
from core.sampling_config import NativeSamplingConfig
from core.native_hardware import bounded_decimal
from cli.sampling import with_sampling_option
from std.collections import InlineArray
from std.ffi import external_call


struct OpenAIRequest:
    """Bounded text completion/chat subset accepted by the native service."""

    var model: String
    var prompt: String
    var system: String
    var chat_prompt: String
    var stream: Bool
    var max_tokens: Int
    var sampling: NativeSamplingConfig
    var has_messages: Bool

    def __init__(out self, body: String) raises:
        self.model = ""
        self.prompt = ""
        self.system = ""
        self.chat_prompt = ""
        self.stream = False
        self.max_tokens = 0
        self.sampling = NativeSamplingConfig()
        self.has_messages = False
        var parser = FlatJSON(body)
        parser.take(123)
        parser.space()
        var seen = List[String]()
        if parser.peek() != 125:
            while True:
                var name = parser.string()
                if name in seen or len(seen) >= 16:
                    raise Error("Duplicate or excessive OpenAI request field")
                seen.append(name)
                parser.take(58)
                if name == "model":
                    self.model = parser.string()
                elif name == "prompt":
                    self.prompt = parser.string()
                elif name == "messages":
                    self._parse_messages(parser)
                    self.has_messages = True
                elif name == "stream":
                    self.stream = parser.boolean()
                elif name == "max_tokens":
                    self.max_tokens = bounded_decimal(parser.number())
                    if self.max_tokens == 0:
                        raise Error("OpenAI max_tokens must be positive")
                elif name == "temperature" or name == "seed":
                    self.sampling = with_sampling_option(
                        self.sampling, name, parser.number()
                    )
                elif name == "top_p":
                    self.sampling = with_sampling_option(
                        self.sampling, "top-p", parser.number()
                    )
                elif name == "n":
                    if parser.number() != "1":
                        raise Error("OpenAI native service supports exactly one choice")
                else:
                    raise Error("Unsupported OpenAI request field: " + name)
                parser.space()
                if parser.peek() != 44:
                    break
                parser.position += 1
        parser.take(125)
        parser.space()
        if parser.peek() != -1:
            raise Error("Trailing OpenAI JSON content")
        if self.model.byte_length() == 0 or self.model.byte_length() > 256:
            raise Error("OpenAI request requires a bounded model name")
        if (self.prompt.byte_length() > 65536
                or self.system.byte_length() > 65536
                or self.chat_prompt.byte_length() > 65536):
            raise Error("OpenAI request text exceeds 64 KiB")
        self.sampling.validate()

    def _parse_messages(mut self, mut parser: FlatJSON) raises:
        parser.take(91)
        parser.space()
        var count = 0
        var last_role = String("")
        if parser.peek() != 93:
            while True:
                if count >= 128:
                    raise Error("OpenAI chat exceeds 128 messages")
                parser.take(123)
                parser.space()
                var role = String("")
                var content = String("")
                var seen = List[String]()
                if parser.peek() != 125:
                    while True:
                        var name = parser.string()
                        if name in seen:
                            raise Error("Duplicate OpenAI message field")
                        seen.append(name)
                        parser.take(58)
                        if name == "role":
                            role = parser.string()
                        elif name == "content":
                            content = parser.string()
                        else:
                            raise Error("Unsupported OpenAI message field: " + name)
                        parser.space()
                        if parser.peek() != 44:
                            break
                        parser.position += 1
                parser.take(125)
                if content.byte_length() == 0 or content.byte_length() > 65536:
                    raise Error("OpenAI chat message content must be bounded and nonempty")
                if role == "system":
                    if self.system != "":
                        self.system += "\n"
                    self.system += content
                elif role == "user" or role == "assistant":
                    self.chat_prompt += (
                        "User: " if role == "user" else "Assistant: "
                    ) + content + "\n"
                else:
                    raise Error("OpenAI chat supports system, user, and assistant roles")
                last_role = role
                count += 1
                parser.space()
                if parser.peek() != 44:
                    break
                parser.position += 1
        parser.take(93)
        if count == 0 or last_role != "user":
            raise Error("OpenAI chat requires a final user message")


def openai_created_unix() raises -> Int:
    var timestamp = InlineArray[Int64, 1](fill=0)
    var observed = external_call["time", Int64](timestamp.unsafe_ptr())
    if observed <= 0 or observed > 9223372036854775807:
        raise Error("Cannot observe OpenAI response wall clock")
    return Int(observed)

struct OpenAIGate:
    """
    ᛟᛈᛖᚾᚨᛁ·ᚷᚨᛏᛖ — The OpenAI Protocol Bridge (OpenAIGate)
    ═════════════════════════════════════════════════════════
    Serializes caller-observed response data. It does not parse requests,
    execute a model, calculate usage, or claim protocol/client compatibility.
    Identity, time, and usage must be supplied; no operational field is invented.
    """

    @staticmethod
    def _validate_identity(request_id: String, created_unix: Int, model: String) raises:
        if len(request_id.bytes()) == 0 or len(request_id.bytes()) > 256:
            raise Error("OpenAI response request ID must contain 1..256 bytes")
        if created_unix <= 0:
            raise Error("OpenAI response creation time must be observed and positive")
        if len(model.bytes()) == 0 or len(model.bytes()) > 1024:
            raise Error("OpenAI response model must contain 1..1024 bytes")

    @staticmethod
    def _validate_finish_reason(finish_reason: String, allow_empty: Bool) raises:
        if allow_empty and len(finish_reason.bytes()) == 0:
            return
        if (
            finish_reason != "stop"
            and finish_reason != "length"
            and finish_reason != "tool_calls"
            and finish_reason != "content_filter"
        ):
            raise Error("OpenAI response finish reason is unsupported")

    @staticmethod
    def _validate_text(text: String) raises:
        if len(text.bytes()) > 16 * 1024 * 1024:
            raise Error("OpenAI response text exceeds the 16 MiB serializer limit")

    @staticmethod
    def format_chat_completion(
        request_id: String,
        created_unix: Int,
        model: String,
        text: String,
        finish_reason: String,
        prompt_tokens: Int,
        completion_tokens: Int,
    ) raises -> String:
        """Formats one bounded response from caller-observed generation data."""
        OpenAIGate._validate_identity(request_id, created_unix, model)
        OpenAIGate._validate_finish_reason(finish_reason, False)
        OpenAIGate._validate_text(text)
        if prompt_tokens < 0 or completion_tokens < 0:
            raise Error("OpenAI response token counts must be non-negative")
        # Keep addition inside a portable signed-Int safety margin.
        if prompt_tokens > 4611686018427387903 or completion_tokens > 4611686018427387903 - prompt_tokens:
            raise Error("OpenAI response token count overflow")
        var total_tokens = prompt_tokens + completion_tokens

        var res = String("{\n  \"id\": \"")
        res += json_escape_string(request_id)
        res += "\",\n  \"object\": \"chat.completion\",\n  \"created\": "
        res += String(created_unix)
        res += ",\n  \"model\": \""
        res += json_escape_string(model)
        res += "\",\n  \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\": \"assistant\",\n        \"content\": \""
        res += json_escape_string(text)
        res += "\"\n      },\n      \"finish_reason\": \""
        res += json_escape_string(finish_reason)
        res += "\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\": "
        res += String(prompt_tokens)
        res += ",\n    \"completion_tokens\": " + String(completion_tokens)
        res += ",\n    \"total_tokens\": " + String(total_tokens) + "\n  }\n}"
        return res

    @staticmethod
    def format_chat_chunk(
        request_id: String,
        created_unix: Int,
        model: String,
        text: String,
        finish_reason: String = "",
    ) raises -> String:
        """Formats one bounded SSE data event from caller-observed stream data."""
        OpenAIGate._validate_identity(request_id, created_unix, model)
        OpenAIGate._validate_finish_reason(finish_reason, True)
        OpenAIGate._validate_text(text)
        var res = String("data: {\n  \"id\": \"")
        res += json_escape_string(request_id)
        res += "\",\n  \"object\": \"chat.completion.chunk\",\n  \"created\": "
        res += String(created_unix)
        res += ",\n  \"model\": \""
        res += json_escape_string(model)
        res += "\",\n  \"choices\": [\n    {\n      \"index\": 0,\n      \"delta\": {\n        \"content\": \""
        res += json_escape_string(text)
        res += "\"\n      }"
        if len(finish_reason.bytes()) > 0:
            res += ",\n      \"finish_reason\": \""
            res += json_escape_string(finish_reason)
            res += "\""
        res += "\n    }\n  ]\n}\n\n"
        return res

    @staticmethod
    def format_completion(
        request_id: String, created_unix: Int, model: String, text: String,
        finish_reason: String, prompt_tokens: Int, completion_tokens: Int,
    ) raises -> String:
        OpenAIGate._validate_identity(request_id, created_unix, model)
        OpenAIGate._validate_finish_reason(finish_reason, False)
        OpenAIGate._validate_text(text)
        if prompt_tokens < 0 or completion_tokens < 0:
            raise Error("OpenAI response token counts must be non-negative")
        if (prompt_tokens > 4611686018427387903
                or completion_tokens > 4611686018427387903 - prompt_tokens):
            raise Error("OpenAI response token count overflow")
        var total_tokens = prompt_tokens + completion_tokens
        return "{\"id\":\"" + json_escape_string(request_id) + "\",\"object\":\"text_completion\",\"created\":" + String(created_unix) + ",\"model\":\"" + json_escape_string(model) + "\",\"choices\":[{\"text\":\"" + json_escape_string(text) + "\",\"index\":0,\"finish_reason\":\"" + json_escape_string(finish_reason) + "\"}],\"usage\":{\"prompt_tokens\":" + String(prompt_tokens) + ",\"completion_tokens\":" + String(completion_tokens) + ",\"total_tokens\":" + String(total_tokens) + "}}"

    @staticmethod
    def format_completion_chunk(
        request_id: String, created_unix: Int, model: String, text: String,
        finish_reason: String,
    ) raises -> String:
        OpenAIGate._validate_identity(request_id, created_unix, model)
        OpenAIGate._validate_finish_reason(finish_reason, False)
        OpenAIGate._validate_text(text)
        return "data: {\"id\":\"" + json_escape_string(request_id) + "\",\"object\":\"text_completion\",\"created\":" + String(created_unix) + ",\"model\":\"" + json_escape_string(model) + "\",\"choices\":[{\"text\":\"" + json_escape_string(text) + "\",\"index\":0,\"finish_reason\":\"" + json_escape_string(finish_reason) + "\"}]}\n\n"

    @staticmethod
    def format_models_list(
        model: String, created_unix: Int, owned_by: String
    ) raises -> String:
        """Formats one caller-observed model catalog record."""
        OpenAIGate._validate_identity("catalog", created_unix, model)
        if len(owned_by.bytes()) == 0 or len(owned_by.bytes()) > 256:
            raise Error("OpenAI model owner must contain 1..256 bytes")
        var res = String("{\n  \"object\": \"list\",\n  \"data\": [\n    {\n      \"id\": \"")
        res += json_escape_string(model)
        res += "\",\n      \"object\": \"model\",\n      \"created\": "
        res += String(created_unix)
        res += ",\n      \"owned_by\": \"" + json_escape_string(owned_by) + "\"\n    }\n  ]\n}"
        return res

    @staticmethod
    def format_model_catalog(models: List[String], created_unix: Int,
                             owned_by: String = "local-operator") raises -> String:
        if created_unix <= 0 or owned_by.byte_length() == 0 or owned_by.byte_length() > 256:
            raise Error("OpenAI model catalog requires observed time and owner")
        var res = String("{\"object\":\"list\",\"data\":[")
        for index in range(len(models)):
            var model = models[index]
            OpenAIGate._validate_identity("catalog", created_unix, model)
            if index != 0:
                res += ","
            res += "{\"id\":\"" + json_escape_string(model) + "\",\"object\":\"model\",\"created\":" + String(created_unix) + ",\"owned_by\":\"" + json_escape_string(owned_by) + "\"}"
        return res + "]}"

    @staticmethod
    def format_embeddings(model: String) raises -> String:
        """Returns a bounded JSON error; no embedding data path exists here."""
        if len(model.bytes()) == 0 or len(model.bytes()) > 1024:
            raise Error("OpenAI embedding error model must contain 1..1024 bytes")
        var res = String("{\n  \"error\": \"unsupported\",\n  \"capability\": \"embedding formatting without real vector data\",\n  \"model\": \"")
        res += json_escape_string(model)
        res += "\"\n}"
        return res
