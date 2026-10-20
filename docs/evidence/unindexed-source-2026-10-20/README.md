# Direct ordinary source without a phantom index

Original Mojo1.1.0 8189361e on native Linux ARM64 Pi, metadata only.
Published-first designf69b498. Four new methods/178 calls, rebuilt indexed5/205,
seven unchanged shared suites53/1916; total62/2299. Frozen indexed binary hash
is retained before helper edits. No failed run/compile; final logs empty/success.

Build pattern: `MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine
<source> -o ../<binary>`. Sources: smidr/tools/unindexed_source.mojo and
tests/hailo_unindexed_source_api.mojo, plus refactored indexed tool/API. Current
hashes/linkage retained; executables outside Git. Fault shim is the previously
published isolated positional-file C oracle, never a production dependency.

```sh
python3 tests/test_hailo_unindexed_source.py --binary ../unindexed-source --api ../unindexed-source-api --indexed ../unindexed-current-indexed --baseline ../unindexed-baseline-collection --faults ../owned-fd-study/io-faults.so --strace /usr/bin/strace --evidence docs/evidence/unindexed-source-2026-10-20/unindexed
python3 tests/test_hailo_shard_collection.py --binary ../unindexed-current-indexed --api ../unindexed-indexed-api --storage ../fd-storage --faults ../owned-fd-study/io-faults.so --strace /usr/bin/strace --evidence docs/evidence/unindexed-source-2026-10-20/indexed-regression
```

Other suites rerun the previous documented fd/inventory/constants/storage/
index/config/root commands with unchanged binaries, evidence folders named by
suite. Every native command/return code is retained in runs.json and *-tests.txt.
Literal machine paths are preserved execution evidence, not production settings;
repository-wide consistency still flags such JSON. No model/source payload or
device operation is tested. Full receipt: `docs/HAILO10H_MOJO_UNINDEXED_SOURCE.md`.
