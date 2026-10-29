# The (byte 3, byte 1 + byte 2) → difference table is not a monotone function of the sum in any byte 3 that carries enough keys to judge — of the 37 byte-3 values with two or more keys, 25 are NEITHER non-decreasing nor non-increasing in the sum, only 8 are non-decreasing, 2 non-increasing and 2 constant — and byte 0's own map is determined by nothing tested: B byte 0 is not a function of A byte 0 alone (23 of 36 A values violate), and it is not even a function of the full (byte 3, byte 1, byte 2) key or of the (byte 3, sum) key, failing on exactly the two narrow keys whose pairs differ only in byte 0; the near-geometric steps' wobble is everywhere nonzero — none of the 324 ratios equals its sequence median, the largest deviation is under 0.84 ppm — and every stated integer-rounding geometric form fails on every sequence (ROUND and FLOOR × first / median / last candidate ratio: 0 of 54 sequences hold for any of the six combinations); the displaced trio's wider windows show the block contexts' windows are the flanked core tail itself, while the split contexts scatter the trio through ordinary body material, the before-flank (2817536, 24, 0) occurs once in each of 271 contexts of cc9b9d1c (including all eight trio contexts) while the after-flank (1113626112, 24, 0) occurs exactly three times, only immediately after the displaced block; and the 41 shared 114×251 acts that are not occurrence-2 fall in six occurrence classes {3: 4, 4: 3, 6: 1, 271: 30, 1058: 1, 1060: 2}, sitting at position difference 0 in 37 cases, −1 in 3 and +4 in 1 (AES-NUM-127)

Slice 4.127, worked under `docs/TASK_CONTRACT_4.127.md`
(contract committed first @ d1631ef1). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef127.py (the hef126 file verbatim as base — itself the
hef125 lineage — plus the new arms127) sha256
`30f1a4efc764b16ba38aed7229d10b6165b059cd748520239e43cde4fb5ae45d`
(378,762 B); arms127.py sha256
`0f323751ad047614b9a23f3f9d5d47e552064160d8c8ba4da7e6589da585d207`
(14,090 B), its gzip sha256
`2702b1c0dd160c6f913269ecd93903395cd6315e4235f44e5df604f528ea347c`
(4,551 B). Provenance: a first single-shot file.write of
the whole gzip was rejected by its base64/sha gate
(re-emission corruption; nothing committed) and the
transfer was redone in the proven form — the gzip split
into 13 binary parts (12 × 373 B + 75 B), each landed on
Mimir as its own file via file.write with its own
whole-part sha256 gate, all 13 passing first try.
Concatenated on-device in order, the whole-gzip sha256
and the decompressed arms sha256 both matched the VM
exactly; hef127.py was assembled on-device from the
verified hef126 base (sha256
`9fe7ff67e96757bcb7a622a80cb0f8aa990a529f3dc0f07dcccdd5775ec9ffff`,
byte-identical on Mimir and the VM) plus arms127, and
its on-device sha256 matched the VM-built file exactly
before anything ran.

FIRST LAUNCH FAILED AT LAUNCH and is recorded honestly:
the script loads its corpus from `sys.argv[1:]`, and the
first detached launch carried no arguments, so every
structure stayed empty and the base died at
`min(camps.keys())` (stdout 222 B, sha256
`2cc7f3aab8d9e22f9633ebec95a8c172c71fab7e6a81c11c78fda982a6e9cece`;
stderr 221 B, sha256
`b92625d771b5ef21cc8d120e3c08a8771cf27b75450ad9afc88c3b94c518cf34`;
both retrieved byte-exact to the VM). The script was
NOT edited. It was relaunched once, detached via
setsid, with the contract's corpus argv — the six
hailo-ollama blobs in glob order, then MiniLM — and ran
to DONE127 with an empty error file. The retrieved
output is 16,636 lines / 2,813,195 B, sha256
`df0f74092ebf86197c2c23a0f021ec8ff77d2e9ea56860abb23221a1d9683fda`;
retrieved gz sha256
`4f1c031607587a8c4f4caeca16133ff3062f0595627a604e701562d80addbfe2`
(359,214 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); DONE127 is the output's last line (16,636);
the 4.127 section begins at output line 15,203 —
exactly one past 4.126's total line count, the base
having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts
CONT 12,411 / BREAK 476 / INDET 2,365; lane-1 pairs
224; (byte 3, byte 1, byte 2) keys 222; (byte 3, sum)
keys 222; trajectories 27 cidxs × (7 deltas / 6 ratios)
per side; shared 114×251 acts 168; occurrence-2
population 127; non-occurrence-2 shared acts 41. The
base's own first control lines also reproduce exactly
(small 128,787; bursts 79,001; pointer actions 745,849;
contexts 1,504; trailing pairs 2,049; champion bursts
75,215).

