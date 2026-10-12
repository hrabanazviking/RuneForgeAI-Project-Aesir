## Slice 117 — Map attention and KV-cache only to measured Hailo support (complete; none measured)

TinyLlama’s source uses grouped-query attention (32 query heads to 4 key/value heads), RoPE on query/key vectors, per-token KV-cache writes, scaled dot-product scores, softmax, and weighted value accumulation. No corresponding Hailo-10H operation sequence, memory residency contract, cache capacity behavior, or measured attention primitive is established for Æsir. The H111 NO-GO prevents a legitimate on-device mapping, and public product-level memory/TOPS claims do not fill these operation-level gaps.

Status: attention and KV-cache support on Hailo are **UNVERIFIED**. Do not implement a host-side attention substitute as model inference. Revisit only when transport, compute configuration, memory semantics, and operation proof gates pass.

Evidence: armvegr/infer.mojo; armvegr/kv_cache.mojo; docs/plunder/HAILO_CONFIG_SURFACE.md; docs/smidr/PHASE_D_GATE.md; Slice 114.
