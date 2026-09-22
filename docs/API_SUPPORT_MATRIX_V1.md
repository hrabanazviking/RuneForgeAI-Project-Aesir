# Local HTTP API support matrix — v1

This is Aesir's **supported subset**, not a promise of complete Ollama or OpenAI
compatibility. The protocol contract is versioned separately from the server's
`/api/version` string. It is exercised by the independently authored requests and
response assertions in `scripts/fixtures/api_contract_v1.json` through
`scripts/test_api_contract_v1.py`. Fields not listed as accepted are rejected;
unrecognized paths return 404. Both modes bind IPv4 loopback, handle one request
at a time and close every HTTP/1.1 connection after its response.

| Route | Native mode (bearer required) | `--ollama` mode (no bearer) | Successful body |
|---|---|---|---|
| `GET /health` | Yes | 404 | JSON `status`, `backend`, `cpu_offload`, `profile`, `context`; loaded-service readiness only. |
| `POST /v1/generate` | Yes | 404 | JSON `text`, `finish_reason`, `prompt_tokens`, `generated_tokens`, `context_used`, `backend`, `cpu_offload`. |
| `GET /v1/models` | Yes | Yes | JSON `object: "list"`, `data[]` with `id`, `object: "model"`, `created`, `owned_by`. Catalog visibility does not mean every listed model is loaded; generation serves only the currently loaded model. |
| `POST /v1/completions` | Yes | Yes | JSON `id`, `object: "text_completion"`, `created`, `model`, one `choices[]` item and `usage`. |
| `POST /v1/chat/completions` | Yes | Yes | JSON `id`, `object: "chat.completion"`, `created`, `model`, one assistant `choices[]` item and `usage`. |
| `GET /api/version` | 404 | Yes | JSON `version`; Aesir identity, not an Ollama release claim. |
| `GET /api/tags` | 404 | Yes | JSON `models[]` with catalog metadata. |
| `GET /api/ps` | 404 | Yes | JSON `models[]` for the currently loaded model. |
| `POST /api/show` | 404 | Yes | JSON `license`, `modelfile`, `parameters`, `template`, `details`, `model_info`. Empty strings are not evidence that a source model lacks a license/template. |
| `POST /api/generate` | 404 | Yes | JSON final record with `model`, `created_at`, `response`, `done`, counts and durations. |
| `POST /api/chat` | 404 | Yes | JSON final record with `message`, `done`, counts and durations. |

## Accepted request fields

| Request | Accepted top-level fields | Constraints and explicit exclusions |
|---|---|---|
| Native generate | `prompt`, `system`, `max_tokens`, `timeout_ms`, `temperature`, `top_k`, `top_p`, `min_p`, `repeat_penalty`, `seed` | Nonempty prompt. `stream`, `messages`, `tools`, `format`, `images`, `logprobs`, unknown or duplicate fields are rejected. No session ID/history. |
| OpenAI completion | `model`, `prompt`, `stream`, `max_tokens`, `temperature`, `top_p`, `seed`, `n` | `model` must identify the loaded model; `n` must be 1. `best_of`, `stop`, `logprobs`, `echo`, `suffix`, `response_format`, `tools`, unknown or duplicate fields are rejected. |
| OpenAI chat | `model`, `messages`, `stream`, `max_tokens`, `temperature`, `top_p`, `seed`, `n` | Messages contain only string `role`/`content`; roles are `system`, `user`, `assistant`, final role `user`. Tool/function roles, arrays or multimodal content, `response_format`, `tools`, `tool_choice`, `stop`, `logprobs`, `stream_options`, unknown or duplicate fields are rejected. |
| Ollama show | `model` or `name` | Loaded model only; no remote lookup. |
| Ollama generate | `model` or `name`, `prompt`, `system`, `stream`, `options` | Nonempty prompt. No `raw`, `format`, `template`, `context`, `images`, `keep_alive`, `suffix` or unknown fields. |
| Ollama chat | `model` or `name`, `messages`, `system`, `stream`, `options` | Messages contain only string `role`/`content`; roles are `system`, `user`, `assistant`, final role `user`. No prompt, images, tools or unknown fields. |
| Ollama `options` | `num_ctx`, `num_predict`, `temperature`, `top_k`, `top_p`, `min_p`, `seed`, `repeat_penalty` | Explicit `num_ctx` must equal loaded context; `num_predict` is positive and within service ceiling. `mirostat`, `stop`, `repeat_last_n` and all unlisted options are rejected. |

Decoded text fields are bounded to 64 KiB; chat has at most 128 messages. JSON
number grammar and sampling bounds are narrower than the external APIs; see
[native service](NATIVE_SERVICE.md). `max_tokens`/`num_predict` may not exceed
the resolved service ceiling. Unsupported input returns 400; wrong loaded model
returns 404; context or generation admission can return 422. Native errors are
`{"error":{"code":N,"message":"..."}}`; Ollama-mode errors are
`{"error":"..."}`. Error messages intentionally do not echo request data.

## Streaming state at v1

`stream: false` returns one JSON response. OpenAI `stream: true` returns **one
final** `data: ...` SSE event followed by `data: [DONE]`; Ollama `stream: true`
(the default) returns **one final** NDJSON line. The service buffers generation
before writing either response. These are final-record wire formats, **not
incremental token streaming**; do not use them to infer time-to-first-token,
progress or cancellation semantics. `/v1/generate` rejects `stream` outright.
S18/S19 will change this only after their separate gates pass.

## Reproduce

With an installed catalog model, a freshly built Linux CUDA binary and no
network/model download:

```bash
python3 scripts/test_api_contract_v1.py --binary /tmp/aesir-s17 --model gemma4-e2b:latest
```

The corpus asserts wire framing, content type, required response types/values,
arithmetic usage consistency, unknown-field refusal, route availability and
authentication through a standard-library HTTP client. It does not certify all
Ollama/OpenAI clients, schemas, timing behavior or transport edge cases.
