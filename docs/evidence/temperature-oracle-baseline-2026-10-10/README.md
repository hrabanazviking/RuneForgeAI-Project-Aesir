# Temperature distribution baseline — 2026-10-10

- Toolchain: `Mojo 1.0.0 (ed45d567)`.
- CPU `sample_token_from_logits` computes softmax of F16 logits divided by temperature after candidate transforms; it uses a 24-bit `RuneRNG.next_float32()` draw and has a fixed `max_logit - 15` candidate window.
- CUDA `sampling_merge` computes relative exponentials in Float64 division then Float32 exp; it uses SplitMix64 keyed by seed and draw index and applies top-k/top-p/min-p filtering. CPU/CUDA random streams are not claimed equivalent.
- Existing CUDA probe covers synthetic sampling configurations but failed on this host with `CUDA_ERROR_INVALID_PTX` during PTX JIT; no physical baseline results are available.
- No model, calibration, quality, or cross-engine parity claim is made.

## Source hashes

- `aesir_engine/core/sampler.mojo` SHA-256: `c1559f6bb7991e276c9512d29f6fe8abbda2ca21b28a72e8cefdeff3804feedc`
- `aesir_engine/core/cuda_sampling.mojo` SHA-256: `6d585f0717613f2b322c190e57bfae6dbae91f26da905794ff8edaec820d761a`
- `aesir_engine/tests/test_inference.mojo` SHA-256: `e1cc5d86f32329d877687b459d51f898114e49f5c5ae96880075613f61d7fe17`
- `aesir_engine/tests/test_cuda_sampling.mojo` SHA-256: `5030cdb35fe3771fd218fd39c2b35b14f562c4fe1a3df833c19ecdba0caf249f`
