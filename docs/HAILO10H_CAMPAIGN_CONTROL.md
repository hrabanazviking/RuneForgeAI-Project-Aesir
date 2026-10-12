## Slice 118 — Map prefill/decode dependencies without host LLM math (complete; blocked)

The existing TinyLlama path divides into:

- **Host preparation:** parse model metadata and weights, tokenize prompt, allocate request/session bookkeeping. These are orchestration and data-preparation steps; they do not provide a Hailo model execution path.
- **Prefill model computation:** for each layer, normalization → Q/K/V projections → RoPE → attention score/softmax/value aggregation → output projection → residual → normalization → FFN gate/up projections → activation/gating → down projection → residual; then final normalization and vocabulary projection.
- **Decode model computation:** repeat the layer computation for the current token, with KV-cache reads/writes and one-token projections, then vocabulary projection; a sampler chooses the next token from logits.

All model arithmetic in prefill and decode must execute on Hailo for this campaign. There is no verified operation/configuration/transport set to realize the chains; thus the chain is a requirements map only, not an implementation plan that may silently substitute host math. Tokenization, sampling, and orchestration may remain host responsibilities only after valid Hailo logits exist.

Dependency result: model mapping and implementation remain BLOCKED by Slices 107–110. No model was run.

Evidence: armvegr/infer.mojo; Slices 111–117; docs/smidr/PHASE_D_GATE.md.
