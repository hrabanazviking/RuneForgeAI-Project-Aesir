# NG scalar law unified, 113 kinship dissolved, extra tails compared (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.89 (AES-NUM-089).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef89.py
(sha256 26a4fb71...), landed via 14 individually
sha256-gated 373 B parts (assembled gz sha256 1ee67f30...
matching; script sha verified on-device; one earlier
single-shot receiver write failed its sha gate and was
discarded uncommitted). Output file /tmp/hef89_out.txt
sha256 8dd30e87.... Controls reproduce
AES-NUM-029/032...088 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (camps, classes, cidx / ngpos) are
as in AES-NUM-061...088. Contract:
docs/TASK_CONTRACT_4.89.md (published @ b5b5e8ab before
implementation).

## (i) The separator is network-group membership — and the two constants are ONE law

The AES-NUM-088 population scan was re-derived
identically (505 segment groups in the band, 372 with
variable ff offsets) and each variable group was
recorded with its contexts' network group (ng, the
proto field-2 grouping), cidx range, scalar range,
position, size, and instance count.

- Every one of the 372 variable groups is ng-pure, and
  ng membership separates the C classes EXACTLY:
  all 181 groups whose contexts lie in ng 0 have
  C = +1; all 191 groups whose contexts lie in ng 1
  carry their artifact's negative constant. No group
  mixes ngs, and no other feature separates the
  classes: position is mixed in 23 of 25 values, size
  in 24 of 209, instance count in 18 of 21, common-ff
  count in 53 of 84, variable-ff count in 15 of 19,
  and artifact in all 6.
- The negative constant is set by the ng boundary:
  in EVERY artifact, -C equals (first cidx of ng 1)
  minus 1 — 0856a10c: ng 1 starts at 100, C = -99;
  0a0d378c: 74, C = -73; 5ab3537d / 773470cd: 95,
  C = -94 (the sisters share the constant because
  they share the boundary); 76c3a8ff: 93, C = -92;
  cc9b9d1c: 134, C = -133.
- So both classes are one law. With ng_start the
  first cidx of a context's own network group:
  scalar = cidx - ng_start + 1 — the context's
  1-based position inside its own network group.
  For ng 0 (start 0) this reads cidx + 1; for ng 1
  it reads cidx + C with the negative constants
  above. The law holds in all 372 populations,
  zero exceptions (the AES-NUM-088 exception group,
  0a0d378c pos 25, obeys it at its first variable
  offset like every other group).

Verdict: MEASURED corpus-wide — the variable ff
scalar is the context's 1-based within-network-group
index. What the scalar MEANS to the device (why a
segment would carry its context's within-group
ordinal) remains NOT PROVEN.

## (ii) The 113 / 302 / 311 kinship dissolves — 302 and 311 are ordinary siblings, 113 is the outlier to everyone

Boundary-group anatomy (hef88's greedy consecutive-sum
matching from position 41) plus per-position
(size, channel) agreement and in-group content
comparison for the 76c3a8ff sibling train:

- 113 vs 302 (22 groups) and 113 vs 311 (16 groups):
  nearly all groups are trivial tail units — the
  giant first "group" is one unmatched bulk span
  (113 a41-348 vs 302 b41-346, sum 6,246,096 B;
  113 a41-372 vs 311 b41-369, sum 6,251,488 B),
  followed by one-action 24 B skeleton groups in the
  universal tail. Per-position agreements from 41:
  exactly 62 for both pairs, with identical third
  distribution (6 in positions 41-159, 0 in 160-279,
  56 in 280+) — the agreements are the shared tail,
  not kinship.
- Controls: 302 vs 311 agree at 298 positions,
  spread evenly (95 / 94 / 109), and each agrees
  with the consensus schedule at 296 positions —
  while 113 agrees with the consensus at exactly
  the same 62 positions it agrees with 302/311.
  302 vs 311 even produce MORE boundary groups
  (24) than either produces against 113.
- Content: in every matched group with equal action
  counts, byte-identical actions number ZERO
  (0/1 in the tail units, 0/11 in the one mid group,
  0/155 in 302 vs 311's long a44-198 group) —
  schedules can coincide in size while content
  differs at every action.

Verdict: MEASURED — there is no special 113/302/311
kinship. AES-NUM-088's group counts were an artefact
of total-byte closeness (cumulative sums meet in the
trivial tail). 302 and 311 are ordinary near-consensus
siblings; cidx 113 differs from ALL of them alike.
Why the train's first context is built differently
remains NOT PROVEN.

## (iii) The four extra tails: one 58-byte-shared family, constant per camp, and present in BOTH camps

The extra 64 B tails (camp 21648's inter-ff regions
before ff ranks 2/8/22/26, beyond camp 21392's region
lengths), extracted from the representative segments:

- Each tail is identical across all 12 camp-21648
  segments at its region (camp-constant, like the
  regions themselves), and occurs exactly once in
  the representative camp-21648 segment.
- Pairwise, the four tails agree on bytes 0-57
  (a 58-byte shared prefix — the AES-NUM-088 "same
  32 B opening" extends to 58 B) and every pair
  first differs at byte 58, inside the final word;
  the four tails' final words carry the byte values
  0x86 / 0x88 / 0x84 / 0x8a at the differing site
  (regions 2 / 8 / 22 / 26 respectively, per the
  printed hex). No tail equals the 64 B before it,
  after it, or its own region's first 64 B.
- Each tail ALSO occurs exactly once in camp
  21392's representative segment, earlier by exactly
  the accumulated staircase: region 2's tail at
  A 8980 vs B 9044 (-64), region 8's at A 11228 vs
  B 11356 (-128), region 22's at A 15444 vs B 15636
  (-192), region 26's at A 17140 vs B 17396 (-256).
  The "extra" content is therefore not new material
  in camp 21648: the same 64 B chunk is present in
  both camps, displaced by the staircase steps that
  precede it.

Verdict: MEASURED — the four tails are one
58-byte-shared, single-site-varying family, constant
across each camp, present once in both camps with
offsets differing by exactly 64 x step index.
Whether camp 21648 is camp 21392's stream with four
chunks duplicated or four chunks displaced (and what
the varying byte encodes) is NOT PROVEN — that is
the stream-alignment question for slice 4.90.

## Next (slice 4.90)

- Constant ff offsets and the 0a0d exception's second
  offset under the unified law: does every aligned ff
  word in the scanned populations carry either a
  constant or the within-ng index?
- Camp stream alignment: full rank-aligned byte-stream
  comparison of the two position-18 camps — duplicated
  vs displaced chunks, with the tail chunks' homes in
  camp 21392's region map.
- First-in-train test: is a train's first context
  distinguished in other artifacts / other trains the
  way cidx 113 is in its train?
Host/artifact analysis only — no physical child.
