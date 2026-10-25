# Mirror extent, reduced low-none six, block0 exceptions (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.58 (AES-NUM-058).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef58.py
(sha256 aa635b23…) plus the labelled follow-up
hef58b.py (sha256 fc16205c…). Controls reproduce
AES-NUM-029/032…057 EXACTLY in both scripts (128,787
pooled small actions; 79,001 pooled 24 B bursts;
745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped parts
at 225 B boundaries (a 300 B split of the same gzip
corrupted deterministically in re-emission and was
discarded uncommitted; the 225 B split landed with its
whole-file sha verified on-device). Definitions
(middle, band, window, core cluster 9168–9248, exclusive
family 9144–9264, shoulders, POS / DENSE / OTHER, low
ladder 8960–9136, 94xx ladder 9408–9488, 97xx ladder
9696–9792, refined low-none segments) are as in
AES-NUM-049…057.

## The +137 lead mirror does not survive audit — retraction

AES-NUM-057 reported that at cidx offset +137 in
cc9b9d1c, 72 of 134 context pairs have byte-identical
window-lead sequences. That count came from hef57b's
B3 comparison, which counted two EMPTY lead lists as
identical. Decomposed by emptiness class, the 134
eligible pairs are:

- both-empty ×60 — neither context has any window at
  all (120 contexts, ng-balanced 60/60; 124 of cc9's
  271 contexts have empty lead lists, most of them
  the 245/256/259-action classes);
- one-empty ×2;
- both-nonempty ×72 — of which identical ×12 and
  DIFFERING ×60.

And the 12 identical non-empty pairs are trivial:
every one is a single-window context whose whole lead
sequence is [80] (sources cidx 12, 16, 24, 36, 44, 48,
56, 60, 68, 80, 88, 108 — all ≡ 0 mod 4; nacts
259 → 256). No pair of contexts with two or more
windows shares a lead sequence at +137, or at any
other offset: cc9's non-empty duplicate pairs top out
at offset 12/20 (15 pairs each, the small-offset
repetitions of short sequences), with +137 at 12 —
all twelve trivial.

Corpus-wide, the mirror is a cc9-only question in the
first place: windowed contexts exist in only three
artifacts — cc9b9d1c (147 non-empty of 271, 123
distinct sequences), 0856a10c (112 of 256, all 112
distinct, ZERO duplicate pairs at any offset) and
76c3a8ff (90 of 325, all 90 distinct, zero duplicates).
MiniLM, 0a0d378c, 5ab3537d and 773470cd have no
windowed contexts at all under the middle definition.
(The blob pair's repetition lives one level down, in
mid-size sequences: 5ab3537d 1,013 duplicate pairs,
top offset 12 ×100; 773470cd 1,047, top offset 12
×102; 76c3a8ff 444, top offset 9 ×40.)

What survives of AES-NUM-057's §3 is the part that
never depended on lead equality: POS family contexts
recur at +137 as POS (9/10, hef57's membership count),
and shoulder stretches are short-gap runs. The
sequence-mirror sentence in AES-NUM-057 and in the
progress note is RETRACTED as a counting artifact
(60 empty==empty + 12 single-window [80] pairs).
Graded MEASURED: at +137 there is no non-trivial
window-lead mirror in any artifact.

## The reduced low-none six are a different grade, paired by profile

The six reduced contexts (cidx 34, 66, 86, 171, 203,
223) differ from the maximal 15 in kind, not degree:

- Grade constants: 606–607 actions (maximal: 738),
  32016 ×32 (maximal: ×96), 32784 ×64–65 (maximal:
  ×223–224), champion body 29 = maximal's 29, order
  normal in all 6 (maximal: all reversed), window
  count variable 54–81 (maximal: uniformly 96).
- A different mid vocabulary: 148–161 distinct mid
  sizes per context against the maximals' 45–58.
  Reduced-only staples: 3088 ×16 in every reduced
  context and never in a maximal; a 30xxx/35xx
  family. Maximal-only staples: 7952 ×32 per context,
  2064, and the 62xx series — absent from all six.
  They are NOT truncated maximals, and no reduced
  lead sequence is a subsequence of any maximal one
  (longest prefix-subsequence ≤ 6 of 54–81 leads).
- Their segment vocabularies are nevertheless drawn
  from the maximal pool: the reduced 93 segment's 10
  distinct leads are a subset of the maximals' 14;
  the 89 segment's 7 of 7 likewise.
- The six form three +137 pairs — (34, 171) 93-led,
  (66, 203) 93-led, (86, 223) 89-led — with the ng
  flipping 0 → 1, nacts 607 → 606, and the profile
  preserved exactly (same window count 81/81, 54/54,
  62/62; same segment dose 20/20, 20/21, 26/26). But
  the sequences themselves are NOT twins: lead
  positions differ at 76/81, 50/54 and 55/62, and
  neither lead nor mid multisets are equal. The
  maximal +137 pairs differ likewise (86–93 of 96
  lead positions). The +137 recurrence is a PROFILE
  recurrence (grade, window count, segment dose),
  never a sequence copy — for either grade.

## The block0 ng0 exceptions are reduced-grade all-97 contexts

AES-NUM-057's block0 class (maxrun ≥ 15 at ordinal 0)
held 13 contexts: 11 maximal ng1 plus ng0 exceptions
cidx 54 and 110. Both exceptions are reduced-grade
contexts of the 606/607 class: 607/606 actions, 32
windows, 32016 ×32, 32784 ×64/63, normal order, no
low/exclusive/cluster/segment windows at all — and
their windows are (nearly) all 97xx-led: cidx 54 has
31/32 (runs [20, 11] at starts [0, 21], the single
non-97 window being one 98-led at ordinal 20), cidx
110 has 32/32 in one run of 32. In a 32-window
context that is all 97xx, a ≥15 run at ordinal 0 is
forced; the "placement" is degenerate, not a
counterexample to the ng rule, which was stated over
maximal contexts. Two more members of the same class
are near-all-97 (cidx 50: 31/32; cidx 187: 31/32) but
fall in the mid/scatter classes by run shape.

The 606/607 class itself is a clean periodic rail,
cc9-only corpus-wide: exactly 55 contexts at cidx
2, 6, …, 110 (28 contexts, step 4) and 143, 147, …,
247 (27 contexts, step 4) — the second rail is the
first shifted by +137 from cidx 6 on (6 → 143,
10 → 147, …, 110 → 247). 51 of 55 are normal-order,
48 carry 32016 ×32 exactly; window counts span
32–96. The reduced low-none six and both block0
exceptions all sit on this rail.

## What this closes and what it queues

- RETRACTED: the +137 window-lead sequence mirror
  (AES-NUM-057 §3). The 72/134 count decomposes as
  60 empty==empty pairs + 12 trivial single-window
  [80] pairs; 60 of the 72 both-nonempty pairs
  DIFFER. No non-trivial lead mirror exists at any
  offset in any artifact; windowed contexts exist
  in only 3 of 7 artifacts, and outside cc9 every
  non-empty lead sequence is distinct.
- MEASURED: the +137 recurrence that does exist is
  profile-level — POS membership (9/10, AES-NUM-057)
  and, for the reduced six, exact preservation of
  grade, window count and segment dose across three
  +137 pairs whose sequences differ at ~90% of lead
  positions.
- MEASURED: the reduced low-none six are a separate
  grade (606–607 acts, 32016 ×32, normal, 3088-led
  mid vocabulary, no 7952), not truncated maximals;
  their segment leads are subsets of the maximal
  pool (93: 10/10, 89: 7/7).
- MEASURED: block0's ng0 exceptions cidx 54/110 are
  reduced-grade all-97 contexts (31/32 and 32/32
  windows 97-led); their ordinal-0 block is
  degenerate. The maximal-context ng placement rule
  of AES-NUM-057 stands untouched.
- MEASURED: the 606/607-action class is a step-4
  periodic rail of 55 cc9-only contexts (cidx 2–110
  and 143–247), carrying the reduced six, both
  exceptions, and two more near-all-97 members.
- NEXT (4.59): the step-4 rail — what distinguishes
  its 55 contexts' four window-count grades
  (32 / 54–62 / 81 / 96) and the all-97 quartet's
  place on it; profile-recurrence rates at +137
  over all cc9 (which features are preserved, for
  which classes); the windowed populations of
  0856a10c and 76c3a8ff (their all-distinct lead
  sequences' internal structure). Host/artifact
  analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
This doc corrects AES-NUM-057 §3's mirror sentence;
its other sections stand as graded there.
