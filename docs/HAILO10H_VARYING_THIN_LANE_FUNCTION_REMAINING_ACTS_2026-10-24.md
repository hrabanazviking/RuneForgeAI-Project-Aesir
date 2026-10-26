# What distinguishes the varying thin triples, the A→B differing-lane relation, and train 48 rank 2's remaining head acts: the 62 varying length-1 triples are NOT set apart by group, gap shape, type pattern or extras count — they are set apart by their common centre itself (the varying triples' common centres {32, 40, 43, 51, 85, 122} and the constant triples' {0, 1, 2, 5, 15, 23, 34, 69, 127} are DISJOINT, counted exactly over 62/253) and by extras that never repeat the centre (0/373 equal; in the 253, 1,254/1,254 equal); the 9 varying AP triples are identical to each other in every measured field except group offset (same (71, 19392) group, same common pair (38, 44) at step 6, same gaps (7, 1, 4), same 12-extra sequence verbatim); over the 2,584 differing lanes B is NOT a function of A pooled (52 of 934 distinct A values carry counterexamples) nor in lanes 0, 3 or 4 — but lane 1 IS a strict bijection (224 distinct A values ↔ 224 distinct B values over 354 lanes, zero counterexamples in either direction), and the 535 in-37 differing lanes are likewise a strict bijection (36 ↔ 36 ↔ 36); and the head's remaining acts are near-lonely: position 0's act occurs 7 times, all in cc9b9d1c (heading five contexts), positions 5 and 6 occur exactly twice each — in cidx 144 and together, order-swapped, in cidx 267 — while cidx 144's act-wise uniqueness ends exactly at its start boundary (position 8) yet its sequence stays corpus-unique through at least the first 40 acts (AES-NUM-120)

Slice 4.120, worked under `docs/TASK_CONTRACT_4.120.md`
(contract committed first @ 491fc44a). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind.

## Run and closing record

hef120.py (hef119 lineage: the inherited base extraction
plus the 4.120 arms) sha256
`8bb8ad4bbf10e854229e3529e6405701d5bfadb8836f6af1d72388638b061b84`;
its gzip sha256
`aa92bf9484b0e90435a91af89a137b59883296ab9090706d8008e82ce6745429`.
The receiver /tmp/recv120.py (sha256
`6c881f71fb2eaf683b9b0bafcf7691a251457e18a9357f48c95110a501475524`)
was landed on Mimir by sha-gated chunked file.write; the
script gzip was then POSTed from the VM through the tunnel
proxy to the one-shot receiver — the POST's response was
lost through the proxy, but the save was verified on-device
by sha256 (gzip and decompressed script both matching the
VM exactly) before anything ran. The analysis was launched
detached on Mimir and polled to DONE120 (output line
11,512). The retrieved output is 11,512 lines / 1,554,743 B,
sha256
`e68b18781ee38315434e545a0bc91bc325eec90dcf6178fec172a96930203ca3`;
the retrieved gzip sha256
`6c5e050f5e0e35e7ac9aca9708186ae28440e5766eb1fd2c0ed588b2275916cd`
decompresses to exactly that sha256 (verified on the VM at
closing).

## Controls

