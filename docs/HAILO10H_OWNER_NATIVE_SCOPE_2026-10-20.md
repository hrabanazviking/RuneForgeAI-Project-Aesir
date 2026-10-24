# Fixed owner scope: broad models loaded directly by Aesir

Date: 2026-10-20. Latest owner clarification takes precedence over any older
work order, compiler experiment or roadmap dependency.

The owner reaffirmed: **broad model support is 100% the target**. Project Aesir
must run ordinary, unmodified source-model files of a size compatible with
Hailo-10H. Users must not specially compile models or supply vendor-precompiled
artifacts. DFC, an outside model compiler or an external compilation machine
cannot become prerequisites. Aesir owns source loading, representation
conversion, architecture semantics, operation lowering, internal device-code/
configuration generation, orchestration and hardware execution in Mojo.

Internal Aesir translation on model load is implementation work. It must not
be turned into a separate user conversion workflow. Missing formats,
architectures, operators, quantization policies or backend encodings are work
to implement toward the broad target, never permanent eligibility restrictions.
No one except the owner may change the target. Actual supported capability
must still be reported accurately; unimplemented hardware behavior is not
certified merely by documenting the goal or estimating memory.

## Immediate reconciliation

`TASK_hailo10h_first_primitive_source.md` and its outside-compiler experiment
are withdrawn. Historical format/interface facts remain preserved. The two
unpublished Mojo ONNX prototype files and their built, unverified diagnostic
binary are preserved outside the production tree with hashes and the reason
for withdrawal. No compiler was invoked, no model downloaded or evaluated and
no device touched by that experiment. A separately created ONNX test-checker
environment remains outside the repository; it is not a production dependency.

Published original source constant readers, semantic/expanded graph, relative
cache layouts, program header and native transport primitives remain useful
Aesir components. None certifies a complete numerical backend. Current native
compiler work must connect source operations to bounded schedules and actual
Hailo numerical configuration, preserving source identity and resource/format
requirements. Unknown CCWs cannot be replaced with invented opcodes or passed
to a device. Public specifications and isolated independent test oracles may
inform original code; external implementations must not be copied/translated.

Native matrix schedules, source weight byte tiles and original Q5/Q6 static
source components are now independently verified at their host-only boundaries.
Current work follows `HAILO10H_SOURCE_EXECUTION_PROGRESS.md`, with actual numerical
encoding/original-program leads contracted in
`TASK_hailo10h_numerical_encoding_sources.md`. Physical numerical encoding,
placement, upload/activation and first hardware result/cleanup remain required
work toward the same broad goal.

All LLM execution stays on Hailo-10H. Host parsing, Aesir-owned internal
compilation and orchestration remain permitted; CPU/CUDA/cloud LLM inference
and inference proxies remain excluded. Preserve historical/negative evidence
and concurrent work. Continue verify → publish → verify remote → next slice
automatically. The recurring continuation prompt has been updated to retain
these exact scope requirements.


2026-10-24 negative grouped physical boundary:
`docs/HAILO10H_GROUPED_DEVICE_PROBE_2026-10-24.md`. Exactly one contracted child
observes D2H return5,H2D EINVAL and kernel offset20/page512 refusal. No accepted
handle/identity/assigned completion;local cleanup is accounted separately from
remote/hardware idle. The batch is closed without repeat. Next host work follows
`TASK_hailo10h_aligned_grouped_control.md`;numerical/packing/placement/program/
results and broad ordinary UNMODIFIED source-model support100% remain work.
