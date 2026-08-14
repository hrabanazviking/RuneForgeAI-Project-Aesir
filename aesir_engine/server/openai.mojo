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
        var res = String('{\n  "aesir_status": "formatter_scaffold",\n  "id": "chatcmpl-unverified-scaffold')
        res += '",\n  "object": "chat.completion",\n  "created": 0,\n  "model": "'
        res += model
        res += '",\n  "choices": [\n    {\n      "index": 0,\n      "message": {\n        "role": "assistant",\n        "content": "'
        res += text
        res += '"\n      },\n      "finish_reason": "'
        res += finish_reason
        res += '"\n    }\n  ],\n  "usage": {\n    "prompt_tokens": 0,\n    "completion_tokens": 0,\n    "total_tokens": 0\n  }\n}'
        return res

    @staticmethod
    def format_chat_chunk(model: String, text: String, finish_reason: String = "") -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᚲᚺᚢᚾᚴ — Formats streaming SSE data chunk (data: {...}) for /v1/chat/completions."""
        var res = String('data: {\n  "aesir_status": "formatter_scaffold",\n  "id": "chatcmpl-unverified-scaffold",\n  "object": "chat.completion.chunk",\n  "created": 0,\n  "model": "')
        res += model
        res += '",\n  "choices": [\n    {\n      "index": 0,\n      "delta": {\n        "content": "'
        res += text
        res += '"\n      }'
        if len(finish_reason.bytes()) > 0:
            res += ',\n      "finish_reason": "'
            res += finish_reason
            res += '"'
        res += '\n    }\n  ]\n}\n\n'
        return res

    @staticmethod
    def format_models_list(models: String) -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᛗᛟᛞᛖᛚᛋ — Formats /v1/models JSON catalog response."""
        var res = String('{\n  "aesir_status": "formatter_scaffold",\n  "object": "list",\n  "data": [\n    {\n      "id": "')
        res += models
        res += '",\n      "object": "model",\n      "created": 0,\n      "owned_by": "unverified"\n    }\n  ]\n}'
        return res

    @staticmethod
    def format_embeddings(model: String) -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᛖᛗᛒᛖᛞᛞᛁᚾᚷᛋ — Formats /v1/embeddings vector response."""
        var res = String('{\n  "error": "unsupported",\n  "capability": "embedding formatting without real vector data",\n  "model": "')
        res += model
        res += '"\n}'
        return res