## (i)(a) The difference as a per-byte-3 function of the sum

The byte-3 difference is well-defined per key: 0 of the
222 (byte 3, byte 1, byte 2) keys carry more than one
difference across their pairs. Read per byte 3 (61
values), keys ordered by their sum (byte 1 + byte 2)
with differences and successive steps printed in full:

- 24 byte-3 values carry a single key (vacuous).
- Of the 37 values with ≥2 keys, the monotonicity
  classes are: NEITHER 25 (byte 3 = 184, 186, 187, 206,
  207, 209, 210, 222, 225, 226, 233, 235, 236, 237,
  240, 241, 242, 243, 246, 247, 248, 249, 250, 251,
  252 — derived at closing from the printed tables),
  NON-DECREASING 8 (174, 192, 219, 220, 224, 232, 238,
  245), NON-INCREASING 2 (182, 211), CONSTANT 2
  (byte 3 = 0: diffs [128, 128] over sums 163, 177;
  byte 3 = 128: diffs [−128 ×4] over its four narrow
  keys). The first NEITHER value is byte 3 = 184,
  whose difference sequence in sum order steps
  [0, +7, −7].
- Constant-step holds for 10 of the 37 multi-key
  values, but 8 of the 10 are two-key values whose
  single step is constant only vacuously, byte 3 = 0
  is a two-key constant, and the only ≥3-key case is
  byte 3 = 128, whose difference is constantly −128
  (steps [0, 0, 0]) — the narrow sign-flip column.
  No multi-step non-constant arithmetic step structure
  is proven anywhere.

Verdict: the difference is NOT a monotone function of
the sum, and no constant-step form holds beyond the
vacuous and constant cases. Per-byte-3 closed form
NOT PROVEN.

## (i)(b) Byte 0's own map over the 224 pairs

All 224 (A byte 0 → B byte 0) pairs printed in full.
A byte 0 takes 36 distinct values; B byte 0 takes 29.
Determination, tested exactly:

- B byte 0 as a function of A byte 0 alone: NOT A
  FUNCTION — 23 of the 36 A values violate (e.g.
  A byte 0 = 0 maps to B byte 0 ∈ {0, 64, 96, 128,
  144, 160, 176, 192}; A byte 0 = 192 maps to ten
  distinct B values).
- B byte 0 as a function of the (byte 3, byte 1,
  byte 2) key: NOT A FUNCTION — exactly 2 violating
  keys of 222, the narrow keys (128, 1, 176) →
  B byte 0 ∈ {28, 32} and (128, 1, 178) → {20, 24}:
  precisely the keys whose two pairs differ only in
  byte 0 (on those pairs B byte 0 == A byte 0).
- B byte 0 as a function of the (byte 3, sum) key:
  NOT A FUNCTION — the same two keys, as (128, 177)
  and (128, 179).

So byte 0 is a free coordinate of the pair exactly at
the narrow keys, and is determined by no tested key
anywhere else only because it never varies there —
its determination status is: carried by the pair,
explained by no smaller key. Byte-0 mechanism
NOT PROVEN.

## (ii) The near-geometric wobble, measured exactly

For each of the 54 cidx-side sequences the six exact
ratios' deviations from the sequence median (median =
mean of the 3rd and 4th sorted ratios, exact Fraction)
are printed in full as fractions and in ppm. Pooled:
324 deviations, ZERO of them zero — no ratio in any
sequence equals its own sequence's median. The largest
absolute deviation anywhere is the exact fraction
513764456848/809833956896348631 (≈ 6.3×10⁻⁷ in ratio
units); per-sequence maximum deviations span
≈ 0.154 ppm to ≈ 0.839 ppm of the median (derived at
closing). Sequence medians span ≈ 0.65564 to 0.78240
(derived at closing).

Integer-rounding geometric forms, stated in the
contract before testing (ROUND = round-half-up,
FLOOR; candidate r = first ratio / median ratio /
last ratio of the sequence; exact rational arithmetic;
delta(k) checked for k = 0..6): ALL SIX combinations
hold for 0 of 54 sequences.

- ROUND × first: 270 counterexample steps; first
  (cidx 2, A, k = 2, actual 183,151,296 vs predicted
  183,151,125).
