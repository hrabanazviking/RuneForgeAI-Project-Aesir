# server/openai.mojo
# OpenAIGate: bounded serializer for caller-observed OpenAI-shaped data

from server.api import json_escape_string

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
    def format_embeddings(model: String) raises -> String:
        """Returns a bounded JSON error; no embedding data path exists here."""
        if len(model.bytes()) == 0 or len(model.bytes()) > 1024:
            raise Error("OpenAI embedding error model must contain 1..1024 bytes")
        var res = String("{\n  \"error\": \"unsupported\",\n  \"capability\": \"embedding formatting without real vector data\",\n  \"model\": \"")
        res += json_escape_string(model)
        res += "\"\n}"
        return res
