# Shared 140 class, stream-head seam pairs, cidx 139 (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.60 (AES-NUM-060).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef60.py
(sha256 a86267a9…) and the labelled follow-up hef60b.py
(sha256 86d25962…). Controls reproduce AES-NUM-029/032…059
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped files:
hef60's 373 B-part crossing failed its whole-file sha and
was discarded uncommitted; the 300 B re-split landed with
its sha verified on-device (gz sha256 8ca6e23e…); hef60b
landed first try at 300 B parts (gz sha256 2de8a2e9…).
Definitions (middle, band, window, cluster, exclusive,
low, 94xx, 97xx, segments) are as in AES-NUM-049…059.
This slice CORRECTS one attribution in AES-NUM-059 (see
§1): the n32016 ×24 dose does not belong to the 140-count
class.

## The shared 140-count class is a step-3 rail head in both monocultures

nwin == 140 occurs in exactly two artifacts corpus-wide
(0856a10c ×28, 76c3a8ff ×26; zero in the other five):

- Position: a perfect step-3 rail at the head of each
  stream. 0856a10c: cidx 1, 4, …, 82 (≡1 mod 3, gaps
  {3: 27}), the first 32% of the stream. 76c3a8ff: cidx
  6, 9, …, 81 (≡0 mod 3, gaps {3: 25}), the first 25%.
  The rail is interleaved with the artifact's other
  window classes: in both streams the windowed head
  block is exactly cidx 0–83, three step-3 class rails
  side by side (0856: 28-class ≡0, 140-class ≡1,
  24-class ≡2 from cidx 8; 76c3: 140-class ≡0 from 6,
  24-class ≡1 from 7, 28-class ≡2 from 5, behind
  two-context heads 124-class at 0/3 and 52-class at
  1/4). After cidx 83 both streams leave a gap before
  a sparse windowed tail (0856: a step-5 16-class rail
  at 100–235; 76c3: stragglers at 85–347).
- Class constants: ng 0 in all 54; champion body 29 in
  all 54; nacts fixed per artifact (0856: 832 ×27 +
  831 ×1; 76c3: 826 ×26). Pair order is mixed in both
  (0856: 13 normal / 15 reversed; 76c3: 6 / 20).
- Lead pool: 3,920 pooled leads in 0856 from 94 distinct
  step-8 values; 3,640 in 76c3 from 84 distinct. The
  pools intersect in exactly 58 values — two contiguous
  step-8 runs, 8192–8440 (32 values) and 8560–8760
  (26 values); Jaccard 0.483. Band share inside the
  class: 0856 3,571/3,920 (91.1%, plus 68 leads in the
  94xx ladder and nothing else named); 76c3 3,589/3,640
  (98.6%, no other named family at all). Per context
  the 140 windows draw on only 14–19 (0856, mean 16.7)
  or 15–35 (76c3, mean 23.3) distinct leads — heavy
  repetition — yet every context's lead SEQUENCE is
  distinct (28/28 and 26/26). No lead value occurs in
  every class context in either artifact (65/94 and
  72/84 values occur in ≥2). Window channels are
  near-balanced in both (0856 1299/1344/1277; 76c3
  1231/1179/1230).
- Companion dose — the correction. The TODO line for
  this slice (from AES-NUM-059) paired the 140 class
  with an "n32016 ×24 dose". Measured: the 140 class
  carries NO 32016 dose (0856: 0 ×27, 1 ×1; 76c3: 0 ×26).
  Its companion is 30480, at the window count itself:
  76c3 n30480 = 140 in 26/26; 0856 n30480 = 140 in 25
  and 139 in 3 (cidx 7, 19, 31 — a step-12 sub-rail;
  those three contexts' leads are still 140/140 band,
  so the missing companion is not a lead-family swap).
  AES-NUM-059's sentence assigning 76c3's "exactly 24"
  n32016 contexts to the 140 class was wrong: the 28
  such contexts are the 24-count class (×26, all with
  n32016 = 24 and n30480 = 0) plus the 52-count class
  (×2, n32016 = 24, n30480 = 28). The per-class
  companion table (hef60b arm A) is regular: each
  window class pairs its windows with one dominant
  companion count — n30480 == nwin (0856 classes 16,
  28, 140; 76c3 classes 28 at 27–28, 124, 140),
  n32016 == 24 fixed (76c3 classes 24 and 52, the
  latter splitting 24 + 28 = 52 across both companions),
  or neither (0856 class 24: n30480 = 0 and n32016
  variable 0–24, exactly 24 in only 8/24; 0856 classes
  4/7/23: ~0). A single corpus companion law is NOT
  PROVEN; the per-class table is the measured object.

## Cidx 0–2 differ at +137 because their partners sit in the seam