All inherited controls reproduce exactly. Shared
enumeration: groups ≥2 54,995; groups ≥1 common 1,323;
cells 55,902; observations 527,236; distinct ladder 11,242;
unanimous 39,673; AP 2,584 with the same step histogram;
non-AP 4,148 (317/298/174); ≥8 cells 25,566, unanimous
18,286, 29 centres, centre-1 561; target cell once
ff010000. Divergent triples rebuild exact: A cells 6,970,
B cells 7,485, shared cidx-keyed 2,981, triples in both
5,152, divergent 2,171 (both-differ 1,997 / A-only 92 /
B-only 82), common instances 15,488 with centres agreeing
15,488/15,488, extras 15,252 (A 7,164 / B 8,088), verdicts
CONT 12,411 / BREAK 476 / INDET 2,365, structure splits and
triple grades (1,679 / 72 / 420) all exact. The 37 and the
96 rebuild exact: centres 2,981/2,981, words 2,885/2,981,
37 / reverse 0, 96 cells, 1,971 differing instances (535 in
the 37), centre lane 0/1,971, distinct B words 1,350. The
cc9b9d1c fit rebuilds exact: union 929, target refs 813,
contexts 271, start distribution exact, 217 in-train rows,
the same 10 exception identities, trains 48/50 CONST_DOM 7.
Thin population 383 (315 L1 UNANIMOUS / 58 L2 UNANIMOUS /
10 L2 AP), thin extras 2,435 (A 967 / B 1,468); differing
lanes 2,584 by lane {0: 1,086, 1: 354, 2: 0, 3: 406,
4: 738}; train 48 rank 2 = cidx 144, start 8, steady 7,
with the recorded 8-act head.

## (i) The varying thin triples against their continuing twins

**Length 1 (315 UNANIMOUS): the split is exact** — 62
varying (extras not constant) / 253 constant, as inherited.

What does NOT distinguish the 62: their groups, gap shapes
and type patterns are the continuing twins' own. The
(pos, size) group sets are IDENTICAL (the same 8 groups:
(11, 26144), (15, 26064), (17, 5904), (17, 32720),
(18, 6816), (21, 8264), (25, 29528), (25, 31160)); the
gap-shape sets are IDENTICAL (all six shapes (0,2), (0,3),
(2,0), (3,6), (4,5), (6,5) in both populations); the six
type patterns are the same six; the per-triple extras
counts share their support {2, 3, 9, 11} (62: {2: 21,
3: 10, 9: 20, 11: 11}; 253: {2: 125, 3: 33, 9: 70,
11: 25}); and both populations draw their common instance
from the same six distinct first-common cidx values in
31..216.

What DOES distinguish them, counted exactly: **the common
centre value itself.** The 62 varying triples' common
centres are {32: 11, 40: 11, 43: 11, 51: 9, 85: 10,
122: 10} — six values. The 253 constant triples' common
centres are {0: 3, 1: 3, 2: 12, 5: 30, 15: 153, 23: 14,
34: 2, 69: 4, 127: 32} — nine values. **The two sets are
DISJOINT (intersection empty).** No varying triple shares
its common centre with any constant triple, and vice
versa. Second, the extras' behaviour at the centre: in
the 62, NO extra equals the common centre (0/373; 157
below, 216 above — exactly the length-1 below/above totals
of AES-NUM-119, so every off-centre length-1 extra in the
corpus sits in a varying triple), while in the 253 every
extra equals it (1,254/1,254). Inside the 62, variation is
total: per-triple distinct extra centres equal the
per-triple extras count in all 62 (every extra carries a
distinct centre, distinct word, and distinct centre-word;
union 29 distinct extra centres, 328 distinct extra words
over 373 extras; all-extras-one-word 0/62, against 241/253
in the constant population, whose 12 remaining triples
carry 2 distinct words at the one centre). Per-triple
extra-centre ranges in the 62: {3: 10, 4: 11, 29: 10,
33: 11, 68: 11, 88: 9}. The inherited verdicts follow the
split by construction for UNANIMOUS commons (373 BREAK in
the 62; 1,254 CONT in the 253) and are recorded as such,
not as an independent finding.

**Length 2 AP (10): the nine varying triples are clones
of each other.** All nine share the group (71, 19392)
(nine distinct offsets 96..19232), the same common pair
(38, 44) at common step 6, the same gaps (7, 1, 4), the
same type pattern XXXXXXXCXCXXXX — the length-2 unanimous
template — and the SAME 12-extra sequence verbatim in
every one: (14, 20, 23, 26, 29, 32, 35, 41, 50, 53, 56,
80). Extras total 108 (A 27 / B 81), 12 distinct centres
per triple, range 66 per triple, no extra equal to either
common centre (63 below the first common centre 38, 45
above it); verdicts BREAK 99 / CONT 9 over the nine. The
one constant AP triple is a different animal entirely:
group (15, 32608), common pair (0, 38) at step 38, gaps
(0, 2, 2), pattern CXXCXX, extras constant (0, 0, 0, 0).
Against their positional twins, the 58 length-2 UNANIMOUS
triples (same gaps, same pattern), the AP nine differ only
in what their extras carry: there 696/696 extras equal a
common centre; here 0/108 do.

