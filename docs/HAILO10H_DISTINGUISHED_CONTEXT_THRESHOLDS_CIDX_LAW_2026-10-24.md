# Distinguished context, threshold landmarks, cidx scalar law (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.87 (AES-NUM-087).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef87.py
(sha256 75f7db4f...), sha-verified on-device after a
one-shot proxy-receiver transfer (the gz bytes never
passed through tool re-emission; the receiver returned
the gz sha256 458020e2... and it matched). Output file
/tmp/hef87_out.txt sha256 f4c981b0.... Controls
reproduce AES-NUM-029/032...086 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (camps, classes, cidx / ngpos) are
as in AES-NUM-061...086. The sibling population is the
AES-NUM-084 home: 76c3a8ff, position 20, size 14,528,
channel 0, ng 1 400-action contexts, cidx 113-338
step 9 (26 segments / contexts). The position-18
population is unchanged: 76c3a8ff len-89 B-main
segments at position 18, cidx %9 == 4, cidx != 112 —
13 contexts in camp 21392, 12 in camp 21648.
Contract: docs/TASK_CONTRACT_4.87.md (published
@ 227f1a62 before implementation).

## (i) Cidx 113 IS distinguished beyond its sibling segment — schedule, consensus content, and no twin elsewhere

AES-NUM-086 showed cidx 113 deviates from the other 25
sibling segments at all 544 two-valued byte positions.
This slice asked whether the distinction stops at that
one segment. It does not:

- Whole-context metadata: all 26 sibling contexts have
  exactly 400 actions. At only 82 of 400 action
  positions is the (size, channel) pair unanimous in
  all 26 contexts. At 249 positions the other 25
  contexts are unanimous in (size, channel) and cidx
  113's context ALONE differs; at the remaining 69
  positions the other 25 are not unanimous either.
  The 249 differences are not noise: in the head they
  are channel flips on 24/48/80 B actions (positions
  1-37), and from position 41 on they are wholesale
  re-groupings of the large actions — where the
  consensus schedule carries (32784, 16464, 5392)
  groupings, cidx 113 carries different groupings of
  the same size vocabulary (7688/7600/7720 heads with
  5392 partners, 25232/9744/1296 patterns later, etc.).
