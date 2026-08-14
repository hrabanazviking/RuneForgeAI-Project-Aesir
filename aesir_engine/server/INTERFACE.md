# Server Domain Interface Specification

## Public Structs & Functions

### `BifrostGate`
POSIX socket transport scaffold. Known generation, embedding, compatibility,
and swarm routes return HTTP 501; unknown paths return HTTP 404. No route
claims successful inference or protocol compatibility.

```mojo
def unsupported_http_response(capability: String) -> String: ...
def route_not_found_response() -> String: ...
```

```mojo
struct BifrostGate:
    var port: Int
    var server_fd: Int32
    var addr_ptr: Pointer[Int16, MutUntrackedOrigin]

    def __init__(out self, port: Int = 11434): ...
    def start(self) -> Bool: ...
    def await_request(self) -> Int32: ...
    def send_response(self, client_fd: Int32, content: String): ...
    def send_chunk(self, client_fd: Int32, chunk: String): ...
    @staticmethod
    def send_chunk_static(client_fd: Int32, chunk: String): ...
    def send_embeddings_response(self, client_fd: Int32, embedding_data: String): ... # Slice 5
    @staticmethod
    def send_embeddings_response_static(client_fd: Int32, embedding_data: String): ... # Slice 5
    def dispatch_http_route(self, client_fd: Int32, path: String, payload: String = ""): ... # Slice 11 & Phase 14 (/api/swarm/nodes, /api/swarm/join, /api/swarm/dispatch, /api/swarm/status)
    def __deinit__(deinit self): ...
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

