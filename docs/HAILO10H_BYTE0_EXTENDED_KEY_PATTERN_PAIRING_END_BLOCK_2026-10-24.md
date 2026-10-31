# Byte 0 IS determined by the full A word — with A byte 0 admitted, the extended key (byte 3, byte 1, byte 2, A byte 0) is an exact function over all 224 lane-1 pairs globally and inside each of the map's three groups (224 extended keys, 0 violating keys) — while byte-0 identity is a narrow-only behaviour: beyond the 8 narrow pairs, B byte 0 equals A byte 0 in only 36 of 216 pairs (all in group (20, 32720); 180 differ, differences spanning −240…+240), so over all 224 pairs identity holds in 44 and fails in 180; the deviation sign patterns of a cidx's two sides are almost never related — over the 27 cidx pairs, EQUAL holds for 3 (cidxs 5, 38, 65), COMPLEMENT for 0, REVERSE for 1 (cidx 80), COMPLEMENT-OF-REVERSE for 2 (cidxs 5, 38, overlapping EQUAL), and 23 pairs satisfy NONE of the four relations; the pooled step is NOT a function of (starting sum, starting diff) (161 steps, 156 distinct keys, exactly 5 violating keys) and is a function of (starting sum, byte 3) only vacuously (161 distinct keys for 161 steps — no key repeats, so no collision could arise); and the class-271 end block is rigid in full: all 28 rigid acts hold a CONSTANT position-from-end in every one of their 271 contexts (54, 53, 52, 51, 50, 47, 46, 45, 44, 43, 42, 41, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 20 in block order), every one of the 27 successive spacings is constant across all 271 contexts (difference 1 for 24 pairs, 3 for two pairs, 4 for the last pair into the before-flank), while the two loose lead acts are not end-anchored (L0 (2727936, 24, 2): 13 distinct from-end values 55–87; L1 (2774016, 24, 1): 12 distinct values 55–68), always precede the block's first rigid act in all 271 contexts (distance at least 1, L0 distances 1–33, L1 distances 1–14), and stand in order L1-before-L0 in 170 contexts against L0-before-L1 in 101 — mechanisms NOT PROVEN (AES-NUM-129)

