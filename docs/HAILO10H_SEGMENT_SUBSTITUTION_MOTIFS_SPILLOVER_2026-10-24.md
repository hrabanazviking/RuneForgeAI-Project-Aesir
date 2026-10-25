# Segment-substitution census, motif families, S76 spillover test (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.77 (AES-NUM-077).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef77.py
(sha256 71cea705…) + labelled follow-ups hef77b.py
(sha256 4e51bcca…), sha-gated gzipped part transfers
(hef77's 373 B part at offset 1865 corrupted in
re-emission twice and was rejected; a 100 B re-split of
that region landed clean — whole-file shas verified
on-device for both scripts). Controls reproduce
AES-NUM-029/032…076 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct (channel,
operand) pairs 2,049; champion-headed bursts 75,215).
Definitions (seam set, classes, cidx/ngpos) are as in
AES-NUM-061…076.

## (i-a) No context pair is a single difflib replace — not even 85→92

Strict census (hef77): pairs in 0a0d378c / cc9b9d1c
sharing head-12 and last-20 size keys, length delta
≤ 24, whose difflib opcodes contain exactly ONE
non-equal opcode and it is a replace:

- 0a0d378c: 1,067 candidate pairs, 0 hits.
- cc9b9d1c: 2,411 candidate pairs, 0 hits.
- A looser head-8 tier adds 2,555 / 5,375 further
  candidates and still 0 hits.

The 85→92 pair itself fails this definition: its
disturbed region is broken by five short equal
islands (2, 1, 1, 2 actions; AES-NUM-076), so it is
several replaces, not one. The single-replace form
of segment substitution does not occur at all.

## (i-a2) Region census: at substitution scale, 85→92 is UNIQUE

Region definition (hef77b): opcodes = equal head
(≥ 12) + ONE disturbed region whose internal equal
islands are ≤ 2 + equal suffix (≥ 20):

- 0a0d378c: 149 of 1,067 candidates (islands ≤ 3:
  242; head-8 changes nothing).
- cc9b9d1c: 5 of 2,411 candidates (same at ≤ 3).

But the region lengths split the hits into two
kinds that share nothing but the definition. Of the
154 strict hits, the a-side region lengths are:
17 (×1), 191 (×2), 197 (×5), 205 (×5), 206 (×62),
212 (×16), 536 (×58), 555 (×7). Exactly ONE hit has
a region at the 85→92 scale:

- a cidx 73 (ng 0, len 85) → b cidx 179 (ng 1,
  len 92): head 12, suffix 56, region a[12:29] (17)
  → b[12:36] (24), delta +7 — the AES-NUM-076
  exemplar itself, recovered by the census.

Every other hit is a whole-body region (≥ 191
actions): same-class 0a0d pairs whose bodies differ
throughout (206→206 in 62 pairs, 536→536 in 58),
and cc9's five hits ALL involve one outlier context
(cidx 132, len 265) against partners of len
259/265/244/256/247 with regions 191–197. No other
localized (region ≤ 40) substitution exists in
0a0d + cc9. Verdict: localized segment substitution
is, on present evidence, a singleton phenomenon —
the 85→92 pair is the only place in either artifact
where one body segment is rewritten while head and
suffix stand.

## (i-b) The motif families: pairs are real, contiguous repeats are not

- The (9144, 184) pair occurs 7 times corpus-wide,
  in exactly 2 contexts (0856a10c ×4 in one context;
  0a0d378c ×3 in one context — the 85 context),
  at positions 15–26. EVERY occurrence is flanked
  by size 24 on both sides: the pattern
  24-(9144,184)-24 accounts for 7/7. The pair never
  repeats contiguously ((9144,184,9144) = 0), and
  the full contiguous A-motif of AES-NUM-076
  (12224, (9144,184)×3, 9144, 24, 184, 24) occurs
  0 times — in the 85 region the repeats are
  separated by the equal islands. Singles: 9144
  ×61, 184 ×57 corpus-wide.
