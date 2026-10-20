# Source-bound native matrix contraction schedules

Date: 2026-10-20. Contract: `TASK_hailo10h_native_matrix_tiles.md`.
Owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Original Mojo `smidr/matrix_tiles.mojo` lowers one source-bound semantic linear
operation to an owned `MatrixSchedule`. Input outer axes flatten to M, the last
input axis is C, and source matrix rows are N. Output outer axes must match
input outer axes exactly; remaining output axes multiply to N, preserving
query/KV head splits. Source offsets, packed kind, exact row byte count and
extent, operation/tensor IDs, consumed weight and local dependency/lifetime/
output-owner constraints are validated. This checks the selected contraction,
not every unrelated graph operation or immutable source identity.

`MatrixTilePolicy` explicitly supplies M/N/C tile extents, input/converted-weight/
accumulator byte widths, power-of-two alignment, workspace bound and provenance.
Workspace is the sum of three separately aligned maximum rectangles: input
Mtile×Ctile, weight Ntile×Ctile and accumulator Mtile×Ntile, clipped to actual
extents. It excludes double buffering, conversion staging and physical device
placement; widths and capacity are assumptions, never discovered hardware facts.
All products, sums, ceiling counts, source extents and full relative scalar/byte
spans are checked for Int64 overflow. Count/selection revalidate returned
schedule constraints rather than trusting cached counts or workspace values.

`matrix_tile_count` and `matrix_tile(schedule,index)` lazily describe M-major,
N-next, C-inner traversal. Each returned tile carries starts, clipped lengths,
logical input/weight/output element origins and row strides, plus exactly one
accumulator-initialize and output-finalize marker per output rectangle. No
M×N×C product tensor or tile list is allocated. The weight origin is a logical
scalar index, not a byte address in packed Q4/Q5/Q6 data. Actual packed source
spans and conversion must be resolved by the following source-streaming pass.
No activation, weight or model arithmetic is evaluated here.

## Verification

Warning-free Mojo 1.1.0 builds and targeted independent tests:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/matrix_tiles.mojo -o ../matrix-tiles
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_matrix_tiles_api.mojo -o ../matrix-tiles-api
python3 tests/test_hailo_matrix_tiles.py --binary ../matrix-tiles --api-binary ../matrix-tiles-api --strace /usr/bin/strace --evidence docs/evidence/matrix-tiles-2026-10-20
```

Seven methods pass, 860 native calls: 799 accepted and 61 refused.
An independent range-enumeration oracle checks all 729 combinations of M/N/C
and tile sizes 1..3, plus tails, head splits, multiple outer axes and returned
ownership: 6672 contraction coordinates, complete nonoverlapping C coverage
and first/final markers for every output element. Source cases cover one/two
layers, tied output, differing query/KV and K/V dimensions, and all current
F32/F16/BF16/Q4_K/Q5_K/Q6_K source descriptor formats. Synthetic source hashes
are unchanged. Exact workspace boundary and malformed policy/graph/binding/
shape/lifetime/owner/extent/index/overflow refusals pass. A 2^32-tile schedule
supports direct final-tile lookup without a tile allocation; diagnostic output
alone refuses enumeration beyond its 4096-tile bound. That bound is not a
compiler/model support limit. Trace confirms read-only source mapping and no
Hailo/CUDA/HailoRT/ggml open or ioctl. Evidence:
`docs/evidence/matrix-tiles-2026-10-20/`.

## Remaining backend work

Every inspector output keeps physical-layout, immutable-source, execution and
device-access flags false. Relative rectangles are not executable Hailo CCWs,
numerical precision, actual packing, physical placement, hardware fit or a
complete model-support certificate. Device numerical configuration and program
upload/configure/activate/result/cleanup remain required. The broad ordinary-
model target is unchanged. Next: `TASK_hailo10h_source_weight_tiles.md` connects
actual source byte spans to these schedules while numerical encoding discovery
continues under `TASK_hailo10h_program_delivery.md`.
