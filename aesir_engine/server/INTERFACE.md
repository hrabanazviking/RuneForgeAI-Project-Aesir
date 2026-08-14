# Server Domain Interface Specification

## Public Structs & Functions

### `BifrostGate`
Bare-metal HTTP socket server facade (Slice 4 streaming, Slice 5 embeddings response formatting, Slice 11 multi-engine routing, Phase 14 Swarm REST endpoints).

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

### `OpenAIGate` (Slice 11)
OpenAI v1 REST API response formatter and protocol bridge.

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

### Swarm REST Endpoints (Phase 14)
- `GET /api/swarm/nodes`: Returns active mesh cluster nodes and cluster status JSON.
- `GET /api/swarm/status`: Returns cluster health and mesh leader socket endpoint JSON.
- `POST /api/swarm/join`: Enrolls local node into target mesh leader cluster.
- `POST /api/swarm/dispatch`: Routes workload execution across mesh cluster to least-loaded peer node.


