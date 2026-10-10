# AES500-301 — UTF-8 safe RAG chunking contract

## Objective and owner

Specify the text and transaction boundary for `chunk_text()` and
`ingest_corpus_batch()` in `aesir_engine/loader/corpus_ingestion.mojo`. The
owner is the RAG ingestion path.

## Chunking contract

- Input is valid NUL-free UTF-8 text, matching shared text admission. Invalid
  UTF-8 and NUL must fail explicitly before any
  chunk is returned; it must not be silently replaced or emitted as malformed
  chunk strings.
- `chunk_size` and `chunk_overlap` are byte-based limits for compatibility
  with existing offsets. Every returned chunk must start and end on a UTF-8
  code-point boundary.
- `byte_offset` is the original input's byte offset, not a character index.
- Chunk text concatenation with the documented overlap policy must preserve
  every input code point in order. Oversized single code points are never split.
- Empty input and invalid non-positive chunk size return no chunks. Overlap
  below zero is clamped to zero; overlap greater than or equal to size follows
  the existing half-size clamp, now explicitly tested.

## Batch ingestion contract

Before mutating `MimirStore`, validate matrix rows and columns, available store
capacity, and nonempty text for every chunk. Rejected batches leave store count,
document contents, and allocation cursor unchanged. Accepted batches copy rows
in order and produce exactly one stored document per chunk.

## Exclusions and acceptance

This task does not add file parsing, persistent indices, provenance citations,
model inference, embedding generation, or semantic retrieval claims. Focused
tests must cover ASCII, multi-byte boundaries, empty/invalid sizing, clamped
overlap, malformed UTF-8 rejection, capacity rejection, empty-chunk rejection,
shape rejection, and mutation-free failure. Full master and documentation gates
remain required before the release slice.
