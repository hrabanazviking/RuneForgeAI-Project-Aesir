# The offset-range boundary between the contexts is a clean tail cut — context B first passes context A's largest offset at B offset rank 721, and the 30 B acts above it form the contiguous offset tail (ranks 721–750), all unshared, in four offset clusters; the 6864/6932 split as a matched-pair comparison across the 27 shared cidx values has NO constant or structured relation — every int, XOR and bytewise relation between the matched two is distinct 27 of 27, except the byte3 differences, which are confined to {14, 15, 16} on both the A side (13/10/4) and the B side (20/5/2) without being constant — the determinant remains NOT PROVEN; and runs 21 (+7), 22 (+111), 23 (+135) and 46 (−102) are each one contiguous B pair, run 23 a +135 PAIR at A 300–301 / B 435–436 (correcting the abbreviated singleton reading in AES-NUM-163's prose), with run 46's −102 pair sitting immediately after run 20's B block (B 301–302) and immediately before run 21 (B 303–304) while its A neighbourhood is all positive shifts (AES-NUM-164)

Slice 4.164, worked under `docs/TASK_CONTRACT_4.164.md`
(contract published in the 4.163 closing commit @
f2ae613a). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef164.py (hef163.py verbatim as base plus the new
arms164) sha256
`62cb13055285028ed1037aeab883fbd01b636ff79b22716058f34a72f6f2d721`
(930,851 B); arms164 sha256
`2a7d7cab83d0e69a96df6864f1d47468c56f7a453e11db2dcd4c32d03fea6c5f`
(17,187 B), its gzip sha256
`babc3ff532a19e4ee56499708ee7c8d8c129366f78d5af9d38b6ffe2d92284b6`
(4,611 B). The base hef163.py was verified on the VM ==
the on-device hef163 (sha256 b98ce9a3…) before
assembly. Crossing record: the gzipped arms crossed
in 13 sha-gated parts of 373 B (last part 135 B);
all 13 verified on-device first try, no part
rejected. The assembled gzip, the decompressed
arms and the assembled hef164 sha256 all matched
the VM exactly on-device, and the script compiled
on-device. The ONE bounded host-side child was
launched directly in a detached tmux session on
Mimir with the contract corpus argv — the six
hailo-ollama blobs in glob order, then MiniLM —
and finished with DONE164 as its last line and a
complete output, err empty. HONEST NOTE: the tmux
wrapper's exit marker read 1 (no traceback, error
channel empty, output complete through DONE164);
cause NOT ESTABLISHED; the run was NOT repeated
(one bounded child per contract — the same posture
as AES-NUM-161/163's identical marker).
Output hef164.out: 45,997 lines / 8,828,204 B, sha256
`057dbf2b66c9c6ab4021eab7ec7d044cdcb0c501df817aae7f44164827b59c11`.
Prefix check: of its first 45,835 lines against
hef163.out, exactly TWO lines differ (lines 41,611
and 42,872 — the frozenset element-order variance
already recorded under AES-NUM-150/153–163; same
content and length), all other 45,833 lines
byte-identical (diff verified on-device).
Section164: 162 lines / 46,195 B, sha256
`0b1f6f142c8ab856a03ea7a9493d9414069556da47318a762e5e941452e416b4`,
fetched by a device file read, verified on the VM
to exactly the on-device section sha, and read in
full. Controls: residue-0 sets 37 / 38 / shared 25 /
A-only 12 / B-only 13; byte2 census 85 listings /
96 distinct individual pairs / 11 hubs / 7 pairs at
exactly 3 listings; 8 gap records; gap 8 = run 102,
step 49; context act counts A 749 / B 751; shared
distinct acts 689, all single-positioned; cell
populations 6864 = 27, 6932 = 27, both = 0; matched
cidx keys 27, every key carrying both cells — all
exact. ONE CONTROL EXPECTATION FAILED, and it was
the worker's own, written into arms164 from
AES-NUM-163's abbreviated prose: run 23's length
was expected as 1 (A 300, B 435) and measured as 2
(A 300–301, B 435–436, acts (783191552, 1552, 2) and
(783193104, 14864, 2) — the standard alternating
pair). The measured value is the record; the
4.163 prose's "run 23 (+135, A 300, B 435)" named
only its first act. All other run controls exact
(runs 21/22/46 lengths 2/2/2, shifts +7/+111/−102).
Raw output kept on the Pi at ~/aesir-build/
(hef164.out, hef164.py, arms164.py, section164.txt);
local lineage in ~/workspace/.verify-tmp/aesir164.

## (i) The offset-range boundary between the contexts in full

Context A: 749 acts, 749 distinct offsets, smallest
262,144, largest 791,780,864, largest act end
791,780,888. Context B: 751 acts, 751 distinct
offsets, smallest 262,144, largest 1,196,445,696,
largest act end 1,196,445,720.

B first passes A's largest offset at B offset rank
721 (0-based; 1-based 722): 721 B acts sit at or
below A's max and exactly **30 B acts sit above it,
forming the contiguous offset tail, ranks 721–750**
— the above-A-max population is precisely a suffix
of B's offset order, not a scatter through it.
Every one of the 30 is unshared (identical act in
A 0, same offset in A 0 for all 30). The smallest
above act is (791781376, 24, 1) at B position 748:
+512 past A's largest offset and +488 past A's
largest act end; in B's own offset order it sits
2,536 past the end of its predecessor, the largest
B act at or below A max — (791778816, 24, 0) at
B rank 720 / B position 746, which IS shared
(run 102, A position 744, shift +2). No A act has
an offset at or above the smallest above-B offset
(count 0), so the two contexts' offset ranges
overlap only up to A's ceiling and B alone extends
past it.

The 30 above acts fall in four offset clusters
(derived at closing from the printed table):
two 24 B acts just past the ceiling at B positions
748/747 (offsets +512/+1,024 past A max, at the
very end of B's position order); one 24 B act at
800,053,760 (B position 749, +8,272,896); a 24 B
ladder triple at 873,198,592…873,199,616 (B
positions 1, 0, 27 — at the very head of B's
position order); one 24 B act at 973,679,616
(B position 750); and the main block of 23 acts
from 1,196,182,016 upward (B positions 5, 6, 8, 10,
11, 13–17, 19, 20, 22, 23, 25, 26, 229, 272, 674,
735–738), which contains the thirteen top acts of
AES-NUM-162/163 as its upper 13. Sizes across the
30: 24 B ×14 and one each of 264, 280, 328, 344,
376, 7712, 7800, 14352, 14416, 24848, 26128, 30008,
32728, 32768 and 32784 ×2; channels 0:8, 1:12,
2:10. Inside the main block the offset spacing is
dense (many 0/488/496 steps, the block is nearly
contiguous in offset), while the jumps BETWEEN
clusters are 7–222 M. B's below-boundary top is
position-scrambled against offset order: B offset
ranks 715–720 sit at B positions 729, 731, 732,
733, 734, 746 — all run 102, all shared at shift
+2. Any law behind the four clusters is NOT PROVEN.

## (ii) The 6864/6932 split as a matched-pair comparison

The 27 shared cidx values (2, 5, 8, …, 80, stepping
by 3) each carry exactly one 6864 pair and one 6932
pair, printed side by side with A/B values, byte
fields, status, group, within-pair diff and XOR,
idx and poscat, and every cross relation. The
matching itself is exact by construction: idx equal
in 27 of 27, poscat equal in 27 of 27, group
(20, 32720) in 27 of 27; status equal in 23 of 27
(the four disagreements are cidx 29, 47, 68, 77 —
read off the printed MATCH lines, derived at
closing). A values are identical across the matched
two in 0 of 27; B values in 0 of 27.

**No cross relation is constant, and none is
low-cardinality structured at the whole-value
level:** the matched A int difference, matched B
int difference, matched A XOR, matched B XOR,
both bytewise difference tuples, both within-pair
diffs, the diff relation and the xor relation are
each distinct in 27 of 27 matches. Byte by byte,
the matched differences are likewise wide —
A byte0 difference 11 distinct values, A byte1 25,
A byte2 19, B byte0 11, B byte1 25, B byte2 24 —
**with ONE confined field: the byte3 difference
takes only the three values {14, 15, 16} on the A
side (15 ×13, 16 ×10, 14 ×4) and the same three on
the B side (15 ×20, 16 ×5, 14 ×2).** That is a
range confinement, not a function: within the
confined range the value still varies match by
match, and no tested companion (idx/poscat/status,
all equal or near-equal by construction) separates
14 from 15 from 16. The matched-pair road thus
closes like the field roads before it: the split
is not a constant shift, not a constant XOR, and
not any per-byte constant offset between the two
cells' pairs at the same cidx. The determinant
remains NOT PROVEN.

## (iii) Runs 21/22/23 and 46 in full

All four runs are single pairs, each one contiguous
B block in A order:

- Run 21: +7 pair at A 296–297, B 303–304 — acts
  (783115264, 1552, 2), (783116816, 14864, 2).
- Run 22: +111 pair at A 298–299, B 409–410 — acts
  (783132160, 32784, 2), (783164944, 26128, 2).
- Run 23: +135 pair at A 300–301, B 435–436 — acts
  (783191552, 1552, 2), (783193104, 14864, 2) (the
  pair correction recorded in the closing record
  above).
- Run 46: −102 pair at A 403–404, B 301–302 — acts
  (784951808, 1552, 2), (784953360, 14864, 2).

Run 46's A neighbourhood (A 400–407) is a wall of
positive shifts: run 43 +32 (A 400), run 44 +239
(A 401), run 45 +275 (A 402), then run 46's own
−102 pair, then run 47 +2 (A 405–406) and run 48
+32 (A 407) — run 46 is the lone negative shift in
its A window. Its B neighbourhood (B 298–304)
reads, in position order: run 20's last three acts
(B 298–300, +5), run 46's pair (B 301–302), then
run 21's pair (B 303–304, +7) — so at B, run 46
sits wedged exactly between run 20's block and its
A-successor run 21, the interposition already
noted in AES-NUM-163 now read with both flanks in
full. Mechanisms NOT PROVEN.

## Next

Slice 4.165 — the above-boundary population's
B-position structure in full (the 30 acts as
B-position segments: the head segment at B 0–27,
the tail segment at B 747–750, the main block's
B positions 5–26 and outliers 229/272/674, and
what shares those B windows); the matched-pair
byte3-difference confinement {14, 15, 16} against
every remaining companion (the pairs' A/B byte3
values themselves, cidx/idx order position, the
within-pair diffs' byte3, status); runs 43/44/45
and 47/48 in full (run 46's A neighbours).
Host/artifact analysis only.
