# Optional bounded fused causal attention

`core/fused_causal_attention.mojo` is a native Mojo primitive for strict3B GQA
geometry: 24 query heads, 8 K/V heads, 128 columns per head, F32 query/output and
F16 K/V. It shares up to 4096 F32 scores within each CTA (16 KiB defined shared
array), so it needs no global score workspace. One 128-thread CTA owns a query
head/token. Four warps compute the original lane-stride dot products and warp
sums; warp0 computes the original maximum, exp and lane-stride softmax sum;
all lanes consume values in the original chronological four-value accumulation
order. Both stage barriers and initialized consumed score cells are explicit.
This is shared-score fusion; online-softmax arithmetic remains a separate gate.

## API and ownership

`admit_attention[batch]` checks fixed head geometry, capacity 1..4096, nonnegative
prefix, tokens 1..batch fitting `prefix+tokens`, F32 query/output spans, their
disjointness and the complete F16 K/V allocation. Batch capacities 1/4/32 only.
Subtract-before-add checks plus `stride <= elements//tokens` bound every offset
and product by the borrowed allocation; the valid model-fixture stride 33824 is
admitted. `attend_fused[batch]` runs admission and checks a compatible CUDA context
before enqueueing grid `(24,tokens)`, block128. Buffers belong to the caller's
context/stream; the caller owns finite validated inputs and prior cache writes.
The wrapper makes no host copies. Failure propagates to the owning session.

Head mapping is `head*8//24`; query token `i` reads only K/V history
`0..prefix+i`. Full capacity includes future cells, which must remain unread and
unchanged. The optional collector proves this causal result against a full
independent reference with distinct position/head patterns. It also checks every
query and K/V cell for mutation and every unowned guard after synchronization.
Admission rejects hostile metadata before the probe constructs a CUDA context.

## Physical acceptance and speed boundary

All 39 cases pass 16 hostile metadata refusals, 1,370,112 F32 values per native
and fused owner, exact original UInt32 bits including signed zero, and 364,518
guard cells. Native checks cover all 1,370,112 query cells and 82,194,432 K/V
cells. These are deterministic exactly representable patterns, zeros and large
stable-softmax logits, rather than actual model Q/K/V. Full causal histories end
at 1/31/32/33/37/255/256/257/1070/1535/1536/4095/4096, including partial batches.
A pinned NumPy2.4.4 Float64 oracle independently computes every output. Fixed
budgets are 0.002 maximum scaled error and 0.0002 normalized RMS, established
before measurement. No tolerance was tuned to observed results.

Worst candidate error: `1.34141323057e-06` scaled / `9.83809686184e-08` normalized RMS.

| Batch capacity | Actual queries | Final causal count | Input mode | Native ms | Fused ms | Native / fused |
| ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 1 | 1 | 1 | dyadic | 0.01051 | 0.00569 | 1.846065 |
| 1 | 1 | 31 | zero | 0.01375 | 0.01426 | 0.964640 |
| 1 | 1 | 32 | large logits | 0.01252 | 0.01192 | 1.050579 |
| 1 | 1 | 33 | dyadic | 0.01295 | 0.01299 | 0.997304 |
| 1 | 1 | 37 | zero | 0.01413 | 0.01591 | 0.888132 |
| 1 | 1 | 255 | large logits | 0.03515 | 0.06465 | 0.543678 |
| 1 | 1 | 256 | dyadic | 0.03435 | 0.06363 | 0.539874 |
| 1 | 1 | 257 | zero | 0.03799 | 0.07792 | 0.487497 |
| 1 | 1 | 1070 | large logits | 0.12898 | 0.35518 | 0.363153 |
| 1 | 1 | 1535 | dyadic | 0.18654 | 0.50948 | 0.366145 |
| 1 | 1 | 1536 | zero | 0.19433 | 0.57470 | 0.338148 |
| 1 | 1 | 4095 | large logits | 0.49257 | 1.33740 | 0.368300 |
| 1 | 1 | 4096 | dyadic | 0.49183 | 1.33918 | 0.367263 |
| 4 | 1 | 1 | zero | 0.01033 | 0.00570 | 1.812244 |
| 4 | 4 | 31 | large logits | 0.04622 | 0.01357 | 3.407091 |
| 4 | 4 | 32 | dyadic | 0.04613 | 0.01361 | 3.389108 |
| 4 | 4 | 33 | zero | 0.04794 | 0.01594 | 3.006910 |
| 4 | 4 | 37 | large logits | 0.04818 | 0.01553 | 3.101713 |
| 4 | 4 | 255 | dyadic | 0.13285 | 0.07441 | 1.785376 |
| 4 | 4 | 256 | zero | 0.15517 | 0.09516 | 1.630525 |
| 4 | 4 | 257 | large logits | 0.14606 | 0.08193 | 1.782689 |
| 4 | 4 | 1070 | dyadic | 0.55302 | 0.39788 | 1.389920 |
| 4 | 4 | 1535 | zero | 0.84956 | 0.65718 | 1.292738 |
| 4 | 4 | 1536 | large logits | 0.79488 | 0.57267 | 1.388029 |
| 4 | 4 | 4095 | dyadic | 1.72844 | 1.23632 | 1.398050 |
| 4 | 4 | 4096 | zero | 1.77330 | 1.36173 | 1.302235 |
| 32 | 1 | 1 | large logits | 0.00752 | 0.00419 | 1.796879 |
| 32 | 31 | 31 | dyadic | 0.19838 | 0.02897 | 6.848346 |
| 32 | 32 | 32 | zero | 0.21020 | 0.03356 | 6.262835 |
| 32 | 32 | 33 | large logits | 0.20472 | 0.03113 | 6.576180 |
| 32 | 32 | 37 | dyadic | 0.21142 | 0.03551 | 5.953005 |
| 32 | 32 | 255 | zero | 0.67892 | 0.32906 | 2.063176 |
| 32 | 32 | 256 | large logits | 0.63916 | 0.27728 | 2.305081 |
| 32 | 32 | 257 | dyadic | 0.64211 | 0.27829 | 2.307347 |
| 32 | 32 | 1070 | zero | 2.92233 | 2.07607 | 1.407625 |
| 32 | 32 | 1535 | large logits | 4.35495 | 2.85842 | 1.523554 |
| 32 | 32 | 1536 | dyadic | 4.37724 | 2.86886 | 1.525778 |
| 32 | 32 | 4095 | zero | 12.35258 | 8.62265 | 1.432574 |
| 32 | 32 | 4096 | large logits | 12.01938 | 7.77351 | 1.546197 |

