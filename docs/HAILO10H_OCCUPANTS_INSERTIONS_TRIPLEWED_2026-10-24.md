# The missing-slot occupants are their slot families in everything but the loose distances and the tuple's third act — every occupant shares its slot family's length, left position, first tuple act and both companion gap tuples (28 of 28 each), shares the modal second act in all 28, but differs from the modal third act in 25 of 28 and in loose distance d0 in 25 of 28 (the two 25-sets overlap in 23, neither containing the other — re-read of the printed section). The six singleton occupant instances (five distinct rows; the cidx 182 row serves two slot families) each share six of seven key components with their slot family, differing only in the loose distances — except the slot-184 singleton, which shares five, differing in the loose distances AND the loose order; slot 182's singleton shares six of seven with BOTH its slot families, differing from each only in the loose distances. Set side by side gap by gap, the two contexts' insertions are the same sizes in the same order at every gap (19 index-paired acts, sizes equal 19 of 19, size multisets equal at all 8 gaps) but almost never the same channels: at gaps 1–7 every paired act differs in channel (0 of 15 equal) with each side channel-uniform per gap (mappings 1→2, 2→0, 2→0, 0→1, 0→1, 0→1, 1→2) and every paired offset difference zero, while gap 8 alone pairs equal channels (4 of 4) at offset differences of +404,667,368 once and +404,667,392 three times. And B byte 0 wed to status, group AND record count jointly still earns no determination: the three byte-0 keys are injective (224 distinct, 0 repeating), (byte 1, byte 2, byte 3) keeps the same two violating repeats because all four of their pairs carry exactly 27 records, the SAME-only subset repeats the pattern (44 pairs; three keys injective, (byte 1, byte 2, byte 3) the same two violating), and the violating repeats re-read against their records' cells and centres show the two pairs of each repeat identical in cidx span (101..205 step 4), centre span (7..111 step 4) and poscat pattern (26 interior + 1 last), differing ONLY in the cell — (14, 9992, 1744) against (14, 9992, 6944), and (14, 9992, 4336) against (14, 9992, 9832) — mechanisms NOT PROVEN (AES-NUM-143)

Slice 4.143, worked under `docs/TASK_CONTRACT_4.143.md`
(contract published in the 4.142 closing commit @
b04c87e1). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef143.py (the hef142 file verbatim as base — itself
the hef141/hef140/hef139/hef138/hef137/hef136/hef135/
hef134/hef133/hef132/hef131/hef130 lineage — plus the
new arms143) sha256
`ca08a2629f3cc963940d6ca7400ed2198ef040fe675903c22a6ea819a67501da`
(608,775 B); arms143 sha256
`5ff5f13bb5117b7f4d12b50d76f4bb95cc9e3146fc6ab2d46ae4daf60fc58c59`
(21,032 B), its gzip sha256
`536bed6279ebfb99d496ef89468b9d9f69eb114612b72e8c12a42a82364940de`
(5,702 B). The arms were built locally by the
10-minute continuity worker. The crossing used the
per-part route banked in AES-NUM-141/142 as the
primary path: the gzipped arms were split into
250 B parts (23 parts), each part crossed as its own
file.write with its own sha256 gate — every part's
sha256 was verified on-device, all 23 landing clean
on their first attempts. The assembled gzip sha256
matched on-device, the decompressed arms143 sha256
matched the VM's exactly, the on-device hef142.py
base sha256 matched the VM's (`ed731d83…`), and the
assembled hef143.py sha256 matched the VM's exactly
before launch; it compiled on-device (py_compile
OK). Exactly ONE bounded host-side child was
launched, with the contract corpus argv (the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract). The launching
invoke hit the node-level ~125 s timeout while the
child was mid-run; the child was verified alive
on-device by process listing and continued under
its own shell bound, finishing on-device with
DONE143 as the output's last line and the error
channel empty (0 B) — the run's numeric exit marker
was NOT captured, because the launching invoke had
already timed out, and this is recorded as it
happened rather than reconstructed. The output is
34,512 lines / 6,591,081 B, sha256
`7435b1c08e1b60c36807600801a25ddc86b148bf302e968fe082c8561a6a94b8`;
the first 33,992 lines are byte-identical to
hef142.out (verified with cmp on-device), the base
having reproduced line-for-line. The 4.143 section
begins at output line 33,993 and is alone 520 lines
/ 90,302 B, sha256
`f62b470802a86ff472779f7b24f170805c3449253d7a7c9b8be0e20a9da2b9a2`
(section gz sha256
`c37840bd6e39a39d19a4071e85a71238988030442c254115e1a626dbf2f97c21`,
kept on the Pi; one VM retrieval of that gz was
corrupted in re-emission and discarded by its sha
gate, uncommitted — the local lineage in
~/workspace/.verify-tmp/aesir143 holds arms143.py
and hef143.py). Controls EXACT (cells 55,902; obs
527,236; divergent triples 2,171; verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
shared single-positioned acts 689; secondary runs
103, long runs 7, internal gaps 431; gap controls
34 / 30 / 87; doubly-wed families 86 distinct, 15
repeating, 200 rows). Raw output kept on the Pi at
~/aesir-build/ (hef143.out, hef143.py, arms143.py,
section143.txt).

