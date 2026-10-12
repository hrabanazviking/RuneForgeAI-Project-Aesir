# Hailo-10H interaction loop

**Roadmap Slice 002 — target user and primary loop**

## Target user

The first user is the Æsir keeper/developer operating the supported Raspberry
Pi 5 and Hailo-10H installation locally. The initial workflow is a private,
single-user text-generation session, entered through Æsir's existing local CLI
or local service interface. A browser UI, voice workflow, multi-user service,
and remote access are not prerequisites for proving this loop.

## Primary interaction loop

1. The user starts Æsir and selects a model that has a verified Hailo-10H
   execution artifact and a compatible runtime.
2. Æsir validates the model/runtime/device combination and reports the active
   model and Hailo-10H backend.
3. The user submits a text prompt and generation limits.
4. Æsir performs request validation and non-LLM orchestration on the Pi, then
   submits LLM inference to Hailo-10H.
5. Æsir returns generated text, preferably as a stream when the chosen backend
   supports streaming, and reports completion or a specific error.
6. If Hailo-10H is unavailable or inference fails, Æsir stops with an explicit
   error; it does not route the request to a Pi CPU LLM backend.

## Slice 002 acceptance

- The initial target user and single-user local scope are written down.
- The interaction's request, accelerator execution, response, and failure
  steps are explicit.
- CLI/local service are identified as the first interface candidates based on
  current repository capabilities; choosing the canonical entry point remains
  an architecture decision for a later slice.
- Every LLM inference step is assigned to Hailo-10H, with CPU LLM fallback
  explicitly forbidden.
