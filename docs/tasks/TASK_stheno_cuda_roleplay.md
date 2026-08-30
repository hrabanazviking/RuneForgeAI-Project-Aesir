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

This initial contract records intent, not implementation success.
