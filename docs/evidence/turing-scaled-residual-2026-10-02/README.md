# Scaled residual representation and accumulation — 2026-10-02

Three captured sessions pass 5,971,968 complete native values, 7560 selected
independent dots and 344064 original F32 sources. All three model sessions pass
every original independent .05/.005/matching-argmax gate and exact repeats,
commits, eight invalid tiles each and 13056 guards. Both nonzero modes miss the
unchanged additionally declared native-model RMS goal .0005.

| Mode | Captured worst native RMS | Long native-model RMS | Refinement | Accepted long prefill ratio |
|---|---:|---:|---|---:|
| 0 | .00009482 | .00291580 | original gates pass | 1.675 |
| 3, scaled corrections | .00000468 | .00113806 | rejected | withheld |
| 4, separate high-high | .000000394 | .00122564 | rejected | withheld |

Mode4 improves captured RMS about241x without earning complete-model acceptance.
Independent long matrix RMS .00161759/.00245646 passes the older .005 limit.
All96 raw timing records remain; both failed modes withhold every speed ratio.
No budget relaxes and no hardware cause is inferred. Checked shared bytes remain
<=12672 with no global workspace. sm75/sm89 probes and legacy staging compile;
ten captured/nine model portable contracts pass. All compilation ends before
serialized GPU captures, independent CPU references afterward. Broader Q5_K,
profiles/contexts/generation and runtime/control/restore/provider lead stay open.

Normal binary remains f3442a1e; authenticated HTTP200 ready and active service
are verified separately. Exact pushed CI has its own receipt. Next harden
checked workspace/profile/device admission for original passing mode0. JSON
retains complete gates/IDs/timings; provenance hashes raw CSV/build/binary/source
artifacts outside Git. [Operation](../../NATIVE_TURING_SCALED_RESIDUAL.md).
