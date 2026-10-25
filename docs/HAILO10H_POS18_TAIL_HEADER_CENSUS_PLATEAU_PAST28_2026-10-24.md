# Position-18 tail per-context anatomy, the 16 B header census, the ng 1 plateau past 28 (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.83 (AES-NUM-083).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef83.py
(sha256 78f4e791…) + labelled follow-ups hef83b.py
(sha256 7dadd8a1…) and hef83c.py (sha256 acb4a922…),
all sha-verified on-device after one-shot proxy-receiver
transfers (the gz bytes never passed through tool
re-emission; the receivers returned the gz sha256s and
they matched: hef83.py.gz ef480fa4…, hef83b.py.gz
e0dbdebb…, hef83c.py.gz 3817b7e3…). Output files
/tmp/hef83_out.txt sha256 cbc8dde8…, /tmp/hef83b_out.txt
sha256 b3936205…, /tmp/hef83c_out.txt sha256 682277f9….
Controls reproduce AES-NUM-029/032…082 EXACTLY (128,787
pooled small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (camps, classes, cidx / ngpos) are
as in AES-NUM-061…082. Provenance note: hef83b printed
all of its tail-tier arms and the ng 1 variable-position
list, then stopped on an index bug — exemplar b's context
is only 91 actions long, so a 28..119 comparison window
overran it; the three numbers it owed are supplied by
hef83c over the corrected 28..90 window and are labelled
as such below. No analysis was re-run or altered.

## (i) The tail's 187 variable positions are a tiered, structured band — 180 in a dense head band, 7 sparse, and the camps drift apart only in the sparse tail

AES-NUM-082 left the position-18 tail (bytes 6,408–end
of the len-89 B-main segments, 76c3a8ff, 25 contexts) as
~98.8% camp-constant with ~187 per-context positions.
The variable set is now exact, and it is the SAME count
in both camps:

- Exactly 187 variable positions in camp 21392 (n 13)
  and exactly 187 in camp 21648 (n 12). 180 of each lie
  at tail-relative offsets ≤ 490; 7 lie beyond.
- Dense band (rel 0–490): offsets fall only at rel
  mod 4 ∈ {0, 1, 2} — 73 / 77 / 37 positions — and NEVER
  at rel mod 4 = 3: byte 3 of every aligned u32 word in
  the band is camp-constant. Every variable position's
  modal byte is nonzero, and all 187 variable positions
  of each camp sit inside a nonzero aligned u32 word of
  the camp's first segment. The per-context variable
  vector is distinct in every context (13/13, 12/12).
- Three distinct-value tiers. 72 positions are BINARY
  (exactly 2 distinct bytes): the same 72 offsets in
  both camps (rel ≡ 1 mod 4 in the band's head: 1, 5,
  9, 13, 29, 33, …), with value pair {0xa2, 0xa3} in
  camp 21392 and {0xa2, 0xb3} in camp 21648 at the head
  positions; across all 72 shared binary offsets, 36
  carry an identical value pair in both camps and 36
  carry different pairs. The remaining positions are
  near-full or full: camp 21392 has 36 positions with
  11 distinct bytes and 79 with all 13 distinct; camp
  21648 has 73 with 11 distinct and 42 with all 12
  distinct; the full-distinct offset sets intersect in
  37 positions.
- The pattern word is per-context, not per-camp. The
  tail's first four bytes are (x, 0xa2|0xa3, 0, 0) in
  camp 21392 — x distinct in all 13 contexts (22, 49,
  63, 72, 86, 101, 110, 123, 125, 130, 131, 160, 224);
  the second byte is 0xa2 in 11 contexts, 0xa3 in 2 —
  and (x, 0xa2|0xb3, 0, 0) in camp 21648, x distinct in
  all 12, second byte 0xa2 in 9, 0xb3 in 3. The second
  byte is rel 1, the first member of the binary tier.
  AES-NUM-082's "3f a2… / da b3…" opening words were the
  first contexts' samples of this per-context word, not
  camp constants.
- Cross-camp alignment: 181 of the 187 offsets are
  shared; 37 shared positions have disjoint value sets
  across camps (single-position camp separators), 144
  overlap. The 6 unshared offsets per camp are all in
  the sparse zone: shared sparse offset 2161, then
  camp-21392-only [4393, 6657, 14825, 14976, 14977,
  14978] against camp-21648-only [4457, 6785, 15081,
  15232, 15233, 15234] — pairwise differences +64,
  +128, +256, +256, +256, +256. The last three variable
  offsets sit 8/7/6 bytes before the tail's end in both
  camps. The sparse positions drift apart as the tail
  lengthens (mechanism NOT PROVEN); the dense band
  never drifts.

Verdict: the per-context content of the tail lives in a
fixed 187-slot frame — a dense, word-aligned head band
(byte 3 of each word invariable; a 72-slot binary tier
whose alternate byte is camp-flavoured, 0xa3 vs 0xb3)
plus 7 sparse slots whose camp-21648 copies sit at
growing offsets (+64/+128/+256) inside the longer tail.

## (ii) The 16 B header occurs at an action start exactly 27 times corpus-wide — the 25 known segments plus two generalised frames, both in 0856a10c

The header (4 B camp word + the fixed 12 B suffix
00 00 00 15 01 00 00 00 58 01 a0 00) was censused two
ways over all seven artifacts:

- At action starts: exactly 27 hits. The exact camp
  forms account for 25 — 13 × camp 21392 and 12 × camp
  21648, every one at (position 18, size 21392/21648)
  in 76c3a8ff, i.e. exactly the known population and
  nowhere else. The generalised form (bytes 1–2 =
  28 f0 and the 12 B suffix exact, bytes 0/3 free)
  occurs exactly twice, both in 0856a10c: cidx 255 at
  position 19, size 528, bytes (2, 3) — inside exemplar
  b's own context, one action after the shared head —
  and cidx 33 at position 21, size 32,656, bytes
  (3, 254).
- As a raw byte pattern: the fixed 12 B suffix occurs
  in only two artifacts. In 76c3a8ff, 51 occurrences:
  the 25 camp-word starts above plus 26 preceded by
  the sibling word 02 28 50 71 (bytes 1–2 = 28 50, so
  neither exact nor generalised — a raw-only relative,
  never at an action start). In 0856a10c, 5 occurrences:
  the 2 generalised starts plus 3 more whose preceding
  words carry other 28 xx seconds bytes (022830ff ×2,
  032870ff, 03284047). In MiniLM, 0a0d378c, 5ab3537d,
  773470cd and cc9b9d1c the suffix occurs ZERO times.

Verdict: the 16 B header is, at action granularity, a
position-18-only frame in one artifact; its generalised
form and its raw suffix family have a small, closed
footprint (2 starts + 3 raw in 0856a10c, 26 raw sibling
occurrences in 76c3a8ff) and no presence at all in the
other five artifacts.

## (iii) Past position 28 exemplar b leaves the ng 1 plateau for good — every later agreement is a shared zero

AES-NUM-082 showed the len-763 ng 1 step-6 train's
channels are group-constant to position 54 while b
(0856a10c cidx 255) shares the zero plateau 13–27. The
plateau's continuation is now measured (hef83c window
28..90, b's full length):

- The group's constant channels at 28–53 are
  [0,0,0,0,0, then (1,1,0,0) repeated]: 33–53 run the
  period-4 pattern 1,1,0,0 (last value 1 at 53). This
  is signal, not silence — the plateau past 28 is a
  patterned channel sequence.
- b agrees with the group at exactly 11 of the 26
  positions 28–53, and every agreement is at a position
  where the group constant is 0; where the group
  constant is 1, b NEVER equals it (0 positions,
  hef83c). b's own 28–53: 1,1,1 at 28–30 (where the
  group is 0), 2,2 at 34–35, zero elsewhere. b's
  channel prefix against the group-constant sequence
  is exactly 28 — the break is at the first patterned
  position.