- Whole-context content (sha256 of every segment, all
  400 positions covered, 0 skipped, 6,434,744 B hashed
  per context at cidx 113's sizes): segment content is
  per-context at most positions — at 320 positions the
  other 25 are not hash-unanimous and cidx 113's hash
  matches none of theirs. Consensus content exists at
  only 80 positions: 57 are identical in all 26
  contexts, and at 23 positions the other 25 are
  hash-identical while cidx 113 differs (exactly 2
  distinct hashes at each). The 23 content-distinguished
  positions are 15 x 24 B bursts (indices 0, 1, 8, 9,
  16, 29, 34, 380-383, 396-399 — the head and tail
  skeleton bursts), 3 x 328 B segments (376-378),
  2 x 48 B, 1 x 80 B, 1 x 5,008 B, and 1 x 32,784 B
  (index 331).
- First-in-train privilege elsewhere: there is NO
  second multi-context train among this artifact's
  len-400 contexts to test — 28 len-400 contexts
  exist, 26 in the sibling train (residue 5 mod 9)
  and two singletons (residues 6 and 7, n 1 each).
  The position-18 populations show NO first-segment
  privilege: in camp 21392 the first segment (cidx
  130) deviates at 36 of the 72 two-valued positions,
  exactly the block-bit count shared by five other
  segments (deviations are 0 or 36 for every segment);
  in camp 21648 deviations are 0 / 36 / 72 across
  segments, the first (cidx 121) deviates at 36, and
  the maximum (72) belongs to later segments.

Verdict: cidx 113's distinction is context-wide — a
different action schedule from position 41 on, private
bytes at every consensus-content position class that
carries consensus at all, and the sibling segment's
544 private bytes. No other tested population has a
distinguished first segment. Why the first context is
built differently, and what any of it MEANS, is NOT
PROVEN.

## (ii) The staircase thresholds are ordinary ff-15 fixture words; nothing else marks them

AES-NUM-086 froze the position-18 ff frame's cross-camp
drift as one staircase with step-ups at camp-21392
offsets 9044 / 11292 / 15508 / 17204. Direct anatomy
of those four offsets:

- Every threshold IS itself an aligned ff offset in
  camp 21392, carrying the constant scalar 15, at
  ff-list ranks 2, 8, 22 and 26. Its rank-matched
  camp-21648 counterpart (9108 / 11420 / 15700 /
  17460) is likewise an ff-15 word, and the 36 B
  window around it is byte-identical to the camp-21392
  window around the threshold.
- The local fixture shape is the same at all four:
  the ff word (ff 0f 00 00, aligned u32 4095) is
  followed by 16 00 00 00 / 01 00 00 00 / e8 23...,
  and the next ff word sits exactly +192 after every
  threshold. The word 8 B before each threshold
  differs per threshold (08 86 80 / 08 88 00 /
  08 84 00 / 08 8a 80 in segment order). For the
  first two thresholds the preceding ff word is a
  variable slot (8568 / 10800, gaps 476 / 492); for
  the last two it is an ff-15 word (14960 / 16656,
  gaps 548 / 548).
- Nothing else is there: in the 256 B windows before
  and after each threshold there are ZERO
  variable-across-camp positions; the nearest tail-
  variable position is 475-4,139 B away. The only
  window-level signature is a density step that is
  identical at all four thresholds: ~0.66 zero
  fraction in the 256 B before, ~0.90 in the 256 B
  after. Inter-threshold gaps are 2,248 / 4,216 /
  1,696; the thresholds mod 64 are 20 / 28 / 20 / 52
  — no common residue, no period.

Verdict: the staircase does not step at landmarks.
Its step points land on generic ff-15 fixture words
indistinguishable in content from their neighbours;
the +64 insertions are absorbed somewhere in the
regions BETWEEN ff words, not at the ff words
themselves. Where in those regions, and what the
steps MEAN, is NOT PROVEN.

## (iii) The position-18 variable ff scalar is exactly cidx - 92 — one law for all three populations

AES-NUM-084 recorded the position-18 variable ff
scalar as "mostly +9 steps". In cidx order the
sequences are: camp 21392 [38, 47, 56, 65, 110, 119,
128, 146, 155, 164, 173, 227, 236] (diffs +9 x9,
+45, +18, +54) and camp 21648 [29, 74, 83, 92, 101,
137, 182, 191, 200, 209, 218, 245] (diffs +45, +9 x7,
+36, +45, +27). Neither is a rank ladder — no exact
a + b x rank fit exists in either camp. But the diff
multiset of each sequence equals the diff multiset
of its own camp's cidx sequence EXACTLY, step for
step in order, and the closed form is:

  variable ff scalar == cidx - 92

verified for every segment in both camps
(38 = 130-92 ... 236 = 328-92; 29 = 121-92 ...
245 = 337-92). The 4 variable slots repeat the
scalar within each segment in both camps (verified
all-equal). And the law is not position-18's alone:
the sibling population's exact ladder 21 + 9 x rank
(AES-NUM-086) IS this law — sibling cidx run
113 + 9 x rank, and 113 - 92 = 21, 338 - 92 = 246.
One identity, scalar = cidx - 92, covers all 51
measured segments across the three 76c3a8ff
populations. Control: the 39 constant ff scalars in
offset rank are NOT a ladder (modal diff 0, no exact
fit) in either camp, and their sequence is the
camp-identical fixture of AES-NUM-086.

Verdict: the variable ff scalar is a pure function
of the context's global index — the segment's own
context number minus 92 — not of rank within any
population, camp, or train. What index 92 is (the
constant's origin), whether the law holds in the
other six artifacts or other ff populations, and
what the scalar MEANS, are NOT PROVEN.

## What this closes and what it queues

- MEASURED: cidx 113 is distinguished context-wide —
  a private (size, channel) schedule at 249 of 400
  positions (consensus-unanimous at those positions)
  and private content at 23 of the 80 positions where
  consensus content exists at all (15 skeleton bursts,
  3 x 328 B, 2 x 48 B, 1 x 80 B, 1 x 5,008 B,
  1 x 32,784 B). No first-segment privilege exists in
  the position-18 camps, and no second len-400 train
  exists in this artifact to test.
- MEASURED: the four staircase thresholds are
  ordinary ff-15 fixture words (ranks 2/8/22/26,
  next ff at +192, byte-identical windows in the
  other camp); no variable position, residue or
  period marks them.
- MEASURED: the variable ff scalar equals cidx - 92
  exactly in all 51 segments of the three measured
  76c3a8ff populations (both position-18 camps and
  the sibling train — its 21 + 9 x rank ladder is
  the same law).
- NEXT (4.88): does scalar = cidx - 92 hold in the
  other artifacts / other ff populations, and what
  is context 92 itself?; is cidx 113's schedule a
  permutation / re-grouping of the consensus schedule
  (same (size, channel) multiset and totals, or a
  different multiset)?; where between ff words the
  staircase's +64 insertions live (rank-aligned
  byte-diff of the camps region by region).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no device child ran.
Grades: the counts, hash categories, threshold
anatomy and the cidx - 92 identity are MEASURED over
the complete stated populations (controls exact;
the cidx - 92 identity re-verified arithmetically
off-device for all 51 segments). Every meaning —
why the first context differs, what index 92 is,
what the scalar or the staircase steps encode — is
NOT PROVEN and nothing here invents one.
