# Request parser release gate — 2026-10-10

AES500-260 release verification against source revision `2e8f895dc933fe16bb7ddee22ec3233be2a209f2`.

- Fresh sm_89 build and CLI help passed.
- Binary `/tmp/aesir-request-parser-260` SHA-256: `1906adace947ddaabd2e77b81763aed1c9e41bdf30362209149b2073d2f0cfbd`.
- Master suite: 248 passed, 0 failed, 1 skipped (249 total).
- Focused `test_local_protocol.mojo` passed.
- Focused `test_local_transport_ownership.mojo` passed transfer, admission, socketpair and hostile-bound cases.
- `python3 scripts/test_check_doc_drift.py`, `python3 scripts/check_doc_drift.py`, and `git diff --check` passed. Existing legacy-artifact warnings remain: 24 duplicate root assets, 7 generated executables, one placeholder model.
- No physical model API service test is claimed; parser tests use local fixtures/socketpairs and the local model file is a zero-byte placeholder.

This gate confirms local parser/transport compilation and tests. It is not external API conformance, Internet security assessment, or physical inference evidence.