- Past 54 the group itself starts to vary (first
  variable position 54: 15 × channel 0, 1 × channel 2;
  further variable positions at 65, 70, 72, 75–78, …,
  dense after 85). b, which ends at 91 actions, agrees
  with the group modal at 32 of 63 positions in 28..90;
  its nonzero channels there are the 28–30 ones, the
  34–35 pair, and a period-4 (1,2) pair repeated at
  72–73, 76–77, 80–81, 84–85, 88–89 — its own tail
  rhythm, not the group's (1,1,0,0).

Verdict: the exemplar and the train share a head (13
sizes), a silence (channels 13–27), and nothing past
28: at the first patterned channel position b diverges
and never rejoins — all 11 of its 28–53 agreements are
zero-coincidences at the group's zero slots.

## What this closes and what it queues

- MEASURED: the tail variable frame — exactly 187
  positions per camp, 180 in a dense band at rel ≤ 490
  (rel mod 4 ∈ {0,1,2} only, modal bytes all nonzero,
  per-context vectors all distinct), tiered as 72
  binary slots (identical offset set in both camps,
  camp-flavoured alternate byte 0xa3 vs 0xb3, 36/72
  value pairs shared) plus near-full/full slots; the
  opening word is per-context; 181 offsets shared
  cross-camp, 37 of them single-position camp
  separators; the 6+6 sparse offsets drift by
  +64/+128/+256×4.
- MEASURED: the 16 B header census — exact form only
  at the 25 known (position 18, len-89) starts;
  generalised form exactly twice, both in 0856a10c
  (cidx 255 pos 19 size 528; cidx 33 pos 21 size
  32,656); raw suffix footprint confined to 76c3a8ff
  (51, incl. 26 with the 02 28 50 71 sibling word) and
  0856a10c (5), zero in the other five artifacts.
- MEASURED: the ng 1 plateau past 28 — group-constant
  pattern (1,1,0,0) over 33–53; b's channel prefix vs
  the group is exactly 28; b agrees at 11/26 positions
  28–53, all at group-zero slots, never at a group-1
  slot; b agrees with the group modal at 32/63 over
  its whole remaining length (28..90) and carries its
  own (1,2) period-4 tail pairs at 72–89.
- NEXT (4.84): the binary tier's choice structure
  (is the a2-vs-alternate choice one bit per context
  across all 72 slots, or per-slot?); the 02 28 50 71
  sibling occurrences inside 76c3a8ff (which segments
  / offsets?); the sparse-slot drift landmarks (what
  sits at rel 2161 and at the +64/+128 steps?).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