**Grade.** Measured, on the complete populations: a
varying thin triple is distinguished from its continuing
twins by its common centre value (disjoint centre sets at
length 1; a single shared group/pair/step/sequence at
length 2 AP) and by extras that never repeat the centre —
not by group, gap shape, type pattern or extras count.
Why those centres, and why the varying triples vary: NOT
PROVEN; no cause invented.

## (ii) The A→B differing-lane relation over the 2,584 differing lanes

Population: 2,584 differing lanes (lane 0: 1,086; lane 1:
354; lane 3: 406; lane 4: 738), 934 distinct A values, 931
distinct B values, 1,033 distinct (A, B) pairs pooled.

**Pooled, B is NOT a function of A.** 52 of 934 distinct A
values map to more than one distinct B value (278 lanes
involved in counterexamples; max 6 distinct B per A), and
the reverse also fails: 48 of 931 distinct B values map to
more than one A (546 lanes; max 7 A per B). No pooled
function claim is made.

**Per lane, exactly one lane is a strict bijection.**
Lane 1: 354 lanes, 224 distinct A values ↔ 224 distinct B
values ↔ 224 distinct (A, B) pairs, ZERO counterexamples
in either direction (max B-per-A 1, max A-per-B 1) — over
its full population, B is a function of A and A is a
function of B in the strict sense. Lane 0 fails (26/244 A
values with counterexamples, 88 lanes; reverse 27/242, 199
lanes; max B-per-A 4). Lane 3 fails (23/249, 81 lanes;
reverse 18/252, 72 lanes). Lane 4 fails (24/309, 74 lanes;
reverse 23/300, 137 lanes; max B-per-A 5).

**Inside the 37 the relation is a strict bijection too.**
The 535 in-37 differing lanes carry only 36 distinct A
values, 36 distinct B values and 36 distinct (A, B) pairs,
with ZERO counterexamples in either direction; their
arithmetic differences take only 10 distinct values and
their XOR patterns only 9 distinct patterns (top:
XOR 00000080 in 418/535, byte-3 ±128 flips in 221 + 197).
Every pooled counterexample lives in the non-37 lanes
(52/898 A values there).

