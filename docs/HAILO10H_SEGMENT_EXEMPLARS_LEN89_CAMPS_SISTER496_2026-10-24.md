# Segment exemplars whole-context, len-89 camps, sister 496 region (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.79 (AES-NUM-079).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef79.py
(sha256 50030361…) + labelled follow-ups hef79b.py
(sha256 da073b2a…) and hef79c.py (sha256 14c53d57…),
all three sha-verified on-device after one-shot proxy
receiver transfers (gz shas verified on-device; output
files /tmp/hef79_out.txt sha256 f930c880…,
/tmp/hef79b_out.txt a9a46488…, /tmp/hef79c_out.txt
d1c27cb3…). Controls reproduce AES-NUM-029/032…078
EXACTLY (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Definitions (region
census, seam set, classes, cidx/ngpos) are as in
AES-NUM-061…078. Segment byte identity is sha256 over
the action's referenced bytes (zero point as in
AES-NUM-013).

## (i) The two segment exemplars ARE the same construction — one shared scaffold, private payloads

The four contexts: 0a0d378c a = cidx 73 (ng 0, ngpos
73, len 85), b = cidx 179 (ng 1, ngpos 105, len 92);
0856a10c a = cidx 99 (ng 0, ngpos 99, len 85),
b = cidx 255 (ng 1, ngpos 155, len 91).

Size level (difflib over size sequences):

- a vs a: len 85 vs 85, equal 83, multiset overlap
  85/85 (the two a-contexts carry the SAME size
  multiset), joint (size, channel) overlap 80,
  LCS(size) 83, LCS(joint) 72.
- b vs b: len 92 vs 91, equal 86, multiset overlap
  90, joint overlap 87, LCS(size) 87, LCS(joint) 77.
- The cross pairs (a0 vs b1, a1 vs b0) score at the
  within-artifact level (equal 74/75, multiset
  76/76) — no pairing is privileged at size level.

Head: both a-contexts open with the same size
scaffold — 24 B bursts then a 304 triple — but the
scaffold is offset by one burst: 0a0d has 24 ×9 then
304 at positions 9–11 (head 12), 0856 has 24 ×10
then 304 at 10–12 (head 13). The head-13-vs-12
difference is exactly that one extra 24. Head
CHANNELS share nothing: joint common prefix 0 in
both a-a and b-b (0a0d a head channels begin
1,2,0,2,1,2,0,1,0; 0856 a begins 2,0,2,1,2,1,2,1,2,1
— different sequences from position 0), and head
segment bytes at the same index are equal 0/9
across artifacts (8/13 and 10/13 within artifacts).
Head = shared size scaffold, private channels and
private bytes.

Suffix (the shared last 56 actions): the size
sequence is IDENTICAL in all four contexts
(56/56 positions, every pairing). Channels differ
at exactly ONE suffix position — position 0 —
and the values cross the artifact/a-b lines:
a0 = 2, b1 = 2, a1 = 1, b0 = 1 (so a0's suffix is
joint-identical to b1's and a1's to b0's, while
each within-artifact pair differs at that slot).
Suffix offsets are not equal across artifacts.

Suffix BYTES (hef79c, full lists): 28 of 56
positions are byte-identical in ALL SIX pairings
(positions 1–5, 8–14, 17–31, 35 — including the
large forms 376/816/584/824/672); 5 positions
differ in every pairing (0, 6, 7, 15, 32); the
trailing burst positions 36–55 differ in every
cross-artifact pairing but partially agree within
artifacts (0a0d a-b agree at 44–55; 0856 a-b agree
at 36–51, differ at 52–55). Cross-artifact hash
equality is 28/56 (a-a) and 31/56 (b-b) against
40/56 and 44/56 within artifacts.

Regions: the a-regions are the same material —
multiset overlap 16, LCS 15 over lengths 17/16;
0856's a-region is the clean form (24, 12224, 200,
then (9144,184) ×4 each 24-separated), 0a0d's
carries (9144,184) ×3 plus a split fourth repeat
(9144, 24, 184, 24). The b-regions likewise
(multiset overlap 21, LCS 19 over 24/22): a shared
preamble (31xxx, 328, 24, 11264, 200, 24 — leading
word 31840 vs 31712) then (528,80) ×3 in 0856
against ×2 adjacent + one split (528, 24, 80) in
0a0d, which adds a longer closing 80-run. Region
bytes aligned from region start: 0 equal in both
pairings (region payloads are per-context; this
alignment also misaligns the end-anchored suffix,
whose comparison is the one above).

Verdict: the two exemplars are one construction
told twice — same a-side size multiset, same
56-action size suffix with a single free channel
slot, same motif rewrite — instantiated with
private head channels, private region/head bytes,
and partially private suffix bytes. They are
related as TEMPLATE instances, not as copies:
no whole-context byte identity exists between
them at any pairing.

## (ii) Len-89 camps: NOTHING besides the position-18 size separates them

76c3a8ff holds 52 len-89 contexts. Position 18
takes three values: 24 in 26 contexts (a step-9
train, cidx 112–335, all ng 1), 528 in one
(cidx 110), and the two signature camps — 21392
in 13 contexts, 21648 in 12 — the 25 contexts of
AES-NUM-078. On the 25:

