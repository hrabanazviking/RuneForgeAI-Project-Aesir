# Socket ownership unit evidence — 2026-10-10

AES500-244 implementation and focused verification against source revision `3ea74fc0256b39361212408527578d4f39ec00c1`.

- `aesir_engine/server/local_transport.mojo` SHA-256: `f02447408dcc2cfb29bb9e2afc0b54efd3fc0638bbb798af3ef89d5ad6cea618`.
- `aesir_engine/tests/test_local_transport_ownership.mojo` SHA-256: `e08839931ae540329588a7c51964a392704314b00952c7d88556c85768a8d281`.
- `aesir_engine/tests/run_all.mojo` SHA-256: `1dd836a8cf51f45580b91d51edfc1a460b602a397f132fb7faf60b160fc633cf`.
- Fresh sm_89-targeted binary `/tmp/aesir-socket-shutdown-244` SHA-256: `1906adace947ddaabd2e77b81763aed1c9e41bdf30362209149b2073d2f0cfbd`.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_local_transport_ownership.mojo` — passed. A nonblocking pipe confirms the moved-from owner leaves the accepted descriptor open; the adopted owner closes it once and the reader observes EOF.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 244 passed, 0 failed, 1 skipped (245 total), including `local_service.fd_ownership`.
- `python3 scripts/test_check_doc_drift.py`, `python3 scripts/check_doc_drift.py`, and `git diff --check` — passed.

The implementation guard skips `close` for the `-1` sentinel used after ownership transfer. No fresh physical model service/shutdown run is claimed because the checked-out model path is a known zero-byte placeholder. Historical Llama3 service receipts remain documented in the baseline only.
