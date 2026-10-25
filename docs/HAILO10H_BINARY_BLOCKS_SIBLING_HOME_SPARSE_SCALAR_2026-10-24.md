# Binary-tier blocks, the sibling word's home, the sparse scalar (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.84 (AES-NUM-084).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef84.py
(sha256 d8bed40c…) + labelled follow-up hef84b.py
(sha256 0e64a05a…), both sha-verified on-device after
one-shot proxy-receiver transfers (the gz bytes never
passed through tool re-emission; the receivers returned
the gz sha256s and they matched: hef84.py.gz 7c741a83…,
hef84b.py.gz f5daceb5…). Output files /tmp/hef84_out.txt
sha256 617b9a3f…, /tmp/hef84b_out.txt sha256 0e6a3cdb….
Controls reproduce AES-NUM-029/032…083 EXACTLY (128,787
pooled small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (camps, classes, cidx / ngpos) are
as in AES-NUM-061…083. The position-18 tail population
is unchanged: 76c3a8ff len-89 B-main segments at position
18, cidx %9 == 4, cidx != 112 — 13 contexts in camp
21392, 12 in camp 21648; tail = segment bytes 6,408–end.

## (i) The binary tier is TWO single-bit blocks of 36 — neither one bit per context nor per-slot choice

AES-NUM-083 left the tail's 72 binary slots (exactly 2
distinct bytes each, identical offset set in both camps)
with an open question: is the low-vs-alternate choice
one bit per context across all 72 slots, or per-slot?
Both extremes are now excluded, and the true structure
is exact:

- Per-context popcounts (bit = byte equals the pair's
  upper value) take ONLY the values 0, 36 and 72: camp
  21392 has 5 contexts at 0, 6 at 36, 2 at 72; camp
  21648 has 6 at 0, 4 at 36, 2 at 72. No context sits
  anywhere else. Strict one-bit-per-context (all-0 or
  all-72 vectors) holds for only 7 of 13 and 8 of 12
  contexts, and per-slot independence is excluded by
  the same census (independent slots would spread
  popcounts across the whole 0–72 range).
- The 72 slots partition into exactly TWO distinct
  columns per camp (hef84b): two blocks of 36 slots,
  every slot in a block sharing the block's single
  per-context bit across all contexts of the camp.
  Pairwise column equality is bimodal in both camps —
  1,260 slot pairs equal in every context (within-block
  pairs, 2 × C(36,2)) and 1,296 pairs equal in only
  7 of 13 (camp 21392) / 8 of 12 (camp 21648) contexts
  (cross-block pairs, 36 × 36), with no third value.
