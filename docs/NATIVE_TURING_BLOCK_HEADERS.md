# Packed-block header reuse: operation and rejected speed candidate

This explicit opt-in primitive experiment uses original GGUF bytes on the exercised
RTX2060 Max-Q sm75, locked Mojo1.0.0/MAX26.5.0. Numerical equality is accepted;
performance is worse for the batch32 FFN target, so do not select it for inference.
[Complete measurements](evidence/turing-block-headers-2026-10-02/README.md).

## Ownership and limits

`project_turing_staged[kind,batch,tile_rows,tile_columns,activation_precision,
cache_headers]` adds a final compile-time Bool default False. True only admits
precision0/rows64/width32. Existing matrix span/device/format admission runs before
enqueue; the old entry body is intact. The separate cached sibling holds two
16-element F32 arrays per thread (Q6 d only), filling each block's scales before
eight original sections. Shared maximum10560 bytes; no new device allocation,
weight mutation, installed patch, assembly fallback or production dispatch.

`test_turing_block_headers.mojo MODEL` explicitly selects this mode and emits
`MODE,turing_mma_staged_header_cache_f16_f32,64,32`. Full ordered VALUE records
hold native/cached/original F32 via Float64 text; all cached/original bits must
match. Existing two device output spans plus a bounded host native snapshot are
used. Real native/independent budgets remain .002-scaled/.0002-RMS. Original
real Q4/Q6 tensors and synthetic Q4/Q5/Q6 have distinct coverage.

## Reproduce safely

From the checkout, use new private artifact paths outside Git. Finish all builds
and other owned GPU work before timing. Keep CSV stdout and stderr separately;
do not overwrite failed captures. Use a prepared test-only interpreter with exact
gguf0.19.0/NumPy2.4.4; it never supplies production inference.

```bash
: "${ARTIFACTS:?set a new private directory outside Git}"
: "${MODEL:?set the original registered GGUF path}"
: "${MODEL_SHA:?set its verified SHA256}"
: "${ORACLE_PYTHON:?set prepared test-only interpreter}"
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_block_headers.mojo \
  -o "$ARTIFACTS/header-probe"
# Finish sm89/master/normal/check builds before this serial physical run.
timeout 300 "$ARTIFACTS/header-probe" "$MODEL" \
  > "$ARTIFACTS/complete.csv" 2> "$ARTIFACTS/stderr.txt"
"$ORACLE_PYTHON" scripts/check_packed_matrix.py "$ARTIFACTS/complete.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_packed_matrix.py
```

The checker admits complete28 cases/1658880 real outputs/840 timings, exact finite
F32 exports, 30 rotating records per case and final newline. Source/model digest
rechecks after the independent oracle. Complete numerical failures retain all
cases/errors but clear every ratio; structural/partial/interrupt failure remains
unsuccessful in an exclusive JSON. Do not treat portable tests or sm89 compilation
as physical inference evidence. Host CI compiles the opt-in collector only.

## Interpret results

`speed_ratio` compares native four-token reference with cached staging;
`original_to_cached_ratio` compares old staged and cached paths captured together.
Both are median elapsed time ratios, with a value below1 meaning the candidate
is slower. There are ten warmed samples per owner and three actual calls per
sample, rotating all three owners. All28 cases and840 records remain, including
losing shapes. Allocation/printing/oracle process time is excluded; profiler time
is not scored. One primitive session does not certify a provider lead.

The targeted batch32 gate/up/down ratios .6843/.6890/.9025 reject this candidate.
Preserve original cache_headers=False and exact arithmetic. Extra register
pressure is a possible cause, not measured here. Larger CTA reuse is the next
separately scoped experiment. Captured real F32 activations, complete model,
decode/replay/controls, broader contexts/devices/concurrency/soak and refreshed
Ollama/provider gates still own any later promotion.
