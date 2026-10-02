# Activation-residual precision and cost — 2026-10-02

Three captured-input sessions pass5,971,968 complete native values/7560 selected
independent dots/344064 original F32 sources. Three model sessions retain all
513024 final logits per mode, exact repeats/commits/eight invalid tiles each and
13056 guards. Every original independent .05/.005/argmax gate passes. Both new
modes miss the additional predeclared native-reference RMS<=.0005 requirement.

| Precision | Captured worst native RMS | Long model native RMS | Refinement | Accepted long speed ratio |
|---|---:|---:|---|---:|
| 0 | .00009482 | .00291580 | original gates pass | 1.675 |
| 1, three terms | .00001370 | .00092567 | rejected | withheld |
| 2, four terms | .00001370 | .00072338 | rejected | withheld |

Four terms reduce long native deviation about4.03x, but do not earn promotion.
Their independent long RMS .00187721 passes the old .005 goal. Retain every96
raw warm/scored timing records; no failed ratio is calculated/published as accepted.
All compilation ends before serialized GPU work, CPU oracles afterward. Default
precision0 stays valid. Ten captured/nine model portable contracts prove strict
metadata/budgets and clearing stale scores on rescoring. Shared bytes<=12672;
no added global workspace or production dispatch. Real captures are strict3B
Q4_K/Q6_K; broader Q5/profile split quality remains open.

Normal executable stays f3442a1e, active service/authenticated healthHTTP200 ready.
Exact pushed CI is separate. Next measure scaled residual storage/accumulation
under the same stricter goal; do not infer hardware causes or relax budgets.
JSON files retain all gates/tokens/timings; provenance hashes raw CSV/build/binary
and source artifacts outside Git. [Operation](../../NATIVE_TURING_ACTIVATION_RESIDUAL.md).
