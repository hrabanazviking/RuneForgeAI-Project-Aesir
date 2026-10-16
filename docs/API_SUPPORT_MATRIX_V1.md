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
| `GET /health` | Yes | 404 | Legacy loaded-service report; retains `status: "ready"` for existing clients. Use the separate routes below for new health checks. |
| `GET /health/live` | Yes | 404 | Schema v1 JSON `status: "ok"`, `scope: "process"`; request-loop liveness only, with no model-readiness claim. |
| `GET /health/ready` | Yes | 404 | Schema v1 JSON `ready`, `status`, resident model identity/profile/context. HTTP 200 when the resident session is healthy, 503 with `status: "not_ready"` otherwise. |
| `POST /v1/generate` | Yes | 404 | Default JSON `text`, `finish_reason`, `prompt_tokens`, `generated_tokens`, `context_used`, `backend`, `cpu_offload`; `stream:true` uses incremental NDJSON text records and a counted terminal record. |
| `GET /v1/models` | Yes | Yes | JSON `object: "list"`, `data[]` with `id`, `object: "model"`, `created`, `owned_by`. Re-reads registered weight manifests on every call; a directly loaded path is included in native mode. Visibility does not imply loaded or runnable. |
| `POST /v1/completions` | Yes | Yes | JSON `id`, `object: "text_completion"`, `created`, `model`, one `choices[]` item and `usage`. |
| `POST /v1/chat/completions` | Yes | Yes | JSON `id`, `object: "chat.completion"`, `created`, `model`, one assistant `choices[]` item and `usage`. |
| `GET /api/version` | 404 | Yes | JSON `version: "0.1.0-aesir"`; fixed adapter identity, not an Ollama release or model-readiness claim. |
| `GET /api/tags` | 404 | Yes | JSON `models[]` from the current registered weight manifests, not a startup snapshot. |
| `GET /api/ps` | 404 | Yes | JSON `models[]` for the currently loaded model. |
| `POST /api/show` | 404 | Yes | Current registered weight manifest. `model_info.aesir.loaded` distinguishes the resident model; unloaded entries omit `aesir.context_length` and do not invent `num_ctx`. Empty license/template strings are not evidence that source metadata is absent. |
| `POST /api/generate` | 404 | Yes | JSON final record with `model`, `created_at`, `response`, `done`, counts and durations. |
| `POST /api/chat` | 404 | Yes | JSON final record with `message`, `done`, counts and durations. |

## Accepted request fields

| Request | Accepted top-level fields | Constraints and explicit exclusions |
|---|---|---|
| Native generate | `prompt`, `system`, `max_tokens`, `timeout_ms`, `temperature`, `top_k`, `top_p`, `min_p`, `repeat_penalty`, `seed`, `stream` | Nonempty prompt. `stream` is a JSON boolean, default `false`. `messages`, `tools`, `format`, `images`, `logprobs`, unknown or duplicate fields are rejected. No session ID/history. |
| OpenAI completion | `model`, `prompt`, `stream`, `max_tokens`, `temperature`, `top_p`, `seed`, `n`, bounded `response_format` | `model` must identify the loaded model; `n` must be 1. `best_of`, `stop`, `logprobs`, `echo`, `suffix`, `tools`, unknown or duplicate fields are rejected. Structured output is the strict Boolean subset below only. |
| OpenAI chat | `model`, `messages`, `stream`, `max_tokens`, `temperature`, `top_p`, `seed`, `n`, bounded `response_format`, bounded `tools`, `tool_choice` | Messages contain only string `role`/`content`; roles are `system`, `user`, `assistant`, final role `user`. Tool/function message roles, arrays or multimodal content, `stop`, `logprobs`, `stream_options`, unknown or duplicate fields are rejected. Structured output is the strict Boolean subset below only; tools use the separate Gemma-only subset below. |
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
Unreadable/corrupt catalog metadata returns 503 on list/show routes without
changing resident-model readiness or `/api/ps`. A missing show name returns
404. Catalog entries are metadata, not verified live inference capacity; only
the resident model may be used for generation. The OpenAI-compatible `created`
integer is response materialization time, not a claim about model creation.

## Strict Boolean JSON response format (S23)

OpenAI chat and completion routes in either service mode accept this one
non-streaming structured-output shape:

```json
{"response_format":{"type":"json_schema","json_schema":{"name":"answer","strict":true,"schema":{"type":"boolean"}}}}
```

