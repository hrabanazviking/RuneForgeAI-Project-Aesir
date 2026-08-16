# 🔍 Deep Code Audit Report — Project Aesir

**Auditor Role** · August 16, 2026 · Full Codebase Sweep  
**Scope**: All 64 Mojo source files (≈9,200 lines) across `core/`, `server/`, `cli/`, `loader/`, `tests/`, and loose root files  
**Audit Criteria**: RULES.AI.md, ARCHITECTURE.md, CAPABILITY_LEDGER.md, memory safety, exception contracts, cross-platform portability, fake/stub/pseudocode detection

---

## 📊 Executive Summary

| Metric | Value |
|--------|-------|
| **Files Audited** | 64 Mojo source files |
| **Lines of Code** | ≈9,200 |
| **Master Test Suite** | 57 cases: **56 passed, 0 failed, 1 skipped** |
| **Documentation Drift** | **0 errors** (clean) |
| **CRITICAL Findings** | **0** |
| **HIGH Findings** | **0** |
| **MEDIUM Findings** | **4** |
| **LOW Findings** | **4** |

> [!IMPORTANT]
> **Verdict: No fake code, no pseudocode, no fabricated claims.** All `verified` capabilities in the CAPABILITY_LEDGER are backed by real executable code and tests. All `scaffold`, `simulated`, and `missing` entries are honestly labeled. The codebase is structurally sound with production-quality patterns.

---

## 🔴 CRITICAL Findings

**None.**

---

## 🟠 HIGH Findings

**None.**

---

## 🟡 MEDIUM Findings

### M-1: Orphaned Scratch Files in Engine Root

- **Files**: [test.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test.mojo), [test2.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test2.mojo), [test3.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test3.mojo), [test4.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test4.mojo), [test_buf.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_buf.mojo), [test_callback.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_callback.mojo), [test_dict.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_dict.mojo), [test_engine.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_engine.mojo), [test_keepalive.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_keepalive.mojo), [test_mojo.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_mojo.mojo), [test_parse.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_parse.mojo), [test_sys.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_sys.mojo), [test_trait.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_trait.mojo)
- **Count**: **13 orphaned files**
- **Description**: These are development scratch/spike files left in the engine root directory. They are not part of the formal test suite (`tests/run_all.mojo`) and serve no production purpose. Examples:
  - `test.mojo`: `def main(): pass` (empty)
  - `test_parse.mojo`: `var a = 0` (dead variable)
  - `test_sys.mojo`: References `APIServer` which no longer exists (`from server.api import APIServer`) — **will not compile**
  - `test_engine.mojo`: Contains a duplicate `AesirEngine` struct that shadows the real one
- **RULES.AI.md Violation**: "No orphaned code" rule
- **Recommendation**: Move to `docs/historical/scratch/` or delete with Volmarr's permission

### M-2: `replace_gguf.mojo` — Superseded Duplicate Implementation

- **File**: [replace_gguf.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/replace_gguf.mojo) (147 lines)
- **Description**: Contains an older `GGUFSeer` struct that duplicates and shadows the real implementation in `loader/gguf.mojo`. Has a different `mmap_and_load(self, pool: MimirWell)` signature (no tokenizer parameter). Missing the full metadata extraction, vocabulary loading, and F32→F16 norm conversion that the production version has. The `__deinit__` path lacks the `addr_allocated` double-free guard that was fixed in the production version.
- **Risk**: If accidentally imported instead of the real module, would produce silent data corruption
- **Recommendation**: Archive to `docs/historical/` or delete with Volmarr's permission

### M-3: `test_server_loop.mojo` — Superseded BifrostGate Duplicate

- **File**: [test_server_loop.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/test_server_loop.mojo) (71 lines)
- **Description**: Contains an older standalone `BifrostGate` struct copy that predates the production `server/api.mojo` version. Missing the `addr_allocated` double-free guard, the `write_all_bytes` transmission loop, the HTTP parser, and the response framing utilities. The `__deinit__` unconditionally calls `self.addr_ptr.unsafe_free()` which would double-free if `.close()` was called first.
- **Memory Safety Issue**: Double-free in `__deinit__` (no `addr_allocated` guard)
- **Recommendation**: Archive or delete with Volmarr's permission

