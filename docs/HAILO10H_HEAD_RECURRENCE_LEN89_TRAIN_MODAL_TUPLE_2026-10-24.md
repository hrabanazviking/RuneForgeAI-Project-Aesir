# Exemplar head recurrence, len-89 three-value train, sister modal-tuple contexts (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.80 (AES-NUM-080).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef80.py
(sha256 748d6d97…) + labelled follow-up hef80b.py
(sha256 90ca293c…), both sha-verified on-device after
one-shot proxy-receiver transfers (gz shas verified
on-device; output files /tmp/hef80_out.txt sha256
9bca886b…, /tmp/hef80b_out.txt 7d022dc8…). Controls
reproduce AES-NUM-029/032…079 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (region census, classes, cidx /
ngpos) are as in AES-NUM-061…079. Segment byte identity
is sha256 over the action's referenced bytes (zero
point as in AES-NUM-013).

## (i) Head channel recurrence is pattern-dependent: 0a0d's heads are private, 0856's are shared vocabulary

The four exemplar heads (AES-NUM-079): 0a0d head-12
sizes 24×9 + 304×3, channels a (cidx 73)
[1,2,0,2,1,2,0,1,0,0,1,2] and b (cidx 179)
[1,2,0,2,1,2,1,1,0,0,1,2] — the two differ at
position 6 ONLY (0 vs 1; common channel prefix 6).
0856 head-13 sizes 24×10 + 304×3, channels a
(cidx 99) [2,0,2,1,2,1,2,1,2,1,0,1,2] and b
(cidx 255) [2,1,2,1,2,1,2,1,2,1,0,1,2] — the two
differ at position 1 ONLY (0 vs 1; prefix 1).

Exact recurrence over all 1,503 other contexts
(channel sequence, and joint (size, channel)
sequence — the two counts are equal in every case
below, so every channel recurrence is also a size
recurrence):

- 0a0d a: 0 others. 0a0d b: 0 others. No context in
  the corpus repeats either 0a0d head channel
  pattern. The longest channel prefix any other
  context shares with either is 6 — the sibling
  exemplar itself; beyond the sibling the best is
  prefix 5 (1 context) and prefix 4 (5 contexts);
  prefix-4 channel matches exist in only 7 other
  contexts, against 1,503 contexts sharing the
  first four SIZES.
- 0856 a: 22 others — 0a0d378c cidx 3,7,…,63
  (16 contexts, all len 623, ng 0, step 4);
  76c3a8ff cidx 99, 101, 107, 113 (len
  294/220/294/400); cc9b9d1c cidx 135, 181.
- 0856 b: 27 others — MiniLM cidx 1, 2, 4, 5
  (4 of its 6 contexts); 0856a10c cidx 0;
  0a0d378c cidx 76,82,…,166 (16 contexts, all
  len 763, ng 1, step 6); 76c3a8ff cidx 92, 109,
  110 (the len-89 singleton of arm (ii)), 352;
  cc9b9d1c cidx 134, 137.

The SIZE scaffolds, by contrast, are common: the
0a0d head-12 size sequence recurs in 271 contexts
(46 distinct channel patterns over them; pattern
counts 33, 27, 26, 25, 25, 22, …) and the 0856
head-13 size sequence in 137 contexts (16 distinct
channel patterns; counts 28, 26, 26, 23, 19, 3, …).
In both scaffold groups the 304 triple's channels
are FIXED at (0, 1, 2) in every context (271/271
and 137/137 at the triple's positions); all channel
variety sits in the 24 B burst positions (0856
group position 0 is channel 2 in 134/137).

Verdict: a head channel pattern is not a scaffold
property. The two near-alternating 0856 patterns
are shared vocabulary — each is the head of whole
context trains in other artifacts — while 0a0d's
irregular pattern occurs in its two exemplar
contexts and nowhere else; even the exemplars'
own a/b variants are not corpus patterns.

## (ii) The len-89 train is TWO interleaved step-9 sub-trains; position 18 is a sub-train property, the camps a B-side choice, and both heads are shifted-region variants

76c3a8ff's 52 len-89 contexts (cidx 110–337, all
ng 1) are not one train: successive cidx diffs are
exactly (2, 7) repeated, i.e. two step-9 sub-trains
interleaved — cidx ≡ 2 (mod 9) and cidx ≡ 4 (mod 9),
26 contexts each (hef80b sub-train extraction).

