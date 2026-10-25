# Camp middles are camp-constant and not a pure insertion, the step pairs do not recur outside the in-band group, and no tested feature separates distinguished train firsts (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.91 (AES-NUM-091).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef91.py
(sha256 88920cfdf3f50169511d75740b4db2808371616fe59678b98427ae687a1319fb...),
landed via one-shot proxy-receiver transfer (gz sha256
6eadb3dcc7e2e32a3a2ac6595616777b779a569fe4b165bb2e95ef30c58df8c7...
returned by the receiver, matching; script sha verified
on-device). Output file /tmp/hef91_out.txt sha256
c36e8df98844ed8ddf0883179578e384b0c0b087f17520d2c7d87cbb5b89e0fb....
Controls reproduce AES-NUM-029/032...090 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Definitions (camps,
regions, trains, D metric) are as in AES-NUM-086...090.
Contract: docs/TASK_CONTRACT_4.91.md (published @
c7a09970 before implementation).

## (i) Grown-region middles: camp-constant, insertion-shaped but not a pure insertion; the extra chunk is camp-B material repeated in all four grown regions

Position-18 camps of 76c3a8ff (camp 21392 = 13 segments,
cidx 130...328; camp 21648 = 12, cidx 121...337) were
aligned by camp consensus instead of single
representatives. The consensus step changes nothing in
the grown regions — and that is itself the first
finding: at every grown rank (2 / 8 / 22 / 26) the
region bytes are IDENTICAL in every segment of each
camp (region-variable positions 0 in both camps, in
prefix, middle and suffix windows alike; the camps'
187 whole-segment variable positions all live outside
the grown regions). The camp representatives of
AES-NUM-090 were already camp-exact here.

All four grown ranks give the SAME middle measurements
(A middle 168 B, B middle 232 B in every rank): the
two camps' middles share no common first byte and no
common last byte (left-common 0, right-common 0), and
the best single-insertion alignment of the B consensus
middle against the A consensus middle — removing one
64 B chunk at offset k and comparing the remaining
168 B — is:

- best k = 111 and 112 (tie), mismatches 21 of 168;
- k = 0 (chunk at the head): 58 mismatches;
- k = 168 (chunk at the tail): 32 mismatches.

No k gives an exact match, so camp B's middle is NOT
camp A's middle plus an inserted 64 B: the insertion
form explains 147 of 168 positions at the best offset
and fails at 21. No masking was needed (0 variable
positions in either middle, 0 masked pairs).

Home search for the best-k extra chunk (sha256
cf52c4fe... at k = 111; 3f04cb4b... at k = 112 — both
shifts occur, see below), exact occurrences:

- in camp 21392 segments: 0 (every segment, every
  offset);
- in camp 21648 segments: 48 — exactly 4 per segment
  in all 12 segments, at the same four segment offsets
  (8815 / 11127 / 15407 / 17167 for k = 111; +1 for
  k = 112), one inside each grown region;
- in the A consensus segment: none; in the B
  consensus segment: the same 4 offsets; as a 64 B
  window of the A consensus grown region: 0.

Both tie offsets producing occurring chunks means the
chunk's neighbourhood is shift-tolerant by one byte:
the 64 B windows at 111 and at 112 both repeat at all
four grown regions. The four grown regions of a camp
carry the same middle content (their middles produce
identical profiles and identical chunk hashes at every
rank in this analysis).

Verdict: MEASURED — camp 21648's extra middle material
is NOT duplicated from camp 21392 and NOT displaced
from it (zero occurrences there); it is camp-B-internal
material repeated identically in all four grown
regions of every B segment, embedded in a middle that
is insertion-shaped (147/168 at the best offset) but
not a pure insertion (21 mismatches, positions not yet
anatomised). What the 21 mismatches or the chunk MEAN
is NOT PROVEN.

## (ii) The ngidx==1 step pairs do not recur in the extension bands; the extended ff vocabulary is CONST/NGIDX only

The ff scan was extended beyond the AES-NUM-090 band
in both contracted directions, groups with >= 8 and
<= 600 instances and >= 3 common aligned ff offsets:

- Band X (position > 30, size 8,000–40,000 B): 60
  groups, 3,335 common ff offsets — CONST 2,802,
  NGIDX 533, OTHER 0. No step offset, no other
  exception, in any artifact (0856a10c 609/117,
  5ab3537d 466/90, 76c3a8ff 392/72, 773470cd 424/79,
  cc9b9d1c 910/175 CONST/NGIDX).
- Band Y (position <= 30, size 2,000–7,999 B or
  40,001–120,000 B): 27 groups, 354 common ff
  offsets — CONST 285, NGIDX 69, OTHER 0, in all six
  blobs.

