# The artifact identity is a CERTIFIED function of the doubly-wed key (86 distinct keys, 15 repeating, ZERO violating) but the context index is NOT (all 15 repeating keys violate) — wedging the artifact identity further repairs nothing (still 86 distinct keys, position-1 failing on 2 keys, position-2 and the whole tuple on the same 3, exactly the known families with 'cc9b9d1c' appended), and wedging the context index makes every row its own key (271 distinct joint keys, 0 repeating — a vacuous repair, derived from the printed counts). The secondary long runs' internal A-position gaps are almost all unit: 431 gaps in total, 423 of size 1 and only 8 larger (distribution {1: 423, 2: 4, 3: 1, 5: 2, 6: 1}, max 6), every non-unit gap in the three merging/extending runs. The 16 long-run flanking acts classify as 6 large-shift tail acts, 3 same-position acts and 7 neither (16 entries, 16 distinct acts — the 6 tail flanks confirming AES-NUM-139's derived count directly). And B byte 0 against the four three-byte sub-keys UNWED over the full 224 pairs: (byte 0, byte 1, byte 2) and (byte 0, byte 2, byte 3) are injective (224 distinct values, 0 repeats), (byte 0, byte 1, byte 3) has exactly ONE repeating value and it AGREES — (20, 1, 128) -> B byte 0 = 20, a cross-group repeat the group wed had split — while (byte 1, byte 2, byte 3) unwed repeats exactly the same two values as wed and violates both times; the two wed violating repeats re-read against A byte 0 show B byte 0 equals A byte 0 in all four pairs (status SAME, diff 0) — mechanisms NOT PROVEN (AES-NUM-140)

Slice 4.140, worked under `docs/TASK_CONTRACT_4.140.md`
(contract published in the 4.139 closing commit @
151f042a). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef140.py (the hef139 file verbatim as base — itself
the hef138/hef137/hef136/hef135/hef134/hef133/hef132/
hef131/hef130 lineage — plus the new arms140) sha256
`d8a1b25a66c41290478112fb0384dce6656037d28bdaf03fc29f10fd894d63ce`
(563,165 B); arms140 sha256
`67893311a5e62afbd01cb06d496da0e7b1744f88949ba01011a69d85caeb0892`
(9,284 B), its gzip sha256
`9410ed95c277cea53a4b4cefcc9bc24aa018808405f843c1fe7e7cb088b2aa5d`
(2,922 B). The arms were built locally by the
10-minute continuity worker and crossed by the
sha-gated chunked file.write route (8 chunks of
373 B; the final chunk carried the whole-file sha256
gate, which passed on-device on the first session);
hef140.py was assembled on-device from the verified
hef139 base (on-device sha256 0f0a696c… == VM) plus
the arms, and the assembled file's sha256 matched
the VM's exactly before the run. The bounded
host-side child was launched in a detached tmux
session on-device with the contract corpus argv
(the six hailo-ollama blobs in glob order, then
MiniLM — the launch law recorded in the contract)
and finished on-device (DONE140 is the output's last
line; the run's exit marker is 0; the error channel
carried nothing). The retrieved output is 33,087
lines / 6,282,184 B, sha256
`cc12fd3790bd86ec8d8664006f346cf19ea850cc1eced44b4c74c1e02800e788`;
retrieved gz sha256
`1b6898b88195d9a14f9cefb0ed63458ffa5ec5703e420ba560bb23e98150e3b9`
(641,810 B, fetched through a temporary on-device
HTTP server via the tunnel proxy; the fetched gz
sha256 equals the on-device gz sha256 and
decompresses to exactly the output sha256, verified
on the VM at closing); the 4.140 section begins at
output line 32,006 — exactly one past 4.139's total
line count, and the first 32,005 lines are
byte-identical to hef139.out (verified with cmp both
on-device and on the VM at closing), the base having
reproduced line-for-line. The section alone is 1,082
lines / 228,770 B, sha256
`007168bab24bc85db9ff88b19d56c324ad4346ccd359bacb4413f1fddb239208`.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared 114×251 acts 168; class-271 acts 30; rigid
context set 271; great group (20, 32720) pairs 216;
gap between-tuple counts 34 / 30 / 87 for gaps 0 / 1 / 2;
contexts indexed 1,504.

