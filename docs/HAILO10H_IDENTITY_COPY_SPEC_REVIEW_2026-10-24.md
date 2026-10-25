# Identity copy spec — review gate (2026-10-24)

Roadmap Campaign 4, slice 4.4 (AES-NUM-004). **Review only —
no emitter, no bytes, no physical run, and Campaign 5 is NOT
contracted by this gate.** The document under review is the
AES-NUM-003 eight-layer description of the elementwise identity
copy (`docs/HAILO10H_IDENTITY_COPY_EIGHT_LAYER_SPEC_2026-10-24.md`),
read against two authorities: the AES-NUM-001 field table
(groups A–E, the only source of IN/OUT grades) and the roadmap
§2.2 Do Not Infer table (16 entries, law until stronger evidence
supersedes an entry).

Gate questions, in order: (1) does every field or value the
spec uses carry a source and a known meaning, or is it
explicitly graded UNKNOWN/OUT? (2) does any statement in the
spec commit a Do Not Infer violation? (3) is the corrected
AES-NUM-002 → roadmap layer mapping sound? (4) does Campaign
4's exit condition hold?

## 1. Field-by-field audit (against AES-NUM-001)

**Fixed shape section.**

| Spec statement | Source / grade | Verdict |
|---|---|---|
| 16 elements × 1 byte, 1-D, contiguous, stride 1, index order | Aesir-side choice, declared as such ("not a device fact") | PASS — no device meaning claimed |
| Elements are opaque bytes; no representation borrowed | Definition-level; borrows nothing from group E | PASS |
| Input/output distinct buffers; aliasing excluded by definition | Aesir-side definition | PASS |
| Parameters: none, proved from the definition | Proof, not assumption; the definition's only argument is the input sequence | PASS |
| Size rationale cites the 2048-byte RPC body cap and the 512-byte descriptor page policy | Group D / Track R addendum, both IN | PASS WITH CLARIFICATION (finding F2 below): the spec's own disclaimer — context only, never a claim this buffer rides either mechanism — is load-bearing and is confirmed as the correct reading |

**Layer 1 (numerical definition).** `out[i] = in[i]` on bytes;
signedness, scaling/zero-point, accumulator, rounding and
saturation each answered by a proof of non-applicability, not
by borrowing a group-E field. Output representation = input
representation; oracle = byte equality with no shared code.
Every group-E row this layer touches is OUT in the table, and
the layer claims none of them. **PASS — COMPLETE stands.**

**Layer 2 (tile plan).** Aesir-side: one logical tile, fully
specified as lowering intent. Device level: tile dimensions
and tiling order are group-E OUT; no IN field expresses them;
if carried in CCW content, that content is OUT (group C).
Graded INCOMPLETE with the exact missing fact named (Track R
lane D). **PASS — the unknown stays unknown; nothing is
zero-substituted (roadmap §2.3 honoured).**

**Layer 3 (physical resource plan).** References group-B
packed layouts (IDs 3, 4, 5, 36) as layouts only, with the
table's own unknowns repeated (unit/cluster counts, claimable
LCUs, completion address space). Assignment values, bank/
window assignment, L2/L3 offsets: group-E OUT, graded
INCOMPLETE. The only resource statement is a requirement (one
compute resource, equal-size windows) with no number asserted.
**PASS.**

**Layer 4 (data-movement plan).** Step 1: payload = one async
session read of exactly the declared size after a readiness
wait — source `rpc_connection.cpp` at the pin via the
AES-NUM-001 Track R addendum; the SoC session readiness
protocol is graded NOT ESTABLISHED in the same breath. Step 2:
stream metadata structure IN (group A), numeric format
semantics OUT — both stated. Step 3: host handling follows the
qualified owners (AES-TRANSFER-002, AES-PROG-002) and the spec
explicitly refuses to credit the AES-TRANSFER-004 CREATE
control exchange as data-stream movement. Step 4: device-
internal movement has no sourced description, graded unknown.
**PASS — specified host / not established device stands.**

**Layer 5 (static configuration).** Admissible content listed
exhaustively and each item matches its table grade: header
hw-arch `HAILO1XH=103` as metadata (group A IN-as-metadata —
the value 103, never the runtime enum 6, is the program field);
CCW pointer/inline actions as references/carriers only; stream
metadata structure; group-B layouts. CCW words OUT entirely
(group C). No bytes emitted; no zero-substitution. **PASS —
INCOMPLETE stands.**