- Sub-train A (cidx 110 + 9k): position-18 values
  are 528 at the head (cidx 110, the AES-NUM-079
  singleton) and 24 in all 25 others (cidx
  119–335). The 25 non-head contexts share ONE
  size sequence once position 18 is stripped, and
  ONE channel sequence (stripped group 0, n=25);
  their segment bytes vary at 26 positions.
- Sub-train B (cidx 112 + 9k): position-18 values
  are 24 at the head (cidx 112) and a signature
  camp value in all 25 others (cidx 121–337):
  21392 ×13 and 21648 ×12 in the order 21648,
  21392 ×4, 21648 ×4, 21392 ×3, 21648, 21392 ×5,
  21648 ×5, 21392 ×2, 21648 (no run over 5, as in
  AES-NUM-079). The 25 non-head contexts share
  ONE stripped size sequence and ONE channel
  sequence (stripped group 1, n=25); their
  segment bytes vary at exactly the 11 payload
  positions of AES-NUM-079 (12, 13, 16, 18, 19,
  22, 26, 29, 30, 31, 32).
- The two main forms differ from each other at
  17 size positions, ALL at original positions
  12–32 (the head/region zone); from position 33
  on they are size-identical, and within each
  main form the ONLY size-variable position is
  18 (B side) resp. none (A side).
- Both heads are shifted-region variants of
  their own sub-train's main form. The A head
  (cidx 110) differs at 12 stripped positions
  (original 9–23): its region run (31152, 17056,
  376, 24, 528, 80, 24, 32496) is the A-main run
  displaced two positions later (original
  14–21 vs 12–19), so its 528 lands at position
  18. The B head (cidx 112) differs at 16
  stripped positions (original 9–33): its region
  values are the B-main values displaced one
  position later from position 13 on (13048 at
  13 vs 12, 200 at 14 vs 13, …), and its large
  camp-class size 21392 sits at position 19, not
  18 — position 18 itself reads 24.

Verdict: the "three-value train" of AES-NUM-079
resolves into structure, not three parallel
populations: one interleaved pair of step-9
sub-trains, each with a uniform main form and a
shifted-region head; position 18 takes 24 on the
A main form, a camp value on the B main form, and
head values (528 / 24) that are artefacts of the
shifts. The camp choice inside the B main form
(21392 vs 21648, Δ 256 at position 18 alone)
remains the one unexplained bit — channel,
offset and byte positions carry no camp signal
(AES-NUM-079), mechanism NOT PROVEN.

## (iii) Sister modal-tuple contexts: one shared template, a 13+1 split in 773, and signature poverty

The len-496 families (28 contexts per sister, all
on a step-4 cidx train 97–205, ng 1) each hold
exactly 9 distinct full size sequences (hef80b
cluster census). The modal tuple (18648, 328, 24,
32776, 15304) at positions 22–26:

- In 5ab3537d the 13 modal contexts (cidx 101,
  109, 117, then 165, 169, …, 197 step 4, then
  205) are ONE size sequence and ONE channel
  sequence — size- and channel-variable positions
  over all 496: ZERO. They are the family's
  largest cluster.
- In 773470cd the 14 modal contexts SPLIT: 13
  (cidx 101, 105, 109, 113, 117, then 173, …,
  205 step 4, gap at 193) share one size
  sequence, while cidx 97 alone carries a
  different one — and cidx 97's sequence is
  EXACTLY 5ab3537d's modal sequence. That
  sequence is the ONLY full size sequence the
  two sisters' len-496 families share (1 of 9
  distinct in each).
