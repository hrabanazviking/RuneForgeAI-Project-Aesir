# Trailing pools vs the global pool, 176 B joint structure, 304 B head-break anatomy (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.37 (AES-NUM-037).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef37.py
(sha256 2f11d792…) plus the labelled follow-up hef37b.py
(sha256 71ddc338…). Controls: the walk reproduces
AES-NUM-029/032/033/034/035/036 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts), and the trailing distinct
(channel, operand) count reproduces AES-NUM-036 exactly
(2,049).

## The trailing pools are mostly slices of the global pool — with a private core

- The global champion population is 75,215 bursts
  (channel 0: 42,118; channel 1: 16,553; channel 2:
  16,544) holding 2,309 distinct operands. Operand and
  (channel, operand) distinct counts are EQUAL (2,309):
  every champion operand lives on exactly one channel
  (2,309 on one channel, 0 on two or three). Per-channel
  distinct operands: ch0 1,120 (AES-NUM-030's population
  exactly), ch1 596, ch2 593 (596 + 593 = 1,189 =
  AES-NUM-025's population exactly).
- The trailing 2,049 operands split as: 1,191 SHARED
  with the non-trailing body, 858 trailing-ONLY. The
  non-trailing body holds 1,451 distinct operands over
  43,631 champion bursts, of which 260 never appear in
  the end block (858 + 1,191 + 260 = 2,309). Shared
  operands carry 20,937 of the 43,631 non-trailing
  champion bursts (48.0%); a shared operand's body
  burst count runs 1–332 (mean 17.58; 291 operands
  occur once in the body, 372 occur 2–5 times, 219
  occur 6–20, 309 occur 21+).
- Per-position law (hef37b): inside each of the five
  4-position groups, the four position pools have
  EXACTLY equal size (98/104/103/100/107 per group)
  and are pairwise disjoint — each group is four
  disjoint sister pools of one size. The group's first
  three positions (the channel cycle 0, 1, 2) have
  identical shared/exclusive splits in every group
  (shared 69/82/78/72/96, exclusive 29/22/25/28/11),
  while the fourth position — channel 0 again — is
  ENTIRELY trailing-only (98/104/103/100/107 of 98/
  104/103/100/107 shared = 0). Position t0 (the
  invariant special-slot burst) is likewise
  trailing-only. The 858 private operands are exactly:
  t0's 1, the five closing positions' 512, and the
  first-three positions' exclusive remainders (345).
  Operand-only and (channel, operand) sharing counts
  agree everywhere, as the one-channel law requires.
- Graded: the end block is NOT a sealed pool — most of
  its operands are ordinary body operands — but every
  group's closing position, and the opening special
  slot, draw on operands that occur nowhere else in
  any artifact.

## The 176 B joint block — near-unique, not determining

- For the two variable pools (99 and 98 distinct
  segments), the joint varying block (p11, p12, p13,
  p19, p20) takes 96 and 91 distinct values: it is
  unique per segment except for 6 and 12 segments in
  collision groups (cluster sizes {1:93, 2:3} and
  {1:86, 2:3, 3:2}). Neither sub-block determines the
  other (A→B determinism violations 37/36, B→A 47/77),
  and no pair of varying positions determines each
  other in either pool.
- The largest sub-block clusters are the sparse cases,
  not structure: the biggest A cluster in both pools
  is the all-zero block (p11 = p12 = p13 = 0; 30
  segments / 569 occurrences in the 3801 pool, 11 /
  475 in b809). The biggest B clusters are
  (0100000001000000, 0100000001000000) with 15
  segments / 175 occurrences (3801) and
  (0000000000000000, 0100000001000000) with 17 / 106
  (b809).
- Even the full joint block plus the segment-unique
  trailer does not make the block a determiner: with
  p21 stripped, 3 (3801) and 5 (b809) collision groups
  still hold segments that share the whole varying
  block yet differ elsewhere in the sparse frame.
  Graded: joint variation without a measured
  generating law — the pools' identity stays at the
  whole-segment level (AES-NUM-035/036).

## The 304 B head-break form — one fixed segment per artifact

- The whole 304 B class is tiny: 3,207 occurrences,
  21 distinct segments corpus-wide. The head breakers
  are 10 of the 21. EVERY context of five artifacts
  breaks its head run with a 304 B action (occurrences
  equal context counts exactly: MiniLM 6/6, blob
  0856a10c 256/256, blob 0a0d378c 180/180, blob
  76c3a8ff 353/353, blob cc9b9d1c 271/271), and the
  sister pair (5ab3537d / 773470cd, 438 contexts)
  NEVER breaks at 304 B.
- Each blob artifact uses exactly ONE breaker segment
  for all of its contexts (occurrences 256/180/353/
  271, each spanning 6–7 different run lengths 4–10);
  MiniLM uses six distinct breakers, one per context
  (runs 9–10 only). All ten breaker segments also
  occur at non-breaker positions. All breakers sit on
  channel 0 (1,066/1,066).
- Segment anatomy (10 distinct breakers, 38 words):
  p0 is the constant `012830020000002e`; p1 is always
  zero; p2–p28 each carry EXACTLY two nonzero bytes,
  at byte positions 0 and 4; p29 carries only byte 0;
  p30–p35 are always zero; p36 carries only byte 4
  (the constant word `0000000001000000`); p37 carries
  three nonzero bytes (positions 0–2) and is distinct
  for all 10 segments — a trailer field of the same
  ≤3-byte shape as the burst lane-2 datum.
- The two-byte body has a dominant walking pattern:
  at positions p2–p17 the modal (byte0, byte4) pair
  is the complementary pair (k, 256 − k) or its swap,
  with k = position − 1 walking 1…16 — (01,ff),
  (02,fe), (03,fd), (04,fc), (05,fb), (06,fa),
  (07,f9), (08,f8), (09,f7), (0a,f6), (0b,f5),
  (0c,f4), (0d,f3), (0e,f2), (0f,f1), (10,f0) —
  dominant but not universal (6–10 distinct words per
  position); from p18 on the pairs are data-like with
  no single dominant complementary form. Graded
  OBSERVED pattern, not a generating rule.

## What this closes and what it queues

- MEASURED, corpus-wide: trailing operands are 58%
  shared body operands and 42% end-block-private, with
  the private core exactly located (t0 + the five
  closing positions + per-position remainders); the
  four sister pools per group are equal-sized and
  disjoint; champion operands are channel-exclusive
  corpus-wide. The 176 B varying block is near-unique
  per segment but determines nothing beyond itself.
  The 304 B breaker is a single fixed, sparsely
  structured segment per artifact, absent from the
  sister pair, with a complementary walking byte pair
  through its first body half.
- NOT established: the meaning of any pool, block, or
  byte pair; what breaks the sister pair's head runs;
  the other 11 distinct 304 B segments' positions and
  roles; whether the sister pools are related by a
  lane-1 subfield transform.
- NEXT (4.38): sister-pair head-break anatomy (which
  forms break the runs in 5ab3537d / 773470cd); the
  non-breaker 304 B population (11 distinct segments,
  their positions and channels); sister-pool lane-1
  subfield comparison (flags/enum/ladder composition
  of the four pools per group). Host/artifact analysis
  only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
