# Small two-member remnants, zero-context vocabularies, 134's tail (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.65 (AES-NUM-065).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef65.py
(sha256 c7ee3dd8…). Controls reproduce AES-NUM-029/032…064
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfer: gzipped script in 373 B parts,
each part sha-gated on-device (one single-shot crossing
failed its whole-file sha gate and was discarded
uncommitted; the part-wise crossing verified whole-file
sha256 55d31de5… for the gzip and c7ee3dd8… for the
script). Definitions (middle, seam set A = 7952,
B = 32784, C = 26896; alt set 7952/25872/32784) are as
in AES-NUM-061…064.

## (i) The small remnants are not alternations — they are carrier streams with isolated insertions

Census (seam sequence uses exactly two distinct members,
n ≥ 4): 143 contexts — 0a0d A/B ×116, 76c3 B/C ×14 (the
AES-NUM-064 genuine population), 76c3 A/B ×3, 0856 A/B
×3, 0856 B/C ×5, cc9 B/C ×2. The small genuine remnants
named by AES-NUM-064 grade as follows against the 76c3
regimes (dense: B-runs 1.83 / C-runs 1.21, gaps 1.47–1.90;
sparse 776: runs ≈ 1.0, gaps 4.42–4.70):

- 0856 B/C ×5 (cidx 14, 20, 23, 82, 83): NO alternation.
  C occurs 1–4 times per context, always as a single
  isolated letter inside a B-carrier stream (B runs mean
  7.8–140, max 165; every C run is length 1; cross
  transitions BC/CB ≈ the C count). Gap means 1.64–10.16
  are B-to-B spacings, not alternation gaps. The same
  shape holds for the A/B remnants (0856 cidx 3, 76, 105;
  76c3 ×3 in the census): the minor member is 1–2
  singletons in a B stream.
- cc9 B/C ×2 (cidx 151, 203; both 606-action, ng 1):
  the extreme case — exactly ONE C, at the head,
  followed by a single 64-long B run (transitions CB 1,
  BB 63). There is no second member behaviour to encode;
  these are B streams with a C prefix.
- One genuinely alternating small population does
  exist, in 0a0d: sixteen 123-action ng-1 contexts
  (cidx 75, 81, …, 165, step 6) share the IDENTICAL
  seam letter sequence `BABAABABABABBAAB` (A 8 / B 8,
  runs ≈ 1.14–1.33, gap mean 1.47) — but 25872 fills
  their gaps (8 occurrences per context, the top
  between-size), so in the alt frame they are
  candidates for the same projection grading as
  AES-NUM-064's other pair subsequences; the alt-frame
  census over all contexts is 219, dominated by cc9's
  171 A/C. Recorded as a pattern, not graded an
  independent block. (0a0d cidx 31, letters BBAA at
  gap mean 149, is a degenerate remnant of the first
  kind.)

Verdict: outside 76c3's 14, the corpus holds NO second
alternation regime. The remnants are one-carrier streams
with isolated foreign insertions (or a head prefix) —
a different, simpler species, and the 76c3 dense/sparse
regimes remain the only alternation laws.

## (ii) Zero-context replacement vocabularies: one shared pool, family-graded — zero private sizes

The 18 collapsed/zero contexts of the 290/419/623
classes (9 zero: triplet count ≤ 2; 9 collapsed-A)
were compared as all-size vocabularies:

- Vocabulary width stands as AES-NUM-064 measured:
  zero/collapsed distinct sizes 119–251 vs the classes'
  full contexts at 44–61 (with single 83/87/109
  exceptions inside the full sets).
- ZERO-ONLY aggregate (9 contexts): union 389 sizes,
  22 common to all nine — exactly the fixed skeleton /
  end-block / small-form sizes (24, 64, 72, 96, 120,
  176, 216, 248, 256, 304, 328, 344, 376, 416, 584,
  672, 816, 824, 7504, 7528, 7536, 7584). **Private
  sizes: ZERO of 389** — every size used by any zero
  context is used by at least one other zero context.
  The replacement vocabulary is a shared pool, never
  per-context invention.
- Pairwise Jaccard is bimodal by family, not by class:
  collapsed-vs-zero pairs are low (0.087–0.208);
  collapsed-vs-collapsed 0.308–0.768 (top: 419/114 vs
  623/27 at 0.768); zero-vs-zero spans 0.144–0.774,
  with the highest pairs CROSS-CLASS at matched stream
  positions (419/168 vs 623/63 0.774; 419/138 vs 623/43
  0.766; 419/120 vs 623/31 0.724; 290/121 vs 623/31
  0.607) — the pool is drawn by position/family, and
  class (action count) does not bound it.
- The collapsed-A contexts keep the class's 55xx band
  on top (5592 counts 16–41) beside their surviving
  7952 dose; the zero contexts' tops are the 55xx–58xx
  ladders with no triplet member at all. 623 cidx 35
  (A 73) is the only collapsed context where 7952
  outranks the 24 B bursts (50).

## (iii) 134's sparse tail members are NOT end-block bursts

cc9 cidx 134 and 135 (both 186 actions; end block =
last 28 actions starting at position 158, sizes
[24, 64, 24, 216, 328×3, 24×21], identical in both):

- 134's tail members (seq 42–49) sit at action
  positions 103–129 — entirely BEFORE the end block
  (0 of 8 inside it). Their span to the end covers 83
  actions with 30 distinct sizes, of which only the
  end block's own four (24, 64, 216, 328) are shared;
  the other 26 (incl. 7952/26896/32784 themselves,
  6512, 11968/11992/12048, 16400) belong to the body.
  The tail is a dissolution into body material
  (AES-NUM-064), not a reach into the trailer: the
  fixed end block is written intact after it, and the
  shared suffix from the skeleton quartet onward is
  byte-identical between 134 and 135.
- 135's tail (seq 42–48) is earlier still (positions
  91–107) and remains a pure A→B→C cycle with no
  repeated letter — the contrast AES-NUM-064 recorded
  holds at the position level. One new datum: the
  pair's champion order differs (134 normal, 135
  reversed) while their end blocks are identical.

## What this closes and what it queues

- MEASURED: the small two-member remnants are not
  alternations — 0856/cc9 remnants are B-carrier
  streams with 1–4 isolated insertions of the minor
  member (or a single head prefix); 76c3's two regimes
  remain the corpus's only alternation laws. A repeated
  16-context A/B pattern in 0a0d's 123 class is
  recorded ungraded (25872 in its gaps).
- MEASURED: zero-context replacement vocabularies are
  ONE shared pool (389-size union, 22 universal,
  exactly zero private sizes), drawn by family/position
  across classes (cross-class zero pairs to J 0.774;
  collapsed-vs-zero pairs ≤ 0.208).
- MEASURED: 134's sparse tail lives in the body
  (positions 103–129 vs end block at 158), shares only
  the end block's four sizes, and the end block is
  written intact and identical after it.
- NEXT (4.66): insertion-position law for the remnant
  singletons (0856 B/C + A/B minor members: ordinal /
  action-position / neighbouring sizes); cross-class
  zero-pair anatomy (the J ≥ 0.72 pairs: which sizes
  carry the overlap, stream positions); the 123-class
  A/B pattern in the alt frame (does 25872 complete a
  rotation there?). Host/artifact analysis only — no
  physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
