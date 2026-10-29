# The 6 distinct near-miss pair-pairs are two species (the four ladder-side pair-pairs carry B-minus-A (0, 0) on both pairs with B step = A step and SAME/SAME; the two (20, 32720) pair-pairs do neither), the (byte1, byte3) = (1, 128) population is exactly 6 pairs whose byte2 176/178 ladder is the unbroken, unextended chain 20–24–28–32, the 50 control comparisons decompose rigidly by verdict field (B byte 0 only 29 / status only 0 — measured zero, never assumed / both 18 / neither 3, each category carrying one fixed differing-field set), and run 74 holds five internal gaps, not three (gaps 3, 4, 5, 6, 7 at steps 24, 31, 33, 37, 48), with skipped-block contiguity a preceding-size chain in gaps 1, 2 and 4, vacuous in the four single-act gaps, and broken only in gap 8, whose 24-byte skipped acts sit at a 512 stride — mechanisms NOT PROVEN (AES-NUM-151)

Slice 4.151, worked under `docs/TASK_CONTRACT_4.151.md`
(contract published in the 4.150 closing commit @
1cbcfdf1). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef151.py (hef150.py verbatim as base plus the new
arms151) sha256
`13dfea5f606dcc5bf5bde9bdc48fef3b054c52df9ca340910f1c4c8f2cb218a8`
(742,165 B); arms151 sha256
`f477ef7afdf039ca7f952e9b9f17e448999da25dab053219a9cfa4fc7917bff8`
(15,604 B), its gzip sha256
`d152e5ec4c47faf07606d16ed57c53bc520b53cf760dfa3e841595cb3824a3ab`.
The base hef150.py was verified on-device ==
VM (sha256 51a5246c…) before assembly. Crossing
record, stated honestly: the gzipped arms crossed
in 13 sha-gated parts of 373 B; every part's sha256
verified on-device. Two parts failed in
re-emission — g_ag's first crossing was rejected
(base64 invalid, nothing committed) and a garbled
g_al send likewise failed its base64 check (the
bad file was removed on-device, never used); both
healed by re-splitting at 187 B boundaries, whose
halves verified sha-clean. The assembled gzip,
arms and hef151 sha256 all matched the VM exactly
on-device, and the script compiled on-device
(py_compile OK).

The ONE bounded host-side child was launched in a
detached tmux session on Mimir with the contract
corpus argv — the six hailo-ollama blobs in glob
order, then MiniLM — and finished with DONE151 as
its last line, exit marker 0, error channel empty.
Output hef151.out: 41,915 lines / 8,087,575 B,
sha256
`2986f519fcc0b2facb5a939542a391b4a9a7f8fd70c0cf7a3b2af24bbe688506`;
its first 41,723 lines are byte-identical to
hef150.out (cmp verified on-device). Section:
192 lines / 49,971 B, sha256
`f0dc30e36d041f960afa70c75c6f55e2c06cce3dcd62b34019112e8baf74f71a`
(gzip kept on the Pi), returned by one device
file.read and decoded on the VM to exactly the
on-device sha. Controls EXACT: every controls-echo
expectation from slices 4.119–4.150 reproduced,
including the 8 byte-0 near-miss listings from the
4.150 arms. Raw output kept on the Pi at
~/aesir-build/ (hef151.out, hef151.py, arms151.py,
section151.txt); local lineage in
~/workspace/.verify-tmp/aesir151.

## (i) The 6 distinct pair-pairs as one population

The 8 listings of AES-NUM-150 deduplicate to the
6 distinct pair-pairs (listings per distinct:
1→[1], 2→[2], 3→[3, 6], 4→[4, 7], 5→[5], 6→[8]):

| # | A (byte0, byte2) step | B step | groups | records | cell thirds (diff) | statuses | B−A |
|---|---|---|---|---|---|---|---|
| 1 | (20,176)→(28,176) +8 | +8 | (19,7712)/(14,9992) | 1/27 | 7568/1744 (−5824) | SAME/SAME | (0,0) |
| 2 | (20,176)→(32,176) +12 | +12 | (19,7712)/(14,9992) | 1/27 | 7568/6944 (−624) | SAME/SAME | (0,0) |
| 3 | (20,178)→(24,178) +4 | +4 | (14,9992)/(14,9992) | 27/27 | 4336/9832 (+5496) | SAME/SAME | (0,0) |
| 4 | (28,176)→(32,176) +4 | +4 | (14,9992)/(14,9992) | 27/27 | 1744/6944 (+5200) | SAME/SAME | (0,0) |
| 5 | (128,146)→(192,146) +64 | −32 | (20,32720)/(20,32720) | 1/1 | 7136/7000 (−136) | DIFF/DIFF | (32,−64) |
| 6 | (104,181)→(112,181) +8 | +56 | (20,32720)/(20,32720) | 1/1 | 7204/7272 (+68) | SAME/DIFF | (0,48) |

