# Real model-root descriptor verification

Original Mojo1.1.0 8189361e on native Linux ARM64. No model/tensor execution.
Five methods/77 calls plus rebuilt index10/516 and config6/190 =21/783.
The isolated C layout oracle was published before code; headers/license/facts
are in `docs/evidence/model-root-facts-2026-10-20/`.

Build `smidr/tools/source_root.mojo` and `tests/hailo_source_root_api.mojo` with
`MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine <source> -o
../<binary>`. Final logs are `build.txt` and `build-api-transfer.txt`. Consumer
rebuild logs name root-reg-index/config and APIs. Initial failed builds and the
successful preliminary acceptance remain. Current hashes/linkage are retained;
binaries stay outside Git. The isolated shim is built with `cc -shared -fPIC
-Wall -Wextra -Werror tests/source_root_io_faults.c -o
../model-root-study/io-faults.so -ldl`.

```sh
python3 tests/test_hailo_source_root.py --binary ../source-root --api ../source-root-api --faults ../model-root-study/io-faults.so --layout docs/evidence/model-root-facts-2026-10-20/layout.json --strace /usr/bin/strace --evidence docs/evidence/model-root-2026-10-20/root
python3 tests/test_hailo_source_index.py --binary ../root-reg-index --api ../root-reg-index-api --faults ../source-index-study/io-faults.so --strace /usr/bin/strace --public-index ../ordinary-model-metadata-study/model.safetensors.index.json --evidence docs/evidence/model-root-2026-10-20/index-regression
python3 tests/test_hailo_source_config.py --binary ../root-reg-config --api ../root-reg-config-api --strace /usr/bin/strace --public-config ../ordinary-model-metadata-study/config.json --evidence docs/evidence/model-root-2026-10-20/config-regression
```

Literal machine/temporary paths in traces/JSON are execution receipts, not new
production settings. They remain preserved even though the repository-wide
machine-path checker flags such JSON. No whole repository pass is claimed.
Boundaries: `docs/HAILO10H_MOJO_MODEL_ROOT.md`.
