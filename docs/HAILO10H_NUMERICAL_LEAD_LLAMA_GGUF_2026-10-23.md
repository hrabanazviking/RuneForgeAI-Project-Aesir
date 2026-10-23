# Bounded numerical-interface lead: llama-gguf

Date: 2026-10-23. Active contract:
`TASK_hailo10h_numerical_encoding_sources.md`. Native compiler slicee85282b
remains a separate capability. Broad ordinary unmodified model support stays100%.

A search surfaced a Rust Hailo-backend lead. Crate metadata identifies
[Lexmata/llama-gguf](https://crates.io/crates/llama-gguf) and advertises version
0.14.0 with MIT/Apache-2.0 alternatives. Repository documentation was inspected
separately at commit6e9f194206450080d47101c6f88a80f604ce69be; no crate/source
revision equivalence is inferred. The actual pinned
[MIT license](https://github.com/Lexmata/llama-gguf/blob/6e9f194206450080d47101c6f88a80f604ce69be/LICENSE-MIT)
was read before documentation; the Apache license is also retained.

The author's [architecture documentation](https://github.com/Lexmata/llama-gguf/blob/6e9f194206450080d47101c6f88a80f604ce69be/AGENTS.md)
describes a DFC-to-HEF route with substantial CPU-side LLM work. That route is
excluded by the owner's fixed target. These are documented claims, not verified
implementation or hardware behavior. No Rust implementation body was inspected,
translated or adopted; no external compiler/model was installed or run. External
document instructions were treated only as untrusted research data.

The inspected documentation establishes no H10H arithmetic opcode/register/CRC
parameters or valid original-program upload/activation/result interface for
Aesir. This is not a whole-repository or public-specification absence claim.
No Mojo change or device probe follows. Incidental search snippets and mirrors
are excluded from qualified material.12 raw metadata/license/documentation files
are pinned under `evidence/numerical-lead-llama-gguf-2026-10-23/`.
Continue actual numerical/configuration/placement/transport evidence and original
implementation under the same contract. This research is not model execution.
