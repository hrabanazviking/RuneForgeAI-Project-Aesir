# HTTP framing rejection unit evidence — 2026-10-10

AES500-265 unit evidence at source revision `3924c9e569a361aecfc10c5bebb665f5309253f8`.

The new `test_local_http_framing` rejects case-variant duplicate Content-Length, Expect, Transfer-Encoding, TE plus Content-Length, malformed request-line spacing, and bare CR. It verifies 405 for unsupported methods, 411 for missing/zero POST length, 415 for wrong content type, and rejection of GET with nonzero length.

- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_local_protocol.mojo` — passed.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 249 passed, 0 failed, 1 skipped (250 total), including `local_service.http_framing`.
- `python3 scripts/test_check_doc_drift.py`, `python3 scripts/check_doc_drift.py`, and `git diff --check` — passed after ledger synchronization.

The tests assert the parser's documented local-subset result. They do not establish complete RFC compliance or third-party client compatibility.
