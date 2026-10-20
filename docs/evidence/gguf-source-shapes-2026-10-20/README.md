# Exact admitted GGUF axes: native verification

Mojo1.1.0 (`8189361e`) on the owner's ARM64 Raspberry Pi. Test-owned synthetic
GGUF byte files only; no model forward or device access. All28 methods/669 calls
pass; see `summary.json`, per-suite receipts and binary hashes. Final build logs
are empty/warning-free; both initial test-API compile failures are preserved.

Build each inspector/API with `MODULAR_CACHE_DIR=../mojo-cache mojo build -I .
-I aesir_engine <source> -o ../<binary>`. Binaries correspond to
`smidr/tools/gguf_shapes.mojo`, `tests/hailo_gguf_shapes_api.mojo`, existing source
inventory/semantic/typed inspectors and `tests/hailo_typed_decoder_api.mojo`.
The frozen pre-refactor baseline was built at `6ec0593` before typed changes;
see `../typed-decoder-2026-10-20/README.md` for its exact provenance.

```sh
python3 tests/test_hailo_gguf_shapes.py --binary ../gguf-shapes --api ../gguf-shapes-api --strace /usr/bin/strace --evidence docs/evidence/gguf-source-shapes-2026-10-20/shapes
python3 tests/test_hailo_source_inventory.py --binary ../gguf-shape-inventory --strace /usr/bin/strace --evidence docs/evidence/gguf-source-shapes-2026-10-20/inventory
python3 tests/test_hailo_semantic_plan.py --binary ../gguf-shape-semantic --strace /usr/bin/strace --evidence docs/evidence/gguf-source-shapes-2026-10-20/semantic
python3 tests/test_hailo_typed_decoder.py --baseline ../semantic-plan-before-typed --binary ../gguf-shape-semantic --typed ../gguf-shape-typed --api ../gguf-shape-typed-api --strace /usr/bin/strace --evidence docs/evidence/gguf-source-shapes-2026-10-20/typed
```

Raw observed paths in traces/compiler logs are evidence, not settings. The new
fixture writer explicitly encodes rank rather than deriving it from rows.
Declared `[N]`, `[N,1]`, `[1,N]` and general matrices are compared to a separate
expected shape dictionary. Descriptor mutation tests validate copied ownership
and lookup failures; they do not authenticate a backing file or execute weights.
No production external dependency, dtype cast or graph-schema change was added.