Population summary: A-step distribution
{4: 2, 8: 2, 12: 1, 64: 1}; B steps
[−32, 4, 4, 8, 12, 56]; B-minus-A pairs
{(0, 0): 4, (0, 48): 1, (32, −64): 1}; statuses
{(SAME, SAME): 4, (DIFF, DIFF): 1, (SAME, DIFF): 1};
record-count pairs {(1, 1), (1, 27), (27, 27)};
9 distinct individual pairs in 12 slots — the
byte2-176 ladder pairs form one connected chain of
shared members ((20,176,byte3 0) in distinct 1 and
2; (28,176,128) in 1 and 4; (32,176,128) in 2 and
4), while the byte2-178 pair-pair's two pairs, and
both (20, 32720) pair-pairs' pairs, appear nowhere
else in the population. The population is two
species: distinct 1–4 (the ladder side) all carry
B-minus-A (0, 0) on both pairs, B step = A step,
SAME/SAME; distinct 5–6 (group (20, 32720),
single-record) carry neither property.

### The (byte1, byte3) = (1, 128) population

Exactly 6 pairs of the full 224 share
(A byte1, A byte3) = (1, 128): A byte0 set
{20, 24, 28, 32, 68} (B byte0 set identical),
A byte2 set {160, 176, 177, 178}, all SAME with
B byte0 = A byte0. By byte2: 176 → byte0
{28, 32} (both group (14, 9992), 27 records);
178 → {20, 24} (both (14, 9992), 27 records);
177 → {20} (group (19, 7712), 1 record, cell
(19, 7712, 2384)); 160 → {68} (group (19, 7712),
1 record, cell (19, 7712, 2880)). Four of the six
(the 176/178 pairs) are the members of distinct
pair-pairs 3 and 4; the other two (byte2 177 at
byte0 20; byte2 160 at byte0 68) are members of
no distinct near-miss pair-pair.

### The ladder chain

Within the (1, 128) population the byte2-176
branch steps 28→32 (+4) and the byte2-178 branch
steps 20→24 (+4); combined, the A byte0 values
are [20, 24, 28, 32] with consecutive differences
[4, 4, 4] — the two branches are offset by one
rung (176 holds the top two rungs, 178 the bottom
two). Zero (1, 128) pairs at byte2 176/178 carry
A byte0 outside 20..32: the chain neither breaks
inside 20–32 nor extends beyond it in this
population. Widening byte3 (A byte1 = 1, byte2 in
(176, 178), any byte3) yields only 5 pairs —
(176, byte3 0) → {20}, (176, 128) → {28, 32},
(178, 128) → {20, 24} — so even outside the
(1, 128) population no further rung exists at
these byte2 values; the byte3-0 pair at
(176, byte0 20) is the shared first pair of
distinct pair-pairs 1 and 2.

## (ii) The 50 control comparisons by verdict-field pattern

The decomposition is exact and cross-checks
against AES-NUM-149 on every total:

- **B byte 0 only: 29** — B byte0 differs, status
  does not.
- **Status only: 0** — MEASURED ZERO: no control
  comparison differs on status without also
  differing on B byte 0. (Tested from the numbers,
  as the contract required; never assumed.)
- **Both: 18** — both verdict fields differ.
- **Neither: 3** — the AES-NUM-150 agreeing-profile
  comparisons (repeats 3 (1–2), 18 (1–2), 35 (2–4)).

Cross-checks: B-byte0-differing 29 + 18 = 47
(expect 47); status-differing 0 + 18 = 18
(expect 18); neither 3 (expect 3).

Each category carries ONE fixed differing-field
set over all its comparisons (derived from the
printed per-category frequencies): B-only always
exactly the 9 fields {A byte1, A byte2, A byte3,
B byte0, B byte1, B byte2, B byte3, diff,
record cell} (mean differing 9.0, 29/29); both
always exactly those 9 + status (10 fields,
mean 10.0, 18/18); neither always exactly the
agreeing 7 {A byte1, A byte2, A byte3, B byte1,
B byte2, B byte3, record cell} (mean 7.0, 3/3).
No field outside the two verdict fields ever
separates the categories.

