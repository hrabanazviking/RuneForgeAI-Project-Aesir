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
Volmarr clarified that Gemma/CUDA inference must be implemented natively in Mojo
with full CUDA support. External inference backends are excluded. Extend the
loader with validated packed GGUF ownership and Gemma metadata; native core
kernels own quantized matrix operations, normalization, RoPE, attention, PLE,
feed-forward layers and logits. Preserve device-resident weights and KV cache.
Use upstream source only as an attributed specification or independent test
oracle, never as the production inference implementation.

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

## Reproduced baseline regression

The locked native build passed. The unmodified master suite returned 142 passed,
2 failed, 1 skipped (145 total). Both failures are deterministic-forward-pass
contracts: default calls now sample at temperature 0.7 despite the prior greedy
contract and the tests' zero-logit argmax oracle. Restore temperature 0 for the
two low-level overload defaults; generation configurations explicitly passed by
the engine remain unchanged. Do not change expected test outputs.

The physical GPU-3 matrix test passed on this RTX 4070. This establishes only
matrix-kernel execution, not model inference. The built CLI explicitly rejected
`run absent.gguf --accel cuda --max-tokens 16384 Hello` before opening a model.
# Native implementation boundaries

The loader owns bounded GGUF parsing and Gemma 4 merge-rank tokenization.
The core owns packed CUDA weights, activations, KV storage, all transformer
operations and token selection. The CLI owns download arguments, session input
and user-visible logs. GPU failures must propagate; CPU fallback is forbidden.
The implementation targets dense text-only Gemma 4 E4B and rejects incompatible
metadata. Multimodal and MoE support are outside this task.

Architecture reference: ggml-org/llama.cpp commit
`62acc89c26c66076cb72e049f307fbe93b8b9750`, MIT; see THIRD_PARTY_NOTICES.md.
Any external tokenizer or inference program used for parity is a test oracle,
never the production engine. Existing locked MAX GPU host APIs provide device
ownership and kernel launches; model mathematics remain native Mojo.

## Recorded implementation result

The native downloader verified the pinned complete model. Native CUDA E4B
execution completed repeated 20-turn runs with the requested 16,384 completion
ceiling; the accepted corrected conversation generated 693 tokens and used
1,535 context positions, with 20 EOS stops. Independent packed-matrix and
tokenizer checks and the repaired 32-token CPU reference passed. The native
session owns generation and state; CLI owns transcript I/O. See
`docs/GEMMA4_CUDA.md` and local `.aesir/evidence/` logs for commands/boundaries.
No external inference engine is used. Publication and final regression status
are recorded in the final task response.
