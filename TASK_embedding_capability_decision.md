# AES500-271 — embedding capability decision contract

## Objective and owner

Decide and document the supported embedding capability boundary before adding
new extraction or service behavior. Primary owners are `core/rag.mojo` query
embedding helpers, `core/inference.mojo` token embedding tables, and the
`MimirStore` retrieval owner in `core/mimir_well.mojo`. The decision must
separate a token-table-derived query vector from a dedicated general-purpose
embedding model/API.

## Current inputs and outputs

The existing extraction path accepts a nonempty sequence of validated token IDs
and a loaded model exposing `token_embd.weight`; it returns the exact
hidden-dimension mean of the selected token embedding rows. Downstream KNN
accepts an equal-dimension query vector and caller-owned in-memory vectors. The
current default suite has synthetic exact-mean tests and an explicitly skipped
real-model engine integration without a pinned external GGUF fixture.

## Decision invariants

1. No hash, constant, random, zero-token, or arbitrary caller text fallback may
   be presented as a semantic embedding.
2. Token-embedding mean pooling is named as a retrieval feature derived from
   the loaded generative model; it is not represented as a trained/dedicated
   sentence embedding model or an external embeddings API.
3. A query vector is produced only from the exact loaded token table and
   validated nonempty token IDs; dimension and finite-value policy remain
   explicit and match the KNN contract.
4. Capability language identifies which steps are local and exercised with
   synthetic fixtures, which require real model weights, and which lack an
   independent embedding oracle.
5. No retrieval-quality, semantic accuracy, cross-model comparability, or
   external API compatibility claim follows from cosine/KNN unit tests.

## Exclusions

This decision slice does not choose or download an embedding model, expose an
HTTP embeddings endpoint, persist a vector index, change token pooling, promise
retrieval quality, or claim independent semantic validity. Those need separate
contracts and pinned fixtures/oracles.

## Acceptance

Reconcile source and ledger owners for AES-RAG-003/004/005; state the supported
feature and exclusions in the interface/API/README surfaces; retain exact
synthetic unit values and explicit real-fixture skip; add no performance or
quality inference. Run documentation checker and diff checks, then push the
contract slice and verify exact remote SHA/hosted CI status. Reviewer status is
reported honestly.
