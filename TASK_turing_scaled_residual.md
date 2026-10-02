# SPD-01/02 — scaled residual representation and accumulation

Established 2026-10-02 before implementation. Volmarr authorizes repeated scoped
slices and pushes. 5adcdcb retains two unscaled input-residual candidates that
pass old quality budgets but miss the additionally declared native-model RMS
goal .0005. Four terms reduce long deviation about 4.03x without earning that
goal. Test finer residual representation and separate correction accumulation;
the cause of the observed error is not established by those measurements.

## Architecture and owned changes

Keep optional precision modes 0/1/2 unchanged. Add explicit modes 3/4 only for
rows64/input-columns32, with the same checked shared high/low allocations and
maximum12672 bytes. Store both weight and activation residuals as
F16(4096*(original-F32(F16(original)))). Compute all four high/low products.
Each correction MMA starts with zero F32 accumulator, then its result is divided
by4096 or16777216 before adding to the unscaled total. Never divide a total
containing an unscaled high-high contribution. Mode3 preserves accumulating
high-high directly into the existing total; mode4 starts even that MMA from
zero, then adds its product in F32. Compare both accumulation orders honestly.

Extract the small MMA accumulation helper before extending the near100-line
kernel. Every function remains under100 lines. Preserve coalesced original
packed decoding, complete initialization of consumed shared cells, both
all-thread barriers, actual-buffer/disjoint-span admission and legacy defaults.
No global workspace, full model copy, production dispatch, provider substitution,
driver/library/target/lock patch, or change to normal one/four admission.

## Fixed acceptance and physical work

Run complete captured ordinary-F32 probes and isolated whole-model probes for
fresh mode0 plus modes3/4. Finish all host compilation before scored sessions;
serialize owned GPU captures, then run independent CPU oracles. Preserve every
attempt, raw value and timing record in distinct files outside Git. Keep one
unscored warm/export pair and three alternating fresh pairs per public prompt.

Retain primitive .002-scaled/.0002-RMS and complete-model .05-max/.005-RMS/
matching-argmax gates. Nonzero modes must still earn native-model RMS<=.0005
in every public case; never relax a budget. Complete captured coverage remains
1,990,656 native values,2520 selected independent dots,114688 F32 source values,
input guards and12 invalid spans per mode. Whole-model coverage remains all
513024 final-prompt logits per mode versus normal native and CPU F32 references,
exact repeats/positions,8 invalid tiles and4352 guards. Nonfinite/overflow or
any quality/identity/guard failure retains complete reports with every speed
ratio withheld. Legacy reports and original0/1/2 modes remain intact.

Extend explicit bounded ordered metadata/checkers/probe dispatch to modes3/4;
unknown/duplicate/mixed/late identities fail closed. Add meaningful portable
contracts for precision admission and failed score clearing, compile sm75/sm89
probes and legacy staging, rebuild/check unchanged normal executable, verify
authenticated active readiness. Hosted compilation never claims GPU execution.
Document observed results, scope and failed candidates in owners, manual,
reviewed evidence,ledger,TODO,roadmap,DEVLOG; push and verify exact CI.

Only a complete stricter pass earns scoring of this test fixture. Production
memory/control/cancellation/sampling/restore/concurrency, broader contexts and
generation quality, and paired provider speed remain separate acceptance gates.
