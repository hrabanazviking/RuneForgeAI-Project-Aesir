# Content-addressed blob identity release gate — 2026-10-10

AES500-230 local release gate at source revision
`3c941de84770ce6183c6d220fb5fce763f94b7d7`.

## Build and verification

- Toolchain: Mojo 1.0.0 (`ed45d567`), Pixi 0.76.2, sm_89 target.
- Build: `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o /tmp/aesir-blob-identity-230` — pass.
- Binary SHA-256: `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`.
- Binary `--help`: pass.
- Master: 242 passed, 0 failed, 1 skipped (243 total).
- Fresh-binary gates all pass: `test_native_model_store.py`,
  `test_catalog_lifecycle.py`, `test_catalog_crash_atomicity.py`, and
  `test_special_file_admission.py`.
- `python3 scripts/test_check_doc_drift.py`: pass.
- `python3 scripts/check_doc_drift.py`: pass with existing tracked-artifact
  warnings; `git diff --check`: pass.
- Push succeeded and exact remote branch revision was checked after commit.
  GitHub Actions runs for the latest slice heads were queued/in progress at the
  release check; no hosted success is claimed in this receipt.

Evidence applies to this local Linux environment and generated fixtures. The
process-kill harness does not establish sudden-power-loss durability.