**The measured distribution (pooled).** Arithmetic
differences B−A (little-endian u32): 826 distinct, never 0
(the lanes differ by definition); positive 1,526 /
negative 1,058; the dominant difference is +131,072
(2^17) in 756 lanes (378 in lane 0 and 378 in lane 4 —
byte 2 differs by +2 in 757 lanes), followed by the byte-3
sign flips −2^31 in 331 and +2^31 in 225. XOR patterns:
834 distinct pooled; the top three are near-single-byte
patterns (00000080: 556; 00000600: 486; 00000200: 270).
Bytes differing per lane value: {1: 1,648, 2: 484, 3: 135,
4: 317} — most differing lanes differ in exactly one of
their four bytes. Per-lane class shapes differ sharply:
lane 1's equality classes are {1: 219, 27: 5} on both
sides (its pairs repeat only in blocks of 27, inside the
37's families), while lanes 0/3/4 carry long class tails
(up to 189).

**Grade.** A function claim is made ONLY where the
contract's test passes with zero counterexamples over the
full population named: lane 1 (354 lanes) and the in-37
subset (535 lanes), in both directions. Everything else is
a measured distribution. What produces the differences —
including lane 1's bijectivity — remains NOT PROVEN.

## (iii) Train 48 rank 2's remaining head acts + cidx 144's context

The three non-unique head acts, corpus-wide (all seven
artifacts):

**Position 0, (961269248, 24, 2): 7 occurrences, all in
cc9b9d1c, in no other artifact.** It heads five contexts —
cidx 119, 144 (its own), 158, 178, 242, at position 0 —
and occurs twice more at position 604, in cidx 143 and
183.

**Position 5, (1225501184, 24, 2): exactly 2 occurrences**
— cidx 144 at position 5, and cidx 267 at position 199.
**Position 6, (1225501696, 24, 0): exactly 2 occurrences**
— cidx 144 at position 6, and cidx 267 at position 197.
Neither heads any context anywhere. The two recur TOGETHER
in cidx 267, order-swapped and near-adjacent (the
position-6 act at 197, the position-5 act at 199, one act
between them). Co-occurrence over the corpus: only two
contexts contain ≥2 of the three remaining acts — cidx 144
(all three) and cidx 267 (positions 5+6 acts); pairwise
context counts (0,5): 1, (0,6): 1, (5,6): 2; and only
cidx 144 contains any remaining act together with any of
the five corpus-unique acts.

**cidx 144's whole context against its train neighbours.**
The context is 245 acts, all 245 distinct, start 8. Train
48 has 28 rows, every one 245 acts long; act-multiset
overlap with cidx 144 is 49–50 for the steady-start rows,
and lower for the other +1-start rows (cidx 140: 38;
cidx 180: 40; cidx 184: 49). Shared prefix is 0 against
every train-48 row — no neighbour shares even the first
act. The longest common contiguous run was computed
against cidx 136: a 15-act run at position 206 in both
cidx 144 and cidx 136; the same 15-act run at cidx 144
position 206 is also the longest run shared with train
47's cidx 57 (at its position 699) and train 49's cidx 193
(at its position 217), the middle rows of the adjacent
trains. (Longest-run was computed for those named rows
only; for the remaining train rows the multiset overlap
above is the measured comparison.) Adjacent trains as the
cc9 fit defines them: train 47 (CONST 7) has 28 contexts
of 738 acts, each with multiset overlap 33 against cidx
144; train 49 (CONST 9) has 27 contexts of 256 acts, with
overlap 33–34.

**Where the head's uniqueness ends inside the context —
two different answers, both measured.** Act-wise, it ends
exactly at the head's edge: the corpus-occurrence counts
of cidx 144's first 40 acts are [7, 1, 1, 1, 1, 2, 2, 1]
across the 8 head positions, then positions 8, 9, 10 jump
to 1,060 / 1,060 / 1,058 — corpus-common material begins
precisely at the start boundary (position 8), with one
further semi-common act at position 27 (25 occurrences)
and the rest at 1–2 in the first 40. Sequence-wise, it
does not end there: the length-1 prefix occurs 7 times
corpus-wide (the position-0 act's contexts), but EVERY
prefix of length 2 through 40 occurs exactly once
corpus-wide — the counting ran to length 40 and the prefix
was still unique when it stopped. Any shift or mechanism:
NOT PROVEN; none invented.

## Next

Slice 4.121 — (i) the disjoint common-centre sets: are the
varying triples' centres {32, 40, 43, 51, 85, 122} special
corpus-wide (their thick triples, their ≥8 cells, their
cells in other artifacts) against the constant triples'
{0, 1, 2, 5, 15, 23, 34, 69, 127}?; (ii) lane 1's bijection
tabulated pair by pair: is the 224-pair map affine, a
constant XOR, or neither — and the in-37 bijection split
per lane (does it hold lane by lane inside the 37, or only
pooled over its lanes)?; (iii) cidx 267 profiled against
cidx 144 (length, multiset overlap, the window around
positions 197–199 where the position-5/6 acts recur
swapped), and cidx 144's prefix uniqueness followed past
length 40 to the first repeated prefix, wherever it ends.
Host/artifact analysis only — no physical child.
