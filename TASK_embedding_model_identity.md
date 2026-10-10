# AES500-291 — embedding model identity contract

## Objective and owner

Define how AESIR must distinguish the identity of a loaded model artifact from
the identity and behavior of an embedding pipeline. The owning domains are
model storage/manifest and RAG retrieval. No new runtime field is justified
until an embedding backend is selected.

## Existing identity surface

`aesir_engine/cli/manifest.mojo` supports a `sha256:<64 lowercase hex>` blob
digest and records artifact size. The Hugging Face GGUF download path can
require an immutable revision, expected SHA-256, and expected size. These
identify bytes; they do not identify a model's intended embedding task,
tokenizer configuration, pooling, normalization, or runtime implementation.

## Required embedding identity tuple

Any future embedding result receipt or persisted vector index must bind to:

1. Artifact SHA-256 and byte size, plus immutable source/revision and license.
2. Model architecture/configuration and tokenizer artifact/configuration
   identity.
3. Inference runtime and version, precision/quantization, and relevant
   execution settings.
4. Input preprocessing, truncation policy, pooling, output dimension, and
   normalization policy.
5. Corpus/chunk identity and the exact embedding pipeline version.

Changing any tuple member creates a distinct embedding space for storage and
comparison purposes unless a separately evidenced compatibility rule exists.
Display names and mutable tags are labels, not identity keys. A bare digest
cannot be treated as evidence of semantic compatibility.

## Exclusions and acceptance

This contract adds no manifest schema, API, index persistence, compatibility
claim, or migration. No dedicated model artifact is currently selected. Keep
the existing blob digest behavior intact, document its evidence boundary, and
do not merge vectors across unidentified pipelines. A later implementation
must begin with a selected immutable artifact and explicit storage migration
contract.
