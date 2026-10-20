# Native ordinary source-index verification

Mojo1.1.0 (`8189361e`), native Linux ARM64 on the owner's Pi. Metadata/static byte
checks only; no LLM/layer/attention forward, device node, external compiler or
model tensor payload. Final primary suite10 methods/516 calls; three consumer
suites27 methods/768 calls;5 extra header-only calls. Summary1289 native calls.
Failed initial compiles/tests and intermediate successful runs are preserved.

Final index builds use `build-6.txt` / `build-api-7.txt`; final consumer rebuilds
use `final-build-*`. Build pattern: `MODULAR_CACHE_DIR=../mojo-cache mojo build
-I . -I aesir_engine <source> -o ../<binary>`. New APIs/tools are
`smidr/tools/source_index.mojo` and `tests/hailo_source_index_api.mojo`.
Existing sources match inventory/constants/storage inspector/API names and
`tests/h043_st_check.mojo`. Binary hashes are retained; binaries/shim are outside
Git. The legacy header-only probe's pre-existing conversion-body warning remains.

The original test-only fault shim is built with:
`cc -shared -fPIC tests/source_index_io_faults.c -o ../source-index-study/io-faults.so -ldl`.
It changes reported syscalls over real selected files, never their contents.
Short reads still perform actual reads; failures and size/type/mask changes are
fault injection, not a claim that a live filesystem spontaneously failed.

```sh
python3 tests/test_hailo_source_index.py --binary ../source-index --api ../source-index-api --faults ../source-index-study/io-faults.so --strace /usr/bin/strace --public-index ../ordinary-model-metadata-study/model.safetensors.index.json --evidence docs/evidence/source-index-2026-10-20/index
python3 tests/test_hailo_safetensors_inventory.py --binary ../index-safe-inventory --api ../index-safe-inventory-api --legacy ../index-legacy-header --strace /usr/bin/strace --evidence docs/evidence/source-index-2026-10-20/safetensors-regression
python3 tests/test_hailo_safetensors_constants.py --binary ../index-safe-constants --api ../index-safe-constants-api --strace /usr/bin/strace --evidence docs/evidence/source-index-2026-10-20/constants-regression
python3 tests/test_hailo_source_storage.py --binary ../index-storage --api ../index-storage-api --gguf-inventory ../gguf-shape-inventory --safe-inventory ../index-safe-inventory --strace /usr/bin/strace --evidence docs/evidence/source-index-2026-10-20/storage-regression
```

Use fresh evidence paths for existing safetensors harnesses. Public index input
is metadata only, under previously recorded license/revision/hash facts in
`../ordinary-model-metadata-2026-10-20/`; no shard file is downloaded/opened.
Copied metadata strings/labels are not execution, model fit or backing-file
identity. Raw observed machine paths in logs are evidence, not settings.

Initial path matching missed strace's octal UTF-8 escapes; the corrected matcher
checks actual closes. The direct raw-cursor test initially allowed its untracked
byte owner to expire; explicit last uses now pin the owner until copying ends.
All previous expected exact bytes remain. Production borrowed input is explicitly
kept alive through both parsing passes. No grammar/refusal expectation was
weakened. The full repository checker/CI remains historically failing separately.
