# Content-addressed blob identity adversarial evidence — 2026-10-10

AES500-227 evidence on local Linux against binary
`/tmp/aesir-blob-identity-226` (SHA-256
`e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`).

All commands exited 0:

- `python3 scripts/test_special_file_admission.py --binary /tmp/aesir-blob-identity-226` rejects source and installed-blob symlinks/FIFOs and catalog FIFOs without blocking.
- `python3 scripts/test_catalog_crash_atomicity.py --binary /tmp/aesir-blob-identity-226` kills at staged write, staged-file sync, rename and directory sync; restart sees old or complete new bytes and stays writable.
- `python3 scripts/test_native_model_store.py --binary /tmp/aesir-blob-identity-226` checks incorrect expected digest/size rollback, same-size installed-blob corruption, missing referenced bytes, source/symlink admission, duplicate content, and concurrent writers.

The harness scopes are generated local fixtures and a test-only Linux preload
shim. They do not establish physical power-loss durability, other filesystems,
or third-party digest implementation independence.
