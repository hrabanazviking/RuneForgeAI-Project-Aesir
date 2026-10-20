# Typed decoder verification evidence

Synthetic structure/static storage only; no CPU/CUDA/cloud model/layer/attention
forward and no Hailo device access. All commands run from the repository root.
Mojo1.1.0 (`8189361e`), Linux ARM64 on the owner's Pi. No external production
compiler/runtime library. `summary.json` records54 methods/1933 child calls.

Build pattern for each tool/API: `MODULAR_CACHE_DIR=../mojo-cache mojo build -I .
-I aesir_engine <source> -o ../<binary>`. Final build logs and binary SHA-256
values are retained; binaries are not committed. Baseline inspector was built
from published `6ec05934ad1eaaf6e34e844147f1f02f1275979a` before source edits.
Its original `smidr/semantic_plan.mojo` SHA-256:
`eb2f79734a2e869d79cfa422c369829e5310223a1a3c2d2db5481a6c73b6aca2`.
Reproduce the baseline build in a separate checkout of that revision. Do not
replace the current implementation with it. Final build logs are empty because
the builds completed without errors or warnings. Initial failed logs remain.

```sh
python3 tests/test_hailo_typed_decoder.py --baseline ../semantic-plan-before-typed --binary ../semantic-plan-typed --typed ../typed-decoder --api ../typed-decoder-api --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/typed
python3 tests/test_hailo_semantic_plan.py --binary ../semantic-plan-typed --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/semantic-regression
python3 tests/test_hailo_primitive_recipes.py --binary ../typed-recipes --graph-binary ../semantic-plan-typed --api-binary ../typed-recipe-api --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/primitive
python3 tests/test_hailo_expanded_graph.py --binary ../typed-expanded --source-binary ../semantic-plan-typed --recipe-binary ../typed-recipes --api-binary ../typed-expanded-api --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/expanded
python3 tests/test_hailo_storage_estimate.py --binary ../typed-storage --graph-binary ../semantic-plan-typed --api-binary ../typed-storage-api --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/storage
python3 tests/test_hailo_expanded_storage.py --binary ../typed-expanded-storage --graph-binary ../typed-expanded --api-binary ../typed-expanded-storage-api --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/expanded-storage
python3 tests/test_hailo_matrix_tiles.py --binary ../typed-matrix --api-binary ../typed-matrix-api --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/matrix
python3 tests/test_hailo_source_weight_tiles.py --binary ../typed-weight-tiles --api-binary ../typed-weight-tiles-api --strace /usr/bin/strace --evidence docs/evidence/typed-decoder-2026-10-20/weight-tiles
```

The new fixture receipt hashes successful output after comparing full decoded
objects, rather than retaining hundreds of duplicate graph JSON documents.
Source bytes are checked unchanged. New native API/span tests operate entirely
on owned descriptors/values. Existing suites retain their customary complete
output/negative receipts. Raw traces/compiler logs contain machine paths as
observations; these are not production settings. The first typed harness run
passed its seven methods but discovery also attempted the imported legacy test
class without that class's CLI arguments. The import was changed to a module
reference and the full rerun passes; no implementation expectation was weakened.

`HAILO10H_MOJO_TYPED_DECODER.md` records proof limits. Whole repository historical
CI/master compilation remains separately failing; no full CI pass is claimed.