- Position 9 is a second separator: every modal
  context in both sisters carries 31288 at
  position 9 (13/13 and 14/14), while non-modal
  contexts carry 29656 in 11/15 (5ab) and 10/14
  (773), with 31288 minorities of 4 each. The
  positions at which the modal group is constant
  and the non-modal set differs are exactly
  {9, 22, 25, 26} in both sisters — position 9
  plus the three tuple slots.
- At other region signatures the modal contexts
  are poor relations. In 5ab they occur ONLY in
  (22, 5, 5) mixed hits (26 = exactly 2 per
  context, all M-N; M-M pairs produce no hit
  because the modal contexts are identical), and
  in NO other signature — (22,4,4), (25,1,1),
  (25,2,2), (26,1,1), (22,1,1) hits (26 total)
  are all N-N. In 773 the 13 main modal contexts
  occur in exactly 3 hits each, all M-N, at the
  three presentations of the same 22–26 region —
  (22,5,5), (25,2,2), (26,1,1), 13 each — while
  cidx 97 occurs in NO localized hit at all (its
  template differs from the 13 at 314 size
  positions). Non-modal contexts, by contrast,
  participate widely (totals 112 in 5ab and 107
  in 773, up to 16 per context).
- Segment bytes separate nothing: hash-variable
  positions number 421 in both 5ab groups and
  in 773's non-modal group (432 in 773's modal
  group, inflated by its two templates) — bytes
  are per-context at most positions whatever the
  tuple. Every len-496 context in both sisters
  carries exactly three (…, 328, 24, …) frames —
  at positions 18, 22 and 473 — in both classes.

Verdict: the modal tuple marks a template, not a
population of variants: in 5ab it is one constant
496-action sequence repeated in 13 contexts; in
773 the same tuple is carried by that template's
sister variant (13 contexts) plus a single
context, cidx 97, carrying 5ab's exact sequence —
the sole whole-sequence bridge between the two
sisters' len-496 families. Modal contexts are
thereby invisible to every other region signature
except the tuple's own region.

## What this closes and what it queues

- MEASURED: exemplar head channel recurrence —
  0a0d's two head patterns occur nowhere else
  (0/1,503 each; best non-sibling prefix 5), while
  0856's two patterns recur exactly (22 and 27
  contexts, joint size+channel) as heads of
  context trains in other artifacts (0a0d len-623
  step-4 and len-763 step-6 trains, MiniLM,
  76c3a8ff, cc9b9d1c); both size scaffolds are
  common (271 / 137 contexts) with the 304
  triple's channels fixed (0,1,2) throughout.
- MEASURED: the len-89 population is two
  interleaved step-9 sub-trains (cidx ≡ 2 / 4
  mod 9, 26 each, all ng 1), each with one uniform
  main form (25 contexts, one stripped size +
  channel sequence) and one shifted-region head
  (cidx 110 / 112); position-18 values are
  sub-train + head artefacts (A main 24, B main
  camp 21392/21648, A head 528 displaced, B head
  24 with its 21392 at position 19); the main
  forms differ only at original positions 12–32
  (17 size positions).
- MEASURED: the sister len-496 families hold 9
  distinct size sequences each and share exactly
  ONE — 5ab's modal sequence, carried in 773 by
  cidx 97 alone; 773's other 13 modal contexts
  carry a sister variant template; modal contexts
  are separated from non-modal by exactly
  positions {9, 22, 25, 26}, are signature-poor
  (only their own region's signatures, M-N only),
  and are byte-per-context like everything else.
- NEXT (4.81): the head-pattern trains (0a0d
  len-623 step-4 contexts carrying 0856 a's head;
  len-763 step-6 contexts carrying 0856 b's head
  — whole-context relation to the exemplars?);
  camp choice vs the B-main form's 11 byte-
  variable positions (contents at position 18 /
  offsets); the len-496 template census (all 9
  sequences per sister: cluster sizes, tuple
  mapping, cidx pattern per template).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
