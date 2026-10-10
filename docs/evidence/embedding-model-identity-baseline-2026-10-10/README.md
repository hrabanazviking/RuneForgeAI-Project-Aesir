# Embedding model identity baseline — 2026-10-10

AES500-292 baseline at revision `2fc4b306aaea8942593491968bc1cb77ee0cb7a2`.

- Existing manifest identity implementation: `aesir_engine/cli/manifest.mojo`
  supports `fnv1a64:` and `sha256:` storage identities; blob admission requires
  SHA-256 with 64 lowercase hexadecimal characters.
- Existing public model download accepts expected SHA-256, expected size, and
  immutable repository revision inputs (`aesir_engine/loader/huggingface.mojo`).
- These fields identify GGUF bytes. They do not bind tokenizer, embedding task,
  pooling, normalization, runtime, precision, preprocessing, or corpus identity.
- No dedicated embedding artifact, embedding manifest metadata, or persisted
  RAG vector index is selected in this checkout. `aesir_engine/model.gguf`
  remains a 24-byte placeholder and is not a fixture.

This source inspection executes no model and adds no new schema. The relevant
identity tuple and migration requirements are in
`TASK_embedding_model_identity.md`.
