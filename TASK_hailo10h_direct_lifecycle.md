# Direct Hailo-10H backend lifecycle and CLI

Status: active, 2026-10-12. Owner authorization: continue the Hailo-only roadmap,
push completed slices, and the current `proceed` following the direct HailoRT
implementation report. Keep Project AESIR as the application and Hailo-10H as
the LLM execution target. CPU inference and Hailo-Ollama are excluded.

The narrow direct Mojo/C++ integration at `cee8588` generated text using
HailoRT 5.3.0 and Qwen2.5-1.5B-Instruct on the attached device. It is not yet
a complete application backend: architecture admission is implicit, exception
cleanup can leak the session, output has a fixed buffer, and the old main
imports CUDA modules unavailable on this host.

## Owned changes

- Check exactly one Hailo-10H device before loading; report live device,
  firmware, library version, and model context capacity.
- Give the Mojo session automatic cleanup and the C ABI handles safe lookup
  and operation lifetime. Return all generated text through an owned buffer.
- Abort an incomplete generation after a read failure and reset its context
  before the next attempt; do not replay a prompt or switch inference device.
- Connect the canonical main to Hailo run, persistent chat, device diagnostics,
  and explicit model path arguments without importing other inference engines.
- Add a reproducible build script using the installed HailoRT and Mojo tools.
- Reconcile the roadmap, capability ledger, dependency and interface docs with
  measured behavior. Preserve historical source and investigation records.

Owning domain: AESIR backend orchestration. Native dependency: the installed
HailoRT 5.3.0 C++ GenAI API, linked directly in-process behind AESIR's C ABI.
The model artifact remains external to Git. No package or OS upgrade is needed.

## Acceptance

Compile the C++ boundary with warnings as errors and build the canonical Mojo
entry point. Check CLI argument handling before device allocation. Run one
meaningful real prompt and a multi-turn/reset sequence on the attached
Hailo-10H, recording device identity, model capacity, output and completion
state. Exercise invalid/closed handles through the C ABI without an LLM.
Verify cleanup on normal and failed request paths. No CPU LLM test, benchmark,
or inference is part of these checks. Push each completed slice to the existing
campaign branch and verify its remote head.

Completion of this task establishes the direct backend and usable CLI, not
general custom-model compilation, raw Mojo Hailo kernels, service packaging,
quality/speed acceptance, or all 200 roadmap slices.
