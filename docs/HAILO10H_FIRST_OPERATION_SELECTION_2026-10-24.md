# Numerical interface — first operation selection (2026-10-24)

Roadmap Campaign 4, slice 4.2 (AES-NUM-002). **Specification
only.** Candidates scored against the AES-NUM-001 field table on:
(1) OUT-dependencies, especially group E (numerical semantics)
and the CCW words; (2) independent-oracle clarity — can a CPU
reference define the exact expected result without vendor code;
(3) shape minimality; (4) what a success would prove.

## Scores

| Candidate | OUT-dependencies | Oracle | Shape | Verdict |
|---|---|---|---|---|
| **Elementwise identity copy** (one tensor in, same tensor out) | CCW/context encoding only. No weights, no constants, no accumulation, **no element-format question at all** — bytes in equal bytes out whatever the representation | **Exact, byte-for-byte**, trivially independent | 1 input, 1 output, no parameters — the smallest complete shape | **SELECTED** |
| ReLU / clamp (unary elementwise) | Copy's set **plus** the element representation (group E: what a value is, where zero sits) | Exact *given* a representation — which is itself OUT | 1 in, 1 out, no weights | Alternate #1 — the first true arithmetic operation, next after copy |
| Constant fill | Constant representation (a weights-class unknown); no input stream makes it atypical of real programs | Exact given the constant encoding | 0 in, 1 out | Rejected for now: spends an unknown to prove less |
| Elementwise add (binary) | Element representation **plus** accumulation semantics (saturation/rounding — group E) and two-input synchronization | Needs a tolerance policy before it needs code | 2 in, 1 out | Rejected for now |
| Small GEMV / dense | Weights layout, tiling, accumulation, representation — the most OUT rows of any candidate | Tolerance policy + layout agreement | weights + input | Rejected for now; it is the *eventual* representative target, not the first |

## Note on the roadmap's expectation

The roadmap's 4.2 text expects, parenthetically, that a
matrix/vector primitive will win — and in the same sentence
subordinates that expectation to the evidence ("the winner is
whichever operation the evidence supports best"). GEMV was
scored under exactly those criteria and lost on criterion (1)
by the widest margin of any candidate. The expectation is
recorded here so the overruling is visible rather than silent;
if the CCW/weights evidence changes, GEMV's score changes with
it, and this record is where that revision would start.

## The selection

**The first operation is the elementwise identity copy of a
single tensor.** Rationale, in the roadmap's own terms — fewest
unknowns, clearest oracle:

- It is the only candidate whose correctness **does not depend on
  any OUT field**. Every other candidate borrows at least one
  group-E value (a representation, a constant encoding, an
  accumulation rule) that evidence does not currently supply.
- Its oracle is the strongest possible: byte equality, checkable
  by an independent implementation with no shared code and no
  tolerance judgment.
- Its success would prove the whole vertical — container,
  upload, context, streams, result retrieval — with correctness
  isolated from arithmetic. Its failures, conversely, can only
  be plumbing failures, which makes them diagnosable.
- Named risk, recorded rather than hidden: the device's program
  vocabulary may not contain a copy/identity primitive at all.
  If 4.3 or later evidence shows that, the selection falls to
  alternate #1 (ReLU) with this record as the reason — the risk
  is a layer-2 question the description process is designed to
  surface, not a defect in the choice.

## Expected eight-layer outcome (stated in advance)

So that slice 4.3 is a test and not a hope, the selection record
predicts, from the field table:

- **Layer 1 (numerical definition): COMPLETE** — identity on
  bytes is exactly definable with no numerical field.
- **Layer 2 (operation definition): COMPLETE at source level**;
  existence in the device's vocabulary **unknown**.
- **Layer 3 (shapes/layout/strides/order): COMPLETE at source
  level** for a fixed small shape; device layout expectations
  unknown.
- **Layer 4 (input/output/parameter derivations): COMPLETE** —
  there are no parameters or constants to derive.
- **Layer 5 (static configuration): INCOMPLETE** — context-action
  layouts exist (group B) but which records a copy program needs,
  and all CCW content, are OUT.
- **Layer 6 (dynamic context actions): INCOMPLETE** — record
  layouts IN; sequencing for a real program unestablished.
- **Layer 7 (result mapping): COMPLETE at source level** (output
  is the input, byte-exact); stream realization unproven.
- **Layer 8 (oracle comparison): COMPLETE** — independent,
  byte-exact, no vendor code in the comparison path.

Prediction: **4 of 8 layers completable now, layers 5–6 blocked
on the same CCW/sequencing unknown the field table flagged** —
Campaign 4 does not exit on this pass, and its iteration item is
exactly the CCW layout research (Track R lane D feeding Campaign
5's encoder gate). If 4.3 contradicts this prediction in either
direction, the contradiction is the finding.
