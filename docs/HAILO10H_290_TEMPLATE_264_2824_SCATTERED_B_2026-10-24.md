# 290 signature template, 264/2824 companions, scattered-B mechanism (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.69 (AES-NUM-069).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef69.py
(sha256 8a2f9499…). Controls reproduce AES-NUM-029/032…068
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfer: gzipped script in 373 B parts,
each part received-byte-counted on-device via the
file-write session, whole-file sha256 verified on-device
before the run (landed first try). Definitions (seam set
A = 7952, B = 32784, C = 26896; collapsed/zero states;
class = the 0a0d contexts of a given action count) are
as in AES-NUM-061…068.

## (i) The 290 signature is a fixed head template — positions 13–27, one order, deterministic neighbours, in all 16 contexts

AES-NUM-068's eight-size signature {200 ×3, 360, 8576,
13176, 13480, 14224, 20488, 32600} was located inside
its contexts:

- In EVERY one of the 16 290-class contexts (collapsed,
  zero and full-dose alike — the collapsed/zero six and
  the other ten have IDENTICAL position sets), the ten
  signature occurrences sit at the same positions in
  the same order, spanning exactly positions 13–27:
  32600@13, 8576@14, 360@15, 14224@17, 200@18, 20488@20,
  13176@23, 200@24, 13480@26, 200@27. The number of
  distinct occurrence-order sequences over the 16
  contexts is exactly 1, and every context's counts
  match the frozen multiplicities (200 ×3, the rest ×1).
- Neighbours are deterministic: across all 16 contexts
  each signature size has exactly ONE predecessor value
  and ONE successor value per occurrence slot —
  304 → 32600 → 8576 → 360 → 24; 24 → 14224 → 200 → 24;
  24 → 20488 → 216; 24 → 13176 → 200 → 24; 24 → 13480
  → 200 → 24. (200's three slots have the three
  distinct predecessors 14224 / 13176 / 13480 and the
  single successor 24 in all 48 occurrences.)
- The signature is not a contiguous block: its ten
  occurrences interleave with fixed non-signature
  actions at positions 16, 19, 21, 22, 25 (24 at 16, 19,
  22, 25; 216 at 21), and exactly half of the signature
  occurrences (80/160) have a signature predecessor and
  half (80/160) a signature successor.

Verdict: the signature is a fixed 15-action head
template segment (positions 13–27) written identically
into every 290-class context, independent of the
context's triplet state. AES-NUM-068's "fixed counts and
first positions" sharpens to a complete fixed template:
positions, order, interleaved fillers, and both
neighbours of every occurrence are all frozen.

## (ii) The 623 fixture's companions: 264 is a shared fixed slot (623 @30, 419 @17); 2824 is the fixed action after the head B (@14)

The two remaining sizes of AES-NUM-068's 623-only
intersection (the nine-size core + 264 + 2824):

- 264: count exactly 1 in ALL 16 623-class contexts,
  always at position 30, always preceded by the core
  size 1280 and followed by 24. It is NOT 623-private:
  it also occurs exactly once in all 16 419-class
  contexts, always at position 17. It occurs in ZERO
  290-class contexts (the property that put it in the
  623-only intersection against the 290 twins).
  Corpus-wide it is common (481/1,504 contexts; 66/180
  in 0a0d), but inside these classes it is a fixed slot
  whose position is class-specific (30 in 623, 17 in
  419).
- 2824: a fixed base occurrence in ALL 16 623-class
  contexts at position 14 — in every case immediately
  after a 32784 (predecessor 32784 in 16/16) and
  followed by 328 (16/16). Exactly two contexts carry
  extra occurrences: cidx 7 (one extra at 213) and
  cidx 43 (extras at 213 and 451); the extras' neighbours
  are seam/band sizes (26896, 25112, 3088 before; 26896,
  25360, 5648 after), not template values. Outside the
  class it is rare and unfixed: 2/16 419 contexts
  (late positions 204/268), 0/16 290 contexts, and only
  29/1,504 contexts corpus-wide.
