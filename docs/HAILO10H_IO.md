# Hailo-10H request and response boundary

**Roadmap Slice 003 — initial inputs, outputs, and integrations**

## Initial inputs

- A user-selected model identifier that resolves to an explicitly supported
  Hailo-10H model artifact and matching runtime.
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
- A Hailo-10H runtime/backend adapter is required between Æsir request handling
  and device inference.
- Cloud model APIs, remote model execution, browser UI, voice input/output,
  retrieval systems, and action-taking tools are outside the first interaction
  boundary.

## Decisions deliberately left open

The concrete Hailo backend, model artifact format, supported model list, and
canonical CLI-versus-service entry point must be selected from current
maintained Hailo documentation and verified on the target hardware before they
are claimed as supported. Every selected path must execute LLM inference on
Hailo-10H; this document adds no CPU LLM path.
