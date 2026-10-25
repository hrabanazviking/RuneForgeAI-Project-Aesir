# Seam trio, companion completion, second-pass cycle (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.61 (AES-NUM-061).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef61.py
(sha256 7b820e6b…) and the labelled follow-up hef61b.py
(sha256 dcdc1c43…). Controls reproduce AES-NUM-029/032…060
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped files,
both whole-file shas verified on-device first try
(hef61 gz sha256 0f3b8472…, hef61b gz sha256 9589178c…).
Definitions (middle, band, window, cluster, exclusive,
low, 94xx, 97xx, segments) are as in AES-NUM-049…060.

## The seam trio are complete contexts built on a 96-fold triplet block

Cidx 137 (499 actions) and 138 (507) — the two windowless
partners of cc9's only differing +137 pairs (AES-NUM-060)
— are not fragments or truncated cycle contexts:

- Both are structurally complete: skeleton quartet
  present exactly once each (72×1, 96×2, 120×1, 416×1),
  the invariant 28-action end block byte-identical in
  size sequence to every other context, champion body
  29, pair order normal, ng 1 (the second-pass network
  group, as at every +137 pair). Their action counts
  are unique corpus-wide: 499 and 507 occur nowhere
  else in any artifact.
- Their bodies are a 96-fold interleaved triplet block:
  sizes 7952, 32784 and 26896 occur exactly 96 times
  each in cidx 137 (32784 97 times in 138), interleaved
  with a small-size vocabulary (~6160–6256 in 137,
  ~6496–6536 in 138 — disjoint sub-ranges). No windows
  (no 3856 at all), no 32016, no 30480. Size-multiset
  overlap between the two is 0.641 Jaccard; against
  cidx 139 it is only ~0.23.
- The triplet block is rare corpus-wide: contexts with
  7952 ≥90 are otherwise the 0a0d378c classes (at doses
  128/160, a different anatomy) and, for 26896 ≥90, the
  0a0d378c 623-class and four 76c3a8ff tail contexts —
  in cc9 the 96-dose triplet exists ONLY at the seam.
- Champion operands: the first 15 positions of 137 and
  138 share ZERO values at equal positions; positions
  15–28 (the 0x2d80 pair plus the universal coda) are
  identical — the same coda every context carries
  (AES-NUM-047). Cidx 139 (432 actions, 64 windows) is
  the third seam context, already anatomised in
  AES-NUM-060; its pair sits reversed, the trio's only
  order exception.

## Companion table completion: the 24-class dose is a templated block, and the 140-class companion is NOT a per-window pairing

0856a10c's 24-window class (24 contexts, all 448 actions,
step-3 rail cidx 2–83) carries n32016 anywhere in 0–24
with n30480 always 0:

- The dose is NOT selected by position, channel, ng or
  pair order: correlation with cidx is only 0.332,
  window-channel splits are mixed at every dose, and
  both orders occur at 0 and at 24. What the dose
  measures is how much of a TEMPLATED 32016 block is
  present. Full-dose contexts share a fixed position
  template in the middle (two variants: positions
  111–368 in cidx 14/29, positions 102–367 in
  cidx 62/65/68/71/74/77/80, the core ~20 positions
  identical within each variant); the 8-dose context
  (cidx 83) holds exactly the first 8 positions of the
  102-template, in order. Sparse doses (1–5) sit at
  off-template positions (e.g. cidx 11: 14/103/124/207/
  253) — a different, sparse variant, not a prefix.
  n32784 co-varies (138 at full dose, 0 at zero dose)
  but not proportionally at sparse doses (cidx 23:
  n32016 1, n32784 31), so the two are fellow block
  members, not a fixed ratio pair.

The 140-class exceptions (0856 cidx 7/19/31, n30480 139):

- They form a step-12 sub-rail (≡7 mod 12, all ≡1 mod 3
  as the class requires), all reversed, all 832 actions.
  Cidx 19/31 draw their leads entirely from the regular
  class pool; cidx 7 additionally uses eight 87xx leads
  (8712–8760, plus 8376) that no regular 0856 140-context
  uses — values from the shared cross-artifact
  intersection run of AES-NUM-060.
