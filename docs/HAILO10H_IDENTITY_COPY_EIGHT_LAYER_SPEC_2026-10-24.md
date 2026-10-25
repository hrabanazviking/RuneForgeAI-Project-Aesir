# Identity copy — eight-layer description (2026-10-24)

Roadmap Campaign 4, slice 4.3 (AES-NUM-003). **Specification
only — no emitter, no bytes, no physical run.** The operation is
the elementwise identity copy selected in AES-NUM-002. This
description uses the roadmap's own eight layers for 4.3:
(1) numerical definition, (2) tile plan, (3) physical resource
plan, (4) data-movement plan, (5) static configuration,
(6) dynamic program/LCU actions, (7) completion contract,
(8) cleanup contract. Every layer is graded against the
AES-NUM-001 field table and tested against the AES-NUM-002
prediction; a layer that is only specified, not established, is
says so — specified is not proven.

## Fixed shape (Aesir-side choice, not a device fact)

- One input tensor, one output tensor, **16 elements × 1 byte**,
  one-dimensional, contiguous, stride 1, order = index order.
- Elements are **opaque bytes**: the operation is defined on the
  byte sequence, so no element representation is borrowed.
- Input and output are **distinct buffers** (aliasing excluded
  by definition, so an oracle comparison cannot be fooled by a
  shared allocation).
- **Parameters: none — proved, not assumed.** The definition
  below references exactly one argument (the input sequence).
  Its constant/weight list is empty by construction; any device
  encoding that demanded a parameter would be a fact about the
  encoding (layers 5–6), not about this operation.
- Size rationale: 16 bytes is large enough that a single 8-byte
  unit special case cannot pass accidentally, and far below
  every IN transport bound in evidence (2048-byte RPC body cap;
  512-byte descriptor page policy). Those bounds are cited only
  as size context, never as a claim that this buffer rides
  either mechanism.

## Layer 1 — Numerical definition: COMPLETE

- Definition: `out[i] = in[i]` for `i` in `0..15`, on bytes.
- Dimensions: 1-D, length 16 (above). Signedness: **not
  applicable, proved** — no interpretation of any byte is part
  of the definition, so signed and unsigned readings give
  identical output bytes.
- Scaling / zero-point: none. The definition needs no group-E
  value under any representation, because output is defined as
  the input byte sequence itself.
- Accumulator width: **no accumulator exists** in this
  definition; there is no accumulation step. Rounding and
  saturation: **cannot occur** — no arithmetic is defined.
- Output representation: exactly the input representation,
  byte-for-byte. Independent oracle: byte equality, checkable
  with no shared code and no tolerance judgment.
- Agrees with the AES-NUM-002 prediction for layer 1.

## Layer 2 — Tile plan: INCOMPLETE (device level)

- Aesir-side plan, complete: the whole tensor is **one logical
  tile** — no split, no partial tile, no boundary case at this
  size. As a statement about Aesir's own lowering intent, this
  is fully specified.
- Device level: **tile dimensions and tiling order are group-E
  OUT** in AES-NUM-001, and no IN field expresses a tile size
  or order to the device; if tiling is carried in CCW content,
  that content is OUT (group C). There is therefore no sourced
  way to state this plan *to the device*.
- Exact missing fact: a sourced definition of how tile
  geometry is expressed for a program on this target (field or
  CCW content) and which tile dimensions are allowed.
  Research item: **Track R lane D (CCW layout)**, with the
  tiling rows of group E as its acceptance target.
- **Contradiction recorded (the finding of this slice):**
  AES-NUM-002 predicted "layers 1–4, 7, 8 completable at source
  level," but its layer list was a different list (operation
  definition / shapes / parameter derivations / result mapping
  / oracle) from the roadmap's 4.3 list (tile plan / resource
  plan / data movement / completion / cleanup). Under the
  roadmap's list — the governing one — layer 2 does **not**
  clear. The prediction's substance survives where the lists
  agree in content (its "shapes" content is the fixed-shape
  section above; its "no parameters" content is proved there),
  but as a layer-by-layer forecast it was scored against the
  wrong layer names. This record corrects the mapping; 4.4's
  review gate inherits the corrected mapping, not the original.

## Layer 3 — Physical resource plan: INCOMPLETE

- Required by the roadmap: cluster, subclusters, APUs/compute
  units, input aligner, local-memory banks/windows, L2/L3
  offsets.
- What evidence actually holds: group B admits the **packed
  layouts** of the LCU enable/disable/batch-switch records
  (IDs 3, 4, 5, 36), with the unknowns stated in the same rows:
  actual unit/cluster counts unknown, which LCUs a program may
  claim unknown, completion address space unknown. Group E
  marks cluster/subcluster/APU **assignment values** OUT, and
  local-memory bank/window assignment and L2/L3 offsets OUT.
  The Do Not Infer law adds: an `active_l2` bitmap's bits have
  no known physical meanings and no known legal H10H resource
  count.
