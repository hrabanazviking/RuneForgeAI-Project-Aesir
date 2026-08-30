# server/openai.mojo
# OpenAIGate: local OpenAI-shaped string formatter scaffold

struct OpenAIGate:
    """
    ᛟᛈᛖᚾᚨᛁ·ᚷᚨᛏᛖ — The OpenAI Protocol Bridge (OpenAIGate)
    ═════════════════════════════════════════════════════════
    Builds OpenAI-shaped strings for local formatter tests. It does not parse
    requests, escape arbitrary JSON, execute a model, calculate usage, or claim
    protocol/client compatibility.
    """

    @staticmethod
    def format_chat_completion(model: String, text: String, finish_reason: String = "stop") -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᚲᚺᚨᛏ — Formats single non-streaming chat completion JSON response for /v1/chat/completions."""
        var res = String("{\n  \"aesir_status\": \"ok\",\n  \"id\": \"chatcmpl-aesir-v1")
        res += "\",\n  \"object\": \"chat.completion\",\n  \"created\": 1700000000,\n  \"model\": \""
        res += model
        res += "\",\n  \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\": \"assistant\",\n        \"content\": \""
        res += text
        res += "\"\n      },\n      \"finish_reason\": \""
        res += finish_reason
        res += "\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\": 16,\n    \"completion_tokens\": 16,\n    \"total_tokens\": 32\n  }\n}"
        return res

    @staticmethod
    def format_chat_chunk(model: String, text: String, finish_reason: String = "") -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᚲᚺᚢᚾᚴ — Formats streaming SSE data chunk (data: {...}) for /v1/chat/completions."""
        var res = String("data: {\n  \"aesir_status\": \"ok\",\n  \"id\": \"chatcmpl-aesir-v1\",\n  \"object\": \"chat.completion.chunk\",\n  \"created\": 1700000000,\n  \"model\": \"")
        res += model
        res += "\",\n  \"choices\": [\n    {\n      \"index\": 0,\n      \"delta\": {\n        \"content\": \""
        res += text
        res += "\"\n      }"
        if len(finish_reason.bytes()) > 0:
            res += ",\n      \"finish_reason\": \""
            res += finish_reason
            res += "\""
        res += "\n    }\n  ]\n}\n\n"
        return res

    @staticmethod
    def format_models_list(models: String) -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᛗᛟᛞᛖ6 — Formats /v1/models JSON catalog response."""
        var res = String("{\n  \"aesir_status\": \"ok\",\n  \"object\": \"list\",\n  \"data\": [\n    {\n      \"id\": \"")
        res += models
        res += "\",\n      \"object\": \"model\",\n      \"created\": 1700000000,\n      \"owned_by\": \"aesir\"\n    }\n  ]\n}"
        return res

    @staticmethod
    def format_embeddings(model: String) -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᛖᛗᛒᛖᛞᛞᛁᚾᚷᛋ — Formats /v1/embeddings vector response."""
        var res = String("{\n  \"error\": \"unsupported\",\n  \"capability\": \"embedding formatting without real vector data\",\n  \"model\": \"")
        res += model
        res += "\"\n}"
        return res
