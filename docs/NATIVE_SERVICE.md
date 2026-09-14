# Native local inference service

**Verified scope, 2026-09-09:** Linux x86-64/WSL2, one loaded native CUDA model,
IPv4 loopback, stateless text generation. The authenticated Aesir endpoint
remains available. A separate Ollama-compatible mode was verified with the
native Gemma 4 E2B Q4_K_M profile at 16,384 context on an RTX 4070 Laptop GPU.
Neither mode is ready for public or multi-tenant deployment.

## Ollama-compatible offline mode

Install a model into the durable catalog once, while the GGUF is available:

```bash
.aesir/aesir create gemma4-e2b:latest \
  --modelfile Modelfile.gemma4-e2b \
  --model .aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
```

The import copies and hashes the model into `.aesir/models/blobs/sha256/`, then
atomically publishes `gemma4-e2b:latest` in `catalog.v1`. Later launches resolve
and rehash that immutable blob without network access:

```bash
.aesir/aesir serve gemma4-e2b:latest --accel cuda --ollama \
  --context 16384 --max-tokens 256
```

This binds only `127.0.0.1:11434` and intentionally uses no bearer key so local
Ollama clients can connect. It implements `GET /api/version`, `GET /api/tags`,
`POST /api/show`, `POST /api/generate`, and `POST /api/chat`. Generation and
chat require `"stream":false`; NDJSON streaming is not implemented. Recognized
`options` are `num_ctx`, `temperature`, `top_k`, `top_p`, `min_p`, `seed`, and
`repeat_penalty`. Unknown fields/options and contexts above the loaded service
context fail explicitly. Chat accepts bounded `system`, `user`, and `assistant`
messages and requires the final message to be from the user.

```bash
curl -sS -H 'Content-Type: application/json' \
  -d '{"model":"gemma4-e2b","prompt":"What is two plus two?","stream":false,"options":{"num_ctx":16384}}' \
  http://127.0.0.1:11434/api/generate

curl -sS -H 'Content-Type: application/json' \
  -d '{"model":"gemma4-e2b","messages":[{"role":"user","content":"Hello"}],"stream":false}' \
  http://127.0.0.1:11434/api/chat
```

The mode is single-session and one-request-at-a-time. Each HTTP generation
resets KV history; clients send prior messages again to `/api/chat`. It does not
implement Ollama pull/create/delete/copy, embeddings, tool calls, multimodal
messages, remote listening, or streaming.

## Start and call

### Sampling defaults and request overrides

`serve` accepts `--temperature`, `--top-k`, `--top-p`, `--min-p`,
`--repeat-penalty`, `--repeat-last-n` and `--seed`, with the same native grammar,
ranges and defaults as `chat`. Repetition-window size is fixed at startup.
For sampling, precedence is native defaults < explicitly present JSON config
fields < stored native recipe < explicit serve flags < explicit request fields.
Omitted request fields inherit the service baseline, not the
previous request's settings; temperature 0 and seed 0 are explicit overrides.
Unsupported request fields still fail instead of being silently ignored.
S07b2 applies stored recipe `num_ctx`, `num_predict`, seven native sampling
parameters and `SYSTEM`. Explicit service flags override those fields; use
`--system ""` to explicitly clear a recipe prompt. Request system values/messages
override the configured baseline. Unsupported native recipe directives/settings
fail before allocation, including custom TEMPLATE/MESSAGE, stops and presence/
frequency penalties. `--config file` (`-c`) applies the existing temperature,
top_p and model-store fields; it cannot be combined with `--model-store`.
No file is loaded implicitly. Unconnected non-neutral config intent fails before
keys/model access; see [the configuration contract](CONFIGURATION.md).

Use `serve <model> --accel cuda --show-settings` to inspect the resolved startup
requests as JSON without opening a listener or reading an API key. Chat exposes
the same preview. A zero context/reply request means automatic; preview is not
hardware planning, model architecture validation or successful inference.