**Layer 6 (dynamic actions).** Group-B layouts (IDs 0, 3, 4,
5, 27, 35 layout-only, 36) and the lifecycle action codecs
(2/4/3/5/10/11/12) as qualified in AES-PROG-001/002 — all used
at exactly their table grades. The real-program sequence and
any safe ID-35 address value are graded unestablished/OUT.
**PASS — INCOMPLETE stands.**

**Layer 7 (completion contract).** Terms: Campaign 2 typed-
reply law; IRQ data 1 = completed, 0 = not yet, 0xFE = channel
error, 0xFF CHANNEL_NOT_ACTIVE never credited as success
(pinned UAPI + AES-CONTROL-018 decode + AES-TRANSFER-001);
byte-equal readback required in addition to any IRQ;
poison-on-uncertainty. Satisfiability explicitly not claimed.
**PASS WITH FINDING F1 (below) — SPECIFIED stands as a
statement of sourced conditions.**

**Layer 8 (cleanup contract).** Host terms from AES-PROG-002/
004 (owner ordering, two handle tiers never interchangeable,
failure tiers with create-failure worst, residue recorded as
not logically destroyed, local cleanup and remote quiescence
recorded separately). Destroy-configured receiver-side
shutdown cited at source level (AES-PROG-004 Q6) and graded
exactly that way. Disconnect cleanup named as a path, never a
guarantee. Partial-state ordering graded NOT ESTABLISHED
(AES-PROG-001). **PASS — specified host / device partial
states open stands.**

### Findings

- **F1 (wording overreach, tightened by this gate).** Layer 7
  requires the output be "read back through the qualified
  result path." No *program result* readback path is qualified
  as such: the Campaign 2 primitive is qualified for raw
  grouped exchanges and AES-TRANSFER-004 proved one CREATE
  *control* exchange through it — the same distinction layer 4
  step 3 correctly enforces. The contract term itself stands
  (byte-equal readback is required, and an IRQ alone never
  suffices), but the readback path's qualification *for
  program results* is NOT ESTABLISHED and is hereby added to
  the dependency set of iteration items R2/R4. The spec is not
  edited retroactively; this gate record is the correction of
  record.
