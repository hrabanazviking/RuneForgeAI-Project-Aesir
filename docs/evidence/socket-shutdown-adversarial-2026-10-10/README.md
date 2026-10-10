# Socket ownership adversarial evidence — 2026-10-10

AES500-247 local evidence at source revision `6d4bcd1959d1268e020054f1c9a9608c3554c393`.

- `test_owned_fd_transfer_release` transfers a nonblocking pipe descriptor by poisoning the old wrapper. The reader observes EAGAIN while the destination owner is live and EOF after its destruction, proving the moved-from destructor did not close the transferred descriptor and the destination closes it.
- `test_socket_admission_rejection` rejects negative, privileged, and out-of-range ports before listener setup and rejects `OwnedFD(-1)`.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_local_transport_ownership.mojo` — passed both focused cases.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 245 passed, 0 failed, 1 external-fixture skip (246 total), including `local_service.fd_ownership` and `local_service.socket_admission`.
- `python3 scripts/test_check_doc_drift.py`, `python3 scripts/check_doc_drift.py`, and `git diff --check` — passed.

No GPU-kernel interruption or fresh physical active-shutdown test is claimed; that remains limited by the absent usable model artifact. Prior real-model evidence is explicitly historical in the baseline/integration receipts.
