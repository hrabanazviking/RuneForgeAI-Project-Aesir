# SPD-01/04 — bounded packed-block header reuse in staged FFN projection

Established2026-10-02 before code. Volmarr authorizes successive scoped slices
and pushes. Actual tensor-bound74e7de5 projection tracing identifies batch32 FFN
gate/up/down as52.04% of long recorded kernel duration; down is largest. Preserve
production one/four and all original numerical/ownership/control boundaries.

The current64-row/32-column staged kernel rereads identical per-row packed-block
scale headers across eight32-column sections. Scope a default-disabled compile-
time header-cache choice for original precision0/64-row/32-column staging only.
Load each admitted row's d/dmin once per256-column packed block into bounded
per-thread16-element F32 arrays. Q6 has only d; inactive rows initialize zero.
Preserve every dequantization expression, F16 high/residual conversion, barriers,
MMA accumulation order and output store. No new shared/global/device buffer,
assembly fallback, dependency, runtime dispatch or weight mutation. Register
pressure may outweigh reused loads: acceptance is measured, never assumed.

Extend the existing physical primitive harness with an explicit opt-in choice;
default collectors retain their exact schema/behavior. For the new collector,
emit complete native/old-staged/cached F32 vectors with Float64 text, including
signed zero. Require all cached/old-staged bits to match before scoring. Retain
all existing native .002-scaled/.0002-RMS and independent real-weight budgets,
144 synthetic tails/three formats,12 invalid spans and all actual guards.
Use existing two device output spans plus one bounded host native snapshot;
no extra device allocation. New metadata binds mode/geometry. Three-owner warmed
timings rotate native/cached/old-staged through ten samples, three actual calls
each; preserve all840 timing records for28 real cases and only score after every
native/old/independent/guard/source gate. Old-to-cached ratio is from paired same-
capture samples, not historical runs. Primitive results do not promote providers.

Own core packed_turing_matrix, tests primitive harness/new collector and scripts
primitive checker/contracts, wire new probe into CI. Finish both target/master/
normal/check builds before serial GPU collection and optional pinned CPU oracle.
Rehash source/model/CSV after oracle; exclusive reports retain complete metrics
on numerical failure and partial/error/interruption evidence, clearing ratios.
Preserve every failed attempt. Verify unchanged normal binary and authenticated
ready service; update owner interfaces/manual/evidence/ledger/TODO/roadmap/devlog,
push and exact CI. If reused headers lose, retain default and report the measured
rejection. If they win, real F32 activation and complete-model gates remain the
next separate slice before any fixture/runtime promotion.
