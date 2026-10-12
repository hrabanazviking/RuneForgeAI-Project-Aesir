# Dependency manifest

Historical native CUDA path (outside the current Hailo-only mission): the Gemma 4 path uses the repository's locked Mojo 1.0.0 / MAX 26.5.0
environment (`pixi.lock`). MAX owns CUDA contexts, buffers and launches; all
model operations and tokenization are Mojo code. NVIDIA's system driver is a
prerequisite. No external inference engine or Python runtime is used for chat.

The loader uses Linux libc file mapping and bounded process/file operations.
Hugging Face transfers use the system `curl` (HTTPS certificate verification,
redirect restrictions, resume, optional parallel ranges), `sha256sum` (GNU
coreutils), and Linux procfs descriptor paths so transfer, verification and
publication remain bound to the opened staging inode.
Content-addressed model-store import and verification also use `sha256sum`,
reading the exact inherited open descriptor through Linux procfs.
Model-store `gc` uses GNU `find` (findutils) over an inherited procfs directory
descriptor with NUL-delimited output; it never interpolates a shell command.
These are separate executables invoked with argv, never a shell command string.
They are justified because this toolchain has no maintained native HTTPS client;
argv-only process execution is isolated in the loader and
`core/posix_process.mojo`. Curl must support `--parallel`
for `--connections > 1` (curl 7.66+). No executable is vendored.

`scripts/offline.py prepare` records SHA-256 and byte size for itself,
`aesir.config.json`, `pixi.lock`, the prepared Mojo compiler, the four named MAX
runtime libraries used by the launch check, the native executable, the selected
catalog blobs, and the currently resolved Pixi executable/version. This is a
bounded prepared-checkout inventory;
it does not enumerate every ELF/system/driver transitive dependency.

Test-only tools: Python standard library for orchestration, `tokenizers 0.22.2`
for independently generated tokenizer fixtures, and `gguf 0.19.0` with NumPy
for independent real-weight dequantization/matvec expectations. These are never
imported by production Mojo. See `THIRD_PARTY_NOTICES.md` for the pinned MIT
architecture/quantization reference. Public model weights are external artifacts
under their model license, pinned in the task contract and `GEMMA4_CUDA.md`.

## Direct Hailo-10H GenAI path — accepted 2026-10-12

The owner said “proceed” after the direct HailoRT route, compatible compiled model artifact, and first device smoke were disclosed. This accepts the narrow C ABI/C++ dependency exception recorded in `DEPENDENCY_POLICY.md` and D-002/D-005 in `docs/HAILO10H_DECISION_LOG.md`. It supersedes historical study-only/no-runtime/no-HEF restrictions for this route. The inference target remains Hailo-10H.

| Dependency / artifact | Qualified version / identity | Purpose and boundary | Origin / license |
|---|---|---|---|
| HailoRT GenAI C++ API and shared runtime | Installed 5.3.0; qualification is limited to this version | Direct in-process Hailo LLM execution through `aesir_engine/hailo10h_bridge.cpp`. Linked system dependency; vendor source is not vendored. The Mojo boundary carries C-compatible handles, strings, sizes, and status values. | Hailo Technologies, [official source](https://github.com/hailo-ai/hailort). Installed GenAI `hailo/genai/llm/llm.hpp` header and `hailort` package copyright record identify MIT. Preserve the license/copyright notice if redistributing covered material. |
| GNU C++ standard runtime (`libstdc++`) | System runtime used with GCC 12 on the qualified host | Required by the bridge and HailoRT C++ ABI. C++ types and exceptions stay inside the bridge; no runtime source is vendored. | Free Software Foundation / GCC; installed `libstdc++6` package copyright record identifies GPLv3 or later with GCC Runtime Library Exception 3.1. |
| OpenSSL EVP digest API (`libcrypto`) | Installed OpenSSL 3.0.22; slice 138 qualification in progress | Non-LLM SHA-256 model-file integrity only, bound to an opened regular HEF descriptor. The installed streaming digest API avoids implementing cryptography in the bridge or spawning a separate hashing process. Linked system library; no vendor source copied, no network operation, and no package installation for this change. | OpenSSL Project, Apache-2.0 as identified by the installed `libssl3` package copyright record. [Official EVP digest API](https://docs.openssl.org/3.0/man3/EVP_DigestInit/); see `THIRD_PARTY_NOTICES.md`. |
| Hailo PCIe driver and device firmware | Installed 5.3.0 on the observed Hailo-10H | System device prerequisites managed separately from Æsir; not bundled by this integration. | Installed Hailo system stack. Package/source and redistribution terms must be retained for any future package that ships them. |
| Qwen2.5-1.5B-Instruct compiled Hailo artifact | Official Hailo 5.3.0 artifact; 2,464,582,493 bytes; SHA-256 `0856a10c2b804cfe1590b80aa5e28369eb7169a9b36de836420a0b8cdf5b8d05` | External local GenAI HEF for the narrow device smoke. Not committed, vendored, or distributed by the source change. Requires a compatible HailoRT/model pair; no GGUF CPU fallback is admitted. | [Official Hailo artifact](https://dev-public.hailo.ai/v5.3.0/blob/Qwen2.5-1.5B-Instruct.hef). Model and compiled-artifact redistribution terms still need a retained license record before packaging/distribution; HailoRT's MIT license does not establish the model's license. |

This profile uses the host for application orchestration and session/result ownership. HailoRT GenAI's installed header documents full LLM-pipeline device offload; that API contract is distinct from independently exposed per-layer execution telemetry. The previous eight-token smoke is narrow runtime evidence, not a portability, quality, or complete dependency-closure claim. Bounded canonical build, lifetime, timeout, admission, and prior-context restoration evidence are recorded in slices 135–137. Slice 138 file-identity-bound fingerprint/provenance changes are being qualified: the intended Linux-specific path loads HailoRT from the already opened descriptor through procfs and checks file metadata before/after model loading. This intended behavior is not yet marked accepted.