- **F2 (clarification, not a defect).** The fixed-shape size
  rationale cites the 2048-byte RPC body cap alongside the
  512-byte descriptor policy. The 2048 cap governs RPC
  *messages* (AES-NUM-001 Track R addendum); the payload phase
  is a session read, not a message. The spec's explicit
  disclaimer ("cited only as size context, never as a claim
  that this buffer rides either mechanism") is therefore
  load-bearing, and this gate confirms the disclaimer — not
  either number — is what the rationale rests on. At 16 bytes
  no chunking question arises at source level under any of
  the cited bounds.

No other field, value, or term in the spec lacks a source or
carries an ungraded meaning. In particular the gate confirms
the spec never asserts: a tile size or order, a resource
count or assignment value, a bank/window or offset, a CCW
word, an action sequence, a typed-write address, a format
semantic, or a readiness mechanism.

## 2. Do Not Infer audit (roadmap §2.2, all 16 entries)

| # | Entry (short form) | Spec's position |
|---|---|---|
| 1 | USERPTR map ⇏ DMA coherence / descriptors / executable program | Not engaged; layer 4 refuses to credit a control exchange as stream movement |
| 2 | Positive launch/count ⇏ descriptor-count formula or capacity | No formula claimed; the 512 policy is cited as size context only (F2) |
| 3 | IRQ ⇏ correct semantics, correct data, or completion | **Actively enforced** by layer 7: data-law correlation plus mandatory byte-equal readback |
| 4 | Closed file ⇏ remote destruction / stopped DMA / idle | **Actively enforced** by layer 8: local vs remote recorded separately; residues named not-destroyed; disconnect cleanup a path, not a guarantee |
| 5 | hRPC action ID ≠ arithmetic opcode / LCU instruction | Actions used only as lifecycle verbs and record layouts; layer 6 claims no arithmetic meaning and no sequence |
| 6 | `active_l2` bits: no known meanings, no known legal count | Layer 3 restates exactly this |
| 7 | HEF metadata naming shape/layout ⇏ instruction encoding known | Stream metadata structure IN, format semantics OUT (layers 4–5) |
| 8 | HailoRT parsing a HEF field ⇏ Aesir knows DFC's CCW generation | CCW words OUT entirely (layer 5) |
| 9 | Weights fitting in LPDDR ⇏ placeable / supported / fitting | Not engaged — parameters proved none; no placement claim |
| 10 | Parsed/correct math ⇏ correct quantization, packing, placement, schedule; parsed ≠ executable | **The central trap, complied with**: layer 1's mathematics is COMPLETE and the operation is still graded UNQUALIFIED |
| 11 | DFC emulator cosine ⇏ silicon agreement (either direction) | Not engaged — no emulator evidence used anywhere in the spec |
| 12 | Valid XXH3 ⇏ microcode CRC / safety / compatibility / correctness | Not engaged — no checksum field is used or cited by the spec |
| 13 | Runtime enum 6 ≠ program enum 103 | Layer 5 uses `HAILO1XH=103` as the program metadata value; 6 appears nowhere as a program field |
| 14 | Compatible-family mapping ⇏ arbitrary HAILO1XH programs valid on this device | No physical validity claimed; satisfiability deferred to a future physical question |
| 15 | Patent field ≠ exact H10H register/bit encoding | Not engaged — no patent material is used as a source in the spec |
| 16 | Community compiler *with* DFC ≠ independent compiler | Not engaged |

**No entry is violated.** Three entries (3, 4, 10) are not
merely avoided but actively enforced by the spec's own terms.

## 3. Corrected layer mapping — certified

AES-NUM-002's prediction was written against its own list
(operation definition / shapes / parameter derivations /
result mapping / oracle). The governing list is the roadmap's
4.3 list. The certified mapping of the prediction's substance:

- "operation definition" + "shapes" + "parameter derivations"
  → the fixed-shape section and layer 1 — completable, and
  completed (proved-none parameters live there).
- "result mapping" + "oracle" → layer 1's oracle definition
  and layer 7 — specified, as predicted in substance.
- The prediction's "layers 1–4 completable" does **not**
  transfer to roadmap layers 2 (tile plan), 3 (resource plan),
  or 4 (data movement): under the governing list those are
  INCOMPLETE / device-half-unestablished, exactly as
  AES-NUM-003 recorded.

**This gate certifies AES-NUM-003's corrected mapping and its
scoreboard as the record of Campaign 4.** The AES-NUM-002
prediction stands corrected, not erased: its L5/L6 forecast
agreed, its substance survives where the mapping above places
it, and its layer-name error is the documented finding.

## 4. Gate verdict

- **The spec PASSES the review gate** as an honest, human-
  readable specification: every field it uses carries a source
  and a known meaning, or is explicitly graded UNKNOWN/OUT;
  no Do Not Infer entry is violated; findings F1–F2 are
  recorded above and F1 tightens layer 7's readback wording.
- **Campaign 4's EXIT CONDITION IS NOT MET.** The exit
  requires a specification in which *every field of one tiny
  operation has a source and a known meaning*. Fields graded
  OUT (CCW words; tile geometry; assignment values; ID-35
  address values; readiness mechanism; action sequence;
  partial-state teardown) have a sourced *unknown* status —
  that is not a known meaning. The operation remains
  **UNQUALIFIED**, and **Campaign 5 is NOT contracted** from
  this spec — contracting it now would require inventing
  exactly the values this campaign exists to refuse.
- **Campaign 4 therefore enters its iteration loop** through
  Track R, items R1–R5 (dependency order from AES-NUM-003):
  R1 CCW word layout (lane D) — unblocks layers 2 and 5;
  R2 SoC session readiness protocol (now including, per F1,
  the program-result readback qualification question) —
  unblocks layer 4's device half; R3 placement counts and
  safe assignment values — unblocks layer 3; R4 minimal-
  program action sequencing incl. any safe ID-35 address —
  unblocks layer 6; R5 partial-state teardown preconditions —
  unblocks layer 8's device half. Each item closes only on
  evidence of the kind AES-NUM-001 grades IN (pinned public
  source with a known meaning, or a separately contracted
  physical observation); a negative or exhausted study is
  recorded as NOT PROVEN for that item, never filled in.
  When an item lands, the affected layers are re-graded in a
  short addendum to AES-NUM-003 and this gate re-runs on the
  changed layers only.

Next: Campaign 4 iteration slice 4.5 — the Track R study for
R1 (CCW word layout, lane D), research only: bounded search of
the pinned public sources and this repo's evidence for any
definition of the CCW word layout, graded on return as
ESTABLISHED (with the exact fields it proves) or NOT PROVEN.
No emitter, no bytes, no physical run.
