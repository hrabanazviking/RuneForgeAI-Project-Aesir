# Independent embedding oracle baseline — 2026-10-10

AES500-282 baseline captured at source revision `fa0538f9532e69fd48918819f0cfcc176f925c6f`.

- `aesir_engine/loader/corpus_ingestion.mojo` SHA-256:
  `b94dfc972fb447e7e90efdd333e42df2335e90c7d280d476ca62bde7ae3b5b8d`.
- `aesir_engine/aesir.mojo` SHA-256:
  `2cbdf6b76d0cf31e397965c37dbe5c9a16f241da711bebcdb875c9cf5c871445`.
- `aesir_engine/tests/test_rag.mojo` at baseline SHA-256:
  `81368158d9219dc4c43dbeba0642262c62d12f16f9ef5baf8b42d195a7b4c1bc`.
- Only model-shaped artifact in the checkout is
  `aesir_engine/model.gguf` (24 bytes, SHA-256
  `a4e5e156ddec27e286f75328784d7106b60a4eb1d246e950a001a3f944fbda99`),
  which is an unusable placeholder.
- No dedicated embedding weights or independent expected vectors were found
  in the repository or Hugging Face cache inspected on this host.
- The repository references the other local stack's `nomic-embed-text`, but
  provides no immutable artifact digest, pinned runtime receipt, expected
  vectors, or AESIR-compatible model fixture for it.
- The Pixi environment pins Mojo `1.0.0 (ed45d567)`; it does not declare
  `sentence-transformers`, `transformers`, or `onnxruntime` as dependencies.

This is an availability/source baseline only. No download, inference, model
selection, or oracle comparison was run. Re-run the artifact/cache inspection
before model selection; this receipt makes no assertion about artifacts added
after its capture.