In-band sanity: restricted to the original band with
>= 10 common offsets, the scan reproduces hef90
EXACTLY (374 groups; CONST 17,351, NGIDX 3,290,
OTHER 4), and all four OTHER offsets classify as
STEP under the contracted test (0a0d378c position 25
size 32,632: offsets 11820/11824 = 15 at ngidx 1 else
0; offsets 31512/31704 = 1 at ngidx 1 else 7).

Verdict: MEASURED — in 87 extension groups and 3,689
further common ff offsets, every aligned ff word is
CONST or the within-ng index; the two-valued
ngidx == 1 step form occurs ONLY in the single
0a0d378c in-band group found by AES-NUM-090. Groups
below the instance floor (< 8 instances) or the
common-offset floor (< 3) were not scanned — that
sparse remainder is slice 4.92's second arm. What
the step encodes remains NOT PROVEN.

## (iii) First-in-train mechanism: no tested feature separates the distinguished firsts; the property is pool-dependent, and cross-train comparison is almost empty by construction

All 52 trains were recomputed; controls reproduce
AES-NUM-090 EXACTLY (sibling D(cidx 113) = 249;
unique-first trains 28, unanimous 13, outlier-
elsewhere 11).

Per (artifact, ng) pool, the unique-first property is:

- ALL trains: 5ab3537d ng 0 (3/3), 76c3a8ff ng 1 (7/7);
- NO trains: 0856a10c ng 0 (0/4), 76c3a8ff ng 0 (0/3);
- SOME trains: the other eight pools (0856a10c ng 1
  2/5, 0a0d378c ng 0 3/4 and ng 1 4/6, 5ab3537d ng 1
  2/4, 773470cd ng 0 2/3 and ng 1 1/5, cc9b9d1c ng 0
  2/4 and ng 1 2/4).

So the SAME artifact carries opposite pool outcomes
in its two network groups (76c3a8ff: ng 0 none, ng 1
all; 0856a10c: ng 0 none, ng 1 some) — network-group
membership alone is not the mechanism either.

Separator tests over the 52 first members
(distinguished 28 vs undistinguished 24), each
reported distinguished / undistinguished:

- ngidx == 1: 4/28 vs 3/24 — no;
- ngidx <= train step: 15/28 vs 14/24 — no;
- first train of its (artifact, ng, n_actions) group:
  28/28 vs 23/24 — no (and near-vacuous: most such
  groups hold a single train);
- first train of its (artifact, ng) pool: 5/28 vs
  7/24 — no;
- step == 9: 7/28 vs 0/24 — the strongest single
  signal (every step-9 train, all in 76c3a8ff ng 1,
  has a distinguished first) but 21 distinguished
  firsts have steps 3–6, so it does not separate;
- n_actions even: 12/28 vs 16/24 — no;
- n_actions >= 400: 16/28 vs 15/24 — no.

Cross-train first agreement (iii-d) is measurable in
exactly ONE (artifact, ng, n_actions) group in the
whole corpus — 0856a10c ng 0 / 280 actions, whose two
trains' firsts (cidx 0 and 42, both undistinguished)
agree at 82 of 280 positions. Every other train is
the sole train of its group, so firsts of different
trains almost never share an action count to compare
against. That emptiness is a property of the corpus's
train structure, recorded, not a gap in the test.

Verdict: MEASURED — none of the seven tested features
separates distinguished from undistinguished firsts,
and the property varies by pool inside one artifact.
WHY a train's first context is so often the outlier
remains NOT PROVEN; the next arm (slice 4.92) attacks
it from the content side — the anatomy of the D
positions themselves (which positions and channel
flips distinguish a first, head vs tail).

## Next (slice 4.92)

- Middle-mismatch anatomy: the 21 mismatching
  positions at the best insertion offset (clustered
  or scattered? constant byte pairs?), and the chunk
  neighbourhood's 1-byte shift tolerance (period /
  self-overlap of the B middle around k = 111).
- Sparse-group ff scan: groups below the floors used
  so far (< 8 instances, or < 3 common ff offsets)
  for step / OTHER forms, completing the ff census.
- D-position anatomy of distinguished firsts: at the
  positions where a distinguished first differs, what
  (size, channel) pairs it carries vs the consensus,
  and where those positions sit in the action list.
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts within the stated bands and floors; blob
identities are sha prefixes only. Every count,
occurrence, alignment and pool tally above is
MEASURED as stated; every meaning — what the extra
middle material is, what the step encodes, why first
contexts are outliers — is NOT PROVEN and nothing
here invents one.
