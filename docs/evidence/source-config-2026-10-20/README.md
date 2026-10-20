# Ordinary configuration metadata verification

Native Mojo1.1.0 8189361e, Linux ARM64 on the owner Pi. Original Mojo production
reader/inspector; Python/strace are isolated metadata oracles. No tensor/model
forward or device access. Six methods/190 calls plus index10/516 =16/706.

Build both `smidr/tools/source_config.mojo` and
`tests/hailo_source_config_api.mojo` using `MODULAR_CACHE_DIR=../mojo-cache mojo
build -I . -I aesir_engine <source> -o ../<binary>`. Build logs are empty/success;
binary hashes/linkage retained, executables outside Git.

```sh
python3 tests/test_hailo_source_config.py --binary ../source-config --api ../source-config-api --strace /usr/bin/strace --public-config ../ordinary-model-metadata-study/config.json --evidence docs/evidence/source-config-2026-10-20/config
python3 tests/test_hailo_source_index.py --binary ../source-index --api ../source-index-api --faults ../source-index-study/io-faults.so --strace /usr/bin/strace --public-index ../ordinary-model-metadata-study/model.safetensors.index.json --evidence docs/evidence/source-config-2026-10-20/index-regression
```

Public metadata provenance/hash precedes this work in
`docs/HAILO10H_ORDINARY_MODEL_METADATA_FACTS.md`. `config-first-*` and
`cleanup-first.strace` preserve the fixture pathname collision failure. Current
`config-tests.txt` and `config/` record the corrected unchanged assertions.
Native command/trace paths are literal machine evidence, not production settings.
Full receipt and boundaries: `docs/HAILO10H_MOJO_SOURCE_CONFIG.md`.
