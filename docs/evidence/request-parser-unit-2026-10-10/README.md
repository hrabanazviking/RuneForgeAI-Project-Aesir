# Request parser boundary unit evidence — 2026-10-10

AES500-255 local test evidence at source revision `6ee5ed86effdfcc057cbb41a3ac75ac71a24ea5e`.

- `aesir_engine/server/local_protocol.mojo` SHA-256: `4a472b202419269d89636e5e213ff7a35b2eb1a953c1cb154e4d50e052ff8148`.
- Focused `test_local_protocol.mojo` and master runner hashes are recorded in the source commit; the new focused matrix asserts exact max content length 131072, HTTP 413 at 131073, decimal overflow rejection, 64 accepted versus 65 rejected unique headers, and 1024 accepted versus 1025 rejected value bytes.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_local_protocol.mojo` — passed.
- Master `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 246 passed, 0 failed, 1 external fixture skipped (247 total), including `local_service.http_bounds`.
- `python3 scripts/test_check_doc_drift.py`, `python3 scripts/check_doc_drift.py`, `git diff --check` — passed after updating the E-MASTER count. Existing unrelated legacy-artifact warnings persist.

The assertions exercise protocol-boundary admission. They do not establish socket throughput, physical inference, or third-party API parity.
