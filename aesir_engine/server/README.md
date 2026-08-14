# Server Domain: BifrostGate

## Domain Overview
The `server` domain currently provides a POSIX socket and response-shape
scaffold, not an operational inference service.

- **`api.mojo` (BifrostGate):** Known generation, embedding, compatibility, and swarm paths return HTTP 501; unknown paths return HTTP 404.
- **`openai.mojo` (OpenAIGate):** Produces explicitly marked local formatter-scaffold JSON. It does not establish protocol compatibility.

## Key Invariants
- `BifrostGate` must NEVER import `core` or access memory pools directly.
- No HTTP route currently executes `AesirEngine.generate()`.
- Explicit string buffer lifetime management (`_ = response`) prevents socket memory corruption.