Slice 4.129, worked under `docs/TASK_CONTRACT_4.129.md`
(contract committed first @ fc88e74e). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef129.py (the hef128 file verbatim as base — itself the
hef127 lineage — plus the new arms129) sha256
`2ce607d7167c96ccbd0749fcc6316a194dffcb2d3581fdd66ae9d3f53b43bb53`
(411,862 B); arms129.py sha256
`0ecb8ca0c05a49fcbaad81e0d7ebf30aa0876237922d47e53be9c5c90ced0139`
(16,243 B), its gzip sha256
`0d5df8b5be6813eabaed565a99671c13759f9a3330a5103250b3c87a8576415d`
(4,905 B). The build, transfer and launch were carried out
by the earlier 4.129 continuity workers (state file entry
03:15 EDT resume; arms129 crossed in sha-gated 373 B gz
parts, assembled on-device, whole-file sha verified
on-device == VM by this closing worker). The one bounded
host-side child was launched with the contract corpus
argv (the six hailo-ollama blobs in glob order, then
MiniLM — the launch law recorded in the contract after
4.127's no-argv failure) and finished on-device with an
empty error file; DONE129 is the output's last line.
The retrieved output is 18,163 lines / 3,239,292 B,
sha256
`1fb1d210d1abad23c9d2e95837b1670578bfc0d338ae0b7842aea35d720fed9c`;
retrieved gz sha256
`c11b5f35f44dcd538383d72e5dca67a8d5ca5bfd0363c85384257514da88bfa6`
(415,780 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.129 section begins at output line
17,369 — exactly one past 4.128's total line count, the
base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: small 128,787 /
burst 79,001 / pointer 745,849 / contexts 1,504 /
trail pairs 2,049 / champion 75,215 (first output line);
cells 55,902 / obs 527,236; divergent triples 2,171,
verdicts CONT 12,411 / BREAK 476 / INDET 2,365; lane-1
pairs 224; (byte 3, byte 1, byte 2) keys 222; (byte 3,
sum) keys 222; trajectories 27 cidxs × (7 deltas /
6 ratios) per side; byte-3 tables 61, multi-key values
37; shared 114×251 acts 168; occurrence-2 population
127; class-271 acts 30; deviation sign patterns over
54 sequences: 15 distinct, modal +-+-+- ×10, -+-+-+
×7, -+-++- ×6; pooled steps 161 in 32 distinct values.

## (i)(a) Byte 0 with A byte 0 admitted to the key

The extended key is (byte 3, byte 1, byte 2, A byte 0)
— the full A word, byte by byte. Determination was
tested over the distinct lane-1 pairs, globally and
inside each group, in full:

- GLOBAL: 224 pairs, **224 extended keys, 0 violating
  keys — IS A FUNCTION.**
- Group (14, 9992): 5 pairs, 5 extended keys, 0
  violating — IS A FUNCTION.
- Group (19, 7712): 3 pairs, 3 extended keys, 0
  violating — IS A FUNCTION.
- Group (20, 32720): 216 pairs, 216 extended keys, 0
  violating — IS A FUNCTION.

Honest grading: the extended key never repeats on this
population (224 keys for 224 pairs), so the test's
positive result is exactly the statement that no two
pairs share a full A word while differing in B byte 0 —
in particular the two narrow collisions of AES-NUM-128
are separated by their differing A byte 0s, as their
pairs copy byte 0. No pair of distinct pairs tests the
key twice. Determination by the full A word is
ESTABLISHED on this population in that exact sense;
any mechanism NOT PROVEN.

## (i)(b) Byte 0 identity beyond the narrow population

- Narrow population: B byte 0 == A byte 0 in **8 of 8**
  pairs (unchanged from AES-NUM-128).
- Non-narrow population (216 pairs, all in group
  (20, 32720)): B byte 0 == A byte 0 in **36 pairs**;
  B byte 0 != A byte 0 in **180 pairs**, each printed
  in full (A/B words, byte-0 values, difference, key,
  group, occurrences — every one with 1 occurrence).
- Over ALL 224 pairs: identity in 44, difference in
  180.
- The 180 differences (derived at closing from the
  printed pairs) span −240…+240 in 40 distinct values;
  the modal values are −128 ×18, −64 ×18, +128 ×16,
  +64 ×15, −32 ×10, +48 ×9, +96 ×8, −96 ×6, −192 ×6,
  −160 ×6, +32 ×6, +192 ×5. A byte 0 in the differing
  pairs spans 32 distinct values (0 ×21, 128 ×28,
  192 ×23, 64 ×18, 96 ×15, 224 ×9, …).

Verdict: the copy behaviour of AES-NUM-128 is confined
to the narrow population. In the great group, byte 0
is rewritten in five pairs out of six. What the
rewriting is a function of beyond the full A word of
(i)(a) is NOT PROVEN.

## (ii)(a) Deviation sign patterns paired across sides

Each cidx's A and B deviation sign patterns (signs of
the six ratios against their own sequence median, in
k order, as in AES-NUM-128) were printed side by side
with complement(A), reverse(A) and
complement-of-reverse(A), and the four relations
tested exactly. Relation census over the 27 pairs
(independent counts; a pair may satisfy more than
one relation):

- EQUAL: **3** — cidxs 5, 38, 65.
- COMPLEMENT: **0** — no cidx.
- REVERSE: **1** — cidx 80.
- COMPLEMENT-OF-REVERSE: **2** — cidxs 5, 38 (both
  also EQUAL: their A pattern is the fully alternating
  `+-+-+-`, whose complement-of-reverse is itself).
- NONE: **23** — cidxs 2, 8, 11, 14, 17, 20, 23, 26,
  29, 32, 35, 41, 44, 47, 50, 53, 56, 59, 62, 68, 71,
  74, 77.
- Pairs satisfying at least one relation: 4 (5, 38,
  65, 80).

Verdict: the two sides of a context do not, in
general, carry the same, flipped, or reversed sign
pattern; the three EQUAL cases and the single REVERSE
case stand against 23 unrelated pairs. Any pairing
mechanism NOT PROVEN.

## (ii)(b) The step against (sum, diff) and (sum, byte 3)

The 161 pooled steps of AES-NUM-128, each anchored at
its starting key, tested exactly in full:

- As a function of (starting sum, starting diff):
  **NOT A FUNCTION** — 156 distinct keys, exactly
  **5 violating keys**, each printed with both of its
  records: (126, −2) → {−6, −3} (byte-3 tables 209 /
  186); (136, −1) → {−10, 0} (207 / 187); (192, −2)
  → {1, 16} (252 / 226); (264, −4) → {1, 3} (251 /
  243); (291, −6) → {5, 6} (250 / 246). Admitting the
  starting level alongside the sum does not determine
  the step.
- As a function of (starting sum, byte 3): IS A
  FUNCTION — 0 violating keys, but **161 distinct
  keys for 161 steps**: no (sum, byte 3) anchor
  repeats, so the verdict is vacuous in exactly the
  sense recorded for the per-byte-3 verdict in
  AES-NUM-128 — it proves nothing beyond the sums'
  distinctness inside their tables.

Verdict: the step is determined by neither the sum
alone (AES-NUM-128), nor the sum with the starting
difference; the (sum, byte 3) form is untestable on
this population because its keys never collide.
Step closed form NOT PROVEN.

## (iii)(a) The 30 class-271 acts, from-end in every context

Each act's position-from-end was computed in every one
of its 271 contexts (all in artifact cc9b9d1c), in full:

- **28 acts are constant**: exactly the rigid block
  of AES-NUM-128 (acts 2–29 in the shared order),
  each at one from-end value in all 271 contexts —
  in block order: 54, 53, 52, 51, 50, 47, 46, 45, 44,
  43, 42, 41, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29,
  28, 27, 26, 25, 24, and the before-flank
  (2817536, 24, 0) itself at 20.
- The two loose lead acts are **not constant**:
  L0 (2727936, 24, 2) takes 13 distinct from-end
  values {55 ×85, 56 ×72, 57 ×43, 58 ×23, 59 ×3,
  60 ×4, 61 ×21, 62 ×3, 64 ×12, 65 ×1, 66 ×2, 68 ×1,
  87 ×1}; L1 (2774016, 24, 1) takes 12 distinct
  values {55 ×75, 56 ×25, 57 ×46, 58 ×22, 59 ×31,
  60 ×14, 61 ×2, 62 ×2, 63 ×39, 64 ×2, 65 ×12,
  68 ×1}.

Verdict: the end block's rigidity is exact and total
— every rigid act is end-anchored at a single offset,
not merely confined to few positions. The loose pair
floats. Mechanism NOT PROVEN.

## (iii)(b) The rigid block's internal spacing

The 28 rigid acts share exactly the same 271-context
set. Within each context, successive rigid acts'
from-end differences were computed; each of the 27
successive pairs was then tested across contexts:

- **All 27 spacings are CONSTANT across all 271
  contexts** (27 of 27 pairs with a single distinct
  difference).
- The differences are 1 for 24 pairs; **3** for the
  pair (173040, 24, 0) → (173568, 816, 0) (from-end
  50 → 47) and for (174968, 24, 0) → (175616, 176, 0)
  (41 → 38); and **4** for the last pair
  (178792, 216, 0) → (2817536, 24, 0) (24 → 20, into
  the before-flank). Pooled distinct differences
  {1, 3, 4}.

Verdict: the block is a fixed end-anchored template:
28 acts at fixed offsets with fixed gaps — the two
gap-3 places and the closing gap-4 are part of the
template in every context. What occupies the gaps
was not read here and is named for 4.130. Mechanism
NOT PROVEN.

## (iii)(c) The two loose lead acts against the block

Measured in every context against the first rigid act
R0 = (172544, 376, 0) (from-end constantly 54):

- Both loose acts **precede R0 in all 271 contexts**;
  no loose act stands at or after R0 in any context
  (0 of 271).
- Distance to R0 (R0 position − loose position):
  L0 — 13 distinct distances {1 ×85, 2 ×72, 3 ×43,
  4 ×23, 5 ×3, 6 ×4, 7 ×21, 8 ×3, 10 ×12, 11 ×1,
  12 ×2, 14 ×1, 33 ×1} (its from-end distribution
  minus 54; the single distance-33 case is its
  from-end-87 outlier). L1 — 12 distinct distances
  {1 ×75, 2 ×25, 3 ×46, 4 ×22, 5 ×31, 6 ×14, 7 ×2,
  8 ×2, 9 ×39, 10 ×2, 11 ×12, 14 ×1}. Each loose act
  is immediately before the block (distance 1) in a
  large minority of contexts (85 and 75 of 271).
- Order of the loose pair: **L1 precedes L0 in 170
  contexts; L0 precedes L1 in 101**; the order census
  over (L0, L1, R0) is exactly {(L0, L1, R0): 101,
  (L1, L0, R0): 170} — no other order occurs.

Verdict: the loose acts form a floating preface of
variable length 1–33 acts before a perfectly rigid
end block, their mutual order itself variable.
Mechanism NOT PROVEN.

## Next

Slice 4.130 — the contents of the rigid block's three
wide gaps (the two gap-3 places and the closing
gap-4, read in every context: which acts stand
between the rigid neighbours, and whether the gap
contents are constant); the loose pair's joint
behaviour (L0 and L1 distances read together per
context — whether they co-vary, whether their order
tracks their distances, and the single distance-33 /
from-end-87 outlier context read in full); and the
byte-0 rewriting in the great group read against the
full A word's other bytes (the 180 differing pairs'
B byte 0 against (byte 1, byte 2, byte 3) forms —
whether any sub-key short of the full word separates
the 36 identity pairs from the 180). Host/artifact
analysis only — no physical child.
