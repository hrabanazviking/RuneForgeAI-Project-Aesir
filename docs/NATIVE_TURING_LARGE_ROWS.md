# Larger row CTA staging: operation and acceptance

This explicitly selected primitive experiment shares the original padded F16
activation staging across128 weight rows. It uses original GGUF bytes and
precision0 on the exercised RTX2060 Max-Q sm75, locked Mojo1.0.0/MAX26.5.0.
[Physical results](evidence/turing-large-rows-2026-10-02/README.md) own acceptance;
this manual describes the mechanism and reproduction, not provider admission.

## Ownership and bounds

`project_turing_large_rows[kind,batch,tile_rows]` admits128 only. Original
`project_turing_staged` and both original/cached kernel definitions remain intact.
Every warp still owns16 rows and retains chronological original public m16n8k8
F32 accumulation. Original packed-block expressions and split F16 weight high/
residual,32-column sections,33 pitch and both all-thread barriers stay intact.
Shared bytes are(2*rows+batch)*33*2: maximum19008 at128, with256 threads. No new global workspace, device allocation or runtime selection.

The input load loop uses ceil(batch/warps), guarding token<batch before storing
shared cells. This initializes all consumed active/inactive token cells even when
there are more row warps than tokens. Extra warps never store outside the batch
array; inactive weight rows initialize zero, and unowned output rows never store.
Existing matrix admission checks actual buffers/format/span/products/disjointness
before enqueue. Do not widen these explicit geometries without new gates.

## Reproduce

Use a new private artifact directory outside Git and verified original GGUF/hash.
Prepare a test-only interpreter with exactly gguf0.19.0/NumPy2.4.4. Finish both
targets, legacy/header collectors, master, normal build/check and other owned GPU
work before captures. Capture128 serially, then run the CPU oracles afterward.
Keep failures/raw stdout/stderr/process/source hashes; do not overwrite outputs.

```bash
: "${ARTIFACTS:?set a new private directory outside Git}"
: "${MODEL:?set original registered GGUF path}"
: "${MODEL_SHA:?set verified lowercase SHA256}"
: "${ORACLE_PYTHON:?set prepared test-only interpreter}"
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_large_rows.mojo \
  -o "$ARTIFACTS/row-probe"
# Finish the other builds before these serial GPU captures.
for ROW_TILE in 128; do
  timeout 300 "$ARTIFACTS/row-probe" "$MODEL" "$ROW_TILE" \
    > "$ARTIFACTS/rows-$ROW_TILE.csv" 2> "$ARTIFACTS/rows-$ROW_TILE.stderr"
done
for ROW_TILE in 128; do
  "$ORACLE_PYTHON" scripts/check_packed_matrix.py \
    "$ARTIFACTS/rows-$ROW_TILE.csv" --model "$MODEL" \
    --model-sha256 "$MODEL_SHA" --output "$ARTIFACTS/rows-$ROW_TILE.json"
done
python3 scripts/test_check_packed_matrix.py
```

The mode is `MODE,turing_mma_staged_large_rows_f16_f32,ROWS,32`. CLI rejects other
rows before model load. Each capture must contain28 complete real cases,144
synthetic Q4/Q5/Q6 tails,12 invalid spans, all guards,1658880 outputs per owner,
and840 rotating records. Real model Q4/Q6 is distinct from synthetic Q5 coverage.
VALUE holds native/new/original64 F32 values via exact Float64 text. Every new/
original bit must match, including signed zero, while native and selected2100
independent Float64 dots pass unchanged .002-scaled/.0002-normalized RMS budgets.
No independent full-model inference belongs to this primitive oracle.

## Read reports

`paired_original=True` binds three complete owners. `cached_headers=False` proves
this mode does not select the rejected header-cache candidate. Ten warmed samples
per owner, three actual calls each, rotate native/new/original. Ratios use median
host-monotonic launch/synchronize time, excluding allocation/export. `speed_ratio`
is native/new; `original_to_candidate_ratio` is original64/new in the same
capture. Below1 means the new shape is slower. Retain every losing tensor/batch.
One primitive session is not a provider or second-session lead certificate.

Strict geometry/identity/rotation/exact finite values/totals/newline and after-
oracle model/CSV digests gate scoring. Complete numerical failures preserve all
metrics with every ratio withheld. Partial, mutated, interrupted or structurally
invalid evidence stays failed in exclusive JSON. Header-cache legacy reports
keep their original_to_cached_ratio alias; other legacy two-owner schemas remain.
Sixteen portable contracts prove admission behavior, not actual GPU execution.
Hosted CI compiles the opt-in collector; physical evidence supplies device proof.

The initial256 probe fails its first physical launch with
CUDA_ERROR_LAUNCH_OUT_OF_RESOURCES. Its source/binary/partial CSV/process/failed
JSON remain retained and unscored. Final kernel/wrapper/CLI/checker admit128 only;
256 rejects before model load without a fallback. Do not infer a precise
register/occupancy cause from the resource error alone.

A primitive win must separately earn ordinary real-F32 activation, full-model
vectors/cache/state, decode/sample/replay/control, broader context/device/concurrency/
soak and refreshed provider gates before runtime selection. Preserve original
production policy while those gates are open.