For example, starting with `--temperature 0.8 --top-k 20 --seed 99` and sending
an OpenAI request with `"temperature":0` uses greedy temperature with top-k 20
and seed 99 still present in its effective policy. The next request without
sampling fields starts again from temperature 0.8, top-k 20 and seed 99.

### Authenticated service

Build the native executable as described in [the runtime guide](NATIVE_RUNTIME.md).
Create a random service key natively in a protected Linux directory. The file must be a
regular file owned by the current effective user, with no group/other permission
bits. Symlinks and special files are rejected. Keys contain 32..256 letters,
digits, hyphens or underscores, optionally followed by one newline. Generate
random key material; do not use a human-chosen password. `keygen` obtains
256 bits from Linux `getrandom`, writes a private temporary file, syncs it, and
publishes it with an atomic no-replace hard link within the opened parent
directory. For example:

```bash
mkdir -p "$HOME/.config/aesir"
./aesir keygen "$HOME/.config/aesir/service.key"
./aesir serve models/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --accel cuda --api-key-file "$HOME/.config/aesir/service.key" \
  --context 8192 --max-tokens 256 --timeout-ms 30000
```

The key command refuses to overwrite an existing file or symlink, never prints
the credential, and needs a filesystem supporting hard links and directory
synchronization. Normal failure paths remove only their owned temporary links.
A crash can leave a private `.aesir-key-*` temporary file; inspect it before
manual cleanup. A synchronization failure after publication can leave a complete
key while reporting failure; retry never overwrites it. The service reads the
key at startup; restart it to rotate the key. Do not store it in Git, a public
directory, a URL or command-line arguments. Keep key files on a Linux filesystem
with working POSIX permissions, not a Windows mount that exposes mode 0777.

The default port is 18434. `--port` accepts 1024..65535. The only bind address
is `127.0.0.1`; there is no external-listen option. `--profile auto|llama3|gemma4`,
`--context`, `--device auto|N` and `--reserve-mib` use the same validated model and
memory admission as chat. Unsupported devices/models fail without CPU fallback.
Readiness is printed only after loading the model and binding the socket.

This shell example passes the credential through curl's standard input rather
than exposing its value in the process argument list:

```bash
{
  printf 'header = "Authorization: Bearer '
  tr -d '\n' < "$HOME/.config/aesir/service.key"
  printf '"\n'
} | curl --silent --show-error --config - \
  -H 'Content-Type: application/json' \
  --data '{"prompt":"What is two plus two? Answer with one word.","max_tokens":16}' \
  http://127.0.0.1:18434/v1/generate
```

Both tested models returned `Four`, one generated token, `finish_reason: eos`,
`backend: cuda` and `cpu_offload: 0`. Prompt/context counts depend on the model's
native framing. Authentication is also required for `GET /health`, which reports
the actually loaded profile, context and backend. Unknown routes return 404.

## Request and response contract

`POST /v1/generate` accepts a flat JSON object. Unknown/duplicate fields, nested
values and unsupported types are rejected. Strings support UTF-8, JSON escapes
and valid UTF-16 surrogate pairs. Malformed Unicode and NUL are rejected.

| Field | Contract |
|---|---|
| `prompt` | Required nonempty string, at most 64 KiB decoded UTF-8. |
| `system` | Optional string, at most 64 KiB; defaults to a concise helpful assistant. |
| `max_tokens` | Positive integer, at most the server's `--max-tokens` ceiling; defaults to the smaller of 256 and that ceiling. Context admission can reject a request even below this limit. |
| `timeout_ms` | Positive integer no greater than the server's `--timeout-ms` limit; defaults to that limit. Clients cannot disable it. |
| `temperature`, `top_k`, `top_p`, `min_p`, `repeat_penalty`, `seed` | Same native sampling bounds/defaults as [chat](NATIVE_RUNTIME.md). Counts/seeds are unsigned decimal integers; floating controls use unsigned decimal notation, without exponents. Repetition window stays 64. |