- The blocks are positional and value-typed. Block Q =
  the FIRST 36 binary slots (rel 1, 5, 9, 13, 29, …,
  the dense band's head), whose value pair is
  {0xa2, 0xa3} in camp 21392 and {0xa2, 0xb3} in camp
  21648 — the camp-flavoured alternate tier of
  AES-NUM-083. Block P = the LAST 36 binary slots
  (rel 254, 258, 262, 266, 282, …, 490), whose value
  pair is {0x01, 0x02} in BOTH camps.
- The two block bits are not the same bit, and they
  are not locked together. Camp 21392 (Q,P) combos:
  (0,0) ×5, (0,1) ×6, (1,1) ×2, (1,0) ×0 — the Q bit
  set implies the P bit set in this camp (Q ⊆ P over
  the 13 contexts). Camp 21648 combos: (0,0) ×6,
  (0,1) ×3, (1,0) ×1, (1,1) ×2 — all four combinations
  occur, so no implication holds corpus-wide.
  Per-slot popcounts confirm the split: 36 slots carry
  the minority count (Q: 2 set-contexts in camp 21392,
  3 in camp 21648) and 36 carry the majority count
  (P: 8 and 5 respectively).

Verdict: the binary tier carries exactly TWO bits of
per-context information per camp, each governing a
fixed positional block of 36 slots — the head block
with the camp-flavoured {a2, a3|b3} pair, the tail-end
block with the camp-shared {01, 02} pair. What either
bit MEANS is NOT PROVEN.

## (ii) The sibling word's home: a position-20 action start in a step-9 train of 400-action contexts — correcting AES-NUM-083

AES-NUM-083 recorded the 16 B sibling pattern
(02 28 50 71 + the fixed 12 B suffix) as a "raw-only
relative, never at an action start". That second clause
was an inference the header census could not support —
the census tested action starts only for the exact and
28 f0-generalised forms — and it is WRONG. The full
mapping (hef84) is:

- All 26 raw occurrences in 76c3a8ff map into a pointer
  action, and every one sits at seg_rel_off 0 — an
  action START. The (position, size, channel) key is a
  single point: position 20, size 14,528, channel 0,
  in all 26.
- The 26 host contexts (hef84b) are one train: ng 1,
  400 actions each, cidx 113–338 step 9 (cidx %9 == 5),
  the sibling action's neighbours in the first context
  being pos 17 size 29,224, pos 18 size 264, pos 19
  size 24, pos 21 size 200, pos 22 size 24, pos 23
  size 32,648 (all channel 0 there). The hosts are a
  different family from the len-89 contexts that carry
  the camp-word headers at position 18 (cidx %9 == 4).
- The 26 sibling segments share their position and
  their first 108 bytes and nothing more: all 26
  sha256 are distinct, and every pairwise common
  prefix against the first segment is exactly 108 B
  (the 16 B sibling header plus 92 further shared
  bytes). The host contexts' full size sequences are
  likewise all distinct (26 of 26), while their
  channel sequences fall into exactly 2 variants.
- The sibling word alone (not followed by the suffix)
  occurs 31 times in the artifact; the 5 occurrences
  without the suffix are all MID-segment, never at an
  action start: inside size-29,248 channel-2 segments
  at rel 23,356 (the same bytes referenced by cidx 89
  pos 194 and cidx 349 pos 196), a size-29,840
  channel-0 segment at rel 27,745 (cidx 89 pos 402 and
  cidx 349 pos 397), a size-28,672 channel-2 segment
  at rel 15,432 (cidx 101 pos 136), a size-19,696
  channel-0 segment at rel 12,642 (cidx 113 pos 290 —
  inside a sibling host context, at a different
  action), and a size-25,592 channel-0 segment at
  rel 18,279 (cidx 123 pos 335).

Verdict: the sibling pattern is a third action-start
header form with a closed home — position 20 of the
step-9, 400-action ng 1 train in 76c3a8ff — and the
suffix-less word is a separate mid-segment resident.
AES-NUM-083's action-start claim for the sibling is
retracted; its remaining census results are untouched.

## (iii) Sparse-slot landmarks: four slots are one repeated per-context scalar in an ff-word frame; the drift is start-anchored early and end-anchored late

AES-NUM-083 left 7 sparse variable slots per camp past
rel 490: a shared rel 2161, then camp-21392-only
[4393, 6657, 14825, 14976, 14977, 14978] against
camp-21648-only [4457, 6785, 15081, 15232, 15233,
15234] (paired diffs +64, +128, +256 ×4). Their
landmarks are now measured:

- Four of the seven — rel 2161, the +64 slot, the +128
  slot and the first +256 slot (4393/4457, 6657/6785,
  14825/15081) — are THE SAME SLOT FOUR TIMES. In each
  camp, the byte at all four offsets is one identical
  per-context value (hef84b: all-equal within every
  context, 13/13 and 12/12; 13 and 12 distinct values
  respectively, one per context). Each sits at rel
  ≡ 1 mod 4 as byte 1 of an aligned word ff <scalar>
  00 00, inside a small recurring frame: the modal
  windows show a step word before it (44 01 a1 00,
  48 01 a1 00, 4c 01 a0 00 at the first three slots —
  a +4 stepping lead word — and 1c 01 b3 80 at the
  fourth) and a 54 01 a1 80 / 24 01 b3 00 class closer
  after the 00 00 and a short counter field. The
  scalar sequences (contexts in cidx order) step
  mostly by +9 with occasional larger jumps: camp
  21392 = 38, 47, 56, 65, 110, 119, 128, 146, 155,
  164, 173, 227, 236 (diffs 9,9,9,45,9,9,18,9,9,9,
  54,9); camp 21648 = 29, 74, 83, 92, 101, 137, 182,
  191, 200, 209, 218, 245 (diffs 45,9,9,9,36,45,9,9,
  9,9,27). At the shared rel 2161 the two camps'
  value sets are disjoint.
- The remaining three sparse slots are a different
  object: bytes 0–2 of the tail's FINAL aligned word
  (end_dist 8, 7, 6 in both camps), holding
  full-distinct per-context data (the whole final
  word distinct in every context). They are not
  ff-words and carry no scalar repetition.
- The drift, re-anchored: paired start-relative diffs
  are +64, +128, +256, +256, +256, +256, but the
  END-relative diffs (camp 21648 minus camp 21392)
  are +192, +128, 0, 0, 0, 0. So the first +256 slot
  and the final word are exactly end-anchored (same
  end_dist in both camps: 159 for the first +256 ff
  slot, 8/7/6 for the final word), the shared rel
  2161 slot is exactly start-anchored, and the +64 /
  +128 ff slots sit between the anchors, their
  spacing stretched inside the longer tail. Mechanism
  NOT PROVEN; the scalar's identity is NOT PROVEN.

Verdict: the sparse zone is one repeated scalar frame
×4 (start-anchored at 2161, end-anchored at end-159,
two stretched copies between) plus the tail's final
data word. The "seven sparse slots" of AES-NUM-083
are two objects, not seven independent positions.

## What this closes and what it queues

- MEASURED: the binary tier's choice structure — two
  positional 36-slot blocks (head block Q, pair
  {a2, a3|b3} camp-flavoured; late block P, pair
  {01, 02} camp-shared), one bit per block per
  context; popcounts confined to {0, 36, 72}; camp
  21392 shows Q ⊆ P over its 13 contexts, camp 21648
  shows all four bit combinations.
- CORRECTED + MEASURED: the sibling pattern's home —
  all 26 occurrences at action starts (position 20,
  size 14,528, channel 0) in the step-9 ng 1 train of
  400-action contexts (cidx %9 == 5) in 76c3a8ff;
  segments share exactly a 108 B prefix and are
  otherwise all distinct; the 5 suffix-less sibling
  words are mid-segment residents in five other
  segments. AES-NUM-083's "never at an action start"
  clause for the sibling is retracted.
- MEASURED: the sparse landmarks — four ff-word slots
  carry one identical per-context scalar per camp
  (13/12 distinct values, mostly +9 stepping), the
  final three sparse bytes are the tail's last word,
  and the drift decomposes into start-anchored,
  stretched-middle and end-anchored parts.
- NEXT (4.85): the sibling segments past their 108 B
  prefix (per-position variability across the 26 —
  is the sibling segment built like the position-18
  segments, with its own camp/prefix/tail anatomy?);
  the two block bits vs the tail's other per-context
  scalars (block bits against the sparse scalar and
  byte 0 — determined, independent, or partial?);
  the ff-frame census (how many ff<scalar> frame
  instances exist per position-18 segment beyond the
  four variable ones — constant-scalar copies?).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
