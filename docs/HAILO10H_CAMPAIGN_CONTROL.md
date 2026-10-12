## Slice 116 — Define conditional weight/activation representation (complete; hypothetical only)

A future Hailo representation cannot be selected until the device’s accepted tensor format, quantization parameters, memory layout, and operation descriptors are publicly specified or experimentally verified under an approved proof. The current ARMVEGR FP16/FP32 host representation is documented as source behavior only and must not be treated as the accelerator contract. Likewise, Raspberry Pi’s INT4 performance specification does not supply scale/zero-point, packing, accumulator, or layer compatibility rules.

For a future candidate format, each tensor record would need an explicit dtype, shape, strides/layout, quantization parameters where applicable, byte length, alignment, ownership, and versioned provenance. These are requirements for evidence collection, not a proposed executable serialization. No format, quantizer, conversion path, or device buffer was implemented or exercised. No CPU LLM execution is in scope.

Evidence: docs/plunder/HAILO_CONFIG_SURFACE.md elements 1–4; Slices 114–115; armvegr/infer.mojo.