- ROUND × median: 310 counterexamples; first
  (cidx 2, A, k = 1, 236,571,520 vs 236,571,586).
- ROUND × last: 323 counterexamples; first
  (cidx 2, A, k = 1, 236,571,520 vs 236,571,518).
- FLOOR × first: 269 counterexamples; first
  (cidx 2, A, k = 2, 183,151,296 vs 183,151,124).
- FLOOR × median: 308 counterexamples; first
  (cidx 2, A, k = 1, 236,571,520 vs 236,571,585).
- FLOOR × last: 323 counterexamples; first
  (cidx 2, A, k = 1, 236,571,520 vs 236,571,517).

The misses are small (the first counterexamples miss
by 1–171 in deltas of ~2×10⁸) but they are everywhere:
integer rounding of a single rational geometric does
not generate the deltas. Exact decay form NOT PROVEN;
the residue is a per-sequence ratio with sub-ppm,
never-zero wobble.

## (iii) Wider windows, flanking acts, and the 41 acts

All 24 displaced occurrences were read in ±8 windows
in full (7 windows left-clipped at the context head,
all in split contexts — derived at closing). The
three block contexts' windows (128 / 251 / 265) are
identical in structure: the window is the common
core's tail — the before-flank, the block D2, D3, D1
in that order, the after-flank, then private material.
The five split contexts' windows show the trio
scattered through ordinary body material: D1/D2 at or
near the head in 125, 130, 143, 261, 262, D3 alone
deep in the body (130@197, 143@87, 261@288) or paired
with D2 around a 328-act in 125 (D3@546, D2@548 around
(1062813696, 328, 0)) and 262 (D3@537, D2@539 around
(2174832128, 328, 0)) — the ±2 neighbourhoods are
printed in full in the raw output for every
occurrence, block and split alike.

Flanking acts, profiled corpus-wide in full:

- BEFORE (2817536, 24, 0): 271 corpus occurrences,
  all in cc9b9d1c, in 271 DISTINCT contexts — once
  per context (derived at closing). It stands inside
  all eight trio contexts (at 818 in 128/265, 821 in
  125/130/251/262, 585 in 143, 853 in 261), but only
  in the three block contexts is it followed by the
  displaced block; in 125 it is followed by
  (1068222464, 24, 0), in 130 by (1144840192, 24, 0),
  in 143 by (1225494528, 24, 0), in 261 by
  (1052250112, 24, 0), in 262 by (1068222464, 24, 0).
  It is the common core's final act (AES-NUM-125/126),
  present far beyond the trio's eight contexts.
- AFTER (1113626112, 24, 0): exactly 3 corpus
  occurrences, all in cc9b9d1c, all inside the trio
  contexts, each immediately after the displaced
  block's final act (128@822, 251@825, 265@822) and
  followed by a (24, 0) / (24, 1) pair of acts private
  to its context. It occurs NOWHERE else in the
  corpus: the after-flank is block-exclusive.

The 41 shared 114×251 acts that are not occurrence-2,
read in full grouped by corpus-occurrence-count
class: {3: 4 acts, 4: 3, 6: 1, 271: 30, 1058: 1,
1060: 2}. Their position differences (251 − 114) are
{0: 37, −1: 3, +4: 1} (derived at closing; consistent
with the AES-NUM-126 closing derivation). The 30 acts
of class 271 are the once-per-context population —
the same class as the before-flank — and the two
largest classes (1058, 1060) are near-universal acts;
the small classes (3, 4, 6) are the 251 closing
segment's shared run and its kin (e.g. the class-3
triple at 114/251 positions 830–832, whose third
occurrence is cidx 5 at 726–728).

Mechanisms NOT PROVEN.

## NEXT — slice 4.128

(i) The ratio sequences' internal order: per
cidx-side, the six ratios' monotonicity in k and
their deviation sign patterns in full, tested
exactly; pooled step-value census of the 25 NEITHER
byte-3 tables (successive-step multiset over all
multi-key tables; step as a function of the sum
tested exactly).
(ii) Byte 0 within groups: B byte 0's determination
by the full key computed separately inside each of
the map's three groups, and the narrow keys' eight
pairs read in their full cell/group context.
(iii) The before-flank across all 271 contexts: its
position distribution and the census of the act
that follows it in every context (how often the
displaced block, how often anything else, in full);
the 30 class-271 acts of the 41 read in full
(positions in 114 and 251; whether they form the
contexts' shared skeleton in order); the
after-flank's following (24, 0) / (24, 1) pairs
profiled corpus-wide. Host/artifact analysis only —
no physical child.
