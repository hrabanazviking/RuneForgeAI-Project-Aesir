## Slice 112 — Map model operations only to verified Hailo primitives (complete; none verified)

The current evidence inventory contains no operation primitive that has passed a real on-device Hailo-10H execution proof under Æsir’s no-HEF/no-DFC/no-vendor-runtime constraints. Therefore no TinyLlama operation is currently mapped as Hailo-supported. Projection GEMV/GEMM, RMSNorm, RoPE, grouped-query attention, softmax, KV-cache movement, residual/SiLU elementwise work, and output logits all remain **UNVERIFIED ON HAILO**. Host implementation or ARM64 kernel tests do not establish Hailo execution.

Mapping rule: promote an operation only after (1) an independently described input/output contract, (2) an evidenced legal chip configuration and submission path, (3) correlated Hailo completion/output, and (4) correctness evidence. Current transport/configuration NO-GO fails prerequisites 2–3. No CPU implementation is being developed or used by this roadmap slice as an inference alternative.

Evidence: Slice 111 inventory; docs/smidr/PHASE_D_GATE.md; docs/plunder/HAILO_CONFIG_SURFACE.md; Slices 107–110 above.
