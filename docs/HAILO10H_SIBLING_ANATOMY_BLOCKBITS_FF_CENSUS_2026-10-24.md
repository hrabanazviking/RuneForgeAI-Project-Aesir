# Sibling anatomy, block bits vs scalars, ff census (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.85 (AES-NUM-085).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef85.py
(sha256 97c8aadc…), sha-verified on-device after a
one-shot proxy-receiver transfer (the gz bytes never
passed through tool re-emission; the receiver returned
the gz sha256 4c18c52b… and it matched). Output file
/tmp/hef85_out.txt sha256 15e7d0bb….
Controls reproduce AES-NUM-029/032…084 EXACTLY (128,787
pooled small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (camps, classes, cidx / ngpos) are
as in AES-NUM-061…084. The sibling population is the
AES-NUM-084 home: 76c3a8ff, position 20, size 14,528,
channel 0, ng 1 400-action contexts, cidx 113–338 step 9.
The position-18 population is unchanged: 76c3a8ff len-89
B-main segments at position 18, cidx %9 == 4, cidx != 112
— 13 contexts in camp 21392, 12 in camp 21648; tail =
segment bytes 6,408–end. Contract:
docs/TASK_CONTRACT_4.85.md (published @ c241fdd1 before
implementation).

## (i) Sibling segments past 108 B: diffuse binary variability, NO camp / prefix / tail anatomy

AES-NUM-084 left the 26 sibling segments sharing exactly
a 108 B prefix and otherwise all distinct. Their internal
anatomy is now measured, and it is NOT built like the
position-18 segments:

- Of 14,528 positions, 13,928 are constant across all
  26 segments and only 600 vary. The common suffix is
  5 B. There is no long constant prefix beyond the
  108 B head and no constant tail block.
- The variability is overwhelmingly binary: 544 of the
  600 variable positions take exactly 2 distinct values,
  9 take 3, 2 take 4, 7 take 5 — and only 38 positions
  are rich (15–26 distinct values, 6 of them distinct in
  all 26 segments). No variable position splits the
  population 13/13, and there is only one segment size,
  so there is NO camp structure of any kind (contrast
  the position-18 segments: two camps split at byte 0,
  a camp-constant 6,408 B prefix, then a tail carrying
  187 variable positions).
- The variable positions are diffuse, not zoned: 183
  bands at gap <= 8 spread over the whole segment;
  per-512 B window counts range 0–110 with two empty
  windows (bytes 7,680–8,704); counts per third are
  248 / 255 / 97 — variability persists to the end of
  the segment rather than living in one tail, though
  the last third is sparser. Split at the position-18
  prefix length for comparison: 353 variable positions
  in [108, 6408) and 247 in [6408, end).
- The body is sparse like its relatives: zero bytes
  83.96% overall, per-segment 83.93–84.01% (near-identical
  in every segment); aligned u32 words are 60.38% zero,
  the commonest nonzero words being 02000000 (5,407),
  01000000 (4,628) and 0000000c (2,132) of 94,432 slots,
  778 distinct words in all.
- Each sibling segment carries exactly 18 aligned
  ff ?? 00 00 words (468 total, 18 in 26/26 segments) —
  a fixed per-segment count, recorded here as a census
  fact; their scalar behaviour is the position-18
  census's subject below, not this population's.

Verdict: the sibling segment is one flat population —
a 108 B shared head, then diffuse, mostly two-valued
variation across the whole body, no camps, no
prefix/tail split. What the variable positions MEAN is
NOT PROVEN.

## (ii) Block bits vs the tail's other scalars: independent in every tested sense

AES-NUM-084 froze two per-context bits in the
position-18 tail: head block Q (36 slots, pair
{0xa2, 0xa3|0xb3}) and late block P (36 slots, pair
{0x01, 0x02}). This slice rebuilt both bits per context
(the (Q,P) combo census reproduces AES-NUM-084 exactly:
camp 21392 (0,0)x5 (0,1)x6 (1,1)x2; camp 21648 (0,0)x6
(0,1)x3 (1,0)x1 (1,1)x2) and tested them against the
tail's other per-context scalars — the sparse ff scalar
(one value repeated at the four ff slots, distinct in
every context) and tail byte 0 (also distinct in every
context: 13/13 and 12/12 distinct values).

- The ff scalar is NOT a function of (Q,P): every
  (Q,P) group carries as many distinct scalars as it
  has contexts (5/6/2 in camp 21392; 6/3/1/2 in camp
  21648). The bits do not determine the scalar.
- Neither bit is a threshold or parity function of the
  scalar: scalar ranges for bit 0 and bit 1 overlap
  almost completely in both camps (camp 21392 Q:
  [38..236] vs [110..227]; P: [38..236] vs [47..227];
  camp 21648 Q: [74..245] vs [29..209]; P: [29..245]
  vs [74..209]); threshold-separable in 0 of 4 tests;
  scalar-parity agreement is 7/13, 7/13, 6/12, 6/12 —
  chance level.
- Tail byte 0 is NOT a function of (Q,P) either: each
  (Q,P) group holds 5/6/2 (camp 21392) and 6/3/1/2
  (camp 21648) distinct byte-0 values, i.e. one per
  context in the group.
- The reverse direction (scalar or byte 0 determining
  the bits) is formally true and recorded as a
  UNIQUENESS ARTEFACT, not a law: both scalars are
  distinct in every context, so any per-context
  quantity is trivially a "function" of them. No
  measured structure supports it.

Verdict: within these populations the two block bits
are independent of the ff scalar and of tail byte 0 —
not determined by them, not determining them, no
threshold, parity or grouping law. What any of these
quantities MEANS remains NOT PROVEN.

## (iii) ff-frame census: exactly 43 ff-words per position-18 segment — 4 variable + 39 constant-scalar copies

An ff-frame instance is an aligned u32 word
ff <scalar> 00 00 at a segment-aligned offset (the form
of the four variable sparse slots, AES-NUM-084). The
census over the position-18 segments is exact and
rigid:

- Every position-18 segment carries EXACTLY 43 such
  words: 43 per segment in 13/13 camp-21392 segments
  (559 total) and 12/12 camp-21648 segments (516
  total), at 43 distinct aligned offsets per camp,
  ALL in the tail (offsets >= 8,224; none in the
  6,408 B prefix).
- Four of the 43 are the known variable slots (word
  starts 8568 / 10800 / 13064 / 21232 in camp 21392;
  8568 / 10864 / 13192 / 21488 in camp 21648 — the
  +64 / +128 / +256 drift of AES-NUM-084), carrying
  the one repeated per-context scalar.
- The other 39 offsets are present in EVERY segment
  of their camp and carry a CONSTANT scalar each —
  39/39 constant, zero partial, zero full-but-variable.
  The constant scalars are a small vocabulary: 0x0f
  (15) dominates (27 of 39 offsets in each camp),
  with 0x23 (35) at 4 offsets, 0x47 (71) at 2,
  0x02 at 4 and 0x0b (11) at 2 — the same per-value
  counts in both camps. A few offsets coincide across camps
  with the same scalar (e.g. 8224 -> 35 and 15700 ->
  15 in both); most sit at camp-drifted offsets like
  their variable siblings.

Verdict: the ff frame is a fixed 43-instance fixture
of the position-18 tail — 4 variable copies carrying
the per-context scalar and 39 constant-scalar copies
from a five-value vocabulary {2, 11, 15, 35, 71}.
What the frame or its scalars MEAN is NOT PROVEN.

## What this closes and what it queues

- MEASURED: the sibling segments' anatomy — flat,
  camp-less, diffuse binary-dominant variability
  (600 variable positions, 544 two-valued) over a
  108 B shared head; no prefix/tail construction.
- MEASURED: the block bits Q and P are independent
  of the tail's ff scalar and byte 0 in every tested
  functional sense (determination both ways,
  threshold, parity); the apparent reverse
  determination is the uniqueness artefact.
- MEASURED: the ff-frame census — exactly 43 aligned
  ff-words per position-18 segment, all in the tail:
  the 4 variable scalar slots plus 39 constant-scalar
  copies over the vocabulary {2, 11, 15, 35, 71},
  dominated by 15.
- NEXT (4.86): the sibling segments' 544 two-valued
  positions — column/block structure (one bit, two
  blocks like Q/P, or per-slot?); the 39 constant
  ff offsets' drift pattern across camps (start- vs
  end-anchored per offset); the sibling segments'
  own 18 ff-words (constant offsets? scalars?).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