- The hunt for the missing companion's window REFUTES
  the per-window reading: in EVERY 140-class context,
  regular ones included, the number of 30480 actions
  between consecutive windows is irregular (0–5, with
  8–9 after the final window). There is no window whose
  companion is missing. The AES-NUM-060 companion law
  n30480 == nwin is a GLOBAL count equality over the
  context, not a local pairing — and the exceptions'
  deficit of one is likewise global. Any encoder must
  reproduce the count, not a pairing. Mechanism NOT
  PROVEN.

## The second pass's cycle is the first pass's, merged and shifted — with the rail head replaced by the seam

Cc9's second pass (cidx ≥140) runs the period-4 cycle
(245, 256, 738, 606) at shifted residues (245 at ≡0,
256 at ≡1, 738 at ≡2, 606 at ≡3), all in ng 1, where
the first pass ran (259, 738, 607, 245) in ng 0.
Class-by-class, pooled over each pass:

- 738 and 245 are preserved almost exactly: identical
  window-count and n32016 multisets (738: 96/96 in all;
  245: 0/0 in all), pooled size histograms differing
  only in singleton swaps (≤1.15 per context). One
  exception: pair order in the 245 class flips — the
  first pass is mixed (15 normal / 13 reversed), the
  second almost uniformly normal (26/1); the 738 class
  keeps its reversed-dominant order in both passes.
- 259 → 256 (−3 actions): window split preserved
  (0×14, 1×13 vs 0×14, 1×14 — one context fewer, as
  every second-pass class has 27 members to the first
  pass's 28, the missing slot being the seam/interruption
  zone). The −3 is concentrated: 80 B actions fall by
  ~3 per context (mean 15.96 → 13.0) and n32784 by
  exactly 1 per context (33.0 → 32.0), against five
  sizes that appear once per context only in the
  second pass (25240, 25464, 31880, 32608, 32688).
- 607 → 606 (−1 action): the second-pass 606 population
  is the MERGE of the first pass's 607 (26) and 606 (2)
  classes, minus the rail head. Its sorted window-count
  list is exactly the first-pass 607 list plus the two
  32s of the first-pass 606s, with one 96 removed; its
  n32016 list is the same merge with the rail head's
  87 — cidx 2's dose, the highest in the class — gone.
  That missing context is precisely the one whose
  +137 partner is the seam fragment cidx 139
  (AES-NUM-060): the second pass does not re-emit the
  rail head as a 606; it emits 139 instead.
- The non-cycle classes repeat in both passes with the
  same counts and profiles (626×3, 686×3, 727×1, 839×3,
  842×3, 873×6, 874×2, 265×1), all flipped to ng 1.

## What this closes and what it queues

- MEASURED: the seam trio are complete, skeleton- and
  trailer-intact contexts; 137/138 are built on a
  96-fold (7952, 32784, 26896) triplet block found at
  that dose nowhere else in cc9, with disjoint
  small-size vocabularies per context.
- MEASURED: the 0856 24-class n32016 dose is the
  filled amount of a templated middle block (full-dose
  position templates in two variants; the 8-dose case
  is an exact template prefix; sparse doses are
  off-template), selected by none of position, channel,
  ng or order.
- REFUTED: per-window companion pairing for the
  140-class. n30480 == nwin (and the 139 exceptions)
  are global count equalities; the exceptions are a
  step-12 sub-rail, and no single window lacks a
  companion.
- MEASURED: the second-pass cycle classes are the
  first pass's merged and shifted — 738/245 preserved,
  259→256 by −3×80 B and −1×32784 per context,
  607+606 merged into 606 with the rail head (cidx 2)
  replaced by seam context 139; classes shrink 28→27
  members; ng flips throughout; 245-class pair order
  flips to normal while 738 keeps its order profile.
- NEXT (4.62): the 96-fold triplet block's anatomy
  (period/order of the triplet cycle, its small-size
  vocabulary as a lead-like family; the same block at
  128/160 dose in 0a0d378c); sparse-dose 32016 variant
  positions vs the templates (are sparse positions a
  third template?); second-pass interruption zone
  (cidx 248–270 classes) vs the first pass's 111–135
  zone. Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
