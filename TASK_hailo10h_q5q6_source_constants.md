# Original Q5_K and Q6_K static source representations

Date: 2026-10-20. Contract before research/implementation.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Parent: source-compiler and original-program-delivery tasks.

Consumer: the native source-weight conversion backend. Publish the exact packed
Q5_K/Q6_K source field layouts and pinned MIT provenance before writing original
Mojo readers. Study only format/interface facts from the previously licensed
public ggml pin a05c9922613c6a2230dbb1d0de679519ecafb4f0; do not copy/translate
its implementation. Reuse original Aesir half-bit expansion and field readers.

Expose bounded owned source constant components: original scale bits, exact
binary32 scale representations, integer quant/scale/minimum factors and source
binding. Decode complete requested windows across groups/blocks/rows without
materializing a model or selecting a Hailo precision/packing format. Validate
live owner, packed shape/extent, selection and explicit host element bound.
No model/layer/attention evaluation or device access is authorized by this slice.

Use independent schema packing, exhaustive small factor domains, boundary/
malformed/ownership tests and the already isolated pinned test-only static
constant oracle, extending it only after recording its exact provenance. Never
run its model forward, use its production runtime, invoke an outside compiler
or require a specially compiled model. Preserve negative evidence. Publish
original verification and continue actual numerical configuration/CCW, packing,
placement, upload/activation and first hardware arithmetic gaps automatically.
Broad ordinary-model support remains the fixed target, not a source-kind cap.
