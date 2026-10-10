# Model catalog schema release gate — 2026-10-10

AES500-220 local release gate from commit `c3192c1201286138b0ff74e6ad1466b2765c807f`.

## Build identity and results

- Toolchain: Mojo 1.0.0 (`ed45d567`), Pixi 0.76.2
- Command: `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o /tmp/aesir-catalog-schema-220`
- Binary SHA-256: `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`
- `/tmp/aesir-catalog-schema-220 --help`: exit 0
- Master: `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 240 passed, 0 failed, 1 skipped (241 total).
- Native gates against the fresh binary all exited 0: `scripts/test_native_model_store.py`, `scripts/test_catalog_lifecycle.py`, `scripts/test_catalog_crash_atomicity.py`, and `scripts/test_special_file_admission.py` (plus the model-store script's selector checks).
- `python3 scripts/test_check_doc_drift.py`: pass.
- `python3 scripts/check_doc_drift.py`: pass, with repository's existing tracked-artifact warnings.
- `git diff --check`: pass.

These are local results for the configured sm_89 build and Linux filesystem.
They do not establish a hosted CI result or power-loss durability. Hosted runs
for recent slice heads were queried separately and were queued/in progress at
the time of this receipt; no hosted success is claimed.