`name` may be any nonempty string up to 64 UTF-8 bytes. All four nested objects
are parsed strictly: duplicate or extra fields, missing fields, malformed JSON,
schema keywords beyond `type`, any type other than `boolean`, `strict:false`,
`stream:true`, and non-greedy sampling return 400 before generation. The model
must have enough requested token and context budget for either literal or
admission fails. The output text is exactly `true` or `false`; the session
stops immediately after the canonical tokenizer sequence and reports `stop`.
Only the allowed canonical tokens compete by raw logits. `top_k` and `top_p`
do not affect this greedy choice. A deadline, disconnect or execution fault
is an error, not a guaranteed JSON response. Native `/v1/generate`, Ollama
`/api/*`, JSON objects/arrays/numbers/strings, arbitrary GBNF and tool calls
remain unsupported structured-output surfaces. The Gemma E2B physical test is
`scripts/test_boolean_json_live.py`; the Llama/Qwen path compiled but lacked
installed-weight evidence in the S23 run.

## Gemma 4 single-function tool calls (S24)

The OpenAI chat route in either service mode accepts exactly one function
declaration for the installed Gemma 4 CUDA template, with `parameters:{}` and
an optional `tool_choice:"auto"`. The function name is 1–64 ASCII bytes from
letters, digits, hyphen, dot, and underscore; description is 1–256 printable ASCII bytes without template
metacharacters. Example:

```json
{"model":"gemma4-e2b:latest","messages":[{"role":"user","content":"Call get_time."}],"tools":[{"type":"function","function":{"name":"get_time","description":"Return the current time","parameters":{}}}],"max_tokens":64}
```

Tool calls require non-streaming chat and cannot combine with
`response_format`. Multiple functions, arguments, forced/none choice, streamed
tool calls, tool result messages, and tool execution are not supported. The
server inserts the declaration using the installed GGUF's control tokens;
when the model emits one complete zero-argument call, it returns
`finish_reason:"tool_calls"`, an assistant `content:null`, one `tool_calls[]`
entry with a server-generated `call-aesir-*` ID and `function.arguments:"{}"`.
If it responds in ordinary text, the usual assistant content and `stop` or
`length` finish reason remain. Malformed, partial, unexpected-name, nonempty-
argument or multi-call model output fails closed rather than executing. Other
model templates reject the tool configuration. This is not general OpenAI
function calling or a tool-result continuation protocol; clients must perform
their own authorized execution outside Aesir.

## Streaming state at v1 (S18/S19 additive extensions)

Native `/v1/generate` `stream:false` returns one JSON response. `stream:true`
returns `application/x-ndjson` over a close-delimited HTTP/1.1 response without
`Content-Length`: each complete UTF-8 text piece is
`{"text":"...","done":false}\n`, followed by one
`{"text":"","done":true,"finish_reason":"...","prompt_tokens":N,"generated_tokens":N,"context_used":N,"backend":"cuda","cpu_offload":0}\n`.
The first text record is sent during decoding, before the final record.
If a connection fails after headers, it can end without a terminal record;
clients must treat that as incomplete rather than as a successful generation.

OpenAI `stream:true` returns close-delimited `text/event-stream` with a
single-line JSON `data:` event for each complete text piece. Chat begins with
an assistant-role delta; intermediate choices have `finish_reason:null`;
the terminal choice has an empty delta/text and an observed `stop` or `length`
finish reason, then exactly one `data: [DONE]` event. Ollama `stream:true`
(the default) returns close-delimited `application/x-ndjson` with nonempty
`done:false` text/message records and one `done:true` record carrying observed
counts, duration and `done_reason`. A short response can be wholly queued in
the kernel even if a client stops reading; writes have a bounded deadline once
backpressure actually fills the socket buffer.

Pre-header validation errors retain the mode's JSON error shape and status.
After headers, a generation/serialization failure emits a sanitized SSE error
event or NDJSON `error` line when delivery is still possible. A generation
deadline is `Gateway Timeout` (`timeout_error` in SSE); response-size overflow
is `Content Too Large`; other execution failures are `Internal Server Error`.
These failures end **without** a
success terminal/DONE marker. A disconnect may prevent even the error record.
Clients must require the successful terminal marker and treat EOF otherwise as
incomplete. This remains a bounded Aesir subset, not full external API parity.

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
