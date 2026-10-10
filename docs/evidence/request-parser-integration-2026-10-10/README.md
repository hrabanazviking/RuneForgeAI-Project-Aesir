# Request parser transport integration evidence — 2026-10-10

AES500-256 integration evidence at source revision `9794a505d7bc63fba07aa0fe825e9618f1a58785`.

- The socketpair transport case writes one HTTP request with a four-byte body in one peer write, calls `receive_head`, then `receive_body` using one absolute deadline. It verifies the returned header terminates exactly at CRLFCRLF and the body returns exactly the four bytes without losing or confusing the adjacent stream contents.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_local_transport_ownership.mojo` — transfer, admission and socketpair framing passed.
- Master `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 247 passed, 0 failed, 1 skipped (248 total), including `local_service.socketpair_framing`.
- Source test SHA-256: `aesir_engine/tests/test_local_transport_ownership.mojo` `b4dc83c782c89958bd6e07e8c4aee2b4533c275f629ef27200198f9deaa414b0`; protocol tests/master runner updated in the same commit.
- Repository doc drift and diff checks passed after ledger count synchronization.

This is local Linux transport framing evidence using a socketpair. It does not establish network load behavior, physical model inference, or external-client compatibility.
