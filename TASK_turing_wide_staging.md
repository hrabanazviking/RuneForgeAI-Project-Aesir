# SPD-01/02 — measured wider staged-input Turing MMA refinement

Established2026-10-01. Volmarr authorizes successive scoped slices and pushes.
62c5f51 publishes three correct shared-staging row choices; exact CI is pending
separately. 9ca36d3's exact CI passes all36 steps. Every batch4 shape still loses,
while64-row/batch32 FFN gate reaches1.92x equal existing primitive work. The next
measurement widens staged input while retaining all precision/control boundaries.

## Owned implementation and fixed gates

Extend the optional staged kernel/launch with compile-time input columns32/64/128,
retaining32 as the current default. Test four new explicit choices: rows32 or64
combined with columns64 or128. Each CTA initializes all consumed F16 high/residual
weight/input cells before its section barrier, uses existing packed_block_group
equations in coalesced32-column subgroups, and consumes8-column public MMA steps
before the second all-thread barrier. Row/token tails never touch unowned data.
Shared bytes=(2*rows+batch)*(columns+1)*2 <=49152; the largest exercised choice
64rows/128columns/batch32 is41280 bytes. No additional global workspace, full
F16 model copy, target/library/driver/dependency patch or normal inference dispatch.
Preserve32-column staging, direct Turing and strict scalar/block/four/SIMT paths.

Each configuration repeats144 synthetic tails,12 invalid spans,1,658,880 complete
native output pairs,2100 selected independent Float64 real dots and560 paired
timing records. Combined four-choice totals are576 synthetic cases,48 invalid
spans,6,635,520 native outputs,8400 selected independent dots and2240 timings.
Keep scaled<=0.002 and normalized RMS<=0.0002 budgets, exact original model/input
formula, warmed resident weights and10 alternating pairs with3 calls per sample.
Finish host compilation before scored captures; serialize GPU work and run CPU
oracles afterward. All failed/successful raw artifacts remain outside Git.

An explicit wide MODE/rows/columns marker and new opt-in probe own configuration
identity. Reject unsupported/mixed/late/duplicate geometry. Existing CSV/default
selectors remain compatible. Extend portable evidence checks and compile-only CI,
update owners/manual/evidence/ledger/TODO/roadmap/DEVLOG, rebuild and verify unchanged
production binary/active authenticated readiness, push and verify exact CI. Larger
batch primitive gains do not earn full-model activation/state/control/provider
gates; choose subsequent work from measured results without cherry-picking.
