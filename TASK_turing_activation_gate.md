# SPD-01/02 — ordinary native F32 activation gate

Established2026-10-01 before implementation. Volmarr authorizes successive scoped
slices and pushes. aff7a1e publishes correct wider staging with measured rejection;
the prior64-row/32-input-column candidate remains the best primitive choice.
Its tests used F16-representable binary fractions. Test actual ordinary native
F32 operands before any full-model integration or default promotion.

## Owned implementation and fixed gates

Add an optional physical precision-only probe and bounded independent checker.
Two fixed public prompts are tokenized by the native strict3B tokenizer; replay
complete four-token tiles with the unchanged native prefill path. After the final
tile, copy layer27 FFN-normalized, attention-output-input and SiLU/down-input
vectors for all four positions. These are actual operands for layer27 output,
gate/up/down. The FFN-normalized vectors are representative normalized operands
for Q/K/V, not a claim of capturing their earlier attention-normalization values.
Record exact replayed token IDs, positions, source identities and every F32 input
through Float64 text. No production capture hook or model/state mutation beyond
the owned test session is introduced.

Exercise original layer27 seven real projection tensors at batch4 and batch32;
batch32 repeats the four captured vectors eight times. Use the optional64-row/
32-column staged candidate and complete native F32 block references. Compare all
1,990,656 outputs, guard/input spans and selected2520 independent Float64 real
dots. Preserve twelve malformed-span rejections. Fixed scaled<=0.002 and normalized
RMS<=0.0002 budgets remain. Emit complete results even on numerical failure;
completion means collection only and never a pass. Independently recompute every
budget and retain failed JSON/exit1. No timing or full-model quality/provider score
belongs to this slice. Independent dots consume the exported original F32 vectors,
not values rounded to F16 or regenerated binary-fraction recipes.

The checker owns ordered bounded regular/no-follow CSV admission, exact source/
case/token/output/count identity, finite values, whole guards, original model hash
and independently validated descriptors. Exclusive reports retain failures and
per-case numerical evidence. Add portable adversarial contracts and compile-only
CI without claiming hosted GPU execution. Finish all compilation before serialized
physical captures; run CPU oracles afterward. Keep all raw attempts outside Git.

Update owners/manual/evidence/ledger/TODO/roadmap/DEVLOG, rebuild and verify the
unchanged production binary and active authenticated readiness, push and verify
exact CI. If ordinary-F32 precision fails, publish the rejection and separately
scope an activation-residual refinement before changing compute; never relax
budgets or quietly promote a larger tile/control policy.
