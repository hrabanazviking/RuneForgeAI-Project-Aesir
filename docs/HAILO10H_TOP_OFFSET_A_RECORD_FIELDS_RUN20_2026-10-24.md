# The top offset region is entirely outside context A — all thirteen B-only acts carry offsets above A's largest offset (insertion rank 749 of 749 for every one, identical act and same-offset counts both 0 of 13), and A's own top eleven acts are all 24-byte acts on the same 488-spaced ladder family, eight of them not in B either; the 6864/6932 split is a function of NO record-level field that is not definitional — every pair in the 54 carries exactly one record, the cidx and idx sequences each take 27 values with every value appearing once in EACH cell, the n / centre / in37 sequences are constant across all 54, poscat's three values are all shared, wedding the (constant) record count to any of them changes nothing, and the only separating fields are the per-record cell sequence itself (the membership definition restated) and the full per-record tuple (which contains the cell, 224 distinct over 224 pairs, near-pair-identity) — the determinant remains NOT PROVEN; and run 20's full context is a staircase of rising shifts in A (run 18 +2, run 19 +240, run 20 +5, run 21 +7, run 22 +111, run 23 +135) while its B block is followed not by its A successors but by run 46's −102 pair, then run 21, run 24 and run 26, with runs 92 (+1 pair, B 669–670), 94 (+1 singleton, B 673) and 95 (+2 singleton, B 676) each contiguous at home (AES-NUM-163)