AES-NUM-059 found window count preserved in 131/134 cc9
+137 pairs, the only differing sources being cidx 0, 1, 2.
The three sources are ordinary first-pass head contexts:

- cidx 0: 259 actions, reversed, ONE window (lead 7952 —
  the degenerate single-window form), n32784 34.
- cidx 1: 738 actions, reversed, 96 windows — a maximal
  low-none POS context (93-segment dose 42, exclusive 9,
  cluster 1, 97-dose 32, n32016 96, hi-shoulder 8).
- cidx 2: 607 actions, normal, 96 windows — the rail
  head of §3 (94xx 61, 97xx 30, n32016 87).

Their partners are not second-pass copies but SEAM
contexts. The first pass runs a period-4 action-count
cycle (259, 738, 607, 245) from cidx 0 (mod-4 classes
hold their cycle value in 26–28 of ~34 slots each).
The second pass does not resume the cycle at 137: cidx
137 (499 actions, 0 windows), 138 (507, 0 windows) and
139 (432, 64 windows) are three off-cycle contexts
found nowhere else in the stream, and the cycle locks
back in only at cidx 140 — with a shifted period-4
cycle (245, 256, 738, 606) repeating from 140 onward
(140 = 245, 141 = 256, 142 = 738, 143 = 606, …). So
the +137 profile law's only failures are exactly the
three positions whose partners precede the second
pass's cycle lock-in: pair (0,137) differs in nacts,
order, nwin (1→0), n32784, ndistmid; pair (1,138) in
nearly every profile field (96→0 windows, the whole
low-none profile vanishing); pair (2,139) in §3. The
sources are not special; the seam is.

## Cidx 139 is a 94xx-only fragment of its source's profile

Cidx 139 (432 actions) is unique in cc9 — no other
context shares its action count. Against its +137
source, the rail head cidx 2 (607 actions, 96 windows):

- Windows: 64, ALL in the 9400–9488 band (62 in the
  strict 9408–9488 ladder plus 2 at 9400); its 12
  distinct lead values are a strict SUBSET of cidx 2's
  21. What it lacks is exactly cidx 2's other family:
  the nine 97xx values (9736–9800) and the degenerate
  lead 24. Cidx 2's own windows open with six 97xx
  leads before the 94xx body; 139 has no 97xx window
  at all (n97 0, cls97 noncarrier).
- Doses shrink with the context: n32016 55 (source 87),
  n32784 117 (179), champion body unchanged at 29,
  order flipped (reversed vs normal), ng flipped
  (1 vs 0, as at every +137 pair).
- Stream shape differs from the first action: 139's
  middle opens with large data actions (13176, 26472,
  31224, …) and its windows sit later, on channels
  26/21/17; cidx 2's middle opens inside the window
  block itself. Mid-size sequences differ at 308
  compared positions, first difference at position 0.
- Neighbourhood: 139 sits between two windowless seam
  contexts (137: 499, 138: 507) and the resumed cycle
  (140: 245, 141: 256, 142: 738, 143: 606 rail). It is
  not a rail context (nacts 432 ∉ {606, 607}) and not
  a truncated copy of cidx 2 — it is a seam context
  that carries only the 94xx half of its source's
  window profile.

## What this closes and what it queues

- MEASURED: the 140-count class exists only in the two
  monocultures, as a step-3 rail in the interleaved
  windowed head block (cidx 0–83) of both streams;
  pools intersect in 58 step-8 values (two contiguous
  runs); per-context lead use is narrow and repetitive
  with all-distinct sequences; ng 0, champion 29, fixed
  nacts per artifact.
- CORRECTED: the 140 class's companion is n30480 at
  the window count (140, or 139 on a step-12 sub-rail
  in 0856), NOT n32016 ×24. The ×24 dose belongs to
  76c3's 24-count and 52-count classes. AES-NUM-059's
  attribution is superseded.
- MEASURED: cc9's +137 window-count failures (cidx
  0, 1, 2) are seam effects — their partners 137–139
  are off-cycle uniques before the second pass's
  shifted period-4 cycle (245, 256, 738, 606) locks in
  at cidx 140; partners 137/138 carry no windows at all.
- MEASURED: cidx 139 is a unique 432-action seam
  context whose 64 windows are entirely 9400–9488,
  its lead set a strict subset of cidx 2's, missing
  exactly the source's 97xx family.
- NEXT (4.61): seam trio anatomy (137/138 windowless
  499/507-action contexts vs cycle classes); companion
  table completion (0856 24-class variable n32016
  0–24 vs position; the 139-companion exceptions at
  0856 cidx 7/19/31); second-pass cycle (245, 256,
  738, 606) class anatomy vs the first pass's.
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
The "stream position" of §1 is position in each
artifact's context stream (cidx), the same coordinate
used throughout AES-NUM-049…059.
