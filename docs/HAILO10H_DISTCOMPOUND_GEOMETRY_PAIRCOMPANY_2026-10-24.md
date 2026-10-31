# Gap 2's chain does not repair under any distance-compound joint key either — wed the first act to the loose distances AND the loose order and nothing changes at all (84 distinct keys, exactly the distances-alone count; position-1 fails 3, position-2 fails 4, every violating key under L1-before-L0), and wed the distances to a sister gap's whole fill and only the widest key's (2, 4) branch falls silent (86 distinct keys under either sister; position-1 fails 2, position-2 fails 3); the whole gap-2 tuple as a function of (position-0, loose distances) fails on exactly 4 of 84 keys. The 19 size-328 acts' occurrence geometry is now read in full: every act is confined to a single artifact, 18 of 19 are position-fixed, and the sole exception, (791774208, 328, 0), is fixed from the END instead — position 725 in a 749-act context and 727 in a 751-act context, position-from-end 23 in both; their 21 partners are position-fixed in only 16 cases (the five twice-occurring partners all move, and none of them is end-fixed either). And the agreeing cross-group two-byte values' whole company is exactly their carriers — (20, 1) three pairs, (68, 1) two, (20, 128) two, every one SAME — while inside a single group NO three-byte value ever repeats agreeing under any of the four keys: the only agreeing three-byte repetition in the whole 224-pair population is the cross-group (20, 128, 1) pair itself, and the only within-group three-byte repetitions of any kind are the two violating (byte 3, byte 1, byte 2) values of the small group (14, 9992) — mechanisms NOT PROVEN (AES-NUM-135)

