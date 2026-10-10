# Atomic model registration release gate — 2026-10-10

AES500-240 release verification against source revision `122b70de4b603d23679a08c92d06e7f1e9d09a62`.

- Fresh command: `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o /tmp/aesir-atomic-registration-240` — passed.
- Binary SHA-256: `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`.
- `/tmp/aesir-atomic-registration-240 --help` — exit 0.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 243 passed, 0 failed, 1 skipped (244 total).
- `python3 scripts/test_native_model_store.py --binary /tmp/aesir-atomic-registration-240` — passed.
- `python3 scripts/test_catalog_lifecycle.py --binary /tmp/aesir-atomic-registration-240` — passed.
- `python3 scripts/test_catalog_crash_atomicity.py --binary /tmp/aesir-atomic-registration-240` — passed at staged-write, staged-file-fsync, rename, and directory-fsync boundaries; restart remained writable.
- `python3 scripts/test_special_file_admission.py --binary /tmp/aesir-atomic-registration-240` — passed; relevant FIFOs were rejected.
- `python3 scripts/test_check_doc_drift.py`, `python3 scripts/check_doc_drift.py`, and `git diff --check` — passed. The drift checker reports its pre-existing legacy artifact warnings (24 duplicate root assets, 7 generated executables and 1 placeholder model).

Results are local Linux and generated-fixture evidence. Process-kill tests do not establish sudden-power-loss durability or portability across filesystems. Hosted Actions state is queried for the pushed revision and recorded separately; queued/in-progress runs are not treated as successful.
