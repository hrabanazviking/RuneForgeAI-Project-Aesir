# Server Domain Interface Specification

## Live native loopback service (2026-08-31)

`local_protocol.mojo`: `LocalHTTPHead` validates bounded HTTP/1.1 and local Host,
mandatory authentication and supported framing. `FlatJSON` validates UTF-8 and
flat string/number JSON with strict duplicate/escape checks. These replace the
legacy permissive parser for live network input.

`local_transport.mojo`: `OwnedFD`, `load_service_key`, `listen_local`,
`accept_local`, `accept_local_ready`, `receive_head`, `receive_body` and
`send_local` own Linux x86-64
nonblocking sockets/files, absolute read/send deadlines and descriptor cleanup.
Only IPv4 loopback is supported. Signals are borrowed pollable descriptors;
transport neither consumes them nor imports inference kernels.

`cli/native_serve.mojo` supplies the loaded-session loop and request policy.
The native, Ollama and OpenAI-subset routes remain serialized through one CUDA
session. Incremental NDJSON/SSE output is supported; up to eight waiting
sockets can be admitted into a bounded FIFO, with HTTP 503 on overflow/expiry.
The default queue limit is four and the default wait deadline is 30 seconds.
See `docs/NATIVE_SERVICE.md` and `docs/API_SUPPORT_MATRIX_V1.md` for exact
route, field, transport and threat limits. The declarations below also retain
legacy primitives/formatters that are not exposed routes.

## Public Structs & Functions

### Sampling precedence (S07a)

`OpenAIRequest` and `OllamaRequest` accept an optional validated
`NativeSamplingConfig` baseline. The native `GenerateRequest` does likewise.
Construction copies it, then applies only supplied fields using core sampling
validation; explicit zero temperature/seed are not treated as missing. The
loaded service passes the same startup baseline to every request, independently
of the last session policy. No protocol imports CLI sampling syntax anymore.
Existing supported-field sets are unchanged: OpenAI permits temperature/top_p/
seed; native and Ollama additionally permit top_k/min_p/repeat_penalty.
Requests cannot change repeat_last_n after allocation.

### Request reply and context limits (S07b4a)

`local_protocol.mojo::resolve_request_token_limit` owns the shared immutable
service reply ceiling policy: omission inherits it; a positive request may
lower it but never exceed it. The ceiling is bounded to 1..32768. Zero is only
an internal omission sentinel; native/OpenAI max_tokens and Ollama
options.num_predict reject explicit zero, negative modes and non-integer input.
Native request defaults no longer truncate configured ceilings above 256.
All three generation routes validate limits before resetting their session.

`require_loaded_context` admits omission or the exact allocated context only.
Ollama num_ctx parses explicit 2..32768, then the generation route checks exact
agreement; smaller requests are rejected, not accepted without effect. Other
adapters still do not expose request-time context resize. Parser/policy tests
are not physical inference or complete third-party API compatibility proof.

S07b2 supplies recipe/CLI system defaults to the request parsers as well.
An explicit native/Ollama `system` value (including empty text), or OpenAI chat
system messages, overrides the baseline rather than appending to it. Without an
override, recipe SYSTEM or service `--system` is inherited. Default baseline
strings are bounded to 64 KiB. No-recipe/no-CLI calls retain each endpoint's
previous system default. Existing restrictions on empty chat messages remain.

`api.mojo::json_escape_string` preserves complete UTF-8 spans and escapes JSON
quotes, backslashes, and ASCII control characters. It is shared by CLI JSON
renderers and protocol formatters; callers provide admitted `String` values.
Unicode regression coverage includes mixed 2/3/4-byte characters adjacent to
escaped ASCII controls, including the built doctor/inspection report paths.

### `BifrostGate`
POSIX socket and HTTP framing primitives. OpenAI-, Ollama-, llama.cpp-, and
Swarm-shaped operational routes return HTTP 501; unknown paths return HTTP 404.
`OpenAIGate` remains a local formatter scaffold and is not wired to successful
compatibility endpoints.

```mojo
struct HTTPRequest:
    var method: String
    var path: String
    var protocol: String
    var headers_raw: String
    var body: String
    var content_length: Int

def parse_http_request(raw_request: String) raises -> HTTPRequest: ...
def dispatch_http_request(req: HTTPRequest) -> String: ...
def build_http_response(status_code: Int, status_text: String, content_type: String, body: String) -> String: ...
def build_sse_chunk(event: String, data: String) -> String: ...
def build_http_chunk(data: String) -> String: ...
def write_all_bytes(client_fd: Int32, data: String) -> Bool: ...
def unsupported_http_response(capability: String) -> String: ...
def route_not_found_response() -> String: ...
def legacy_route_response(path: String) -> String: ...
```

```mojo
struct BifrostGate:
    var port: Int
    var server_fd: Int32
    var addr_ptr: Pointer[Int16, MutUntrackedOrigin]
    var addr_allocated: Bool

    def __init__(out self, port: Int = 11434): ...
    def is_valid(self) -> Bool: ...
    def set_nonblocking(self, non_blocking: Bool = True) -> Bool: ...
    def start(self) -> Bool: ...
    def close(mut self): ...
    def await_request(self) -> Int32: ...
    def send_response(self, client_fd: Int32, content: String): ...
    def send_chunk(self, client_fd: Int32, chunk: String): ...
    @staticmethod
    def send_chunk_static(client_fd: Int32, chunk: String): ...
    def send_embeddings_response(self, client_fd: Int32, embedding_data: String): ...
    @staticmethod
    def send_embeddings_response_static(client_fd: Int32, embedding_data: String): ...
    def dispatch_http_route(self, client_fd: Int32, path: String, payload: String = ""): ...
```

### `OpenAIGate` (formatter scaffold)
Local JSON-shape formatter only. Completion payloads carry
`aesir_status=formatter_scaffold`, timestamps and usage counts are zero, and
embeddings return an unsupported object. This is not OpenAI API conformance.

```mojo
struct OpenAIGate:
    @staticmethod
    def format_chat_completion(model: String, text: String, finish_reason: String = "stop") -> String: ...
    @staticmethod
    def format_chat_chunk(model: String, text: String, finish_reason: String = "") -> String: ...
    @staticmethod
    def format_models_list(models: String) -> String: ...
    @staticmethod
    def format_embeddings(model: String) -> String: ...
```

### Reserved Swarm REST Endpoints

`/api/swarm/nodes`, `/api/swarm/status`, `/api/swarm/join`, and
`/api/swarm/dispatch` return HTTP 501. They do not inspect or mutate a cluster.

### Native private-key publication

`aesir keygen <new-private-file>` calls `server/keyfiles.create_service_key`.
Linux `getrandom` supplies a 256-bit key; a separate random staging name is
exclusively created in the opened parent directory. File sync precedes atomic
no-replace linking; directory sync follows owned temporary-link removal. Existing
outputs are never deleted or replaced. Contents are never printed. All POSIX
path pointers refer to explicitly terminated, owned byte buffers. The native
key probe runs in CI without a GPU; crash/persistence limits are documented in
`docs/NATIVE_SERVICE.md`.
