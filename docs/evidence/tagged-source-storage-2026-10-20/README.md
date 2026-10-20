# Tagged source storage: native evidence

Mojo1.1.0 (`8189361e`) on the owner's ARM64 Pi. Source metadata/static integer
byte arithmetic only, no tensor/model/layer/attention forward or device access.
All46 methods/1340 native calls pass; `summary.json` separates suites/outcomes.
Final builds: `build-4.txt` (catalog), `build-api-5.txt` (direct API), existing
reader/API build logs. Binaries are not committed; SHA-256 values are retained.
Initial missing-raises compile failure, unused initializer warning and missing
legacy-test argument are preserved with their actual outputs. The full command
reruns pass. Earlier seven-method catalog pass preceded added refusal cases.

Build pattern: `MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine
<source> -o ../<binary>`. Sources are `smidr/tools/source_storage.mojo`,
`tests/hailo_source_storage_api.mojo`, `smidr/tools/safetensors_inventory.mojo`
and `tests/hailo_safetensors_inventory_api.mojo`. Existing unchanged GGUF shape/
inventory/semantic/typed binaries were rebuilt in the preceding slice; their
hashes and all repeated executions are recorded. The pre-refactor baseline and
legacy header-only probe retain their prior exact provenance/hashes.

```sh
python3 tests/test_hailo_source_storage.py --binary ../source-storage --api ../source-storage-api --gguf-inventory ../gguf-shape-inventory --safe-inventory ../tagged-safe-inventory --strace /usr/bin/strace --evidence docs/evidence/tagged-source-storage-2026-10-20/catalog
python3 tests/test_hailo_source_inventory.py --binary ../gguf-shape-inventory --strace /usr/bin/strace --evidence docs/evidence/tagged-source-storage-2026-10-20/inventory-regression
python3 tests/test_hailo_gguf_shapes.py --binary ../gguf-shapes --api ../gguf-shapes-api --strace /usr/bin/strace --evidence docs/evidence/tagged-source-storage-2026-10-20/shapes-regression
python3 tests/test_hailo_semantic_plan.py --binary ../gguf-shape-semantic --strace /usr/bin/strace --evidence docs/evidence/tagged-source-storage-2026-10-20/semantic-regression
python3 tests/test_hailo_typed_decoder.py --baseline ../semantic-plan-before-typed --binary ../gguf-shape-semantic --typed ../gguf-shape-typed --api ../gguf-shape-typed-api --strace /usr/bin/strace --evidence docs/evidence/tagged-source-storage-2026-10-20/typed-regression
python3 tests/test_hailo_safetensors_inventory.py --binary ../tagged-safe-inventory --api ../tagged-safe-api --legacy ../safetensors-header-regression --strace /usr/bin/strace --evidence docs/evidence/tagged-source-storage-2026-10-20/safetensors-regression
```

Use a new evidence directory when repeating the safetensors suite (its harness
requires one). Isolated safetensors0.7.0 is a licensed format oracle in that
pre-existing suite only, not a production dependency. Source hashes stay
unchanged. New tests independently encode GGUF directory ranks and safetensors
JSON/byte extents, compare previous inventory projections and sorted intervals,
and assert all execution/fit/fingerprint flags false. Raw machine paths in logs
are observations only. GGUF's legacy parser-work policy is not replaced by the
new catalog's descriptor bounds. No complete model/compiler/device acceptance
or full historical repository CI pass is claimed.