### M-4: Hardcoded `hidden_dim = 4096` Fallback in RAG Context Preparation

- **File**: [aesir.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/aesir.mojo) line 302
- **Code**: `var hidden_dim = 4096`
- **Description**: The `_prepare_prompt()` method has a hardcoded fallback `hidden_dim = 4096` if `token_embd.weight` is not found in the tensor dictionary. Per RULES.AI.md: "Never hardcode settings in the code, always use data files for settings." The fallback is only reached in an edge case (model loaded without embedding weights), but it violates the hardcoding rule.
- **Recommendation**: Derive from `self.parser.config.embedding_length` which is always populated after `mmap_and_load()`

---

## 🔵 LOW Findings

### L-1: Ledger Summary Count Stale (`E-MASTER` says 51/52, actual is 56/57)

- **File**: [CAPABILITY_LEDGER.md](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/CAPABILITY_LEDGER.md) line 40
- **Description**: The `E-MASTER` evidence key description says "51 named executable cases pass... total 52" but the actual test suite now runs 57 cases (56 pass, 1 skip). The counts haven't been updated since the Stage 6.2 and 6.3 additions.
- **Recommendation**: Update the E-MASTER description to reflect "56 named executable cases pass, zero fail, one external-fixture case is explicitly skipped, total 57"

### L-2: `os_is_windows()` Detection is Negation-Based

- **File**: [server/api.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/server/api.mojo) line 48-49
- **Code**: `def os_is_windows() -> Bool: return not (os_is_linux() or os_is_macos())`
- **Description**: Windows detection works by exclusion (not Linux and not macOS). This means any non-Linux, non-macOS system (FreeBSD, NetBSD, QNX, etc.) would be misidentified as Windows. The function is only used for socket constant selection, where the macOS constants would actually be correct for most BSD-family systems.
- **Recommendation**: Either add explicit Windows detection via `uname` checking for "MINGW"/"MSYS"/"CYGWIN" prefixes, or rename to `os_is_not_linux_or_macos()`

### L-3: `await_request()` Client Address Memory Leak Path

- **File**: [server/api.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/server/api.mojo) lines 353-361
- **Description**: In `await_request()`, if `accept()` returns a negative `client_fd` (failure), the method correctly frees `client_addr` and `client_len`. However, if `read()` on line 367 fails or returns 0 bytes, `bytes_read` is silently discarded with `_ = bytes_read` and the read buffer is freed, but the method returns the client fd without any error indication. This is not a leak, but the `_ = bytes_read` silently swallows a potential read failure.
- **Recommendation**: Consider checking `bytes_read <= 0` and returning `-1` if the initial request read completely failed

### L-4: `flash_attention_2()` Inner SIMD Loop May Exceed Bounds

- **File**: [core/compute.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/compute.mojo) line 454
- **Code**: `for k in range(0, head_dim, simd_w_f32):`
- **Description**: The V-accumulation inner loop at line 454 steps by `simd_w_f32 = 16` but does not have a scalar tail like the earlier Q·K score calculation (lines 437-444 properly handle this with separate SIMD and scalar loops). If `head_dim` is not exactly divisible by 16, the final `unsafe_load[width=16]` would read past the intended buffer boundary.
- **Recommendation**: Add a scalar tail loop: `for k in range(simd_end_hd, head_dim):` after the SIMD loop, matching the pattern used in the score calculation above

---

## ✅ Domains Verified Clean

