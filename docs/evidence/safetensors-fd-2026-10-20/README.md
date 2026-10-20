# Same-descriptor header verification

Mojo1.1.0 8189361e on Linux ARM64 Pi. Metadata/static byte tests only, no tensor/
model/layer/attention forward. Public ABI refinement was published before code;
frozen baseline hash/layout at `docs/evidence/safetensors-fd-facts-2026-10-20/`.
Original production code plus isolated Python/C/strace verification.

Five methods/365 calls plus rebuilt consumers48/1551 =53 methods/1916 calls.
`shared-methods-unchanged.txt` confirms original descriptor/metadata/coverage
method statements unchanged (one extent comment normalized). Build pattern: `MODULAR_CACHE_DIR=../mojo-cache mojo build
-I . -I aesir_engine <source> -o ../<binary>`. Logs name sources by tool/API.
Initial move-ownership errors remain; final new builds succeed warning-free.
The legacy header probe retains a historical unused conversion-body warning.
Current hashes/linkage are recorded; binaries are outside Git.

Fault shim: `cc -shared -fPIC -Wall -Wextra -Werror
tests/safetensors_fd_io_faults.c -o ../owned-fd-study/io-faults.so -ldl`.
It operates on actual synthetic admitted fds and real positional short reads;
failures never become production dependencies. Source payloads are not evaluated.

```sh
python3 tests/test_hailo_safetensors_fd.py --binary ../safetensors-fd --api ../safetensors-fd-api --inventory ../fd-safe-inventory --baseline ../owned-fd-baseline-inventory --faults ../owned-fd-study/io-faults.so --strace /usr/bin/strace --evidence docs/evidence/safetensors-fd-2026-10-20/fd
python3 tests/test_hailo_safetensors_inventory.py --binary ../fd-safe-inventory --api ../fd-safe-api --legacy ../fd-legacy --strace /usr/bin/strace --evidence docs/evidence/safetensors-fd-2026-10-20/inventory-regression
python3 tests/test_hailo_safetensors_constants.py --binary ../fd-constants --api ../fd-constants-api --strace /usr/bin/strace --evidence docs/evidence/safetensors-fd-2026-10-20/constants-regression
python3 tests/test_hailo_source_storage.py --binary ../fd-storage --api ../fd-storage-api --gguf-inventory ../gguf-shape-inventory --safe-inventory ../fd-safe-inventory --strace /usr/bin/strace --evidence docs/evidence/safetensors-fd-2026-10-20/storage-regression
python3 tests/test_hailo_source_index.py --binary ../fd-index --api ../fd-index-api --faults ../source-index-study/io-faults.so --strace /usr/bin/strace --public-index ../ordinary-model-metadata-study/model.safetensors.index.json --evidence docs/evidence/safetensors-fd-2026-10-20/index-regression
python3 tests/test_hailo_source_config.py --binary ../fd-config --api ../fd-config-api --strace /usr/bin/strace --public-config ../ordinary-model-metadata-study/config.json --evidence docs/evidence/safetensors-fd-2026-10-20/config-regression
python3 tests/test_hailo_source_root.py --binary ../fd-root --api ../fd-root-api --faults ../model-root-study/io-faults.so --layout docs/evidence/model-root-facts-2026-10-20/layout.json --strace /usr/bin/strace --evidence docs/evidence/safetensors-fd-2026-10-20/root-regression
```

Literal machine paths in native command/trace receipts are preserved evidence,
not production settings; the repository checker still flags such JSON. Limits
and exact acceptance: `docs/HAILO10H_MOJO_SAFETENSORS_FD.md`.