- The (528, 80) pair is a common unit: 551
  occurrences in 339 contexts across ALL seven
  artifacts (76c3a8ff 279, cc9b9d1c 107, 0856a10c
  57, 773470cd 42, 5ab3537d 38, 0a0d378c 20,
  MiniLM 8); positions 9–137, median 17. 330/551
  are preceded by 24 and the commonest follower is
  also 24 (444). It NEVER repeats contiguously:
  (528,80)×2 = (528,80)×3 = 0, and the full
  contiguous B-motif occurs 0 times — the three
  pairs in 92's region are likewise island-
  separated. Singles: 528 ×902, 80 ×7,905.

So both "motifs" are pair-level units embedded in a
24-framed local grammar, not literal repeated
blocks: (9144, 184) is a rare pair (2 contexts),
(528, 80) a ubiquitous one (339 contexts), and in
neither family does the pair ever sit directly
against itself.

## (ii) S76 spillover: 6 of the 10 outside-pair flips are neighbour swaps

hef77 reproduced S76 vs the G10 reference exactly
(182 diffs, 49 runs; G10 cidx 88, 94, 100, 106, 112,
136, 142, 154, 160, 166). For each of the 10
outside-pair / third-channel positions inside long
run spans (AES-NUM-076), the test: does swapping
the PREVIOUS or NEXT run's dominant pair produce
the observed target channel from the reference?

- Neighbour-explained (6/10): pos 172 (2→1; the
  previous run 146–167's pair {1,2} swap; edge
  distance 0); pos 449 and 450 (0→1; the next run's
  pair {0,1}; edge 2 and 1); pos 557 and 558 (1→2;
  the next run 582–583's pair {1,2}; edge 1 and 0);
  pos 615 (1→2; the previous run 613's pair {1,2};
  edge 0).
- Unexplained (4/10): pos 173 (2→0, run 172–184,
  edge 1); pos 517 (1→2 third-channel flip, run
  517–527, edge 0); pos 618 and 619 (0→2, run
  615–619, edge 1 and 0).
- All 10 positions sit at edge distance 0–2 of
  their run span. S82 control: 0 outside-pair
  positions in long runs (as in AES-NUM-076).

Verdict: spillover is PARTIALLY established. A
majority of the outside-pair flips are exactly the
swap the neighbouring run performs, and every one
of the ten hugs a span edge (≤ 2) — consistent with
run boundaries being drawn 1–2 positions inside a
wider swap zone whose far side belongs to the
neighbour's pair. The remaining four (173, 517,
618, 619) match neither neighbour and stand as the
residue for the next test.

## What this closes and what it queues

- MEASURED / REJECTED: the single-replace form of
  segment substitution (0 hits in 3,478 strict
  candidates + 7,930 loose); and contiguous motif
  repetition ((9144,184,9144), (528,80)×2/×3, and
  both full AES-NUM-076 motifs all occur 0 times).
- MEASURED: under the region definition the
  exemplar itself satisfies (islands ≤ 2, head
  ≥ 12, suffix ≥ 20), localized substitution
  (region ≤ 40) is UNIQUE to 85→92 in 0a0d + cc9 —
  1 hit; all 153 other region hits are whole-body
  regions ≥ 191 (cc9's five all involve the single
  outlier context cidx 132).
- MEASURED: the motif pairs' grammar — (9144,184)
  rare (7 occ, 2 contexts), always 24-flanked on
  both sides (7/7); (528,80) ubiquitous (551 occ,
  339 contexts, all 7 artifacts), 24-preceded in
  330/551 and 24-followed most often (444).
- MEASURED: S76 spillover PARTIAL — 6/10
  outside-pair flips are neighbour-run swaps, all
  10 at edge distance ≤ 2; 4/10 (173, 517, 618,
  619) match neither neighbour. S82 stays clean
  (0 outside-pair positions).
- NEXT (4.78): region census extended to the
  remaining five artifacts (does localized
  substitution stay unique corpus-wide?); the
  four unexplained S76 flips vs second-neighbour
  runs and span-extension (does widening spans by
  2 absorb them into an adjacent pair's zone?).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