Each admitted generation resets logical history and sampling state. This API
does not retain a conversation, share KV prefixes or offer session IDs. Loaded
weights and allocated CUDA storage are reused. Reset does not securely erase
GPU memory. Calls are serialized through `ControlledTextSession`; transport
does not own tensors or execute kernels.

Successful JSON responses contain `text`, `finish_reason`, `prompt_tokens`,
`generated_tokens`, `context_used`, `backend` and `cpu_offload`. A generation
deadline may return a partial answer with `finish_reason: timeout`; a deadline
during prefill returns HTTP 504 without an answer. The next valid request resets
state before use. Invalid JSON/control values return 400; model/context admission
returns 422; failed CUDA execution stops the service after attempting a 500.
No engine error, request body or key value is echoed in an error response.

## Bounds and threat model

- Exactly one active request; kernel listen backlog 8. Queued clients can time
  out while another request runs. There is no worker pool, batching or fair queue.
- Headers: 8 KiB maximum, 64 fields, 1 KiB per value. Bodies: 128 KiB maximum.
  Decoded generated text: 1 MiB maximum before JSON escaping.
- One strict HTTP/1.1 request per connection, mandatory local `Host`, explicit
  `Content-Length` for POST, exact `Content-Type: application/json`. No chunked
  uploads, `Expect`, pipelining or keep-alive reuse. Every response closes.
- Authentication is checked before reading a request body or invoking inference.
  An equal-length credential comparison scans every byte. No cryptographic
  constant-time claim is made about compiler transformations or the whole server.
- Browser `Origin`, `Referer` and `Sec-Fetch-Site` headers are rejected; there is
  no CORS support. Host checks reduce DNS-rebinding exposure. This is a native
  local-client endpoint, not a directly exposed browser application backend.
- `--io-timeout-ms` defaults to 5,000 and accepts 1..30,000. A single deadline
  covers receiving headers and body; sends have a separate bounded deadline.
  Nonblocking I/O handles partial transfers and suppresses SIGPIPE.
- `--timeout-ms` defaults to 30,000 and accepts 1..3,600,000. It checks native
  token boundaries, not in-flight kernel execution, loading or tokenization.
  A disconnected client's generation can continue until completion or deadline.
- Ctrl+C/SIGTERM stop the foreground service cooperatively, including an active
  generation; clients may receive a closed connection during shutdown. Native
  descriptor and CUDA owners release resources. It is not a daemon manager.
- Logs contain request sequence, phase, status and elapsed time, not prompts,
  responses or credentials. Model-loading diagnostics still identify the model.

There is no TLS, remote access, rate limiter, per-user quota, multi-tenant
isolation, audit-log persistence, streaming response API, deployment supervisor
or independent security assessment. A local user who can read the key can use
the model. Do not publish this port through a proxy/tunnel and assume these
controls establish an Internet-facing service.

## Reproduction and evidence

```bash
python scripts/test_native_service.py --binary ./aesir \
  --llama models/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --gemma models/gemma-4-E4B-it-Q4_K_M.gguf
```

Python is the external test/client driver; inference and serving stay native
Mojo. The test creates temporary keys and owned processes, checks `/proc` for
actual loopback binding and worker signal masks, exercises real generation and
seeded replay, rejects unsafe key files and malformed protocol inputs, forces
slow-client and prefill deadlines, then verifies recovery and active shutdown.
Tests use context 512, a 64-token ceiling and a 300 ms I/O deadline to make bounds
observable on the available GPU. They do not prove service operation at every
possible context size or under sustained load. Four counted protocol/request/path
cases join the master suite; hosted CPU CI does not claim GPU service execution.

Native key publication is also tested without a GPU, including filename byte
lengths 1..33, Unicode, mode/format, existing files/symlinks, a four-process
publication race and temporary-link cleanup:

```bash
python scripts/test_native_keygen.py --binary ./aesir
```

This probe runs in hosted CI. Every POSIX path uses an explicitly terminated
owned byte buffer; Mojo strings are not assumed to be C strings. The service
probe now creates its actual API key through the native `keygen` command.