## (i) The doubly-wed violating families against the contexts' own identities

The doubly-wed key is the maximal compound joint key
wed to BOTH companions (context length and gap-2 left
position), as established in AES-NUM-138 (86 distinct
over the 271 contexts).

- Artifact identity as a function of the doubly-wed
  key: CERTIFIED — 86 distinct keys, 15 repeating, 0
  violating keys. Every repeating family in full
  carries the single artifact value 'cc9b9d1c'.
- Context index within its artifact as a function
  of the doubly-wed key: NOT a function — 86
  distinct keys, 15 repeating, and ALL 15 repeating
  keys violate. Each family's contexts are spread
  over many indices (e.g. the (109662208, 328, 0)
  family at distances (7, 2), length 738 / left 713,
  carries 13 indices 13, 21, 29, …, 109).
- Doubly-wed wed further to the artifact identity
  adds NO distinct key (86 distinct joint keys, 15
  repeating — exactly as the certification requires):
  position-1 is NOT a function (2 violating keys),
  position-2 is NOT a function (3 violating), and
  the whole tuple is NOT a function (the same 3).
  The violating keys are exactly the doubly-wed
  violating families with 'cc9b9d1c' appended:
  (33312256, 328, 0) at (1, 3) with length 245 /
  left 220, (976502784, 328, 0) at (1, 3) with
  873 / 848, and (1255547392, 328, 0) at (2, 9)
  with 606 / 581 violating only at position-2 /
  the whole tuple.
- Doubly-wed wed further to the context index gives
  271 distinct joint keys, 0 repeating, 0 violating
  under all three tests (position-1, position-2,
  whole tuple) — formally IS A FUNCTION on each,
  but only because the wed makes every one of the
  271 rows its own key (derived from the printed
  counts): no family survives the wed, so it
  certifies nothing about the families and repairs
  the chain only vacuously.

One more companion is proven redundant (the artifact
identity) and one is proven non-redundant but
individually identifying (the context index). What
varies the fill inside a maximal family is still
NOT PROVEN.

## (ii) The secondary long runs' internal gaps, and the flanking acts classified

The exception is (791774208, 328, 0) (689 shared
acts, every shared act single-positioned in both
contexts, as in AES-NUM-137..139).

- Secondary runs total 103; the 7 runs of length
  ≥ 20 hold 431 internal A-position gaps in total.
  Gap size distribution {1: 423, 2: 4, 3: 1, 5: 2,
  6: 1}; max gap 6; only 8 gaps are larger than 1.
- The four primary long runs themselves (158 at +2
  over A 26–183, 20 at −2 over 192–211, 29 at 0 over
  242–270, 37 at +2 over 305–341) are perfectly
  unit-spaced: every internal gap is 1 (157 / 19 /
  28 / 36 gaps, max 1 each).
- Every non-unit gap sits in one of the three
  merging/extending runs, printed in full in the
  raw section:
  - run 62 (53 at +3 over A 438–497): gaps 3 at
    step 5 (A 443 → 446) and 6 at step 11
    (A 451 → 457);
  - run 74 (83 at 0 over A 524–614): gaps 2 at
    step 24 (A 548 → 550), 5 at step 31
    (A 556 → 561), 2 at step 33 (A 562 → 564),
    2 at step 37 (A 567 → 569), 2 at step 48
    (A 579 → 581);
  - run 102 (58 at +2 over A 683–744): gap 5 at
    step 49 (A 732 → 737; the right act of this
    gap, (768609280, 24, 0), is itself the right
    flanking act of primary long run 116).