- Reference companion 16400 (AES-NUM-067's 5/6 size):
  present in 15/16 contexts of BOTH the 623 and 290
  classes at the same near-fixed positions (623:
  [176, 178]; 290: [164, 211]; one context ×1, one
  context absent in each class — the same ordinal
  pattern), and in 0/16 419 contexts. Recorded as
  context, not graded as a companion of the fixture.

Verdict: both intersection companions are fixture
members, of two different kinds. 264 is a fixed
single slot shared by the 419 and 623 classes at
class-specific positions (and absent from 290). 2824
is a position-14 fixture of the 623 class alone,
sitting immediately after the context's first head
action (a 32784) — which is exactly why AES-NUM-068's
head-fixed B pairs appeared to be "followed by 2824":
the follower is the template, not a reaction to the B.

## (iii) The scattered-B 26896 follower IS the next seam member — an adjacent rotation C at gap 1 (3/4); head-fixed B's never take it

The 0a0d population-B minor-B population (AES-NUM-068)
splits into 6 head-fixed occurrences (the collapsed
623 contexts' BB pairs at positions 13/17) and 4
scattered occurrences (all in cidx 109):

- Scattered (4): three are followed immediately by
  26896, and in all three that 26896 IS the next seam
  member, at gap exactly 1, with next seam letter C
  and previous seam letter A (×2) or C (×1) — the
  scattered B is the middle of an A→B→C rotation step
  whose B and C actions are adjacent in the stream.
  The fourth (position 106) is followed by 26584, its
  next seam member an A at gap 3 — no adjacency.
  Test result: nxt == next seam size in 3/4, and
  nxt == 26896 with gap 1 and next seam C in 3/4.
- Head-fixed (6): NEVER followed by 26896 (0/6); their
  immediate followers are the template sizes 2824
  (first B, position 13) and 21408 (second B, position
  17), and their next seam members lie at gaps 4–33.
- Baselines: major-A occurrences in the same contexts
  are followed immediately by 26896 in only 4/189;
  over all 18,383 B occurrences in 0a0d, a (C, gap 1)
  successor occurs 1,994 times (~10.8%) — B→C adjacency
  is an ordinary rotation-block feature, and the
  scattered minors inherit it because they sit inside
  rotation steps, not because a minor-specific
  follower exists.

Verdict: the 26896 "follower mechanism" of
AES-NUM-068 is seam adjacency — a scattered B that is
immediately followed by 26896 is simply a B whose
rotation successor C is the very next action. No
separate follower rule operates; the contrast with
the head-fixed pair (template followers 2824 / 21408,
never a seam member) is the template-vs-rotation
distinction already seen in (i) and (ii).

## What this closes and what it queues

- MEASURED: the 290 signature is a fixed head template
  at positions 13–27 — one occurrence order in 16/16
  contexts, single-valued positions per size, fully
  deterministic neighbours, identical in collapsed/
  zero and full-dose contexts.
- MEASURED: 264 = fixed slot ×1 in 16/16 623 contexts
  (@30, after core 1280) and 16/16 419 contexts (@17),
  0/16 in 290; 2824 = fixed @14 in 16/16 623 contexts
  (after 32784, before 328), extras only at 213
  (cidx 7, 43) and 451 (cidx 43), 0/16 in 290.
- MEASURED: the scattered-B 26896 follower is the next
  seam member at gap 1 in 3/4 cases (the fourth's next
  seam is A at gap 3); head-fixed B's take template
  followers instead (2824 / 21408, 0/6 seam-adjacent).
- NEXT (4.70): the shared head template — full action
  sequences at positions 0–35 across the 290 / 419 /
  623 classes (one template with class-specific slots,
  or three templates?); the extra 2824 occurrences at
  213 / 451 and their surroundings; B→C seam adjacency
  as a rotation diagnostic at corpus scope. Host/
  artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
