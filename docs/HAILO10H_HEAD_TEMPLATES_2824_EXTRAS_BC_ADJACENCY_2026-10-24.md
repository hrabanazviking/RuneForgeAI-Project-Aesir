# Shared head templates, extra 2824s, B→C adjacency at corpus scope (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.70 (AES-NUM-070).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef70.py
(sha256 08b60859…) + labelled follow-up hef70b.py
(sha256 81a3f72b…). Controls reproduce AES-NUM-029/032…069
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfer: gzipped scripts in sha-gated
per-part files on Mimir (hef70's first whole-file crossing
failed its sha gate and was discarded uncommitted; every
part then landed with its own sha verified, the assembled
gzip and script shas verified on-device before the runs).
Definitions (seam set A = 7952, B = 32784, C = 26896;
collapsed/zero states; class = the 0a0d378c contexts of a
given action count) are as in AES-NUM-061…069. Each class
holds 16 contexts (623: cidx 3–63; 419: cidx 78–168;
290: cidx 79–169), each split 3 collapsed-A / 3 zero /
10 other.

## (i) Three head templates on one shared scaffold — shared 0–12, class-specific 13–28, 623 runs to 31

The full action-size sequence at positions 0–35 of all
48 class contexts:

- Every class is SINGLE-VALUED at every position of its
  template span: 290 and 419 at all of positions 0–28
  (29 positions), 623 at all of positions 0–31 (32
  positions). So each class carries exactly ONE head
  size-sequence over its span, in all 16 contexts,
  collapsed/zero and full-dose alike (the varying
  positions inside either state subset lie entirely at
  positions 29–35, never inside the span).
- The shared scaffold is positions 0–12: the modal size
  is identical in all three classes at 11 of the first
  13 positions — nine 24 B bursts at positions 0–8, then
  304 at positions 10–11. The only scaffold deviations
  are the 419 class's: it takes its first 304 one step
  early (position 9: 304 in 419, 24 in 290/623) and has
  32368 at position 12 where 290/623 take a third 304.
- Positions 13–28 are CLASS-SPECIFIC in all three
  classes (every position single-valued within its
  class, the three values pairwise distinct at 13–15,
  17–23, 25, 27; isolated coincidences only where a
  class's filler 24 meets another's: positions 16, 24,
  28). The three segments are the ones already met:
  290's signature segment (32600@13 … 200@27, AES-NUM-069),
  623's fixture segment (32784@13, 2824@14, 328@15,
  24@16, 32784@17, 21408@18, 424@19, 24@20, 32576@21,
  4976@22, 280@23, 24@24, 31984@25, 280@26, 24@27,
  32768@28 — the nine-size core interleaved with fixed
  fillers), and 419's own segment (2776@13, 344@14,
  24@15, 27056@16, 264@17, 24@18, 31816@19, 312@20,
  24@21, 11040@22, 184@23, 24@24, 25088@25, 24@26,
  232@27, 24@28).
- The template ENDS at different positions: at 29 the
  290 and 419 heads dissolve into the body (positions
  29–35 carry 6–13 distinct values per class, modal
  frequencies only 2–11 of 16), while the 623 template
  runs three positions longer (1280@29, 264@30, 24@31 —
  all single-valued) and dissolves at 32. Distinct
  full head (0–35) sequences per class: 15 / 14 / 15
  of 16 — the differences live entirely in the
  dissolved tail 29–35. Head channels are far less
  rigid than sizes: a single channel across all 48
  contexts at only 11 of 36 positions.

