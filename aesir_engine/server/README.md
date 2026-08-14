# Server Domain: BifrostGate

## Domain Overview
The `server` domain implements the high-concurrency network transport layer.

- **`api.mojo` (BifrostGate):** POSIX raw socket HTTP server listening on port `11434`. Accepts Ollama-compatible API requests (`/api/generate`) and streams JSON responses back across the socket.

## Key Invariants
- `BifrostGate` must NEVER import `core` or access memory pools directly.
- All request execution is delegated through `AesirEngine.generate()`.
- Explicit string buffer lifetime management (`_ = response`) prevents socket memory corruption.
