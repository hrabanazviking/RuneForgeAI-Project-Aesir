# Project Aesir — Master Interface Directory

> *"Let every boundary declare its contract clearly. Evidence governs execution."*  
> — **Rúnhild Svartdóttir, The Architect**

---

## 🏛️ Repository Interface Structure

Project Aesir enforces modular domain boundaries. Each subsystem contains an `INTERFACE.md` defining its public contracts, data structures, and truth boundaries.

### Domain Interfaces & Present-Tense Status

| Domain | Directory | Primary Contracts | Capability Ledger Status |
|---|---|---|---|
| **Valhalla (CLI)** | `aesir_engine/cli/INTERFACE.md` | Single-shot generation, Modelfile/parser structures, in-memory manifest catalog, slash-command state, and flag parsing | Single-shot and Modelfile parsing are verified (`AES-CLI-002`, `AES-CLI-003`); catalog persistence/operations, interactive inference, and broad option wiring are partial, scaffolded, or missing (`AES-CLI-004`, `AES-CLI-005`, `AES-CLI-008`, `AES-CLI-009`) |
| **Midgard (Server)** | `aesir_engine/server/INTERFACE.md` | `BifrostGate` HTTP Socket Listener, `HTTPRequest`, `OpenAIGate` | Verified POSIX socket setup, HTTP parser & response framing (`AES-SRV-001`, `AES-SRV-002`, `AES-SRV-003` `verified`); chunk forwarding (`AES-SRV-004` `scaffold`) |
| **Loader** | `aesir_engine/loader/INTERFACE.md` | `GGUFSeer`, `RuneWeaver`, `RuneStreamDecoder`, `RuneChatTemplate` | Verified GGUF v3 F16 CPU mmap, GGUFState machine, stream decoder, multilingual corpora & chat templates (`AES-LDR-001`, `AES-LDR-005`, `AES-TOK-003`, `AES-TOK-004`, `AES-GEN-007` `verified`) |
| **Core (Compute, Session & Facade)** | `aesir_engine/core/INTERFACE.md` | `AesirEngine`, `GenerationConfig`, `SessionContext`, `SessionManager` | Verified CPU kernels, scalar tails, GenerationConfig, token suppression masking, finite argmax & session token accounting (`AES-CPU-001`, `AES-CPU-005`, `AES-GEN-005`, `AES-GEN-006`, `AES-GEN-007`, `AES-GEN-008`, `AES-GEN-009` `verified`) |
| **Core (Memory)** | `aesir_engine/core/INTERFACE.md` | `MimirWell` linear allocator, `RuneTensor`, `KVCache` | Verified allocation bounds & checked indexing (`AES-MEM-001`, `AES-MEM-002` `verified`) |
| **Testing** | `aesir_engine/tests/INTERFACE.md` | `TestLedger`, `run_all.mojo`, `test_real_gguf.mojo` | Fail-closed counted runner (`AES-FND-001` `verified`) |

---

## 🛡️ Truth & Capability Alignment Policy

1. **Evidence Boundary**: Declarations in `INTERFACE.md` reflect executable behavior backed by [`CAPABILITY_LEDGER.md`](CAPABILITY_LEDGER.md).
2. **Historical Vision**: Unconstrained target feature designs and long-term interface aspirations are preserved under [`docs/historical/2026-08-16/`](docs/historical/2026-08-16/).
