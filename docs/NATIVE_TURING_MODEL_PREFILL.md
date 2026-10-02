# Isolated complete-model Turing prefill gate

This optional native test runs the measured matrix candidate through all 28 layers
of the original strict Llama 3.2 3B model. It compares every final-prompt logit with
normal four-token AESIR and an independent CPU reference. Normal core, CLI and
service admission remain unchanged. A passing fixture is a prerequisite for
separate runtime/control integration.

## Architecture and measured work

tests/turing_prefill_fixture.mojo owns a normal validated reference session at
context 1536 and a separate checked 32-token scratch layout, guarded F16 KV,
sampler/history and output. It shares the normal session's immutable model weights
and owning CUDA context. It never changes the reference session's layout, scratch
or cache. Checked products and actual lengths bound memory, and allocation requires
observed free memory plus 256 MiB reserve. Normal admission still allows one/four.

A complete 32-token tile uses CTA rows 64/input width 32 staged public Turing MMA
for Q, attention output and FFN gate/up/down. K/V use the existing four-token F32
projections. Four-token and scalar tails retain those native reference operators.
Embedding, normalization, RoPE, causal attention, SiLU and residual operations
reuse native kernels. Each token sees only its causal positions; the owning stream
consumes shared scores before reuse. Only synchronized complete tiles commit IDs
and positions. Failed GPU execution poisons this fixture until context recreation.

The last input token runs singly and produces fresh logits through the original
F32 output projection and native sampler. Both modes own equivalent fresh history
and sampling work. The fixture does not generate replies or expose request controls;
generation, restore, cancellation, concurrent use and recovery need their own
runtime slice. Eight malformed metadata/token/context/buffer/health cases reject
before mutation. A checked 32-value padding gap per token accommodates the
physical guard prefix inside borrowed matrix-span admission. Scratch/cache edges
and every token padding cell retain 1088 values per public case. The initial
unpadded guarded layout failed admission before its first larger tile; that raw
source/binary/CSV is retained and no span check is relaxed.

The four existing SPD-00 public prompts include the 1070-token graph paragraph.
Each mode exports all 128256 final-prompt F32 logits per prompt through Float64
text. All three scored repeats must exactly reproduce their mode's exported vector
and committed IDs/positions. One warm/export pair is unscored, followed by three
alternating fresh pairs. Timing includes synchronized native prefill and final
sampling work, with allocation, reset, tokenization, export and printing outside
the interval. Complete model quality gates must pass before ratios are admitted.

## Reproduction

Use frozen Mojo 1.0.0/MAX 26.5.0, the original GGUF and physical sm_75 device.
Compile all targets before captures; run other GPU tests and CPU inference afterward.
Set ARTIFACTS to a new private directory outside Git, MODEL/MODEL_SHA to the original
blob/hash, and ORACLE_PYTHON to the prepared llama-cpp-python 0.3.23/NumPy 2.4.4
test interpreter. REFERENCE/REFERENCE_SHA identify the separately derived F32
oracle artifact. DERIVATION is the original successful conversion JSON containing
source/derived/converter hashes, size and exit status. It is never a production model.

```bash
: "${ARTIFACTS:?set a new private artifact directory outside Git}"
: "${MODEL:?set original GGUF}"
: "${MODEL_SHA:?set verified original SHA-256}"
: "${ORACLE_PYTHON:?set prepared CPU oracle interpreter}"
: "${REFERENCE:?set separately derived F32 test GGUF}"
: "${REFERENCE_SHA:?set verified derived SHA-256}"
: "${DERIVATION:?set original successful conversion JSON}"
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_model_prefill.mojo \
  -o "$ARTIFACTS/model-prefill-probe"
timeout 300 "$ARTIFACTS/model-prefill-probe" "$MODEL" \
  > "$ARTIFACTS/complete.csv" 2>&1
"$ORACLE_PYTHON" scripts/check_turing_model_prefill.py "$ARTIFACTS/complete.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-model "$REFERENCE" --reference-sha256 "$REFERENCE_SHA" \
  --reference-provenance "$DERIVATION" --threads 4 \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_turing_model_prefill.py
```

Keep every failed attempt and complete raw CSV outside Git. JSON publication is
exclusive. A COMPLETE marker means collection only. The bounded regular/no-follow
checker requires exact ordered inputs/full logits, finite exact F32 values,
all alternating samples, committed positions, zero repeat mismatches, guards and
completion totals. Eight portable adversarial contracts cover admission and scoring;
hosted CI compiles the optional probe without claiming GPU execution.

The independent test-only CPU oracle uses zero GPU layers, context 4096, F16 KV,
batch 128, four CPU threads and the declared F32-expanded weights. Both native
modes use context 1536; all tested positions fit both. It consumes the exact
exported input IDs, compares all 513024 values per mode and verifies original/
derived model hashes before and after inference plus conversion provenance.
The fixed maximum absolute error 0.05, RMS error 0.005 and matching full-vocabulary
argmax gates are unchanged. No approximate Q8_K activation reference replaces
this independently expanded F32 oracle.

## Acceptance boundary

Any numerical, identity, completion or guard failure withholds every timing ratio
and retains the full failed report. A pass earns only four final-prompt vectors
and their observed fresh-prefill timings in one physical session. There is no
whole-request, decode, Ollama/provider lead or second-session certificate.
Normal four-token inference remains unchanged. Separately scope runtime memory,
control checkpoints, tails, sampling, exact restore, interruption/reset, concurrency
and longer context/decode quality before promotion.
[Projection operation](NATIVE_PACKED_TURING_MATRIX.md),
[captured activation gate](NATIVE_TURING_ACTIVATIONS.md),
[independent reference derivation](SPEED_MEASUREMENT.md).

The first padded physical fixture passes all 513024 final-prompt values per mode,
eight mutation-free rejections, 4352 outer/padding guards and exact full-vector
repeats/committed IDs. Original public input streams match the earlier SPD-00
measurement. Independent matrix worst max/RMS errors are .02159834/.00398677,
with matching argmax in every case; fixed .05/.005 budgets pass. Native-reference
worst matrix errors are .00948805/.00291580. Initial unpadded admission failure
remains. Every scored and warm sample is retained.

| Prompt input tokens | Native prefill median, seconds | Matrix prefill median, seconds | Native/matrix ratio |
|---:|---:|---:|---:|
| 30 | .32753 | .34034 | .962 |
| 37 | .39228 | .24471 | 1.603 |
| 31 | .35150 | .36453 | .964 |
| 1070 | 12.71706 | 7.57781 | 1.678 |

The 30/31-token prompts use only reference tails and gain no speed. This is one
physical fresh-prefill fixture session, with no generation or provider comparison.
RMS on the long matrix case is closer to the fixed limit than the original native
reference; an explicitly gated activation-residual precision/cost experiment is
the next refinement before runtime/control integration. No limit is relaxed.
Original production binary remains f3442a1e with active authenticated readiness;
exact pushed CI is separate. [Reviewed evidence](evidence/turing-model-prefill-2026-10-01/README.md).
