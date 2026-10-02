# SPD-01/02 — activation-residual precision and cost refinement

Established2026-10-01 before implementation. Volmarr authorizes repeated scoped
slices and pushes. 37a53ca publishes passing complete-model prefill gates and a
1.678x long fresh-prefill fixture ratio; long independent RMS .00398677 passes
but is closer to .005 than the native reference. Measure precision improvement
and its cost before runtime/control integration. Exact previous CI is separate.

## Owned changes and fixed gates

Add explicit optional activation_precision0/1/2 to the staged Turing kernel and
launch, retaining0 as the current one-F16-input default. Nonzero modes are admitted
only for rows64/input-columns32. Stage F16 input high plus F16 residual(original
F32-F32(high)) in the same checked shared input allocation. Mode1 adds high-weight
times input-residual MMA, omitting only low-weight times low-input; mode2 includes
that fourth MMA term. All paths accumulate F32, initialize all consumed cells and
take both barriers. Shared bytes=(2*rows+batch*(1+(precision!=0)))*33*2, at most
12672 for split batch32. No new global workspace/full model copy, target/library/
driver/dependency patch or production dispatch. Preserve precision0 and references.

Exercise both modes through complete captured ordinary-F32 gates (1,990,656 full
native values/2520 selected independent dots/114688 source values each) and the
isolated complete-model fixture (513024 logits per mode against full native and
CPU F32 references, exact repeats/commits/eight invalid tiles/4352 guards). Preserve
existing primitive .002/.0002 and independent full-model .05/.005/argmax budgets.
The refinement additionally requires full-model native-to-matrix RMS<=.0005 in
every public case; never relax an old budget. Record all outputs/failures.

Keep one unscored warm/export pair and three alternating fresh pairs per public
prompt. Score only complete original and stricter numerical/identity/guard passes.
Finish all compilation before scored captures, serialize GPU work, then run CPU
oracles. Preserve all failed/successful raw artifacts outside Git. Compare complete
precision0/1/2 sessions honestly; no decode/provider or hardware-cause inference.

Explicit metadata identifies precision in both bounded ordered CSV checkers;
unknown/duplicate/mixed/late modes fail closed and legacy precision0 remains valid.
Extend portable admission/scoring contracts and compile-only CI as needed; update
owners/manual/evidence/ledger/TODO/roadmap/DEVLOG, rebuild/verify unchanged production
binary and authenticated active readiness, push and verify exact CI. A refinement
pass is still test-only. Runtime memory/control/sampling/restore/concurrency,
longer context/decode quality and paired provider lead remain separate gates.