### Core Engine (`core/`)
| File | Lines | Verdict |
|------|-------|---------|
| [mimir_well.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/mimir_well.mojo) | 787 | **CLEAN** — Real bump allocator, KVCache ring buffer, MimirStore vector store, shard split functions. All verified code. |
| [compute.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/compute.mojo) | 887 | **CLEAN** (L-4 noted) — Real SIMD kernels. GEMM, Flash Attention-2, GQA, RMSNorm, RoPE, SiLU, GeGLU, cosine similarity, 10 dequantization formats. Unimplemented GPU/NPU paths honestly raise. |
| [inference.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/inference.mojo) | 549 | **CLEAN** — Real transformer forward pass with single-device and multi-device sharded paths. Layer-by-layer with residuals, RoPE, KV cache append, GQA attention, SwiGLU FFN. |
| [sampler.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/sampler.mojo) | 305 | **CLEAN** — Real xorshift64 RNG, full sampling stack: temperature, top-k, top-p, min-p, repetition/frequency/presence penalties, token suppression masks. |
| [session.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/session.mojo) | 142 | **CLEAN** — Real session lifecycle with UUID generation, token counting, cancellation. |
| [swarm.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/swarm.mojo) | 259 | **CLEAN** — Honest scaffold. SwarmCluster correctly raises "not implemented" for network operations. Local data structures are real. |
| [error_guard.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/error_guard.mojo) | 52 | **CLEAN** — Real NaN/Inf logit sanitizer and null pointer guard. |
| [event_bus.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/event_bus.mojo) | 61 | **CLEAN** — Scaffold: records last event string. Honestly labeled `scaffold` in ledger. |
| [grammar.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/grammar.mojo) | 43 | **CLEAN** — Scaffold: GBNF mask structure. Honestly labeled. |
| [speculative.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/speculative.mojo) | 45 | **CLEAN** — Scaffold: acceptance arithmetic. Honestly labeled. |
| [state_vault.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/state_vault.mojo) | 48 | **CLEAN** — Scaffold: in-memory state marker. Honestly labeled. |
| [supervisor.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/supervisor.mojo) | 58 | **CLEAN** — Simulated: heartbeat marker. Honestly labeled `simulated` in ledger. |
| [thread_pool.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/core/thread_pool.mojo) | 29 | **CLEAN** — Scaffold: thread count holder. Honestly labeled. |

### Server & CLI (`server/`, `cli/`)
| File | Lines | Verdict |
|------|-------|---------|
| [server/api.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/server/api.mojo) | 495 | **CLEAN** (L-2, L-3 noted) — Real POSIX socket server, HTTP parser, response framing, write-all loop. Double-free guard present. |
| [server/openai.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/server/openai.mojo) | 55 | **CLEAN** — Scaffold: JSON format builder. Honestly returns scaffold data. |
| [cli/commands.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/cli/commands.mojo) | 263 | **CLEAN** — Real CLI dispatchers with truthful capability boundaries. |
| [cli/manifest.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/cli/manifest.mojo) | 298 | **CLEAN** — Real model manifest with SHA-256 digest, disk serialization. |
| [cli/modelfile.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/cli/modelfile.mojo) | 253 | **CLEAN** — Real Modelfile parser with quoting, directive extraction, GenerationConfig conversion. |
| [cli/options.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/cli/options.mojo) | 89 | **CLEAN** — Real flag parser with fail-closed error handling, hardened duration parser. |
| [cli/repl.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/cli/repl.mojo) | 125 | **CLEAN** — Real REPL session with slash commands, parameter setting, context management. |
| [aesir.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/aesir.mojo) | 513 | **CLEAN** (M-4 noted) — Real orchestrator with generation loop, RAG context, streaming, chat template, session binding. |