Hosts (derived from the printed host table): the
14 both-class hosts [2, 5, 6, 8, 9, 10, 12, 13,
18, 21, 24, 26, 34, 35] ALL carry the status set
{DIFF, SAME} over their pairs; the 21 hosts that
carry B-only comparisons and no both comparison
ALL carry the single status set {DIFF}. The
neither-class hosts are exactly [3, 18, 35].
Only host 35 (4 pairs, 6 comparisons) carries
all three categories (1 B-only, 4 both,
1 neither); host 18 carries both + neither;
host 3 carries B-only + neither. Host pair counts
do not separate the classes (both-hosts are
2-pair in 12 of 14 cases, like the B-only-only
hosts). Read plainly: at comparison level the
category is exactly the verdict-field pattern;
at host level, a both comparison exists exactly
where the host's pairs mix SAME and DIFF statuses
— measured structure, mechanism NOT PROVEN.

## (iii) Run 74's internal gaps; contiguity over all 8 gaps

CORRECTION to the TODO shorthand: run 74's
internal gaps are FIVE, not three — gaps
3, 4, 5, 6, 7 at steps 24, 31, 33, 37, 48. (The
TODO parenthetical named steps 31, 33, 37 —
gaps 4, 5, 6, the subset studied since
AES-NUM-144.) The full sequence:

| gap | step | distances A/B | skipped A/B | mapping (set) |
|---|---|---|---|---|
| 3 | 24 | 2/2 | 1/1 (32784; ch A 2, B 0; offset 788357120) | ((2, 0),) |
| 4 | 31 | 5/5 | 4/4 (32784, 26128, 32784, 26128; ch A 0, B 1) | ((0, 1),) |
| 5 | 33 | 2/2 | 1/1 (32784; ch A 0, B 1) | ((0, 1),) |
| 6 | 37 | 2/2 | 1/1 (32784; ch A 0, B 1) | ((0, 1),) |
| 7 | 48 | 2/2 | 1/1 (26128; ch A 1, B 2; offset 789100544) | ((1, 2),) |

Step differences [7, 2, 4, 11]; total skipped
acts 8 on each side; A and B distances equal at
every gap. The mapping set is NOT identical
across the full sequence — it is ((0, 1),) only
over the 4/5/6 subset; gaps 3 and 7 carry
((2, 0),) and ((1, 2),).

Skipped-block contiguity (internal offset
advances against the preceding acts' sizes),
over all 8 gaps: multi-act blocks occur in gaps
1 (2 acts), 2 (5 acts), 4 (4 acts) and 8
(4 acts). Gaps 1, 2 and 4 are contiguous chains
on BOTH sides — every advance equals the
preceding size exactly (gap 1 advances [1552];
gap 2 [26128, 32784, 26128, 32784]; gap 4
[32784, 26128, 32784], A and B identical).
Gaps 3, 5, 6, 7 are single-act on both sides
(vacuous). Gap 8 is the ONLY non-contiguous
gap, on both sides: side A advances
[488, 512, 512] and side B advances
[512, 512, 512], against sizes [24, 24, 24, 24]
on both sides — its skipped acts are 24-byte
units at a 512 stride (B uniform; A's first
advance is 488, not 512), a different species
from the size-chained blocks. The two sides
agree on the contiguity verdict at all 8 gaps.
So gap 4's chain is not unique in kind: the
preceding-size chain holds in 3 of the 4
multi-act blocks, and gap 8 alone breaks it.
Mechanisms NOT PROVEN.

## Next

Slice 4.152 — gap 8's non-contiguous block read
in full against the contiguous blocks of gaps 1
and 2 (its 512-stride 24-byte skipped acts, the
A-side 488 first advance, bounding acts and
contexts); the two (1, 128)-population pairs
that sit in no near-miss pair-pair (byte2 177 at
byte0 20 and byte2 160 at byte0 68, both
single-record (19, 7712)) read against the four
member pairs — their full sub-key neighbourhoods
under both injective sub-keys; and run 74's
remaining two gaps (3 at step 24, mapping
((2, 0),); 7 at step 48, mapping ((1, 2),)) read
in full against gaps 4, 5 and 6 (feature tables),
completing run 74. Host/artifact analysis only.