Slice 4.135, worked under `docs/TASK_CONTRACT_4.135.md`
(contract published in the 4.134 closing commit @
41c15323). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef135.py (the hef134 file verbatim as base — itself
the hef133/hef132/hef131/hef130 lineage — plus the new
arms135) sha256
`1d9f213ade6beab0969293723a448a15d357b09701ec74fcfbb49bb1034ba588`
(493,815 B); arms135 sha256
`551f56a9e6cc763257a921fd40c6d05dfc9fd7a0e0e401e09ff8d292a8b61783`
(13,000 B), its gzip sha256
`7ccc76dbc2c84a908095839f6e5417eab52a197a232f29bcd031c935ae9d9464`
(3,722 B). The arms were built locally by the
10-minute continuity worker and crossed by the
proxy-upload route (a one-shot on-device receiver
derived on-device from the verified recv134 receiver,
held in the foreground by a worker agent; the
receiver reported SAVED 3722 and the on-device gz
sha256 matched the VM's before assembly); hef135.py
was assembled on-device from the verified hef134 base
(on-device sha256 48eba702… == VM) plus the arms, and
the assembled file's sha256 matched the VM's exactly
before the run. Launch record, stated plainly: a
first launch through the device runner was killed
when the invoke hit its node timeout before
completion (partial output, empty error file, no
DONE marker) and was discarded; the bounded
host-side child was then launched in a detached tmux
session on-device with the identical contract corpus
argv (the six hailo-ollama blobs in glob order, then
MiniLM — the launch law recorded in the contract)
and finished on-device with an empty error file;
DONE135 is the output's last line. The retrieved
output is 27,371 lines / 5,176,438 B, sha256
`0c603a505bc9ac12946fef04065ea2ef47c02a6e604363dd5dd1eef25902d596`;
retrieved gz sha256
`d6602f3e2436b259311eb37024c50672ba6912fab670eb82ce88816d3a026c24`
(545,541 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.135 section begins at output line
25,131 — exactly one past 4.134's total line count, and
the first 25,130 lines are byte-identical to hef134.out
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

## (i) Gap 2's chain against distance-compound joint keys

All seven tests are computed exactly over the 271 rigid
contexts (271 rows each). Every test prints its distinct
joint keys, its repeating joint keys in full, and every
violating joint key with its alternatives and every
carrying context's full row.

- (position-0, loose distances (d0, d1), loose order):
  84 distinct keys, 14 repeating — the loose order adds
  NO distinct key over the distances alone (AES-NUM-134:
  84 distinct). Position-1 is NOT a function of it
  (3 violating keys: (33312256, 328, 0) at distances
  (1, 3) with 3 alternatives and at (2, 4) with 2, and
  (976502784, 328, 0) at (1, 3) with 2); position-2 is
  NOT a function of it (4 violating: the same three
  keys, plus (1255547392, 328, 0) at (2, 9) with 3) —
  the identical violating sets to the distances alone,
  and every violating key under this compound carries
  the order L1-before-L0 (derived from the printed
  violating keys).
- (position-0, loose distances (d0, d1), gap-0 tuple):
  86 distinct keys, 15 repeating. Position-1 NOT a
  function (2 violating: (33312256, 328, 0) at (1, 3)
  under the gap-0 tuple ((1198581248, 248, 0),
  (1198581760, 176, 0)) with 2 alternatives, and
  (976502784, 328, 0) at (1, 3) under its gap-0 tuple
  with 2); position-2 NOT a function (3 violating:
  those two keys, plus (1255547392, 328, 0) at (2, 9)
  under its gap-0 tuple with 3). Against the distances
  alone, the sister fill adds 2 distinct keys and
  silences exactly the widest key's (2, 4) branch —
  the (33312256, 328, 0) alternatives at distances
  (2, 4) separate by their gap-0 tuples — and no more.
- (position-0, loose distances (d0, d1), gap-1 tuple):
  86 distinct, 15 repeating — the same counts and the
  same violating position-0 sets (2 for position-1,
  3 for position-2, derived likewise), the widest
  key's (2, 4) branch silenced the same way.
- Whole gap-2 tuple as a function of (position-0,
  loose distances (d0, d1)): 84 distinct, 14
  repeating, NOT a function — 4 violating keys:
  (33312256, 328, 0) at (1, 3) carrying 3 tuples and
  at (2, 4) carrying 2, (976502784, 328, 0) at (1, 3)
  carrying 2, and (1255547392, 328, 0) at (2, 9)
  carrying 3 tuples that differ only at position-2
  (position-1 is (1255547720, 328, 0) in all three).

No distance-compound joint key tested repairs the
chain. The distances remain the strongest companion
(the order is inert beside them; a sister fill buys
exactly one silenced branch), but they do not close
it; what else varies the fill inside a (position-0,
distances, sister-tuple) family is NOT PROVEN.

## (ii) The 19 size-328 acts' occurrence geometry in full

The corpus offset index is rebuilt in full (538,233
distinct offsets; 745,849 act occurrences) and the
census of AES-NUM-133/134 is reproduced exactly:
19 offsets. Every one of the 19 size-328 acts and
every one of the 21 partner acts is read in the run
with every occurrence's artifact, cidx, position,
context length and position-from-end, its position /
context-length / position-from-end distributions, and
its per-artifact cidx sequence with successive diffs.

- Confinement and fixity (counted exactly over the
  printed rows): each of the 19 acts' occurrences are
  confined to a single artifact (per-artifact counts:
  0856a10c 8 acts, 76c3a8ff 4, cc9b9d1c 3, 5ab3537d 2,
  0a0d378c 1, 773470cd 1, MiniLM 0). 18 of the 19 are
  position-fixed. Every multi-occurrence act but one
  also stands in contexts of a single length, so its
  position-from-end is constant as well.
- The exception, (791774208, 328, 0), read in both
  its contexts in full (5ab3537d cidx 86, 749 acts,
  and cidx 210, 751 acts — both contexts printed act
  by act in the run): it stands at position 725 in
  the first and 727 in the second — position-from-end
  23 in BOTH. The one position-varying small act is
  end-anchored: its distance from the context's end
  is the constant, its distance from the start is
  not (derived from the printed occurrence rows; the
  two contexts otherwise differ act by act and share
  no long common alignment — no mechanism claimed).
- Cidx patterns (from the printed sequences): several
  acts march at one constant step through their
  artifact — the target (120529920, 328, 0) at step 8
  over cidx 14–102, (711228416, 328, 0) at step 6
  over cidx 80–164, (109145088, 328, 0),
  (302853120, 328, 0) and (438940160, 328, 0) at
  step 12 — while others are irregular
  ((112060928, 328, 0): diffs 9, 6, 12, 12, 12, 12;
  (197286400, 328, 0): 3, 12, 12, 12, 12;
  (1068529664, 328, 0): 5, 40, 20, 15, 20, 25).
  No single cidx law covers the population.
- The partners, by contrast: 16 of 21 are
  position-fixed, every one of those trivially (a
  single occurrence). All five twice-occurring
  partners MOVE — (109145088, 32784, 2) at positions
  173 / 122, (112060928, 32784, 0) at 181 / 789,
  (120529920, 32784, 0) at 721 / 474,
  (482159104, 32784, 0) at 115 / 659,
  (811546112, 1552, 1) at 247 / 237 — and none of the
  five is position-from-end-fixed either (their
  from-end pairs are 147/157, 839/112, 299/427,
  905/242, 443/453; derived from the printed rows).
  End-anchoring, where it appears, belongs to the
  small acts, not to their partners.

So the small acts are rigid residents of one artifact
each — fixed by position, and in the single varying
case fixed by distance from the end — while the
partners that share their offsets wander. Any deeper
relation is NOT PROVEN.

## (iii) The cross-group two-byte values' pair company, and agreeing three-byte repetitions inside a single group

For each agreeing cross-group two-byte value of
AES-NUM-134, every pair carrying that value in the
full 224-pair population is printed in full in the
run (A and B words, all four A bytes, B byte 0,
status, difference, group, and every record). Then,
with the cross-group condition dropped, every
three-byte sub-key value that repeats is tested for
agreement over the full population and inside each
group separately (all four three-byte keys × the
full population and the three groups).

- (byte 0, byte 1) = (20, 1): exactly 3 pairs carry
  it, and they are its whole company — A 1401b000 ->
  B 1401b080 (group (19, 7712), 1 record), A 1401b180
  -> B 1401b100 (group (19, 7712), 1 record), A
  1401b280 -> B 1401b200 (group (14, 9992), 27
  records) — all SAME at B byte 0 = 20.
- (byte 0, byte 1) = (68, 1): exactly 2 pairs —
  A 4401a080 -> B 4401a000 (group (19, 7712)) and
  A 4401a200 -> B 4401a280 (group (14, 9992)) —
  both SAME at 68.
- (byte 0, byte 3) = (20, 128): exactly 2 pairs —
  the agreeing three-byte pair itself, A 1401b180 ->
  B 1401b100 and A 1401b280 -> B 1401b200, both SAME
  at 20. No agreeing value hides further pairs in
  its own group or anywhere else: the company is the
  carriers, counted exactly.
- Inside a single group, NO three-byte value repeats
  agreeing under any key. Per group: group
  (20, 32720) repeats under no key (216 distinct
  values of 216 pairs under every key); group
  (19, 7712) repeats under no key (3 pairs, all
  distinct under every key); group (14, 9992) repeats
  under exactly one key — (byte 3, byte 1, byte 2) —
  and both its repeated values VIOLATE: (128, 1, 176)
  -> B byte 0 {28, 32} and (128, 1, 178) -> {20, 24}.
- Over the full population the picture is the same:
  (byte 0, byte 1, byte 2) and (byte 0, byte 3,
  byte 2) take 224 distinct values on 224 pairs —
  no repetition at all; (byte 3, byte 1, byte 2)
  repeats only on the two violating small-group
  values above; and (byte 0, byte 3, byte 1) repeats
  exactly once — the value (20, 128, 1), agreeing,
  whose two pairs live in DIFFERENT groups. The one
  agreeing three-byte repetition in the population
  exists only across a group boundary, never inside
  one group. Mechanism NOT PROVEN.

## Next

Slice 4.136 — gap 2's chain against the maximal
compound joint key ((position-0, loose distances,
loose order, gap-0 tuple, gap-1 tuple) together; the
whole gap-2 tuple as a function of (position-0,
loose distances, gap-0 tuple) and of (position-0,
loose distances, gap-1 tuple)); an end-anchoring
census over the 19 size-328 acts and their 21
partners (each act classified start-fixed /
end-fixed / both / neither, counted exactly), with
the exception's two contexts' shared-act census;
and B byte 0 against the two-byte sub-keys INSIDE
each group separately (every repeated two-byte value
per group, agreeing or violating, in full).
Host/artifact analysis only.

Mechanisms NOT PROVEN throughout: no feature or key
tested is claimed to be the mechanism of the gap-2
fill, of the cross-size offset sharing, or of the
byte-0 rewriting; the grades above are exact
population counts and nothing more.
