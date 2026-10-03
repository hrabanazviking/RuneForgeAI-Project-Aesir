# Narrow16-column shared staging — 2026-10-03

All56 measured comparisons lose to original64; no default promotion.
Both64/128-row numerical gates pass. The candidate is separately appended and
all earlier packed Turing kernel/wrapper definitions remain verbatim. Half-groups
initialize every16-column shared cell, including inactive rows/tokens; every warp
participates in original public MMA and both barriers. High/residual conversion
and sequential F32 accumulation remain, with no device/global workspace or
production dispatch. Defined batch32 padded shared arrays5440/9792 bytes versus
10560/19008 are a source storage reduction, not observed register/occupancy proof.

Each configuration passes144 synthetic Q4/Q5/Q6 tail cases/12 span refusals,
all1658880 actual native/candidate/original F32 outputs/1622640 guards/2100 selected
independent original-weight Float64 dots under unchanged .002-scaled/.0002-RMS.
Every original64/candidate F32 bit matches, including signed zero. Real Q4/Q6
coverage remains distinct from synthetic Q5. All840 rotated timings retain ten
samples/three launches per native/candidate/original owner, with synchronization.
Both serial GPU captures finish before pinned gguf0.19/NumPy2.4.4 CPU oracles;
all seven target/original/header/master/normal/check gates finish first.

Original64/columns32 versus candidate median elapsed ratios from each SAME capture:
below1 means slower. These are warmed primitive timings, not service speeds.

| Candidate rows | Batch | Q | K | V | Output | Gate | Up | Down |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 4 | 0.8062 | 0.7434 | 0.8655 | 0.8173 | 0.8568 | 0.8671 | 0.9393 |
| 64 | 8 | 0.7619 | 0.6021 | 0.8476 | 0.7627 | 0.6143 | 0.6170 | 0.9463 |
| 64 | 16 | 0.6300 | 0.5462 | 0.7115 | 0.6242 | 0.5130 | 0.5167 | 0.8082 |
| 64 | 32 | 0.5384 | 0.5067 | 0.5800 | 0.5312 | 0.4740 | 0.4381 | 0.6580 |
| 128 | 4 | 0.7949 | 0.6020 | 0.6430 | 0.8134 | 0.7240 | 0.7330 | 0.9206 |
| 128 | 8 | 0.7617 | 0.5278 | 0.5455 | 0.7625 | 0.6085 | 0.6142 | 0.7015 |
| 128 | 16 | 0.6972 | 0.5192 | 0.6819 | 0.6796 | 0.5609 | 0.5626 | 0.8821 |
| 128 | 32 | 0.6608 | 0.5406 | 0.6815 | 0.6836 | 0.5457 | 0.5496 | 0.8405 |

Best ratio0.946255 atrows64/batch8/blk.0.ffn_down.weight; 0 of56
cases exceed1. Complete numerical acceptance earns no automatic promotion. No
comparison to historical128/32 elapsed time is scored; a direct comparison would
need its own same-capture owner. More barriers/half-lane work are design tradeoffs,
not demonstrated causes of any measured result. All samples, failures and hashes
remain; no favorable subset replaces complete evidence.

Nineteen portable adversarial contracts preserve old schemas and bind narrow
geometry/original bits (signed zero)/rotated timing/full failures/source changes/
interrupt/exclusive outputs. The audit also fixes positive per-call underflow and
nonfinite ratio overflow: a complete failed score clears every ratio while
retaining all28 cases. Master190 passes/one skip; actual256 with a nonexistent
model path refuses before model/CUDA. Normal f3442a1e remains active/authenticated
ready/prefill4/cpuoffload0. No broader actual F32/full-model/decode/replay/control/
context/device/concurrency/soak/provider gate is promoted.
[Operation](../../NATIVE_TURING_NARROW_STAGING.md). Exact push/CI receipts are separate.
