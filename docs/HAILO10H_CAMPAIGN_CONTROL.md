## Slice 113 — Record unsupported or unknown operations (complete)

All operations in Slice 112 remain explicitly unsupported/unverified for Æsir-on-Hailo: projection GEMV/GEMM, RMSNorm, RoPE, grouped-query attention, softmax, KV-cache movement, residual/activation elementwise work, and logits projection. “Unsupported” here means no qualifying Æsir/Hailo-10H proof exists; it does not make a claim about the silicon’s theoretical capabilities or other vendor-supported stacks. Do not replace these operations with CPU LLM math, CPU fallback, or host shadow inference. Any future model request must remain fail-closed until every required operation is verified on Hailo.

Evidence: Slices 111–112; docs/smidr/PHASE_D_GATE.md.
