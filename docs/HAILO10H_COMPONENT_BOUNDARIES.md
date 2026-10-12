# Hailo-10H component boundaries

**Roadmap Slice 005 — host and accelerator responsibilities**

| Component | Owns | Must not do |
|---|---|---|
| Æsir host application | CLI/service lifecycle, request validation, model selection, prompt preparation required by the chosen backend, local logging policy, and response delivery | Execute LLM layers, logits, or token generation on the Pi CPU or CUDA |
| Hailo backend adapter | Translate the stable Æsir request contract to the selected Hailo runtime; verify device/model identity; return generated tokens/text and runtime status | Silently switch runtimes or report an accelerator execution that was not observed |
| Hailo-10H device/runtime | Execute supported LLM model inference and expose supported health/performance evidence | Depend on a CPU LLM fallback for any part of generation |
| UI/client | Collect user input and display progress, results, and errors | Select a different inference backend behind the user's back |

The adapter is the only boundary between Æsir's existing request surface and
the Hailo inference stack. Exact process boundaries and whether the adapter
uses Hailo-Ollama, another official Hailo GenAI interface, or a supported
direct runtime API remain undecided until compatibility is established.

Tokenization, request parsing, network framing, and UI rendering may run on the
Pi as ordinary support work when required. Model forward passes, logits
calculation, sampling that is part of the generation engine, and token
generation must not be routed to CPU LLM code. The final design must measure
the chosen runtime's actual device placement and document any host-side
operations accurately.

## Slice 005 acceptance

- Host, adapter, Hailo device/runtime, and UI ownership are distinguished.
- No component may silently select CPU or CUDA LLM inference.
- Backend choice remains evidence-driven rather than assumed from an API name.
- Hailo placement is to be confirmed through runtime and device evidence.
