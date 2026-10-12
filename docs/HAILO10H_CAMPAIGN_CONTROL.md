## Slice 120 — Publish operation coverage matrix (complete; integration blocked)

| Æsir model operation | Required phase | Current Hailo-10H proof | Status |
|---|---|---|---|
| Weight projection GEMV/GEMM | Prefill + decode | None; H019 op/config and H102 transport gaps | UNVERIFIED |
| RMSNorm | Every transformer layer | None | UNVERIFIED |
| RoPE | Query/key processing | None | UNVERIFIED |
| KV-cache transfer/read/write | Decode | No Æsir DMA/residency contract or device proof | UNVERIFIED |
| Grouped-query attention score products | Prefill + decode | None | UNVERIFIED |
| Softmax | Prefill + decode | None | UNVERIFIED |
| Attention value aggregation | Prefill + decode | None | UNVERIFIED |
| Residual additions and activation/gating | Every transformer layer | None | UNVERIFIED |
| Final normalization and vocabulary projection | Output logits | None | UNVERIFIED |
| Sampling/token selection | After valid accelerator logits | Host orchestration allowed, but no logits source exists | BLOCKED by compute |
| Tokenization, request management | Host preparation | Host-side responsibilities only; do not treat as model execution | Not a Hailo compute claim |

No model integration may begin until every required model computation row has a verified Hailo primitive, data path, completion contract, and correctness evidence. The matrix does not assert that silicon cannot perform an operation; it records the absence of qualifying Æsir evidence. Pi CPU LLM development, fallback, shadow inference, and serving remain out of scope.

Evidence: Slices 111–119; docs/plunder/HAILO_CONFIG_SURFACE.md; docs/smidr/PHASE_D_GATE.md.
