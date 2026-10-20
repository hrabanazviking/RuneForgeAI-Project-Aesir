# Actual indexed source collection verification

Original Mojo1.1.0 8189361e on native Linux ARM64 Pi. No tensor/model evaluation.
Published-first design1a74c1b. Five methods/205 new native calls; seven regression
suites53/1916; full slice58/2121. Preliminary202-call pass is preserved.

Build pattern: `MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine
<source> -o ../<binary>`. Main sources are smidr/tools/shard_collection.mojo and
tests/hailo_shard_collection_api.mojo. Final logs build-final/build-api-final;
all new/rebuilt logs are empty/success. Changed index/config/storage pairs are
rebuilt; other existing binaries are rerun. Exact hashes and linkage retained;
executables stay outside Git. Extended test-only fd fault shim adds an injected
byte after actual EOF without modifying the source file.

```sh
python3 tests/test_hailo_shard_collection.py --binary ../shard-collection --api ../shard-collection-api --storage ../fd-storage --faults ../owned-fd-study/io-faults.so --strace /usr/bin/strace --evidence docs/evidence/shard-collection-2026-10-20/collection
```

Regressions use the prior documented commands, with collection-index/config/
storage binaries and APIs for rebuilt consumers; fd-safe inventory/API, fd
constants/API, fd-root/API and safetensors-fd/API are unchanged binaries. Evidence
subfolders name each suite and corresponding *-tests.txt records completion.
All detailed native commands/return values remain in runs.json. Literal machine
paths in execution receipts are preserved evidence, not production settings;
repository-wide checker still flags such JSON. Exact limits and next connection:
`docs/HAILO10H_MOJO_SHARD_COLLECTION.md`.