Verdict: ONE shared scaffold (0–12, with the 419
class's two deviations), THREE distinct class templates
(13–28), and class-specific template lengths (290/419
end at 28, 623 at 31). AES-NUM-069's question is
answered: not one template with class-specific slots —
a common opening carrying three different fixtures.

## (ii) The extra 2824s are in-band, channel-normal body occurrences — no template echo

All 22 occurrences of 2824 in 0a0d378c: the 623 base
slot at position 14 (×16), extras at 213 (cidx 7, 43)
and 451 (cidx 43 only), and three in the 419 class
(cidx 84 @268; cidx 138 @204 and @268). The extras:

- Channel-normal for their slots: position 14's
  channel is 0 in 16/16 623 contexts, position 213's
  is 0 in 16/16, position 451's is 1 in 16/16 — and
  every 2824 occurrence carries exactly its position's
  fixed channel (base 0, @213 extras 0, @451 extra 1;
  the 419 extras carry 1, 2, 1 at 268/204/268).
- The CHANNEL SCAFFOLD around them is total: the
  17-action channel window at 205–221 is ONE single
  sequence in all 16 623 contexts (2×8, 0, 1, 1, 1,
  2×4, 1), and the window at 443–459 likewise
  (1 distinct in 16). Sizes vary freely inside the
  channel scaffold; channels do not.
- In-band sizes: at position 213 the class's values
  run 2600–3088 (2824 sits inside, alongside 3088 ×3);
  at 451 they run 2616–3088 (2824 once, 3088 ×2).
  The extras are ordinary members of their positions'
  size bands, not intrusions.
- The two @213 windows share NOTHING but the 2824
  itself (1/17 equal sizes) and the channel scaffold:
  cidx 7's extra sits inside a full rotation stream —
  neighbours 26896 on BOTH sides (seam window A B C C
  A A), and cidx 7's seam counts are IDENTICAL to its
  full-dose peers (386 total; A 128, B 130, C 128), so
  no seam member was displaced: the 2824 occupies a
  non-seam slot between two consecutive C actions.
  Cidx 43 is a zero-state context (seam total 2 — the
  head BB pair only); its extras at 213 and 451 sit in
  plain data streams (neighbours 25112→25360 and
  3088→5648), with no seam member anywhere near.
- The 419-class extras are the same species: late body
  occurrences in data/rotation streams. The two @268
  extras (cidx 84 and 138) share an IDENTICAL
  17-action channel window, though their size windows
  differ.

Verdict: the extra 2824s are NOT a second template
fixture and not seam events. 2824 is a body size that
happens also to be frozen into the 623 head template
at position 14; in the body it recurs rarely (6 extras
in 1,504 contexts' classes) at channel-normal,
in-band slots. The head @14 occurrence is the template
borrowing a body size, exactly as 264 turned out to be
a shared slot (AES-NUM-069).

## (iii) B→C adjacency is a real rotation diagnostic — pair-specific, artifact-scoped (95.4% corpus; 99.4% in 0a0d)

Corpus-wide (all 7 artifacts, 199,606 consecutive
seam-letter transitions):

- B→C: 7,347 transitions, 7,009 at gap 1 — 95.40%
  adjacent, median gap 1, mean 1.17; gap ≤2 in 97.2%.
  A→B is the only comparable forward step (91.91%
  gap 1 of 12,126). Rotation pooled (A→B, B→C, C→A)
  is 75.40% gap 1 — dragged down entirely by C→A.
- The controls show adjacency is PAIR-SPECIFIC, not a
  generic seam property: transitions INTO A are never
  adjacent (C→A 0/4,603 gap 1; A→A 0/5,966; B→A
  1/8,509), while anti-rotation A→C is itself 82.70%
  gap 1 and C→B 64.70%. B→B — the bulk population
  (155,254 transitions, mostly from the B-only
  artifacts) — is 44.35% gap 1. So a gap-1 successor
  discriminates: B followed immediately by its next
  seam action is a C in the rotation sense far above
  any baseline, and A is a seam-block BOUNDARY (never
  entered adjacently, usually exited adjacently).
- Artifact scope: the diagnostic lives only where C
  populations are real. 0a0d378c: B→C 1,994/2,007 =
  99.35% gap 1. cc9b9d1c: 4,031/4,227 = 95.36%.
  76c3a8ff: 984/1,104 = 89.13%. The sister blobs hold
  NO C at all (B-only streams, B→C undefined); MiniLM
  has 3 seam actions total; 0856a10c holds 10 C's whose
  9 B→C transitions are 0% gap 1 — its C's are the
  isolated remnant singletons of AES-NUM-065, not
  rotation members.
- Head vs body: B→C adjacency is a body phenomenon
  (6,867/7,193 = 95.47% gap 1) and slightly weaker in
  the head region (142/154 = 92.21%), where the fixed
  templates intervene.

Verdict: B→C seam adjacency at gap 1 is a VALID
rotation diagnostic within the three artifacts that
carry real rotation streams (0a0d378c, cc9b9d1c,
76c3a8ff) — a B whose next seam member is immediately
adjacent is overwhelmingly mid-rotation. It does not
generalise to B-only or remnant-C artifacts, and its
strength is pair-specific (C→A adjacency is exactly
zero), which is what makes it diagnostic rather than
a generic density effect. This closes the mechanism
behind AES-NUM-069's scattered-B follower: those B's
were rotation members, and rotation members take
their C adjacently 95–99% of the time.

## What this closes and what it queues

- MEASURED: one shared head scaffold at positions
  0–12 (419 deviations at 9 and 12 only), three
  distinct single-sequence class templates at 13–28
  (29 positions single-valued in 290/419, 32 in 623),
  template ends at 28 (290/419) vs 31 (623).
- MEASURED: extra 2824s (213 ×2, 451 ×1 in 623;
  204/268 in 419) are channel-normal (channel windows
  single-valued in 16/16 contexts around both slots),
  in-band body occurrences; cidx 7's extra displaces
  no seam member (seam counts identical to peers).
- MEASURED: B→C gap-1 adjacency 95.40% corpus-wide
  (7,009/7,347), 99.35% in 0a0d378c, against C→A at
  exactly 0/4,603 — a valid, pair-specific,
  artifact-scoped rotation diagnostic.
- NEXT (4.71): the channel scaffold as a corpus
  object (are fixed channel windows universal beyond
  the class contexts?); the A-boundary law (why A is
  never entered adjacently — A's own predecessor
  structure); C→A gap distribution (where the rotation
  resets). Host/artifact analysis only — no physical
  child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
