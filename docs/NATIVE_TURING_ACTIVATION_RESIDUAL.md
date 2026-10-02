# Optional activation-residual precision and cost experiment

The original isolated matrix fixture passes complete-model gates and reaches
1.678x long fresh-prefill speed, with independent long RMS .00398677 under the
fixed .005 limit. This experiment measures whether keeping an input residual
improves precision enough to justify its actual cost. It changes optional test
paths; normal runtime admission remains one/four.

## Operand and storage contract

project_turing_staged gains an optional fifth template parameter
activation_precision. Zero preserves one F16 input and two weight MMA terms.
Modes one/two are admitted only for CTA rows 64 and input width 32. The shared
input allocation contains F16 high plus F16 residual(original-F32(high)) rows.
Every consumed cell, including inactive tokens, is initialized before the existing
all-thread barriers. Original weight high/residual decoding remains unchanged.

Mode one adds high-weight times low-input to the existing high/low-weight times
high-input terms. It omits only low-weight times low-input. Mode two includes
that fourth term. All accumulation remains F32. The numerical gates, rather
than an assumption about term size, decide whether either is acceptable.
Shared bytes=(2*rows+batch*(1+(precision!=0)))*33*2, at most 12672 for split
batch 32. There is no additional global workspace or full F16 model copy.
Target, pinned dependencies and normal inference policy remain unchanged.

## Reproduce complete comparisons

Read [captured-input operation](NATIVE_TURING_ACTIVATIONS.md) and
[whole-model operation](NATIVE_TURING_MODEL_PREFILL.md) first. Their original
model/hash, private artifact, CPU interpreter and F32-reference derivation
variables remain required. Both probes accept an optional final integer 0/1/2;
omission preserves legacy zero. Compile both once, finish every host build,
then serialize all owned GPU captures before running independent CPU oracles.
Use a new file for every attempt, including precision zero.

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_activations.mojo \
  -o "$ARTIFACTS/activation-probe"
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_model_prefill.mojo \
  -o "$ARTIFACTS/model-probe"
# After all compilation ends, repeat separately for PRECISION=0,1,2.
timeout 300 "$ARTIFACTS/activation-probe" "$MODEL" "$PRECISION" \
  > "$ARTIFACTS/activation-$PRECISION.csv" 2>&1
timeout 300 "$ARTIFACTS/model-probe" "$MODEL" "$PRECISION" \
  > "$ARTIFACTS/model-$PRECISION.csv" 2>&1
```

Apply the complete independent checker commands from the two operation guides
to their matching CSVs, with distinct exclusive JSON filenames. Their sources,
inputs, output coverage, warmup/alternating order and original model are unchanged.
Captured inputs cover all 1,990,656 native values and 2520 selected independent
dots per precision. Whole-model evidence covers all 513024 final-prompt values
per mode, eight invalid tiles, 4352 guards and all 32 paired timing records.

Nonzero metadata explicitly identifies precision. Captured streams use
META,1,turing_native_f32_split,64,32,precision,12. Whole-model streams add precision
before the final invalid-count field. Only one/two are accepted in those extended
identities; zero retains its original schema. Unknown/mixed/duplicate/late
metadata rejects. Ten captured-input and nine model portable contracts cover
legacy admission, strict identity and failed scoring. Hosted CI compiles all
explicit variants without claiming GPU execution.

## Acceptance and next work

All original primitive .002-scaled/.0002-RMS and complete-model .05-max/.005-RMS/
matching-argmax gates remain. Nonzero whole-model modes additionally require
native-to-matrix RMS at most .0005 in every public case. Completion never means
success. Any failure retains complete metrics and withholds every ratio, including
stale ratios if a report is rescored after an earlier pass.

Compare every complete precision session honestly. First warm/export pairs are
unscored; all three alternating fresh pairs remain. These are isolated prefill
timings, not generation, decode, Ollama/provider or second-session scores. Broader
contexts and decode quality, runtime memory/control, sampling, restore and
concurrency still need separate gates. Retain every failed/successful raw artifact
outside Git and publish reviewed hashes/summaries with exact pushed CI receipts.

The first complete comparison spans three captured-input and three whole-model
sessions after all compilation ends. All three captured-input sessions pass their
original budgets: 5,971,968 complete native values, 7560 selected independent dots,
344064 original source values and all input/guards. All three whole-model sessions
preserve exact repeats/commits, eight invalid tiles each and 13056 guarded cells.
Every original independent .05/.005/argmax gate passes. The nonzero refinements
miss the additionally predeclared .0005 native-reference RMS goal on the long case.

| Precision | Captured native worst RMS | Long native-reference RMS | Refined goal | Accepted speed ratio, long |
|---|---:|---:|---|---:|
| 0, original | .00009482 | .00291580 | original budgets pass | 1.675 |
| 1, three terms | .00001370 | .00092567 | rejected | withheld |
| 2, four terms | .00001370 | .00072338 | rejected | withheld |

Precision two reduces long deviation from normal AESIR by about 4.03x, but that
does not earn the stricter goal. Its independent long RMS .00187721 passes the
older .005 gate. Preserve all 96 raw warm/scored model records; do not calculate
or publish accepted ratios for rejected modes. No mode is promoted and no budget
is relaxed. Next separately scope scaled residual storage and accumulation to
measure whether finer correction representation earns the same stricter gate.
There is no hardware-cause inference from these errors. Real residual captures
exercise original strict3B Q4_K/Q6_K; broader Q5_K/profile split precision remains
unproved. Normal production binary stays f3442a1e with active authenticated
readiness. Exact pushed CI is separate.
[Reviewed comparisons](evidence/turing-activation-residual-2026-10-02/README.md).
