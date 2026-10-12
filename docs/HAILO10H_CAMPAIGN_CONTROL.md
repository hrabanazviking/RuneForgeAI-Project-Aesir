## Slice 111 — Inventory selected model operations (complete; host inventory only)

The repository’s documented integrated ARMVEGR inference path targets TinyLlama-1.1B-Chat-v1.0 and its forward/decode code. Its model layer uses FP16 weight projections (Q/K/V, attention output, FFN gate/up/down, output logits), RMSNorm, interleaved-pair RoPE, grouped-query attention with score scaling and softmax, KV-cache append/read, residual additions, SiLU gating/elementwise products, and final greedy or configurable sampling. Prefill uses matrix-matrix projections; decode uses matrix-vector projections. The tokenizer and model parsing are host-side preparation responsibilities, not accelerator compute evidence.

This inventory is derived by source inspection only. It does not claim any operation is supported or executed on Hailo-10H. The campaign gate remains NO-GO, so all Hailo mappings and inference integration stay blocked; no CPU LLM execution was performed as part of this slice.

Evidence: armvegr/infer.mojo (model shape, projection calls, attention, cache and activation flow); armvegr/gemv.mojo; armvegr/gemm_tuned.mojo; armvegr/rmsnorm.mojo; armvegr/rope.mojo; armvegr/kv_cache.mojo; armvegr/sampler.mojo; armvegr/sp_tokenizer.mojo; CAPABILITY_LEDGER.md SMIÐR Phase-D NO-GO section.
