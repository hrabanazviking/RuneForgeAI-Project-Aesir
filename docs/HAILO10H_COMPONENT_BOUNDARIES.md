# Hailo-10H component boundaries

**Roadmap Slice 005 — host and accelerator responsibilities**

| Component | Owns | Must not do |
|---|---|---|
| Æsir host application | CLI/service lifecycle, request validation, model selection, prompt preparation required by the chosen backend, local logging policy, and response delivery | Execute LLM layers, logits, or token generation on the Pi CPU or CUDA |
| Hailo backend adapter | Implement the stable Æsir request contract in Mojo over the verified native Hailo path; verify device/model identity; return generated tokens/text and device status | Silently switch runtimes or report an accelerator execution that was not observed |
| Hailo-10H device/runtime | Execute supported LLM model inference and expose supported health/performance evidence | Depend on a CPU LLM fallback for any part of generation |
| UI/client | Collect user input and display progress, results, and errors | Select a different inference backend behind the user's back |

The adapter is the only boundary between Æsir's existing request surface and
the Hailo execution path. It must preserve the no-HEF/no-DFC/no-vendor-runtime
constraints in `HAILO10H_ARCHITECTURAL_CONSTRAINTS.md`; Hailo-Ollama and HailoRT
are not approved implementation dependencies under the current project
requirements. The native device interface remains a feasibility gate.

Tokenization, request parsing, network framing, and UI rendering may run on the
Pi as ordinary support work when required. Model forward passes, logits
calculation, sampling that is part of the generation engine, and token
generation must not be routed to CPU LLM code. The final design must measure
the chosen native execution path's actual device placement and document any host-side
operations accurately.

## Slice 005 acceptance

- Host, adapter, Hailo device/runtime, and UI ownership are distinguished.
- No component may silently select CPU or CUDA LLM inference.
- Backend choice remains evidence-driven rather than assumed from an API name.
- Hailo placement is to be confirmed through runtime and device evidence.
