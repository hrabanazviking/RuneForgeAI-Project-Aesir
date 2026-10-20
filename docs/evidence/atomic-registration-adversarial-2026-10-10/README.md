# Atomic model registration adversarial evidence — 2026-10-10

AES500-237 local Linux evidence against
`/tmp/aesir-atomic-registration-236` (SHA-256
`e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`).

All commands exited 0:

- `python3 scripts/test_catalog_crash_atomicity.py --binary /tmp/aesir-atomic-registration-236`: test-only preload shim kills catalog updates after staged write, staged-file fsync, rename, and directory fsync. Reopen sees only old or complete new bytes, and each store remains writable.
- `python3 scripts/test_special_file_admission.py --binary /tmp/aesir-atomic-registration-236`: source and installed-blob symlinks/FIFOs plus catalog FIFO are rejected without blocking.
- `python3 scripts/test_native_model_store.py --binary /tmp/aesir-atomic-registration-236`: expected digest/size mismatch rolls back, same-size corruption and missing bytes are detected, and concurrent/deduplicated writes preserve valid records.

This is process-kill and adversarial Linux fixture evidence. It does not prove
sudden-power-loss durability or behavior on other filesystems.
