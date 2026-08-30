# Gemma 4 Q4_K_M CUDA conversation acceptance contract

## Authorization and requested result

Volmarr requested a download through Aesir's built-in Hugging Face feature,
20 coherent user/assistant exchanges, NVIDIA CUDA inference without CPU model
fallback, a 16,384 maximum generation-token setting, visible conversation logs,
and verified improvements published to `main`. Implementation and fixes needed
for this result are authorized. Model weights and raw logs remain outside Git.

## Inspected starting point

- Starting revision: `0b9fe2d`.
- `loader/huggingface.mojo` invokes shell-interpolated `curl`, with no immutable
  revision, digest validation, or atomic destination protection. Its stale ledger
  entry still describes an unsupported operation.
- `cli/commands.mojo` exposes `pull`, but hardcodes an unrelated default model
  filename. Single-shot CUDA selection is explicitly rejected.
- `cli/repl.mojo` constructs an engine per turn and requests GPU execution;
  `core/inference.mojo` still calls unavailable realm-only GPU gateways.
- The Gemma 4 graph and chat template are not implemented. Accepting nonempty
  architecture names does not establish compatibility with Gemma 4.
- The installed standalone Mojo compiler cannot import the required MAX GPU
  package. Restore the repository's locked environment before source diagnosis.
- Observed hardware: NVIDIA GeForce RTX 4070 Laptop GPU, 8 GiB VRAM, WSL2 Ubuntu.

## External artifact

- Repository: `unsloth/gemma-4-E4B-it-GGUF`.
- Revision: `bfc15c382204943c3a8fff0c750b94ae2364d7a3`.
- Filename: `gemma-4-E4B-it-Q4_K_M.gguf`.
- Hub-reported size: `4977171584` bytes.
- Hub-reported SHA-256:
  `85a896a047553e842f25297ee5b031d64ff30147d9c4af17b1e4b394cd1fab87`.
- Publisher model card identifies Apache-2.0. This is an external acceptance
  artifact, not a tracked test weight or proof of native model support.

## Ownership and first implementation slice

Loader owns safe HTTPS download, artifact identity, validation and publication.
CLI owns explicit download parameters and truthful diagnostics. Core owns actual
model execution and device resources; templates belong to loader and conversation
history to the CLI/session owner. Preserve existing CPU inference and all tests.

First restore the locked build, reproduce the relevant baseline failures, then
repair the built-in downloader and exercise it against the pinned artifact.
Native Gemma/CUDA compatibility remains a separate acceptance boundary. An
optional external inference backend is a material design choice and must be
explicitly approved; it must never be described as native Mojo inference.

## Invariants and verification

- No shell execution of user-provided repository, filename or destination text.
- Download failure, HTTP errors and integrity mismatch cannot produce success or
  overwrite an existing completed destination.
- Public downloads verify TLS; redirects cannot downgrade HTTPS.
- Immutable revision, actual bytes and SHA-256 identify downloaded weights.
- All model computation claimed as CUDA must execute on the selected GPU. Host
  orchestration/tokenization is reported separately; utilization is measured,
  never represented as a guaranteed constant 100 percent.
- Twenty genuine model responses must retain prior conversation context, with
  a human-readable transcript and execution metadata. No canned responses.
- The 16,384 generation-token ceiling is distinct from context capacity; history
  plus generation must fit the configured context and available GPU memory.
- Run focused loader/CLI regression tests, the counted master suite, native
  build, negative control, repository consistency and fixture gates. Preserve
  baseline failures explicitly rather than weakening checks.
- Validate the physical CUDA path and the downloaded model before any capability
  promotion. Record exact execution commands, outputs and limits.
- Review every staged change, publish only authorized verified improvements to
  `main`, verify remote revision and report CI truthfully.

## Completion boundary

This contract is planning evidence only. It does not claim a completed download,
Gemma compatibility, CUDA model inference, a conversation, or passing tests.
