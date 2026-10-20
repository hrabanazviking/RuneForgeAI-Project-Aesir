# UTF-8 RAG chunking baseline — 2026-10-10

AES500-302 baseline at revision `cdbfb05608e3753454b277c2ef588ba999168eb5`.

- `aesir_engine/loader/corpus_ingestion.mojo` SHA-256:
  `b94dfc972fb447e7e90efdd333e42df2335e90c7d280d476ca62bde7ae3b5b8d`.
- `aesir_engine/tests/test_rag.mojo` SHA-256 at this baseline:
  `a5ecae5b422f61aa95e9a4984a19965379dbdae07aec2cf127ab2aa2c7880ccf`.
- Existing `chunk_text()` slices raw UTF-8 bytes at `offset + chunk_size` and
  converts each raw slice directly to `String`; no boundary validation is
  present. A multi-byte scalar can therefore straddle adjacent chunks.
- Existing `ingest_corpus_batch()` checks shape/capacity/nonempty text before
  the copy loop. The RAG test verifies shape rejection preserves `store.count`,
  but does not verify capacity, empty text, allocation cursor, or document
  contents on rejection.
- No baseline behavior tests are run by this source inspection; the focused
  existing RAG case can be executed with
  `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_rag.mojo`.
