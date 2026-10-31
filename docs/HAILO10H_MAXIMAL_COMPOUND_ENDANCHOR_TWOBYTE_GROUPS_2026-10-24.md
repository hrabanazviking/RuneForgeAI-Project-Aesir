# Gap 2's chain does not repair under the maximal compound joint key either — wed EVERY companion together at once (the first act, the loose distances, the loose order, and BOTH sister gaps' whole fills) and the key count does not even move past what one sister beside the distances already gave (86 distinct keys; position-1 fails on 2 keys, position-2 on 3, the same violating sets as the single-sister tests), and the whole gap-2 tuple asked of (position-0, loose distances, one sister tuple) fails on exactly 3 of 86 keys under either sister. The end-anchoring census over the 19 size-328 acts and their 21 partners is now counted exactly: the small acts classify BOTH 18 and END-ONLY 1 (the exception (791774208, 328, 0) — no small act is start-only or neither), while the partners classify BOTH 16 — every one of them a trivial single-occurrence act — and NEITHER 5, those five being exactly the twice-occurring partners; among multi-occurrence acts the split is total (small acts anchored 9 of 9, partners anchored 0 of 5). The exception's two contexts share 689 distinct acts of a union of 811 (60 A-only, 62 B-only), yet only 126 of the shared acts stand at the same position in both contexts while 563 stand at different positions — the two homes are the same population re-laid, not the same layout. And B byte 0 answers to no two-byte part of the A word inside any single group either: in the great group (20, 32720) every one of the six two-byte keys carries violating repeats (34 repeating values under (byte 0, byte 3) alone, 27 of them violating); in group (14, 9992) the byte-0 keys never repeat at all and the three keys without byte 0 repeat only violating; in group (19, 7712) the one agreeing repeat in the whole per-group study beyond the great group is (byte 0, byte 1) = (20, 1), while (byte 1, byte 3) repeats violating there too — mechanisms NOT PROVEN (AES-NUM-136)