## (i) The missing-slot occupants as a population

For each of the 28 missing lattice slots of
AES-NUM-142, the occupant row (its gap-2 tuple, its
key, its wider-lens features) was read against its
slot family: the family's modal gap-2 tuple
(per-position most common act over the family's
rows), and the family's key components (length,
left position, maximal bet0, gap-0 and gap-1
tuples, loose distances (d0, d1) and loose order).

Against the modal tuple, every occupant shares
position 0 and position 1 (28 of 28 each);
position 2 is shared in only 3 and differs in 25 —
the match-count distribution over occupants is
{2 shared: 25, 3 shared: 3}. Against the slot
family's key components, length, left position,
bet0, gap-0 tuple and gap-1 tuple are EQUAL in
28 of 28 occupants each; loose d1 is equal in 21
and differs in 7; loose order is equal in 27 and
differs in 1; loose d0 is equal in only 3 and
differs in 25. A closing re-read of the printed
section (derived) cross-tabulates the two 25-sets:
(position-2 differs, d0 differs) 23, (position-2
differs, d0 equal) 2, (position-2 shared, d0
differs) 2, (both shared) 1 — the counts coincide
at 25 but the sets do not, and neither difference
implies the other. What an occupant is, measured:
a row carrying its slot family's whole scaffold —
same context length, same left position, same
first two tuple acts in modal form, same companion
gaps — distinguished from the family by its loose
distances and (usually) its third tuple act.

The singleton occupants: 6 instances over 5
distinct rows (the cidx 182 row occupies a missing
slot in two families at once). Read component by
component against their slot families' keys, five
instances share 6 of 7 components, differing ONLY
in the loose distances: slot 181 in family 2,
(2, 10) against (2, 5); slot 182 against family 3,
(8, 2) against (3, 1), and against family 4,
(8, 2) against (7, 1); slot 144 in family 9,
(1, 4) against (1, 3); slot 180 in family 9,
(1, 7) against (1, 3). The sixth instance, slot
184 in family 9, shares 5 of 7: its loose
distances (7, 2) against (1, 3) differ AND its
loose order L0-before-L1 differs from the family's
L1-before-L0 — the population's only order
difference. Slot 182 in full: occupant row
('cc9b9d1c', 182, ((1244657152, 328, 0),
(1244657480, 328, 0), (1513925120, 328, 0)), 713);
its singleton key is (((1244657152, 328, 0),
(8, 2), 'L0-before-L1', gap-0 tuple, gap-1 tuple),
738, 713); the key occurs exactly once in the
whole gap-2 population (the row itself); against
family 3 (22 rows) and family 4 (3 rows) alike it
shares bet0, loose order, both gap tuples, length
738 and left position 713 — 6 of 7 with each —
differing from both only in the loose distances.

## (ii) The gap-by-gap insertion comparison

