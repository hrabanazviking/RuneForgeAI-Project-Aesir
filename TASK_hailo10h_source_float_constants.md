# Floating source constant decoding

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Consumer: an original Mojo compiler constant reader over the existing live,
bounded PackedGGUF source owner. Read explicit tensor element windows and emit
owned IEEE binary32 bit patterns for source F32, F16 and BF16 constants. Preserve
source tags/extents and element order. Decode only source representation; do not
select a Hailo precision/layout, allocate device weights or execute any model
operation. BF16 expansion and binary16 normalization must be explicit integer
bit operations with defined zero/subnormal/infinity/NaN-payload behavior.

Check tensor kind, logical element count, source extent, first/count arithmetic
and a caller-declared host window bound before allocating/copying. No tensor
pointer or mapping borrow may escape. Refuse unsupported packed quantized kinds
with a named next conversion gap; that is incremental compiler coverage, never
permission to narrow the owner's source-model target. Carry fingerprint and
device format/execution proof flags as false.

Acceptance: independent Python struct floating-format oracles, exhaustive
16-bit patterns (with explicit NaN classification/payload policy), F32 pass-
through vectors, row-crossing and tail windows, malformed/range/extent/refusal
and returned ownership. Source hashes must stay unchanged. No model, layer,
attention or CPU/CUDA/cloud LLM inference. Tests inspect static constants only.
Production is Mojo; no external implementation may be copied or translated.
After verification, publish and continue into quantized source constants and
actual backend/program encoding under the same broad Hailo source-model goal.
