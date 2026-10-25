# Region census at corpus scope, S76 residue tests (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.78 (AES-NUM-078).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef78.py
(sha256 cc356034…) + labelled follow-ups hef78b.py
(sha256 08c73b44…) and hef78c.py (sha256 416e98c4…),
all three sha-verified on-device after one-shot proxy
receiver transfers (gz shas verified on-device; output
files /tmp/hef78_out.txt sha256 59efde20…,
/tmp/hef78b_out.txt c60b4e1b…, /tmp/hef78c_out.txt
3a389c09…). Controls reproduce AES-NUM-029/032…077
EXACTLY (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Definitions (region
census, seam set, classes, cidx/ngpos, S76/G10) are as
in AES-NUM-061…077.

## (i) Region census extended: localized substitution is NOT unique corpus-wide — but it splits by scale

The AES-NUM-077 region definition (difflib opcodes =
equal head ≥ 12 + ONE disturbed region whose internal
equal islands are ≤ 2 + equal suffix ≥ 20; prefilter
groups share (sizes[:12], sizes[-20:]), |len delta|
≤ 24), applied unchanged to the five artifacts the
4.77 census had not covered:

| artifact | ctx | groups | candidates | single-replace | K2 hits | K3 hits | localized ≤40 | region a-lengths |
|---|---|---|---|---|---|---|---|---|
| MiniLM | 6 | 2 | 10 | 0 | 0 | 4 | 0 | — |
| 0856a10c | 256 | 69 | 1,079 | 0 | 1 | 4 | 1 | 16 ×1 |
| 76c3a8ff | 353 | 37 | 3,723 | 157 | 160 | 160 | 157 | 1 ×157, 218 ×2, 219 ×1 |
| 5ab3537d | 219 | 46 | 1,207 | 54 | 109 | 136 | 109 | 1 ×21, 2 ×33, 4 ×12, 5 ×43 |
| 773470cd | 219 | 45 | 1,219 | 88 | 107 | 121 | 107 | 1 ×52, 2 ×36, 4 ×4, 5 ×15 |

Remaining-five totals: 7,238 candidates, 377 K2 hits,
374 localized, 3 whole-body (all in 76c3a8ff, regions
218/219, four distinct contexts, cidx 92 in three of
them). Corpus totals with AES-NUM-077 (0a0d 149 hits /
1 localized; cc9 5 / 0): 531 K2 hits, 375 localized.

The localized hits split cleanly by REGION SCALE:

- Micro scale (a-side region ≤ 5): 373 of the 374.
  Every one sits inside a repeated context family.
  In 76c3a8ff, 156 of 157 are a SINGLE signature:
  len-89 contexts, region [18:19] 1→1, the size at
  position 18 taking exactly two values (21392 /
  21648; 91 + 65 directed pairs = 13 × 12) across 25
  contexts on the cidx step-9 train 121–337 (ng 1) —
  every cross-camp pair is a hit, within-camp pairs
  are identical. The 157th is a len-296 pair
  (cidx 207→243, region [107:108], 3088→2832).
  In the sister pair, 109 / 107 hits over 56 / 49
  distinct contexts, 11 signatures each, all regions
  ≤ 5, concentrated in the len-496 families (region
  starts 22/25/26), len-470 (start 17, 2→2) and
  len-761 (starts 14/15); region-1 value pairs are
  artifact-specific size pairs (773470cd's commonest
  29528↔31160, 20 pairs).
- Segment scale (a-side region 8–40): exactly ONE
  in the five — see below.

And the single-replace form, absent in 0a0d + cc9
(AES-NUM-077: 0 in 3,478 strict candidates), is the
micro form in the train-heavy artifacts: 299 hits in
the remaining five (76c3a8ff 157, sisters 54 + 88).

Verdict: micro-substitution is a property of
artifacts holding many near-identical contexts
(trains/classes); it is absent precisely where they
are absent (MiniLM 0, 0856a10c 0, 0a0d/cc9 0).

## (i-b) Segment scale: 85→92 has exactly one corpus mate — 0856a10c 85→91

The one segment-scale hit in the remaining five:

- a cidx 99 (ng 0, len 85) → b cidx 255 (ng 1,
  len 91): head 13, suffix 56, region a[13:29] (16)
  → b[13:35] (22), delta +6.
- a region: [24, 12224, 200, 24, (9144,184) ×4 each
  24-separated, 24] — this is the 0856a10c context
  AES-NUM-077 counted four (9144,184) occurrences in.
- b region: [31712, 328, 24, 11264, 200, 24,
  (528,80) ×3 each 24-separated, 24, 80, 80, 24,
  80, 80, 48, 80].

Against the 0a0d378c exemplar (AES-NUM-076/077):
a-side len 85 in BOTH, ng 0 → ng 1 in BOTH, suffix
56 in BOTH, head 12 vs 13, region 17→24 (delta +7)
vs 16→22 (delta +6), a-side (9144,184) ×3 vs ×4,
b-side (528,80) ×3 in BOTH.

Verdict: segment-scale localized substitution is
NOT unique corpus-wide. Its class has exactly TWO
members in 531 region hits across seven artifacts,
and both are the same rewrite — a (9144,184)-motif
segment replaced by a (528,80)-motif segment in an
85-action ng-0 context, producing a 91/92-action
ng-1 context over an identical 56-action suffix.
AES-NUM-077's uniqueness stands only within its
stated scope (0a0d + cc9).

## (ii) S76 residue: second-neighbour and span-extension tests are NEGATIVE for all four flips

hef78b reproduced the AES-NUM-077 construction
exactly (S76 vs G10: 182 diffs, 49 runs, 10
outside-pair positions in long runs, 6 explained by
first neighbours; S82 control 0 outside positions).
New tests per outside position: (a) second-neighbour
runs (i−2 / i+2) dominant-pair swap; (b) span
extension by 2 — a neighbour run's span widened by
2 positions covers the flip AND its pair swap
produces it; (c) gap-bridged super-runs (consecutive
runs merged across agreement gaps ≤ 2; 49 runs →
27 super-runs in S76, 22 → 12 in S82) — is the flip
pair-internal under its super-run's dominant pair?

The four residue flips (173, 517, 618, 619) fail
EVERY test:

- pos 173 (run 16, ref 2 → tgt 0): prev2 run 14
  pair {0,1} and next2 run 18 pair {0,1} — swap no,
  exact flip not present in either; extension
  coverage no on both sides (prev run 15 ends 167,
  +2 = 169 < 173; next run 17 starts 189, −2 = 187
  > 173); its super-run is run 16 alone, internal
  no. Nearest (0,2) flip in any other run is 34
  positions away (run 13, pos 139).
- pos 517 (run 37, ref 1 → tgt 2): prev2 run 35
  {0,1} and next2 run 39 {0,1} — swap no on both;
  the exact (1,2) flip IS present in run 39 (at
  557/558 — the flips AES-NUM-077 explained by
  run 40), but under no dominant pair that produces
  it here; extension coverage no; super-run 20
  (runs 37+38 merged across a gap of 2) has dominant
  pair {0,2}, internal no. Nearest exact flip is 13
  away at run 38 pos 530 — inside its own super-run,
  again under a non-producing dominant pair {0,1}.
- pos 618 (run 45, ref 0 → tgt 2): prev2 run 43
  {1,2} and next2 run 47 {0,1} — swap no, flip
  absent from both; extension no (next run 46
  starts 622, −2 = 620 > 619); super-run 25
  (runs 44–47 merged) dominant {0,1}, internal no.
  Nearest (0,2) flip in any other run is 502
  positions away (run 10, pos 116): the flip type
  is otherwise absent from S76's second half.
- pos 619 (same run/flip): identical second
  neighbours, swap no; extension misses coverage
  by one (619 < 620); super-run internal no;
  nearest exact flip 503 away.

For contrast, over all 10 outside positions the
second-neighbour swap matches 5 — all among the six
already explained by first neighbours (449, 450,
557, 558, 615) — span extension by 2 matches 1
(pos 615, its prev-run explanation restated), and
super-run internality holds for 2 (449/450). None
of the three tests touches the residue.

Verdict: the four residue flips are NOT a wider
spillover zone at radius 2, in run space or in
position space. Pos 173/618/619 carry a (0,2)-class
flip that their whole neighbourhood lacks; pos 517's
flip recurs nearby only under non-producing pairs.
The residue stands: 4 of 763 positions, mechanism
NOT PROVEN.

## What this closes and what it queues

- MEASURED: region census at corpus scope — 531
  K2 hits / 375 localized over seven artifacts;
  localized hits split by scale into micro (373,
  repeated-family property) and segment (2).
- CORRECTED: AES-NUM-077's segment-substitution
  uniqueness — true in 0a0d + cc9, false corpus-
  wide; the segment class has exactly two members
  (0a0d 85→92, 0856a10c 85→91), both the same
  (9144,184)→(528,80) motif rewrite at a-len 85
  over a 56-action suffix, ng 0 → ng 1.
- MEASURED / REJECTED: single-replace absence as a
  corpus claim (299 hits in the remaining five);
  second-neighbour swap, span extension by 2, and
  gap-bridged super-run internality as explanations
  of the S76 residue (0/4 on every test).
- NEXT (4.79): the two segment exemplars compared
  whole-context (are the 0856 and 0a0d a-contexts /
  b-contexts themselves related? head 13 vs 12,
  suffix byte-identity); the 76c3a8ff len-89 camps
  (what besides position 18 separates the 21392 /
  21648 camps — channel at 18, camp cidx pattern);
  sister len-496 5→5 signature region contents.
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