Ratios above one mean lower fused elapsed. All 780 actual timing records remain:
ten alternating samples per case, three complete original or fused attention
calls plus synchronization per sample. Original dispatch enqueues scores,
softmax and values per query; fused dispatch enqueues one batched attention call.
Allocation, warmups, input generation, export, builds, process and CPU oracle
are unscored. This is one exploratory physical session. Single-query long
histories lose; retain the existing single-token path. Full batches4/32 improve
in this capture, but earn no default, full-model or provider promotion.

## Reproduce from a prepared checkout

Finish locked Mojo1.0.0 / MAX26.5.0 sm75/sm89/original/master/normal/check builds
before GPU work. Use an exclusive private artifact directory and serialize GPU
capture, followed by CPU validation. Record source and binary hashes before
build/capture and source/binary/CSV hashes afterward, with UTC process receipts.
Shell redirection below can overwrite files; the supervised evidence collector
uses exclusive creation and a fresh directory instead.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_fused_causal_attention.mojo \
  -o "$ARTIFACTS/fused-attention"
"$ARTIFACTS/fused-attention" > "$ARTIFACTS/complete.csv"
"$ORACLE_PYTHON" scripts/check_fused_causal_attention.py "$ARTIFACTS/complete.csv" \
  --binary "$ARTIFACTS/fused-attention" --binary-sha256 "$BINARY_SHA" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_fused_causal_attention.py
```

The probe takes no arguments; incorrect usage refuses before CUDA. The checker
admits a bounded no-follow regular CSV, exact geometry/input/guard/timing totals,
strict ordered complete F32 values, finite positive per-call times and the pinned
oracle. It requires exact binary identity before and binary/CSV identity after
validation. Exclusive JSON preserves failed/interrupted reports; full numerical,
bit or changed-artifact failures atomically clear every ratio. Underflow/overflow,
nonfinite or incomplete evidence cannot earn a speed score. Python supplies only
test supervision/reference math and never production inference or a fallback.

Nine portable adversarial contracts and master190 pass, with one explicit skip.
Hosted CI tests and compiles the probe; physical execution is established by the
separate retained capture. The initial reserved variable `ref` failed parsing and
was renamed; failed sources/log remain. A CUDA-context fence prompted a complete
rebuild before the first physical capture. The first successful capture remains
preliminary: audit removed an arbitrary32768 stride ceiling in favor of checked
actual allocation bounds and added valid33824 admission. All six final builds
finished before a new physical capture and independent oracle. No earlier data
or binary was overwritten, and the normal authenticated prefill4 service stays
ready with unchanged f3442a1e binary.

## Next gate for human and AI contributors

Read [the accepted model fixture](NATIVE_TURING_DOWN_MODEL.md) before integrating.
Use a default-disabled capability and keep slow single-token attention on the
original path. Prove actual model Q/K/V or full-model source-bound exact logits,
full F16 cache, IDs, causal/sample state and independent CPU quality before any
selection. Then earn generation, replay, enabled controls, context/device,
concurrency and soak gates. Do not combine primitive ratios to predict request
speed. Production32 and refreshed Ollama comparison remain open. Publish a Task
MD before implementation; retain all failures and exact push/CI receipts.
