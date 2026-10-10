# AES500-281 — independent embedding oracle contract

## Objective and owner

Establish a reproducible comparison oracle for AESIR query embeddings and
retrieval before claiming semantic embedding quality. The owner is the RAG
retrieval domain, with inputs from `mean_pool_token_embeddings()` and the
loaded-model path in `AesirEngine.extract_query_embedding()`.

## Oracle requirements

An accepted oracle must identify all of the following in a checked-in receipt:

1. A dedicated embedding model and immutable upstream revision, including
   artifact SHA-256 values, tokenizer/configuration, pooling and normalization
   rules, and license/source.
2. A pinned executable/runtime version and exact inference command or script.
3. A deterministic text corpus with expected vectors or independently
   generated raw vectors, plus explicit numeric tolerance and ranking metrics.
4. A clearly stated comparison target. Comparing generative-model token-row
   means with a dedicated sentence model measures disagreement; it cannot
   establish correctness of either model or semantic equivalence.
5. A valid model fixture that AESIR can load, plus a documented path from text
   through tokenization, extraction, and retrieval to the comparison output.

## Current baseline and boundary

Repository and local-cache inspection found no dedicated embedding model,
reference vectors, or valid GGUF fixture. `aesir_engine/model.gguf` is a
24-byte placeholder and cannot serve as a fixture. A mention of
`nomic-embed-text` in another stack is not an immutable artifact receipt.
Therefore the current synthetic arithmetic mean tests prove only the helper's
defined computation. They do not constitute an independent semantic oracle.

## Exclusions

This contract does not download or vendor model weights, add an embedding
runtime, select a model, change extraction behavior, or claim semantic quality.
Those choices require an immutable source/artifact identity, licensing review,
runtime/dependency decision, and suitable valid AESIR model fixture. No such
choice is implied by this contract.

## Acceptance and next gates

- Capture the absent-artifact baseline and source hashes without running an
  unpinned model or network-dependent inference.
- Keep the existing helper interface unchanged until an oracle-backed behavior
  contract is selected.
- Preserve explicit skipped integration status and the current capability
  boundary in `CAPABILITY_LEDGER.md` and `aesir_engine/INTERFACE.md`.
- Do not mark implementation, integration, or semantic-quality acceptance as
  complete without satisfying the oracle requirements above.
- Revisit model selection as a separate user-visible decision after the
  prerequisites and license/runtime impact are concrete.
