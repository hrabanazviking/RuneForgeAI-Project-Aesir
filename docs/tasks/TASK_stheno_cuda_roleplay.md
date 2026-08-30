# Native Stheno CUDA roleplay acceptance contract

## Requested outcome

Use Aesir's built-in Hugging Face download function to fetch
`bartowski/L3-8B-Stheno-v3.2-GGUF`, Q4_K_S. Implement any native Mojo CUDA
support required, run 20 actual roleplay exchanges with an 8,192-new-token
ceiling, preserve and show the conversation, and push verified milestones to
`main`. No external inference engine or CPU model offload is permitted.

## Artifact and baseline

- Baseline: `240de29acef29b132803df54f401d0f3ddb60651`.
- Repository revision: `dcf7446b0049ee524188ea0b15bd9a5e24cd889b`.
- File: `L3-8B-Stheno-v3.2-Q4_K_S.gguf`.
- Bytes: `4692668960`.
- SHA-256: `2234b17374b1f4781b663c03df24d2bc64fc8474c427b7ca318948535e65e259`.
- The publisher identifies CC-BY-NC-4.0; weights remain external and their
  license does not become the engine license.
- Observed accelerator: NVIDIA RTX 4070 Laptop GPU, 8188 MiB, WSL2 Ubuntu.

## Ownership and limits

The loader owns GGUF admission and Llama 3 byte-level BPE/chat framing. Core
owns device weights, activations, F16 KV, Llama transformer math and session
state. CLI owns architecture selection, prompt input and durable logs. Reuse
validated native packed matvec primitives without changing Gemma semantics.

The generation ceiling and context capacity are distinct. Respect the model's
declared context; do not silently truncate history or claim an unverified RoPE
extension. When available context is shorter than the requested generation
ceiling, report context exhaustion explicitly. An 8K ceiling does not promise
an 8K response after a nonempty prompt in an 8K context.

## Acceptance and publication

1. Pin and verify the full artifact through the existing Aesir downloader.
2. Compare native token IDs with an independent pinned tokenizer, including
   whitespace, contractions, digits, Unicode and chat framing.
3. Verify actual CUDA operations and model generation on the named GPU, with
   zero CPU model offload; preserve GPU telemetry.
4. Conduct a coherent fantasy roleplay across 20 real user/model exchanges.
   Preserve initial and any revised runs; do not edit generated responses.
5. Retain CPU and Gemma regressions and pass native build, master suite,
   negative control, repository and fixture gates.
6. Publish the contract, a verified implementation milestone, and final
   evidence/documentation to `main` without weights or raw runtime artifacts.

## Milestone 1: download and tokenizer

The native `aesir pull` command completed the full pinned download and verified
both size and SHA-256. The new native Llama 3 byte-level BPE passed 12 independent
Hugging Face token-ID cases, UTF-8 decode round trips and the system/user/assistant
chat frame. Unicode categories are compiled from pinned Unicode 16 data; no
Python, regex library or external tokenizer runs in production.

## Milestone 2: native CUDA inference

The separate `Llama3CUDASession` admits the dense 32-layer Llama 3 8B profile,
uploads packed weights once and uses a device-resident F16 KV cache. Native
chat accepts `--profile llama3 --context 8192 --max-tokens 8192`; context
exhaustion is distinct from the requested reply ceiling.

Physical RTX 4070 verification passed 35 independent real-weight Q4_K/Q5_K/Q6_K
dot-product checks (maximum absolute error `4.172325e-07`) and 34,816 independent
NumPy comparisons of CUDA RoPE, SiLU and grouped-query attention values. The
boundary-position test exposed F32 rotary phase error; device-side F64 phase
reduction corrected it without moving model computation to the CPU. The
counted master suite remains 147 passed, 0 failed, 1 skipped, 148 total.

A short native roleplay smoke test completed with natural EOS. The first full
roleplay attempt was deliberately interrupted during turn 1 when the rotary
precision check failed; its unedited partial logs remain in `.aesir/evidence/`.
## Final acceptance

The corrected native run completed all 20 exchanges with natural EOS, 5,152
generated tokens and 6,514 context positions; every turn retained the 8,192
completion ceiling. All 32 layers, weights, activations and F16 KV remained on
CUDA with zero CPU model offload. Telemetry reached 100% utilization and
7,136 MiB total device memory used.

The tokenizer proof now includes 15 cases, adding three independent Vietnamese
whole-segment lookup regressions. Additional tests passed eight malformed
profile cases, actual CUDA session closure/rejection boundaries, the pinned
32-token CPU oracle, the Gemma CUDA smoke regression, master suite and negative
control. Numerical checks also cover nonzero F16-cache offsets and rounding.

The [published transcript](../evidence/stheno-roleplay-20.md) is byte-identical
to the native log. Its connected story and model-generated continuity defects
are assessed candidly in [the guide](../STHENO_CUDA.md); no response was edited.
Current status, interfaces, ownership/flow maps, ledger and test documentation
now distinguish both supported CUDA profiles from unsupported generalizations.

Published milestones: contract `4b36383`, tokenizer/download `5b244e7`, native
CUDA implementation `b141543`; final evidence and documentation follow them on
`main`. The three initial milestones passed GitHub Actions.
