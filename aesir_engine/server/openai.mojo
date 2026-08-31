# server/openai.mojo
# OpenAIGate: local OpenAI-shaped string formatter scaffold

from server.api import json_escape_string

struct OpenAIGate:
    """
    ᛟᛈᛖᚾᚨᛁ·ᚷᚨᛏᛖ — The OpenAI Protocol Bridge (OpenAIGate)
    ═════════════════════════════════════════════════════════
    Builds OpenAI-shaped strings for local formatter tests. It does not parse
    requests, execute a model, calculate usage, or claim protocol/client
    compatibility. All caller strings are escaped and all unobserved numeric
    fields remain zero.
    """

    @staticmethod
    def format_chat_completion(model: String, text: String, finish_reason: String = "stop") -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᚲᚺᚨᛏ — Formats single non-streaming chat completion JSON response for /v1/chat/completions."""
        var res = String("{\n  \"aesir_status\": \"formatter_scaffold\",\n  \"id\": \"unassigned")
        res += "\",\n  \"object\": \"chat.completion\",\n  \"created\": 0,\n  \"model\": \""
        res += json_escape_string(model)
        res += "\",\n  \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\": \"assistant\",\n        \"content\": \""
        res += json_escape_string(text)
        res += "\"\n      },\n      \"finish_reason\": \""
        res += json_escape_string(finish_reason)
        res += "\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\": 0,\n    \"completion_tokens\": 0,\n    \"total_tokens\": 0\n  }\n}"
        return res

    @staticmethod
    def format_chat_chunk(model: String, text: String, finish_reason: String = "") -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᚲᚺᚢᚾᚴ — Formats streaming SSE data chunk (data: {...}) for /v1/chat/completions."""
        var res = String("data: {\n  \"aesir_status\": \"formatter_scaffold\",\n  \"id\": \"unassigned\",\n  \"object\": \"chat.completion.chunk\",\n  \"created\": 0,\n  \"model\": \"")
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
    def format_models_list(models: String) -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᛗᛟᛞᛖ6 — Formats /v1/models JSON catalog response."""
        var res = String("{\n  \"aesir_status\": \"formatter_scaffold\",\n  \"object\": \"list\",\n  \"data\": [\n    {\n      \"id\": \"")
        res += json_escape_string(models)
        res += "\",\n      \"object\": \"model\",\n      \"created\": 0,\n      \"owned_by\": \"aesir\"\n    }\n  ]\n}"
        return res

    @staticmethod
    def format_embeddings(model: String) -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᛖᛗᛒᛖᛞᛞᛁᚾᚷᛋ — Formats /v1/embeddings vector response."""
        var res = String("{\n  \"error\": \"unsupported\",\n  \"capability\": \"embedding formatting without real vector data\",\n  \"model\": \"")
        res += json_escape_string(model)
        res += "\"\n}"
        return res