Slice 4.136, worked under `docs/TASK_CONTRACT_4.136.md`
(contract published in the 4.135 closing commit @
9f435fec). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef136.py (the hef135 file verbatim as base — itself
the hef134/hef133/hef132/hef131/hef130 lineage — plus
the new arms136) sha256
`81c5790e7e72d9d39de59f8351661d0b421c117bea5e610e9e1573e691219b7f`
(506,691 B); arms136 sha256
`68f56696d92f6eac1d72b2c88eefc60bf23a5fabbe656e4f0ad8a0025565fbec`
(12,876 B), its gzip sha256
`7cf38e5f877fe242788d59636a73db94bfa3c25a2bb3a101a9a18b7a3a6f4049`
(3,868 B). The arms were built locally by the
10-minute continuity worker and crossed by the
proxy-upload route (a one-shot on-device receiver
derived on-device from the verified recv135 receiver,
held in the foreground by a worker agent; the
receiver reported SAVED 3868 and the on-device gz
sha256 matched the VM's before assembly); hef136.py
was assembled on-device from the verified hef135 base
(on-device sha256 1d9f213a… == VM) plus the arms, and
the assembled file's sha256 matched the VM's exactly
before the run. The bounded host-side child was
launched in a detached tmux session on-device with
the contract corpus argv (the six hailo-ollama blobs
in glob order, then MiniLM — the launch law recorded
in the contract) and finished on-device (DONE136 is
the output's last line; the run's exit marker is 0;
the error channel carried nothing but that marker).
The retrieved output is 28,718 lines / 5,398,420 B,
sha256
`e32929192a48f3829e709c01417b51cf431daa42bd09f5b853736a6b976585b3`;
retrieved gz sha256
`f18418e566e08eff76f7b3824dbc5adf324cb794d7bcc867774a193878ee3481`
(566,598 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.136 section begins at output line
27,372 — exactly one past 4.135's total line count, and
the first 27,371 lines are byte-identical to hef135.out
(verified with cmp both on-device and on the VM at
closing), the base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared 114×251 acts 168; class-271 acts 30; rigid
context set 271; great group (20, 32720) pairs 216;
gap between-tuple counts 34 / 30 / 87 for gaps 0 / 1 / 2;
contexts indexed 1,504; corpus offset index 538,233
distinct offsets / 745,849 act occurrences; cross-size
census 19 offsets.

## (i) Gap 2's chain against the maximal compound joint key

All four tests are computed exactly over the 271 rigid
contexts (271 rows each). Every test prints its distinct
joint keys, its repeating joint keys in full, and every
violating joint key with its alternatives and every
carrying context's full row.

- The maximal compound joint key (position-0 act,
  loose distances (d0, d1), loose order, gap-0 tuple,
  gap-1 tuple): 86 distinct keys, 15 repeating.
  Position-1 is NOT a function of it (2 violating
  keys: (33312256, 328, 0) at distances (1, 3) under
  the sister tuples ((1198581248, 248, 0),
  (1198581760, 176, 0)) / ((1198582272, 256, 0),
  (1198582528, 176, 0)) with 2 alternatives, and
  (976502784, 328, 0) at (1, 3) under its sister
  tuples with 2); position-2 is NOT a function of it
  (3 violating: those two keys, plus
  (1255547392, 328, 0) at (2, 9) under its sister
  tuples with 3 alternatives that differ only at
  position-2).
- The maximal key adds NO distinct key over
  (position-0, loose distances, gap-0 tuple) alone
  or (position-0, loose distances, gap-1 tuple)
  alone (AES-NUM-135: 86 distinct under either
  sister): once the distances and ONE sister fill
  are in the key, the loose order and the second
  sister contribute no further distinction anywhere
  in the 271 contexts, and the violating sets are
  exactly the single-sister sets.
- Whole gap-2 tuple as a function of (position-0,
  loose distances (d0, d1), gap-0 tuple): 86
  distinct, 15 repeating, NOT a function — 3
  violating keys, the same three position-0 acts,
  carrying 2, 2 and 3 whole tuples respectively.
- Whole gap-2 tuple as a function of (position-0,
  loose distances (d0, d1), gap-1 tuple): 86
  distinct, 15 repeating, NOT a function — the
  same 3 violating keys with the same alternative
  tuples.

No compound of the companions tested — distances,
order, either sister, both sisters together —
repairs the chain. The fill inside a
(position-0, distances, sister) family still varies
with none of those companions accounting for it;
what else varies it is NOT PROVEN.

## (ii) End-anchoring census over the 19 size-328 acts and their 21 partners

The corpus offset index is rebuilt in full (538,233
distinct offsets; 745,849 act occurrences) and the
census of AES-NUM-133/134 is reproduced exactly:
19 offsets. Every one of the 19 size-328 acts and
every one of the 21 partner acts is printed in the
run with every occurrence's artifact, cidx, position,
context length and position-from-end, its position /
position-from-end / context-length distributions,
and its classification: start-fixed (one position),
end-fixed (one position-from-end), BOTH, or NEITHER.

- Size-328 population (19 acts): BOTH 18, END-ONLY
  1, START-ONLY 0, NEITHER 0. The END-ONLY act is
  the known exception (791774208, 328, 0). Split by
  occurrence count (derived from the printed rows):
  10 single-occurrence acts (BOTH trivially) and 9
  multi-occurrence acts, of which 8 are BOTH and 1
  is END-ONLY — every multi-occurrence small act is
  anchored at at least one end.
- Partner population (21 acts): BOTH 16, NEITHER 5,
  START-ONLY 0, END-ONLY 0. Split the same way: the
  16 BOTH partners are exactly the 16
  single-occurrence partners (anchored trivially),
  and the 5 NEITHER partners are exactly the 5
  twice-occurring partners (109145088, 32784, 2),
  (112060928, 32784, 0), (120529920, 32784, 0),
  (482159104, 32784, 0) and (811546112, 1552, 1) —
  no multi-occurrence partner is anchored at either
  end.
- Combined (40 acts): BOTH 34, END-ONLY 1,
  NEITHER 5. Among the 14 multi-occurrence acts the
  anchoring split is exact and total: the 9 small
  acts are all anchored (8 from both ends, 1 from
  the end only), the 5 partners are anchored from
  neither end.
- The exception's two contexts read against each
  other (5ab3537d cidx 86, 749 acts, every act
  distinct; and cidx 210, 751 acts, every act
  distinct; both contexts' acts are single-occupancy,
  so distinct counts equal lengths): the two
  contexts SHARE 689 distinct acts; 60 distinct acts
  occur only in A and 62 only in B; the union holds
  811 distinct acts. Of the 689 shared acts, only
  126 stand at the SAME position in both contexts,
  while 563 stand at different positions — including
  the exception itself (position 725 in A, 727 in
  B; its constancy is from the end, 23 in both, not
  its position). The two homes hold nearly the same
  population laid out differently: sharing of acts
  is not sharing of layout. Any deeper relation is
  NOT PROVEN.

## (iii) B byte 0 against the two-byte sub-keys inside each group

For each of the three lane-1 groups separately and
each of the six two-byte sub-keys of the A word,
every key value carried by more than one pair of
that group is printed in full in the run (A and B
words, all four A bytes, B byte 0, status, difference,
group, and every record), with its agreeing /
violating verdict (agreeing = one B byte 0 across the
value's pairs; violating = more than one).

- Group (14, 9992) — 5 pairs: the three keys that
  include byte 0 — (byte 0, byte 1), (byte 0,
  byte 2), (byte 0, byte 3) — take 5 distinct values
  on 5 pairs: NO value repeats, so inside this group
  those keys hold only by unique identification.
  The three keys without byte 0 repeat only
  violating: (byte 1, byte 2) on (1, 176) -> B byte
  0 {28, 32} and (1, 178) -> {20, 24}; (byte 1,
  byte 3) on (1, 128), 4 pairs -> {20, 24, 28, 32};
  (byte 2, byte 3) on (176, 128) -> {28, 32} and
  (178, 128) -> {20, 24}. No agreeing repeat exists
  in this group under any two-byte key.
- Group (19, 7712) — 3 pairs: exactly one agreeing
  repeat — (byte 0, byte 1) = (20, 1), 2 pairs, both
  B byte 0 = 20 (the within-group half of the
  cross-group agreeing value of AES-NUM-134/135) —
  and exactly one violating repeat: (byte 1,
  byte 3) = (1, 128), 2 pairs -> {20, 68}. The other
  four keys never repeat inside this group.
- Group (20, 32720) — 216 pairs: EVERY two-byte key
  carries violating repeats, so no two-byte key
  determines B byte 0 in the great group even with
  repetition to spare. (byte 0, byte 1): 209
  distinct, 7 repeating (2 agreeing — (0, 3) -> 0
  and (128, 68) -> 128 — and 5 violating).
  (byte 0, byte 2): 207 distinct, 8 repeating (1
  agreeing — (0, 87) -> 128 — and 7 violating).
  (byte 0, byte 3): 168 distinct, 34 repeating (7
  agreeing and 27 violating, the widest two-byte
  traffic in the group; its heaviest values are
  (128, 187) with 6 pairs -> {0, 128} and
  (128, 186) with 5 pairs -> {0, 128}).
  (byte 1, byte 2): 215 distinct, exactly 1
  repeating value, violating — (128, 146) ->
  {128, 160}, which is also the great-group
  projection under which the (byte 3, byte 1,
  byte 2) key failed in AES-NUM-133. (byte 1,
  byte 3): 214 distinct, 2 repeating, both
  violating ((44, 249) -> {104, 128}; (84, 252) ->
  {8, 120}). (byte 2, byte 3): 215 distinct,
  exactly 1 repeating value, violating —
  (181, 249) -> {104, 160}, the two-byte projection
  carried by the identity pair A 682cb5f9 -> B
  6884f5f8 among others.

So the two-byte ladder closes the same way the
three-byte ladder did (AES-NUM-135): inside a single
group, no sub-key of the A word — two bytes or
three — ever both repeats and agrees universally;
where a key's values repeat with more than one pair
behind them, violation is present in every group
that repeats at all, except the single small
agreeing value (20, 1) in the smallest group.
Mechanism NOT PROVEN.

## Next

Slice 4.137 — gap 2's chain against the maximal
compound joint key wed to the context length and to
the gap's left position (the two companions the
maximal key does not yet carry), the whole tuple
likewise; the exception contexts' shared-act
position-shift anatomy (the exact shift distribution
over the 689 shared acts, the 126 same-position
acts' position distribution, and shift runs in
position order); and B byte 0 against the six
two-byte sub-keys over the FULL 224-pair population
(every repeated value in full, agreeing or
violating, with each repeated value's group
composition). Host/artifact analysis only.

Mechanisms NOT PROVEN throughout: no feature or key
tested is claimed to be the mechanism of the gap-2
fill, of the cross-size offset sharing, of the
exception contexts' re-layout, or of the byte-0
rewriting; the grades above are exact population
counts and nothing more.