- The only honest resource statement available is a
  requirement, not a plan: a copy conceptually needs one
  compute resource and equal-size input/output windows. No
  number, unit, cluster, bank, or offset value is asserted —
  inventing one is exactly what this campaign forbids.
- Exact missing facts: resource counts for this target; safe
  assignment values; memory bank/window assignment definitions.
  Research item: **Track R placement study** (group-E
  assignment rows), distinct from lane D.

## Layer 4 — Data-movement plan: SPECIFIED (host), NOT ESTABLISHED (device)

Specified, from IN facts only, in order:

1. A program object reaches the device through Campaign 3's
   separate payload phase: **one async session read of exactly
   the declared size after a readiness wait**
   (`rpc_connection.cpp` at the pin, per AES-NUM-001's Track R
   addendum). Gate: the **SoC session readiness protocol is
   NOT ESTABLISHED**, so this step is specified but cannot yet
   be scheduled or executed under a contract.
2. Program streams bind through stream metadata whose
   **structure is IN** (group A: name/shape/format entries,
   consumed by the configure handler per AES-PROG-004). The
   numeric **format semantics are OUT**; a byte-opaque copy is
   the one operation whose source-level correctness does not
   depend on them, but the device's binding semantics remain
   unproven for any operation, this one included.
3. Host-side buffer handling follows the qualified owners
   (AES-TRANSFER-002 primitive; AES-PROG-002 lifecycle owner).
   **Not credited:** AES-TRANSFER-004 physically proved one
   CREATE *control* exchange through the primitive — a control
   exchange is not data-stream movement for a program, and the
   Do Not Infer law forbids reading it as such.
4. Device-internal movement (aligner → compute → output) has
   **no sourced description**; it is the same unknown as
   layers 2, 3, and 5 seen from the data side.

- Exact missing facts: SoC session readiness protocol;
  device stream-movement semantics. Research items: **Track R
  session study** (already the named gate in AES-NUM-001) and
  layers 2/3/5 research above.
- Verdict: the plan is written; the layer does **not** clear,
  because its device half is unestablished.

## Layer 5 — Static configuration: INCOMPLETE (as predicted)

- Admissible content, listed exhaustively: container metadata
  admitted as references/carriers only (group A — header
  hw-arch `HAILO1XH=103` as metadata; CCW pointer/inline
  actions as carriers; stream metadata structure), and the
  group-B context-action **layouts**.
- The blocking fact is unchanged: **CCW words are OUT
  entirely** (group C — opcode layout, register addresses,
  operand encoding all without any public definition found).
  A copy program's static configuration is, on present
  evidence, precisely CCW content plus a selection of context
  records — and *which* records a copy needs is itself
  unestablished (layer 6). No bytes are emitted by this slice,
  and no unknown field may be zero-substituted (roadmap §2.3:
  unknown stays `Unknown`).
- Exact missing fact: the CCW word layout. Research item:
  **Track R lane D** — the same item that blocks layer 2 and
  gates Campaign 5's encoder.

## Layer 6 — Dynamic program/LCU actions: INCOMPLETE (as predicted)

- Admissible: the group-B record layouts (IDs 0, 3, 4, 5, 27,
  35 **layout only**, 36) and the program lifecycle action
  codecs (2/4/3/5/10/11/12) as qualified in AES-PROG-001/002.
- Unestablished: the **sequence** for a real program — which
  actions, in which order, with which counts and completion
  addresses, this operation requires. ID 35's **address values
  remain OUT**: no safe address exists in evidence, so no
  typed-write step can be specified with a value.
- Exact missing fact: a sourced minimal-program action
  sequence (from the pinned receiver/configure path), plus —
  for any typed-write step — a safe address. Research item:
  **Track R program-sequencing study**, dependent on lane D
  for any CCW-carrying steps.

## Layer 7 — Completion contract: SPECIFIED (terms fully sourced)

A run of this operation may be called complete **only** when
all of the following hold — every term is sourced, none is
aspirational:

