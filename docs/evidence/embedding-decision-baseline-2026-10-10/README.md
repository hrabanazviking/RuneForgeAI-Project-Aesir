# Embedding capability decision baseline — 2026-10-10

AES500-272 baseline at revision `f2c43e1d3d8d7c3eb1306a1cf91af79dc58144cc`.

- Pixi `0.76.2`; Mojo `1.0.0 (ed45d567)`.
- `aesir_engine/loader/corpus_ingestion.mojo` SHA-256:
  `b94dfc972fb447e7e90efdd333e42df2335e90c7d280d476ca62bde7ae3b5b8d`.
- `aesir_engine/aesir.mojo` SHA-256:
  `2cbdf6b76d0cf31e397965c37dbe5c9a16f241da711bebcdb875c9cf5c871445`.
- `aesir_engine/core/mimir_well.mojo` SHA-256:
  `bec756a9144495bc7303dff0e7135ed36b7c46bd4596bf17142497ecbda18d19`.
- `aesir_engine/tests/test_rag.mojo` SHA-256:
  `81368158d9219dc4c43dbeba0642262c62d12f16f9ef5baf8b42d195a7b4c1bc`.
- `aesir_engine/tests/run_all.mojo` SHA-256:
  `5dd46d9e998c162e3f61fa7c55f65f6b2589acef9d735aac698c6357fa0b652f`.
- `CAPABILITY_LEDGER.md` SHA-256:
  `8dfb6106652c16b56c09032988225aeb9437491366714a0779c29762a5d61335`.
- `aesir_engine/model.gguf` is 24 bytes, SHA-256
  `a4e5e156ddec27e286f75328784d7106b60a4eb1d246e950a001a3f944fbda99`; it is
  not a usable model fixture.

`mean_pool_token_embeddings` validates a nonempty token sequence and token-row
bounds before allocation, then computes a direct arithmetic mean from the
provided token table. `AesirEngine.extract_query_embedding` requires loaded
`token_embd.weight`, checks hidden dimension, tokenizes the prompt and calls
that helper. The master has an exact synthetic-row mean test and an explicit
skip for `rag.real_engine_integration`, which requires a validated external
GGUF. No independent embedding oracle or dedicated embedding model is available
in this baseline. No tests are executed by this source/hash capture.