- The 16 flanking acts of AES-NUM-139, reconstructed
  from the primary long runs and classified exactly:
  - large-shift tail acts (|shift| ≥ 100): 6 —
    right of run 7 (+432, A 184), left of run 11
    (+434, A 191), left of run 33 (+107, A 304),
    right of run 71 (−154, A 498), left of run 83
    (−239, A 523), right of run 88 (−111, A 615).
    This confirms directly, act by act, the count
    AES-NUM-139 marked derived.
  - same-position acts (shift 0): 3 — left of
    run 7 (A 24), right of run 83 (A 550), left
    of run 88 (A 579).
  - neither: 7 — right of run 11 (−4, A 214), left
    of run 24 (−2, A 241), right of run 24 (+2,
    A 271), right of run 33 (+6, A 342), left of
    run 71 (+3, A 451 — the same act that is the
    left act of run 62's gap-6 step), left of
    run 116 (−7, A 682), right of run 116 (+2,
    A 737).
  - 16 entries, 16 distinct acts; no flank is both
    a tail act and a same-position act (the classes
    are disjoint by construction).

So the secondary reading's looseness is exactly 8
skipped A-positions' worth of gaps, all inside the
three runs that already merge or extend primary
runs; the strict runs are gapless under both
readings. Which acts occupy the skipped positions,
and why, is NOT PROVEN.

## (iii) B byte 0 against the four three-byte sub-keys UNWED; the wed violating repeats re-read

Over the full 224 lane-1 pairs, each three-byte
sub-key of the A word tested UNWED (value alone, no
group) as a would-be determinant of B byte 0:

- (byte 0, byte 1, byte 2): 224 distinct unwed
  values, 0 repeating — injective; no agreeing or
  violating repeat (a function claim from zero
  repeats is vacuous and none is made).
- (byte 0, byte 1, byte 3): 223 distinct unwed
  values, exactly 1 repeating value, and it is
  AGREEING: (20, 1, 128) carried by two pairs —
  A 1401b180 -> B 1401b100 (group (19, 7712),
  1 record) and A 1401b280 -> B 1401b200
  (group (14, 9992), 27 records) — both with
  B byte 0 = 20, status SAME, diff 0. This is a
  CROSS-GROUP repeat: the group wed of AES-NUM-139
  split exactly this pair of pairs and reported
  the key injective. Unwed, the key has one repeat
  and it does not violate.
- (byte 0, byte 2, byte 3): 224 distinct unwed
  values, 0 repeating — injective, as above.
- (byte 1, byte 2, byte 3): 222 distinct unwed
  values, 2 repeating, 0 agreeing, 2 VIOLATING —
  NOT a function. The two repeats are exactly the
  wed ones (both pairs of each are in group
  (14, 9992) anyway, so the wed changed nothing
  for this key): (1, 176, 128) -> B set {28, 32}
  and (1, 178, 128) -> B set {20, 24}.

The two (byte 1, byte 2, byte 3) wed violating
repeats re-read against A byte 0, in full:

- wed value ((14, 9992), (1, 176, 128)): pairs
  A 1c01b080 -> B 1c01b000 (A byte 0 = 28,
  B byte 0 = 28) and A 2001b080 -> B 2001b000
  (A byte 0 = 32, B byte 0 = 32).
- wed value ((14, 9992), (1, 178, 128)): pairs
  A 1401b280 -> B 1401b200 (A byte 0 = 20,
  B byte 0 = 20) and A 1801b280 -> B 1801b200
  (A byte 0 = 24, B byte 0 = 24).
- In all four pairs: B byte 0 equals A byte 0,
  status SAME, diff 0. The violation lives entirely
  BETWEEN the pairs of a repeat: the shared
  (byte 1, byte 2, byte 3) value is carried by two
  different A byte-0 values, and B byte 0 follows
  its own pair's A byte 0 in each case. (That
  reading is the run's printed rows restated;
  any mechanism behind it is NOT PROVEN.)

Net for (iii): no unwed three-byte key earns a
determination either — two are injective, one has
a single agreeing cross-group repeat, and the
byte-0-free key violates on the same two values
wed or unwed. Mechanisms NOT PROVEN.

## Next

Slice 4.141 — the cidx sets inside the 15 repeating
doubly-wed families in full (each family's indices,
their step/residue structure), with cidx-derived
companions (residue and quotient under the family's
own step) tested the same way; the acts occupying
the 8 skipped A-positions inside the secondary long
runs (identity, shared or not, position in B if
shared); B byte 0 against the four three-byte
sub-keys wed to the pair's status (SAME / DIFF)
over the full 224 pairs, with the (byte 0, byte 1,
byte 3) unwed agreeing repeat's two pairs re-read
record by record. Host/artifact analysis only.