Slice 4.163, worked under `docs/TASK_CONTRACT_4.163.md`
(contract published in the 4.162 closing commit @
244a303f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef163.py (hef162.py verbatim as base plus the new
arms163) sha256
`b98ce9a34aa2ce05d7f8f051683aa111a337062b4b6f2f3e3a9e5fefc74c0096`
(913,664 B); arms163 sha256
`f492fb8e31fc76dc94b879ccdb7b161e7f5a2f3c006ed7bdcafd5960b5562927`
(14,322 B), its gzip sha256
`6715bb4888749104b8c8edcf4d92b304b821b191a5261ddaf79b54ce3068b4c5`.
The base hef162.py was verified on the VM ==
the on-device hef162 (sha256 e9305082…) before
assembly. Crossing record: the gzipped arms crossed
in 11 sha-gated parts of 373 B (last part 350 B);
all 11 verified on-device first try, no part
rejected. The assembled gzip, the decompressed
arms and the assembled hef163 sha256 all matched
the VM exactly on-device, and the script compiled
on-device. The ONE bounded host-side child was
launched directly in a detached tmux session on
Mimir with the contract corpus argv — the six
hailo-ollama blobs in glob order, then MiniLM —
and finished with DONE163 as its last line and a
complete output, err empty. HONEST NOTE: the tmux
wrapper's exit marker read 1 (no traceback, error
channel empty, output complete through DONE163);
cause NOT ESTABLISHED; the run was NOT repeated
(one bounded child per contract — the same posture
as AES-NUM-161's identical marker).
Output hef163.out: 45,835 lines / 8,782,009 B, sha256
`8fc735694641156c043d3e00ef894d58f5a87c06c7ad7cbb0858365e894d6def`.
Prefix check: of its first 45,601 lines against
hef162.out, exactly ONE line differs (line 41,611 —
the frozenset element-order variance already
recorded under AES-NUM-150/153–162; same content
and length), all other 45,600 lines byte-identical
(diff verified on-device).
Section163: 234 lines / 42,808 B, sha256
`e1101a39c8e7172cf358fcc74ab45764080b64453162589830969f09943d4f21`,
fetched by a device file read, verified on the VM
to exactly the on-device section sha, and read in
full. Every control in the controls echo reproduces
its expectation exactly: residue-0 sets 37 / 38 /
shared 25 / A-only 12 / B-only 13; byte2 census
85 listings / 96 distinct individual pairs / 11
hubs / 7 pairs at exactly 3 listings; 8 gap
records; gap 8 = run 102, step 49; context act
counts A 749 / B 751; shared distinct acts 689,
all 689 single-positioned; top-region B positions
[19, 20, 22, 23, 25, 26, 229, 272, 674, 735, 736,
737, 738], all not shared; cell populations
27 / 27 / both 0; run 20 length 16, shift +5,
A extent 280..295, B extent 285..300; runs
92/94/95 lengths 2/1/1, shifts +1/+1/+2.

Raw output kept on the Pi at ~/aesir-build/
(hef163.out, hef163.py, arms163.py, section163.txt);
local lineage in ~/workspace/.verify-tmp/aesir163.

## (i) The thirteen B-only acts against context A in full

Context A holds 749 acts with 749 distinct offsets,
running from 262,144 to its largest offset
791,780,864 (act (791780864, 24, 0) at A 748, ending
791,780,888). Context B's largest offset is
1,196,445,696.

- **None of the thirteen is in A in any form.**
  For every one of the thirteen acts (B offset
  ranks 738–750): the identical act (offset, size,
  channel) occurs in A **0 times**, and its offset
  occurs in A under any size/channel **0 times**
  (derived count from the printed tables: 0/13 on
  both tests). The whole region sits in an offset
  range A never reaches.
- **Every one inserts past A's end.** Each of the
  thirteen offsets is larger than A's largest
  offset, so each takes insertion rank 749 of 749
  distinct A offsets, with A offset predecessor
  (791780864, 24, 0) and no A successor. The
  region's smallest offset, 1,196,304,896 (B 19),
  is 404,524,032 past A's largest offset — the
  contexts' offset ranges overlap below that point
  (689 shared acts) and B alone extends above it.
- **A's own top is a different population.** A's
  offset ranks 738–748 (eleven acts, A positions
  731–748) are ALL 24-byte acts at offsets
  791,776,256 … 791,780,864, spaced 488 apart
  (two 0/464 exceptions at ranks 739–741). Only
  three are shared with B (ranks 738, 739, 744 —
  run 102 acts at B 733, 734, 746, shift +2); the
  other eight occur nowhere in B. So both contexts
  end their offset orders with 24 B ladder acts
  that are mostly their own — A's top and B's top
  are parallel structures, not shared ones. Any
  mechanism is NOT PROVEN.

## (ii) The 6864/6932 split against the record-level fields

Population as before: 54 pairs, 27 in cell
(20, 32720, 6864), 27 in (20, 32720, 6932), none in
both. A record is (cell, cidx, idx, n, centre,
poscat, in37). **Every pair in the 54 carries
exactly one record** (over all 224 pairs: 219 carry
one record, 5 carry 27 — none of the five is in
the 54), so every per-record sequence below is a
length-1 sequence and the record count is the
constant 1 across the whole population. Sixteen
fields were function-tested over the full 224 pairs
and membership-tabled over the 54.

- **cidx and idx sequences DO NOT separate — they
  match the two cells pair-for-pair.** The cidx
  sequence takes 27 distinct values over the 54 —
  (2,), (5,), (8,), …, (80,), stepping by 3 — and
  EVERY value appears exactly once in EACH cell
  (27 violating values over the full 224; NOT A
  FUNCTION). The idx sequence likewise takes 27
  values, (0,) through (26,), each once in each
  cell. For every cidx in the ladder there is
  exactly one 6864 pair and one 6932 pair recorded
  at it. Whatever chooses the cell, it is not the
  record's context or index.
- **n, centre and in37 are constant; poscat is
  fully shared.** The n sequence is (27,) for all
  54 pairs; the centre sequence is (127,) for all
  54; the in37 sequence is (False,) for all 54;
  poscat takes exactly the three values first /
  interior / last, all three in both cells. None
  is a function over the full 224 (1–3 violating
  values each), none separates.
- **Wedding the record count changes nothing.**
  The count is 1 for every pair in the population,
  so each (count, sequence) key inherits its
  sequence's verdict exactly — cidx/idx/n/centre/
  poscat/in37 wed keys all DO NOT SEPARATE, with
  the same shared values.
- **The only separating fields are definitional or
  near-identity, recorded as trivial.** The
  per-record cell sequence separates the 54 with
  exactly 2 population values — ((20, 32720, 6864),)
  (27, 0) and ((20, 32720, 6932),) (0, 27) — but
  membership is DEFINED by which target cell the
  record carries, so this is the definition
  restated, not a determinant. The full per-record
  tuple sequence (and its count-wed form) separates
  with 54 distinct population values and 224
  distinct values over 224 pairs: it contains the
  cell and otherwise near-identifies the pair, the
  trivial verdict of AES-NUM-162. **The split's
  determinant remains NOT PROVEN** — no record-level
  field of genuinely lower dimension than the pair
  is a function of the split, and the matched
  cidx/idx structure shows the split varies WITHIN
  every (cidx, idx) record position.

## (iii) Run 20's full context and runs 92/94/95

- **Run 20's A neighbourhood (A 276–300) is a
  staircase.** A 276–277 close run 18 (+2);
  A 278–279 are run 19 (+240, B 518–519); run 20
  itself at A 280–295 (+5, B 285–300 contiguous);
  A 296–297 open run 21 (+7, B 303–304); A 298–299
  open run 22 (+111, B 409–410); A 300 opens run 23
  (+135, B 435). In A order the shifts around run
  20 rise +2, +240, +5, +7, +111, +135 — run 20's
  modest +5 sits between run 19's large jump home
  and a rising tail of displaced successors.
- **What follows run 20's B block is NOT its A
  successors.** B 301–302 are run 46's −102 pair
  (A 403–404) — an act pair from far ahead in A
  landing immediately after the block; only then
  come run 21's acts at B 303–304 (A 296–297, the
  A successors themselves), run 24's +3 pair at
  B 305–306 (A 302–303) and run 26's +2 acts from
  B 307 (A 305–308). The B order after the block
  is 46, 21, 24, 26 — interleaved, not the A order
  21, 22, 23. Run 22's and run 23's acts are
  absent from B 301–310 entirely (they sit at
  B 409–410 and B 435).
- **Runs 92/94/95 in full** (the B 280 singleton's
  home runs, AES-NUM-162 (iii)): run 92 is a +1
  pair, A 668–669, contiguous at B 669–670 —
  (791061504, 32784, 2) and (791094784, 26128, 1);
  run 94 is the +1 singleton (791173632, 32784, 0),
  A 672, B 673; run 95 is the +2 singleton
  (791240192, 26128, 1), A 674, B 676. Each is one
  contiguous B block at home, with the gaps
  between them in B (671–672, 674–675) held by the
  A-only act's B-position namesake region and run
  101's −7 act at B 675 (AES-NUM-162) — the home
  neighbourhood is in-place except for the run-93
  singleton itself. Any mechanism is NOT PROVEN.

## Next

Slice 4.164 — the offset-range boundary between
the contexts in full (every B act above A's
largest offset: count, offset ranks, positions;
every A act in B's top band); the 6864/6932 split
as a matched-pair comparison (for each of the 27
shared cidx values, the 6864 pair against the 6932
pair recorded at it — value difference, XOR and
record fields side by side); runs 21/22/23 and 46
in full (run 20's A successors and its B
successor). Host/artifact analysis only.
