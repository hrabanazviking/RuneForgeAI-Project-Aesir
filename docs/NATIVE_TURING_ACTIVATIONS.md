# Captured native F32 activation precision gate

Binary-fraction primitive inputs do not establish ordinary activation quality.
This optional test captures actual native F32 vectors from two fixed public
prompt replays and checks the staged Turing candidate with the same error limits.
It collects every numerical failure and keeps inference policy unchanged.

## Source and ownership

test_turing_activations.mojo owns an independent strict Llama 3.2 3B session at
context 512, F16 KV, original packed weights, prefix reuse disabled and batch four.
It tokenizes the fixed river/project prompts in the probe, replays all complete
four-token tiles and records exact committed input IDs and positions. The final
one to three input tokens, if present, are outside this capture. It performs no
generation, full-model logit comparison or production-service attachment.

After the final tile, it copies all four token positions from three layer-27
buffers: FFN-normalized input, attention result before output projection and
SiLU input to FFN down. These are actual operands for output, FFN gate/up/down.
Q/K/V use the captured FFN-normalized vectors as representative normalized inputs;
the test does not claim to capture their earlier attention-normalization operands.
Sources retain every original F32 value through exact Float64 text export.

For each replay it checks all seven original layer-27 projection tensors at
batch four and batch 32. Batch 32 repeats the four captured vectors eight times;
it does not represent a 32-token full-model trajectory. The optional candidate
uses CTA rows 64 and staged-input width 32. Complete native F32 block references
and all input/guard cells are checked in separate borrowed output spans. Twelve
malformed matrix spans reject before GPU enqueue. No production hook, control
change, full-model conversion or additional candidate workspace is introduced.

## Reproduction

Use the frozen Mojo 1.0.0/MAX 26.5.0 environment and physical sm_75 GPU. Set MODEL
to the original GGUF, MODEL_SHA to its verified SHA-256, ARTIFACTS to a new private
directory outside Git, and ORACLE_PYTHON to the prepared independent interpreter
with exactly gguf 0.19.0 and NumPy 2.4.4. Compile everything before capture; run
the independent CPU oracle after GPU work has ended. Keep every failed attempt.

```bash
: "${ARTIFACTS:?set a new private artifact directory outside Git}"
: "${MODEL:?set the original GGUF path}"
: "${MODEL_SHA:?set its verified SHA-256}"
: "${ORACLE_PYTHON:?set the prepared independent oracle interpreter}"
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_activations.mojo \
  -o "$ARTIFACTS/activation-probe"
timeout 300 "$ARTIFACTS/activation-probe" "$MODEL" \
  > "$ARTIFACTS/complete.csv" 2>&1
"$ORACLE_PYTHON" scripts/check_turing_activations.py "$ARTIFACTS/complete.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --output "$ARTIFACTS/complete.json"
python3 scripts/test_check_turing_activations.py
```

The COMPLETE marker certifies collection only. Every output is exported even
when it violates the fixed scaled-per-value 0.002 or normalized-RMS 0.0002 budget.
The checker independently recomputes all 28 native case metrics and compares
five selected real weight rows per case with Float64 dots using the exact exported
F32 inputs and independent GGUF decoding. It verifies original model hashes before
and after the oracle, independent descriptors and every ordered source/value/
guard/count. Selected independent coverage differs from complete native coverage.
Failed numeric gates produce an exclusive complete report and exit one.

CSV admission rejects special/symlink files, inputs over 256 MiB, nonfinite or
inexact-F32 values, unsupported metadata, wrong source/case order, mismatched
replay positions, incomplete/duplicate/trailing records and false native metrics.
Nine portable adversarial contracts exercise those boundaries; hosted CI compiles
the optional probe without claiming actual GPU execution. Reports record ordinary
inputs that cannot be represented in F16 and any F16 overflow. These observations
do not certify all activation ranges or complete model quality.

## Acceptance boundary

A numerical failure prevents promotion and requires a separately scoped precision
refinement. Keep the original failed capture and limits. A pass earns only these
two captured final-layer projection cases; full-model independent logits, causal
state, tails, seeded/greedy generation, restore, interruption/reset and paired
whole-request speed remain separate gates. This precision-only capture has no
speed score. [Packed candidate operation](NATIVE_PACKED_TURING_MATRIX.md).

The first physical capture passes all 1,990,656 complete native outputs and 2520
selected independent Float64 dots, with 114688 exported source values and all
guards. Both public replays commit 32 positions. Of the source values, 114677
are not exactly F16-representable; none overflows F16, and maximum magnitude is
27.140867. Worst complete-native scaled/RMS errors are .0013060/.00009482;
worst selected-independent errors are .00020492/.00007762. Budgets are unchanged.
The initial list-constructor compile error and corrected build remain outside
Git. Nine portable contracts pass, optional physical/hosted-target builds pass,
and the native production executable remains f3442a1e with active authenticated
readiness. Exact pushed CI is separate. Next separately scope whole-model
prefill precision/state/control integration.
[Reviewed capture](evidence/turing-activations-2026-10-01/README.md).