- Size sequences are identical WITHIN each camp
  (78/78 and 66/66 pairs) and in NO cross-camp
  pair (144/300 total = the within sums exactly).
  The only size-variable position across the 25
  is position 18 (hef79 variable-position scan).
- Channel sequences are identical in ALL 300
  pairs — channel at 18 is 0 in both camps;
  channels separate nothing.
- Offsets are all-distinct per context (0/300
  identical pairs); the 11 offset-variable
  positions (12, 13, 16, 18, 19, 22, 26, 29, 30,
  31, 32) are NOT camp-functional (each camp
  draws 4 of the same 6 offset streams).
- Segment bytes: 78 of 89 positions carry ONE
  hash across all 25 contexts (both camps). The
  same 11 positions are byte-variable — with
  exactly 25 distinct hashes each: every context
  holds its OWN segment at those positions,
  within camp as much as across. At position 18
  the segment is likewise private per context
  (25 distinct hashes); no position's bytes are
  camp-functional.
- Cidx pattern: the camps interleave on the
  step-9 train (121 +21648, 130/139/148/157
  +21392, 166–193 +21648, 202–220 +21392,
  229 +21648, 238–265 +21392, 274–310 +21648,
  319/328 +21392, 337 +21648); within-camp diffs
  are 9 with gaps of 18–54 where the other camp
  (or the 24-train) takes the slot. No run of
  either camp exceeds 5.

Verdict: the camp is a ONE-SLOT size choice —
21392 vs 21648 (Δ 256) at position 18 — over an
otherwise byte-shared scaffold whose 11 payload
positions are private to each context regardless
of camp. Channel, offset and content carry no
camp signal; the mechanism choosing the size is
NOT PROVEN.

## (iii) Sister len-496 5→5 regions: a three-slot size tuple over private payloads, one universal burst

The 5→5 signature (AES-NUM-078: region start 22,
5→5) in the len-496 family (28 contexts in each
sister):

- Pair counts: 43 pairs in 5ab3537d (8 distinct
  a-contexts × 24 b-contexts), 15 in 773470cd
  (7 × 11) — the signature is the family's modal
  micro-substitution in 5ab, a minority one in 773.
- Region form, all pairs: sizes (X, 328, 24, Y, Z)
  at positions 22–26, channels (2, 2, 2, 2, 2)
  throughout. X ∈ {15384, 17016, 18648} (stride
  1632), Y ∈ {29528, 31160, 32776}, Z ∈ {12024,
  12040, 13656, 13672, 15288, 15304}.
- Tuple census over ALL 28 contexts per sister
  (hef79c): exactly 8 distinct tuples each; the
  maximal tuple (18648, 328, 24, 32776, 15304)
  dominates (13 in 5ab, 14 in 773); 4 of the 8
  tuples are shared across sisters. No slot is a
  function of another: Y=f(X), Z=f(X), Z=f(Y) and
  Z=f(X,Y) all fail in both sisters (2–5
  conflicting distinct tuples each).
- Segment bytes at positions 22–26 (hef79b, all
  28 contexts per sister): position 24 (the 24 B
  burst) is ONE hash in both sisters, shared —
  universal. Every other region position carries
  28 distinct hashes per sister (per-context
  payloads) and size→hash fails at all of them
  (23–27 violations): content is not a function
  of the tuple. Cross-sister hash pools: pos 23
  (328) FULLY shared (28/28 — the same 28 payload
  segments in both artifacts, assigned to
  different contexts); pos 22 shared 14, pos 26
  shared 16, pos 25 shared ZERO (artifact-private
  pools at the Y slot).

Verdict: the 5→5 region is a fixed five-action
frame — one universal burst, one constant 328
slot whose payload pool the sisters share whole,
and three size slots (X/Y/Z) drawn from small
pools with no functional relation among them,
filled with per-context payload bytes (at the
Y slot, from artifact-private pools).

## What this closes and what it queues

- MEASURED: the segment-exemplar class's two
  members are template instances of one
  construction — identical a-side size multiset,
  identical 56-size suffix with exactly one free
  channel slot (whose value crosses artifact and
  a/b lines), head scaffold offset by one burst —
  with private channels/bytes in head and region
  and a half-universal suffix (28/56 positions
  byte-identical in all pairings, 5 differing in
  all).
- MEASURED: the len-89 camps are separated by
  the position-18 size ALONE (Δ 256); channels
  are camp-blind (300/300 identical), offsets and
  segment bytes are per-context at exactly the
  same 11 positions in both camps, and the other
  78 positions are byte-identical across all 25.
- MEASURED: the sister len-496 5→5 region is the
  frame (X, 328, 24, Y, Z), channels all 2, 8
  tuples per sister (4 shared, modal tuple
  13–14/28), no slot a function of another;
  bytes are per-context except the universal
  position-24 burst, with the 328 payload pool
  fully shared cross-sister and the Y-slot pool
  fully private.
- NEXT (4.80): the exemplars' head channel
  sequences vs the corpus (does either head
  channel pattern recur in other contexts?);
  the len-89 position-18 three-value train
  (24/21392/21648 interleaving over the full
  step-9 train, incl. the 528 singleton at
  cidx 110); the modal-tuple contexts in the
  sisters (cidx pattern of (18648,32776,15304)
  contexts; what separates them at other region
  signatures). Host/artifact analysis only — no
  physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
