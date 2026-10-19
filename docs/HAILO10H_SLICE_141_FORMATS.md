# Slice 141 — current formats and architecture inventory

Completed 2026-10-19 against campaign source `1f1766b` and the physical
[slice-140 receipt](HAILO10H_SLICE_140_SMOKE.md). This inventory changes no
runtime admission and promotes no additional model family.

## Active canonical Hailo build

| Surface | Current supported scope | Evidence boundary |
|---|---|---|
| User entry point | Canonical Mojo `main` dispatches `run`, `chat` and `hardware` to the direct Hailo commands. | `aesir_engine/main.mojo`, `aesir_engine/cli/hailo_commands.mojo`; no generic loader is imported into this dispatch chain. |
| Model input | Explicit nonempty regular compiled Hailo GenAI artifact, passed directly to HailoRT `LLMParams` and `LLM::create`. | `aesir_engine/hailo10h_bridge.cpp`; filename extension alone does not prove artifact compatibility. |
| Physically qualified model | Official compiled Qwen2.5-1.5B-Instruct artifact with the exact digest/size in slice 140, HailoRT/firmware 5.3.0, 2048-token capacity. | Real Hailo-10H identity, generation, context lifecycle and unchanged file fingerprints. This is one model/artifact profile. |
| Architecture admission | Exactly one physical HAILO10H endpoint before model creation; model compatibility is then validated by HailoRT. | The adapter does not parse an upstream Transformers architecture or compile arbitrary source weights. |
| Additional catalog models | Potential candidates, individually unqualified until their own pinned artifact/runtime/device acceptance. | A vendor catalog entry is not an Æsir physical receipt. |

The model architecture metadata and tokenizer identity will be recorded in
slice 143 from authoritative model sources. This slice does not infer those
fields from the compiled filename.

## Preserved loader and historical execution surfaces

| Format / family | Repository evidence | Meaning for the current campaign |
|---|---|---|
| GGUF v3 metadata and tensors | `aesir_engine/loader/gguf.mojo` checks GGUF magic/version and metadata; `packed_gguf.mojo` handles packed weight spans. Historical receipts cover specific Llama, Gemma and Qwen-related profiles. | Parsing or past CPU/CUDA execution does not provide a GGUF-to-Hailo compiler. The legacy transformer guard explicitly rejects that representation for Hailo execution. |
| GGUF v2/v3 ARMVEGR loader | `armvegr/gguf_loader.mojo`; ledger entries AES-LOAD-041/042 preserve parser/quantization evidence. | Historical data I/O only for this mission. ARMVEGR LLM inference entry points raise `CpuInferenceProhibited`. |
| safetensors | `armvegr/safetensors.mojo`; ledger AES-LOAD-043/044 records checked JSON metadata, offsets and F16/F32/BF16 tensor conversion. | Tensor reading is not a compiled Hailo GenAI artifact and is not an active canonical model route. |
| Other parser headers / descriptors | Owning loader interfaces document bounded primitives and unsupported model integration. | ONNX/EXL2 or other names are not Hailo LLM compatibility claims. |
| Historical dense CUDA profiles | The repository preserves Gemma 4, Llama 3/Stheno and Llama 3.2 evidence. | They do not authorize a CUDA or CPU substitute in the Hailo-only campaign. |

## Source checks and acceptance

Inspected the actual canonical imports, direct native `LLM::create` call,
regular-file/model-fingerprint ownership, GGUF magic/version guards,
safetensors owner path and the explicit CPU/GPU/GGUF execution refusals in
`core/inference.mojo`, `armvegr/infer.mojo` and `armvegr/f1_infer.mojo`.
All cited source paths exist at this campaign revision. No model was executed
on CPU/CUDA and no parser test was substituted for accelerator inference.

Slice 141 is complete as a repository-grounded inventory. Slice 142 selects
the first vendor catalog candidate while retaining the exact physical profile.
