# SPD-01/02 — coalesced shared staging for public packed Turing MMA

Established2026-10-01. Volmarr authorizes successive scoped slices and pushes.
9ca36d3 publishes split-weight precision success and rejection of every28 speed
case; exact remote CI is pending separately. e5e988c's physical prerequisite CI
passes all36 steps. No measured candidate replaces strict batch-four defaults.

## Owned design and fixed acceptance

Extend optional core/packed_turing_matrix.mojo with a separately named staged
candidate. Read original packed_block_group equations with coalesced32-column
lanes, stage F16 weight high/residual plus F16 inputs in padded shared rows and
reuse them in public m16n8k8 F32 MMA. Test CTA row tiles16/32/64, with1/2/4 warps;
each warp owns16 rows and iterates8-token output groups. All threads participate
in both section barriers, including row/token tails. Explicit zeros mask unused
operands. Shared storage is compile-time bounded<=10560 bytes (64rows/batch32),
not a persistent/full-model F16 copy. No extra global workspace or production
dispatch. Preserve the direct optional candidate and every scalar/block/four/SIMT
reference. Use only the already proved explicit sm_75/PTX6.5 public operation.

Each of three configurations repeats144 synthetic three-format tail cases,
12 invalid-span rejections, all1,658,880 native output comparisons,2100 selected
independent Float64 real dots and560 paired equal-work timings. Combined counts
are432 synthetic cases,36 invalid spans,4,976,640 native outputs,6300 selected
independent dots and1680 timings. The predeclared budgets stay scaled<=0.002 and
normalized RMS<=0.0002. Exact same model bytes, shapes, binary input formula,
resident warmup,10 alternating pairs and3 calls/sample. Finish host compilation
before final captures; serialize owned GPU work and retain all failures.

An explicit staged MODE/row metadata marker distinguishes every configuration.
Extend the reusable harness through an opt-in selector with existing defaults
unchanged, strict checker mode/geometry admission and portable adversarial tests.
CI compiles optional probes without a GPU claim. Update owning documentation,
operation/evidence, ledger/roadmap/TODO/DEVLOG and private raw hashes. Rebuild and
verify unchanged native binary, active authenticated service readiness, push and
verify exact CI. No primitive improvement earns full-model precision, cancellation/
restore/state or provider lead. Choose next work from actual measurements; do not
infer a hardware cause or promote a favorable subset.
