# Hailo-10H request and response boundary

**Roadmap Slice 003 — initial inputs, outputs, and integrations**

## Initial inputs

- A user-selected model identifier that resolves to a source model format
  supported by Æsir and a verified native Hailo-10H execution configuration.
  Hailo-compiled HEF artifacts are outside the campaign constraints.
- A text prompt, with optional conversation turns only after the selected
  model's chat template is verified.
- Bounded generation settings supported by the selected Hailo backend, such
  as maximum output tokens and sampling controls.
- Local configuration selecting the Hailo-10H execution path.

The request layer must reject missing, malformed, or unsupported model and
generation settings before inference. It must not silently reinterpret a
model artifact for CPU execution.

## Initial outputs

- Generated text, returned as a complete response or a stream when the chosen
  Hailo backend supports it.
- A terminal outcome: completed, cancelled, timed out, invalid request, model
  unavailable, or Hailo/runtime failure.
- Non-content diagnostics identifying the model, runtime, accelerator, and
  timing/resource counters when the backend exposes them.

Prompts and responses are not included in default operational logs.

## Initial integrations

- Existing Æsir local CLI and local service are the integration candidates for
  the first end-to-end workflow.
- A Mojo-native Hailo-10H execution path is required between Æsir request
  handling and device inference; it must not require HailoRT or Hailo-Ollama.
- Cloud model APIs, remote model execution, browser UI, voice input/output,
  retrieval systems, and action-taking tools are outside the first interaction
  boundary.

## Decisions deliberately left open

The concrete native Hailo execution interface, accepted source model format,
supported model list, and canonical CLI-versus-service entry point remain open.
They must be established with evidence and comply with
`HAILO10H_ARCHITECTURAL_CONSTRAINTS.md` before they are claimed as supported.
Every selected path must execute LLM inference on Hailo-10H; this document adds
no CPU LLM path.
