# Native ordinary safetensors source inventory

Date: 2026-10-20. Contract before source inventory implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.
Scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Broaden the original SMIÐR source input path beyond GGUF without running model
math. First audit existing project `armvegr/safetensors.mojo` header/descriptor
ownership and bounds, plus source inventory consumers. Read/pin the public
safetensors format license before format material, extracting schema facts only.
Publish exact format facts and a narrowed adapter/repair contract before code.
Reuse sound existing project parsing rather than create a competing parser.
Do not import or invoke CPU inference/tensor evaluation/conversion accidentally
through a metadata-only path. Preserve historical evidence and CPU guardrails.

The bounded inventory should retain ordinary tensor names, dtype, all shape
axes, checked element/byte counts and actual file spans in owned values. Enforce
explicit header/tensor/rank/work bounds before allocations, strict numeric/UTF-8
and duplicate/overlap/extent validation, malformed-input cleanup and owner
lifetimes. Establish scalar/empty tensor and metadata behavior from the actual
format, not guessed assumptions. File/buffer identity and sharded/architecture
mapping remain explicit follow-up work; reject unimplemented formats honestly
without claiming permanent model restrictions. No user model conversion or
special compiled artifact prerequisite may be added.

Verification must use independent synthetic byte fixtures and an isolated
licensed format oracle where useful, signed/overflow/truncation/duplicate/
UTF-8/shape/extent adversaries, owned-result destruction/mutation and read-only
resource cleanup. No real model download, model/layer/attention evaluation,
CPU/CUDA/cloud inference, device access or external compiler is part of this
source metadata slice. Continue actual numerical instruction/configuration/
placement/upload/activation/result work toward broad model execution. Publish
verified narrow progress and advance automatically.
