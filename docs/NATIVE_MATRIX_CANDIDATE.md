# Experimental packed matrix projection

The first SPD-01 candidate is an opt-in native Mojo SIMT matrix primitive,
reached by test_packed_matrix.mojo, not normal inference dispatch. It preserves
batch-one/four, model bytes, causal KV and four-token deadline polling. SPD-01
integration remains open. Slower candidates must never become defaults.

## Design and admission

One 128-thread block owns 32 output rows by 4/8/16/32 input tokens. Shared decoded
Q4_K/Q5_K/Q6_K weights and activation tiles reuse values across rows/tokens.
Padded 33-element shared rows need 4608/5136/6192/8448 bytes per block respectively.
There is no full expanded model or device-global matrix workspace. All threads
take both barriers, including row/token tails. This uses ordinary F32 SIMT;
no Tensor-Core claim. See the [MAX barrier contract](https://max.modular.com/api/mojo/max/gpu/sync/sync/barrier/)
and [Mojo allocation API](https://mojolang.static.modular.com/1.0.0/docs/std/memory/stack_allocation/stack_allocation/).
Actual locked-toolchain sm_75 execution is separate from documentation.

Column-chronological accumulation differs from the warp reference. Predeclared
primitive budgets are abs(actual-reference)/(1+abs(reference))<=0.002 for every
finite output, and RMS of those scaled errors<=0.0002. The independent whole-model
0.05 absolute/0.005 RMS/matching-argmax budgets remain unchanged; another slice
must pass them before runtime integration.

project_matrix[kind,batch] admits actual borrowed buffer lengths, columns 256..14336
aligned 256, rows 1..128256, tokens 1..batch, weight bytes, nonoverlapping input/output
and complete token strides before enqueue. Bounded shapes plus subtraction/division
checks avoid overflow. The wrapper allocates nothing and mutates no session state.
Kernel-only callers must meet the same contract. Nonfinite outputs fail the probe
and independent evidence gates; the optional raw kernel does not sanitize values.

## Physical reproduction and schemas

Use the existing locked Pixi environment, a new output outside Git, actual installed
Llama3.2 3B weights and serialized GPU work. The probe owns one context 512 allocation;
observe enough VRAM and never stop unrelated services to make space.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_packed_matrix.mojo \
  -o /your/new-matrix-probe
/your/new-matrix-probe /your/registered-3b-model > /your/new-matrix.csv
```

Retain every unsuccessful build/probe/checker artifact. Require process exit 0 and
final PASS,matrix,28,1658880,560. Tests cover 144 synthetic cases: three quant kinds,
four widths, three row tails and four batches. Full input/guard spans are checked;
twelve invalid spans reject before enqueue. Seven real layer-zero tensor shapes
at each batch provide all 1,658,880 native-reference output comparisons. Inputs
are exact F32 binary fractions: ((column*7+token*13)%29-14)/16.

CSV owns ordered CASE/VALUE/GUARD/TIME/SYNTHETIC and mandatory final PASS records.
Each case has ten paired timing samples of three calls, alternating order. Host
monotonic launch/synchronize times use uploaded/warmed weights; allocation, copies
and printing are excluded. Baseline executes batch/4 existing four-token kernels
for equal work. This is neither fresh service prefill nor whole-request speed.

## Independent real-weight check

Use an isolated optional test environment with gguf==0.19.0 and numpy==2.4.4.
They never supply production inference. Independent GGUFReader metadata and
upstream dequantization supply Float64 CPU dots for five selected rows per real
tensor/batch, covering 2100 outputs against candidate and native reference. Full
native-reference coverage is separate from this selected independent subset.

```sh
python scripts/check_packed_matrix.py /your/new-matrix.csv \
  --model /your/registered-3b-model --model-sha256 YOUR_MODEL_SHA256 \
  --output /your/new-matrix-summary.json
python3 scripts/test_check_packed_matrix.py
```

The checker requires a bounded regular UTF-8 input<= 256 MiB, final-component
symlink/special-file rejection, complete ordered counts, passing guards/finite
values, independent descriptor identity and original model hash. Six portable
adversarial tests verify missing/duplicate/wrong/nonfinite records and fixed
budgets. Exclusive output retains failures. Exit0 means primitive evidence passes;
it does not authorize dispatch promotion. Memory scales with full CSV/arrays.
Keep raw CSV, binaries and weights outside Git; publish hashes and summaries.

The first design loses at batch 4 on every real shape. Batch 32 modestly wins some
larger Q/output/FFN shapes but loses K/V. Next: reduce staging/barrier cost and
measure tile/occupancy choices, then a separate full-model/control integration
gate if viable. Neither 2x prefill nor an overall Ollama lead is earned here.

## Explicit shared-tile tuning

Optional tile_rows=8/16/32 and tile_columns=32/64/128 retain the original32/32
compile-time defaults. Staging uses (rows+batch)*(columns+1)*4 shared bytes, with
an enforced49152-byte block ceiling. Inactive output threads still participate
in both barriers and never read/write outside the shared/output tile. Changing
staging does not change chronological F32 accumulation or primitive budgets.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_matrix_tile_tuning.mojo \
  -o /your/new-tuning-probe
/your/new-tuning-probe /your/registered-3b-model 32 64 > /your/new-tuning.csv
```

Declared physical tuning choices are32/64,32/128,16/64,16/128,8/128. Use the
original probe for32/32. TILE,rows,columns metadata precedes synthetic/case
records; legacy CSV without TILE explicitly means32/32. Duplicate/unsupported
metadata fails. Each configuration repeats all physical/oracle/timing gates.
Compile first, then serialize GPU captures; host compilation must be idle during
scoring. Final six-choice evidence rejects every batch4 shape for promotion;
maximum observed batch32 benefit is about1.29x. No default inference changes.