- Lifecycle exchanges complete under the Campaign 2 law:
  typed replies validated by the consumer; completion credited
  only on an IRQ completion record with data **1** for an owned
  channel; **0** means not yet, **0xFE** is a channel error,
  and **0xFF (CHANNEL_NOT_ACTIVE) is never credited as success**
  (AES-TRANSFER-001's decode of the -018 physical evidence).
- The output buffer compares **byte-equal** to the input buffer
  under the layer-1 oracle, read back through the qualified
  result path — an IRQ alone does not imply correct returned
  data (Do Not Infer law).
- No stage poisoned the owner; any uncertainty is a failure of
  the run, never a partial success.

- Honest boundary: this contract is **specified, not shown
  satisfiable**. Program actions' physical completion remains
  the Campaign 3 gate (AES-PROG-003 branch B2: the action-2
  metadata exchange earned no reply before the payload phase).
  Layer 7 clears as a *specification* because a completion
  contract is a statement of conditions and every condition
  above has a source; whether the device can be brought to
  meet it is Campaign 5's physical question, not a missing
  term in this contract.

## Layer 8 — Cleanup contract: SPECIFIED (host), NOT ESTABLISHED (device, partial states)

Specified terms, from AES-PROG-002/004 (host-qualified):

- Teardown follows the lifecycle owner's conservative
  client-side order; the two handle tiers (infer vs configured)
  are never interchangeable; destroy-configured performs
  shutdown receiver-side at source level (AES-PROG-004, Q6).
- Failure accounting is exact: corrupting any stage's reply
  stops the owner at that stage with its residue tier printed;
  a create failure is the worst class (object possibly created,
  handle never learned); recovery-by-adoption is deliberately
  not implemented.
- Any failure after a device CREATE records the handle as
  **residue — not logically destroyed** — and closes the batch.
  Local cleanup and remote quiescence are recorded separately,
  always (this repo already carries three recorded residues
  under exactly this honesty rule).
- A reclaim path exists at source level: connection disconnect
  cleanup releases a client's resources (AES-PROG-004). Whether
  our sessions trigger it on this profile is **not
  established**, so it is named as a path, never as a guarantee.

- The unestablished term: teardown **ordering and
  preconditions for partial states** were NOT ESTABLISHED in
  AES-PROG-001 and remain so. That is a genuine layer unknown,
  so layer 8 does **not** fully clear: host terms specified,
  device partial-state terms open. Research item: Track R
  receiver study of partial-state teardown preconditions.

## Scoreboard against the AES-NUM-002 prediction

| Layer (roadmap 4.3) | Result | Prediction test |
|---|---|---|
| 1 Numerical definition | **COMPLETE** | Agrees |
| 2 Tile plan | **INCOMPLETE** (device) | **Contradicts** — prediction used a different layer list; corrected here |
| 3 Physical resource plan | **INCOMPLETE** | Same contradiction class as layer 2 (group-E assignment was already OUT in AES-NUM-001) |
| 4 Data-movement plan | Specified host / not established device | Partially agrees (its host content was the prediction's "derivations" content) |
| 5 Static configuration | **INCOMPLETE** | Agrees — CCW content |
| 6 Dynamic actions | **INCOMPLETE** | Agrees — sequencing |
| 7 Completion contract | **SPECIFIED** (satisfiability = Campaign 5) | Agrees in substance (prediction's result-mapping/oracle content lives here and in layer 1) |
| 8 Cleanup contract | Specified host / not established device (partial states) | Stronger than predicted on host terms; weaker on device terms |

**Campaign 4 does not exit on this pass** — as AES-NUM-001 and
AES-NUM-002 both predicted in substance. The identity copy does
not clear all eight layers, so it stays **unqualified**, and no
Campaign 5 encoder may be contracted from this spec. The
iteration items, in dependency order:

- **R1 (lane D):** CCW word layout — blocks layers 2 and 5,
  gates Campaign 5.
- **R2:** SoC session readiness protocol — blocks layer 4's
  device half and every payload contract.
- **R3:** Placement counts and safe assignment values —
  blocks layer 3.
- **R4:** Minimal-program action sequencing (incl. any safe
  ID-35 address) — blocks layer 6.
- **R5:** Partial-state teardown preconditions — blocks
  layer 8's device half.

Next: slice 4.4, the spec review gate — this description
reviewed in human-readable form against the Do Not Infer table
before Campaign 5 is contracted (it will not be, on this pass:
the gate's job is to certify exactly that, field by field).

## Addendum 2026-10-24 (AES-NUM-006, Track R R2)

R2 landed ESTABLISHED at source level (firmware-cap sub-part
NOT PROVEN); the study and full citations live in
`docs/HAILO10H_SOC_SESSION_READINESS_STUDY_2026-10-24.md`.
Effect on this spec, gate re-run on the changed layers only
(PASS, AES-NUM-006 §5):

- **Layer 4:** the readiness gate in step 1 is resolved at
  source level — there is no wire-level readiness signal; the
  receiver's session admits transfers by a local bounded-queue
  rule and the size comes from the preceding RPC message.
  Layer 4 re-grades to SPECIFIED (host) / readiness
  ESTABLISHED (device, source level); steps 2 and 4 remain
  unsourced, and no payload movement is physically proven.
- **Layer 7:** the F1 term now reads "read back through the
  source-described, Aesir-unqualified result path" — the path
  is described in the pinned client layer (registered read
  buffers read after a success reply) and remains unqualified
  in Aesir.

All other layers unchanged. Operation remains UNQUALIFIED;
Campaign 4 exit NOT MET; Campaign 5 NOT contracted.