At each of the 8 non-unit secondary gaps, the
A-side skipped acts and the B-side skipped acts
were set side by side in gap order (offset, size,
channel each), paired by index within the gap.
Per-gap skipped counts are equal at every gap
(2, 5, 1, 4, 1, 1, 1, 4 — 19 a side); size
multisets are equal at every gap; index-paired,
the sizes agree in 19 of 19 pairs, and the corpus
size counts by side are identical ({24: 4, 1552:
1, 14864: 1, 18448: 1, 26128: 5, 32784: 7}).
Channels behave oppositely: at gaps 1–7 the
paired channels agree in 0 of 15 pairs, and each
side's skipped acts are channel-uniform within
the gap, with per-gap A→B channel mappings 1→2
(gap 1), 2→0 (gap 2), 2→0 (gap 3), 0→1 (gap 4),
0→1 (gap 5), 0→1 (gap 6), 1→2 (gap 7); the side
channel totals differ only by the 1↔2 swap
(A {0: 8, 1: 4, 2: 7}; B {0: 8, 1: 7, 2: 4}).
Offset differences (B − A) at gaps 1–7 are zero
in all 15 pairs. Gap 8 (secondary run 102) is the
single exception on both measures: its 4 pairs
agree in channel 4 of 4 (channels 0, 1, 2, 0 in
order on both sides) and in size (24 each), but
their offset differences are +404,667,368 once
and +404,667,392 three times — the B-side acts sit
at offsets 1,196,444,160 and onward against the
A-side 791,776,792 and onward, the same small
insertion read at a wholly different address.
Any mechanism behind the per-gap channel mapping
or gap 8's relocation is NOT PROVEN.

## (iii) B byte 0 wed to status, group and record count jointly

Wed key = ((status, group, record count),
three-byte value of A) over the full 224 pairs
(record-count distribution printed; the pairs of
the violating repeats each carry 27 records). The
three byte-0-containing sub-keys are injective
under the triple wed: 224 distinct wed values, 0
repeating, 0 agreeing, 0 violating each — no
determination earned (a function claim from zero
repeats would be vacuous, and none is made).
(byte 1, byte 2, byte 3) gives 222 distinct wed
values, 2 repeating, 0 agreeing, 2 VIOLATING —
the same two values as under every weaker wed:
(('SAME', (14, 9992), 27), (1, 176, 128)) -> B
byte 0 set {28, 32} and (('SAME', (14, 9992), 27),
(1, 178, 128)) -> {20, 24}. The record-count wed
does not split them, because all four pairs carry
exactly 27 records. Inside the SAME-only subset
(44 pairs) the joint-wed tests repeat the pattern
at subset scale: the three byte-0 keys injective
(44 distinct, 0 repeating), (byte 1, byte 2,
byte 3) 42 distinct with the same 2 violating
repeats.

The two violating repeats re-read against their
records' cells and centres: within each repeat,
the two pairs' records are indistinguishable on
every printed axis but one. Both pairs of the
(1, 176, 128) repeat carry cidx span 101..205
step 4 (27 records), centre span 7..111 step 4,
poscat counts {interior: 26, last: 1} — and so do
both pairs of the (1, 178, 128) repeat. The sole
difference is the cell: (14, 9992, 1744) for
A 1c01b080 -> B 1c01b000 against (14, 9992, 6944)
for A 2001b080 -> B 2001b000; (14, 9992, 4336) for
A 1401b280 -> B 1401b200 against (14, 9992, 9832)
for A 1801b280 -> B 1801b200. Each pair carries
exactly one cell. The violation therefore
survives status, group and record count, and its
two pairs are separated, on the record evidence
printed, by nothing but the cell's third
component — whether the cell (or anything else)
determines B byte 0 is NOT PROVEN, and no
determination is claimed.

## Next

Slice 4.144: the occupants read against their OWN
families (the symmetric comparison — modal tuple
and key components of the occupant's own doubly-wed
family, with the slot-family and own-family
comparisons cross-tabbed for position 2 and d0);
the per-gap channel mapping read against the gaps'
bounding acts (left and right acts' channels and
the run shift at each gap) and gap 8's B-side
insertion neighbourhood in context B (the acts
immediately around the insertion point); and B
byte 0 against the four three-byte sub-keys wed to
status, group, record count AND cell jointly, with
the cell's third component tested as a companion
across the full 224 pairs. Mechanisms NOT PROVEN.
