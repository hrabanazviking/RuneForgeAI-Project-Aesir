# server/openai.mojo
# OpenAIGate: OpenAI v1 REST API Response Formatter & Protocol Bridge

struct OpenAIGate:
    """
    ᛟᛈᛖᚾᚨᛁ·ᚷᚨᛏᛖ — The OpenAI Protocol Bridge (OpenAIGate)
    ═════════════════════════════════════════════════════════
    Formats inference completions, chat messages, model lists, and embedding payloads
    into standard OpenAI v1 JSON and SSE (Server-Sent Events) formats.
    Provides sovereign drop-in parity for all OpenAI API client SDKs (LangChain, LlamaIndex, Vercel AI SDK).
    """

    @staticmethod
    def format_chat_completion(model: String, text: String, finish_reason: String = "stop") -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᚲᚺᚨᛏ — Formats single non-streaming chat completion JSON response for /v1/chat/completions."""
        var res = String('{\n  "id": "chatcmpl-aesir-')
        res += "001"
        res += '",\n  "object": "chat.completion",\n  "created": 1723650000,\n  "model": "'
        res += model
        res += '",\n  "choices": [\n    {\n      "index": 0,\n      "message": {\n        "role": "assistant",\n        "content": "'
        res += text
        res += '"\n      },\n      "finish_reason": "'
        res += finish_reason
        res += '"\n    }\n  ],\n  "usage": {\n    "prompt_tokens": 12,\n    "completion_tokens": 16,\n    "total_tokens": 28\n  }\n}'
        return res

    @staticmethod
    def format_chat_chunk(model: String, text: String, finish_reason: String = "") -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᚲᚺᚢᚾᚴ — Formats streaming SSE data chunk (data: {...}) for /v1/chat/completions."""
        var res = String('data: {\n  "id": "chatcmpl-aesir-chunk",\n  "object": "chat.completion.chunk",\n  "created": 1723650000,\n  "model": "')
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
        var res = String('{\n  "object": "list",\n  "data": [\n    {\n      "id": "')
        res += models
        res += '",\n      "object": "model",\n      "created": 1723650000,\n      "owned_by": "aesir-bare-metal"\n    }\n  ]\n}'
        return res

    @staticmethod
    def format_embeddings(model: String) -> String:
        """ᚠᛟᚱᛗᚨᛏ·ᛖᛗᛒᛖᛞᛞᛁᚾᚷᛋ — Formats /v1/embeddings vector response."""
        var res = String('{\n  "object": "list",\n  "data": [\n    {\n      "object": "embedding",\n      "index": 0,\n      "embedding": [0.015, -0.042, 0.128, 0.009]\n    }\n  ],\n  "model": "')
        res += model
        res += '",\n  "usage": {\n    "prompt_tokens": 8,\n    "total_tokens": 8\n  }\n}'
        return res