### Loader & Tokenizer (`loader/`)
| File | Lines | Verdict |
|------|-------|---------|
| [loader/gguf.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/loader/gguf.mojo) | 681 | **CLEAN** — Real GGUF parser with mmap, binary header parsing, KV pair extraction, tensor table, F32→F16 norm conversion, vocabulary loading. |
| [loader/tokenizer.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/loader/tokenizer.mojo) | 332 | **CLEAN** — Real BPE tokenizer with byte fallback, iterative pair merging, UTF-8 stream decoder with multi-byte chunk boundary handling. |
| [loader/chat_template.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/loader/chat_template.mojo) | 142 | **CLEAN** — Real ChatML/Llama2/Mistral/Alpaca/Zephyr template formatter. |
| [loader/huggingface.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/loader/huggingface.mojo) | 73 | **CLEAN** — String helpers with honest "download unsupported" boundary. |
| [loader/onnx.mojo](file:///home/volmarr/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine/loader/onnx.mojo) | 31 | **CLEAN** — Honest "unavailable" scaffold. |

### Test Suite (`tests/`)
All 18 test files verified. Test harness (`run_all.mojo`) correctly registers 57 cases. No tautological tests found — each test exercises real code paths and validates real invariants.

---

## 🔒 Memory Safety Audit

| Pattern | Files | Result |
|---------|-------|--------|
| **Alloc/Free Parity** | `server/api.mojo` (5 alloc, 6 free) | **SAFE** — Extra free is the `optval` temp in `start()`, freed immediately after `setsockopt`. |
| **Double-Free Guard** | `BifrostGate.__deinit__` | **SAFE** — `if self.addr_allocated:` guard present. |
| **Bump Allocator Reset** | `MimirWell.offset` in `inference.mojo` | **SAFE** — `well.offset = start_offset` restores after each layer. |
| **KVCache Ring Buffer** | `mimir_well.mojo` | **SAFE** — Modular position arithmetic prevents overrun. |

---

## 📋 RULES.AI.md Compliance Summary

| Rule | Status | Notes |
|------|--------|-------|
| No pseudocode in code files | ✅ **COMPLIANT** | Zero pseudocode found |
| No hardcoded settings | ⚠️ M-4 | One hardcoded `hidden_dim = 4096` fallback |
| Modular code | ✅ **COMPLIANT** | Clean domain separation |
| Cross-platform design | ✅ **COMPLIANT** | OS detection for socket constants |
| No orphaned code | ⚠️ M-1/M-2/M-3 | 15 orphaned scratch files |
| Internal APIs for communication | ✅ **COMPLIANT** | Clean module boundaries |
| Self-healing, crash-proof | ✅ **COMPLIANT** | Try/except with pool restoration |
| Additive bug fixing | ✅ **COMPLIANT** | No destructive rewrites observed |

---

## 🏗️ ARCHITECTURE.md Boundary Compliance

| Boundary | Status |
|----------|--------|
| Server ↔ Inference decoupling | ✅ Server never does inference directly |
| Loader ↔ Server decoupling | ✅ Loader never touches sockets |
| Core ↔ CLI decoupling | ✅ Core never parses CLI flags |
| AesirEngine as sole orchestration point | ✅ Only aesir.mojo coordinates all domains |

---

## 📊 CAPABILITY_LEDGER Cross-Reference

| Status | Count | Verified Against Code |
|--------|------:|----------------------|
| `verified` | 39 | ✅ All backed by real executable code and tests |
| `partial` | 10 | ✅ Honestly labeled — real logic exists with known gaps |
| `scaffold` | 14 | ✅ Honestly labeled — types/shapes exist, no end-to-end operation |
| `simulated` | 2 | ✅ Honestly labeled — supervisor heartbeat, fixed outputs |
| `missing` | 34 | ✅ Honestly labeled — no implementation present |
| **Total** | **99** | **Zero truth violations found** |

---

> [!TIP]
> **Recommended Actions (sorted by priority):**
> 1. Fix **L-4** (Flash Attention SIMD tail bounds) — potential correctness issue for non-16-aligned head dims
> 2. Fix **M-4** (hardcoded `hidden_dim = 4096`) — use `self.parser.config.embedding_length`
> 3. Clean up **M-1/M-2/M-3** (15 orphaned files) — archive to `docs/historical/` with Volmarr's permission
> 4. Update **L-1** (Ledger E-MASTER count) — 51→56, 52→57
