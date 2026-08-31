# Server Domain Interface Specification

## Live native loopback service (2026-08-31)

`local_protocol.mojo`: `LocalHTTPHead` validates bounded HTTP/1.1 and local Host,
mandatory authentication and supported framing. `FlatJSON` validates UTF-8 and
flat string/number JSON with strict duplicate/escape checks. These replace the
legacy permissive parser for live network input.

`local_transport.mojo`: `OwnedFD`, `load_service_key`, `listen_local`,
`accept_local`, `receive_head`, `receive_body` and `send_local` own Linux x86-64
nonblocking sockets/files, absolute read/send deadlines and descriptor cleanup.
Only IPv4 loopback is supported. Signals are borrowed pollable descriptors;
transport neither consumes them nor imports inference kernels.

`cli/native_serve.mojo` supplies the loaded-session loop and request policy.
Only authenticated `GET /health` and `POST /v1/generate` execute. Responses are
nonstreaming, stateless and serialized. See `docs/NATIVE_SERVICE.md` for exact
limits, threats and both real-model proofs. The declarations below describe
legacy primitives/formatters, not an exposed compatibility service.

## Public Structs & Functions

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
