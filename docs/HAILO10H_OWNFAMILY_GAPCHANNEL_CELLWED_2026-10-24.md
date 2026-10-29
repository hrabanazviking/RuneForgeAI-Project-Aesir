# The occupants match their OWN families' modal third act in all twenty-eight cases — the very act that set twenty-five of them apart from their slot families — while the loose-distance match against their own families is identity by construction (the distances are a component of the key that names the family, and every row of a family carries the same key components). Cross-tabbed, position 2 reads (slot differs, own matches) in 25 and (both match) in 3 over all twenty-eight occupants — over the twenty-two repeating-row occupants alone, (slot differs, own matches) in 21 and (both match) in 1 — and loose d0 reads the same totals over all twenty-eight, (slot differs, own equal) in 22 of the twenty-two repeating occupants; the six singleton instances (five distinct rows) have as their own family themselves alone. The per-gap channel mapping is NOT a function of the gaps' bounding acts or shifts: every bounding act is the identical act in both contexts (channel in A equals channel in B at all sixteen bounds), the one bounding-channel key that repeats — (1, 0), at gaps 3 and 7 — carries two different mappings ((2→0) and (1→2)), the bounding-shift keys violate in both their repeating keys, and the global paired channel map is one-to-many in every channel ({0: [0, 1], 1: [1, 2], 2: [0, 2]}). Gap 8's B-side insertion is a four-act run of 24 B acts at B positions 735–738, offsets 1,196,444,160 stepping by 512 with channels 0, 1, 2, 0 — a block from a wholly different offset region, set between neighbours at offsets 791,776,768 and 768,609,280. And B byte 0 wed to status, group, record count AND cell jointly is injective under all four three-byte sub-keys (224 distinct wed values, 0 repeating) — the cell component splits the two AES-NUM-143 violating repeats (their pairs carry cells (14, 9992, 1744) against (14, 9992, 6944), and (14, 9992, 4336) against (14, 9992, 9832), with each pair's B byte 0 equal to its own A byte 0: 28/32 and 20/24) — but with no repeating wed value anywhere, no determination is earned (a function claim from zero repeats would be vacuous, and none is made). The cell as a companion on its own is NOT a function of B byte 0 either way: all 224 pairs carry exactly one cell, there are only 16 distinct cells, and the 8 repeating cells — all in group (20, 32720), 27 pairs each, third components 6796, 6864, 6932, 7000, 7068, 7136, 7204, 7272 — all violate, with B byte 0 sets of 2 to 19 values; the cell's third component alone gives the identical test (16 distinct thirds, the same 8 violating repeats), and (cell, A byte 0) jointly still violates (99 distinct keys, 41 repeating, 5 agreeing, 36 violating) — mechanisms NOT PROVEN (AES-NUM-144)

Slice 4.144, worked under `docs/TASK_CONTRACT_4.144.md`
(contract published in the 4.143 closing commit @
0f35786c). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef144.py (the hef143 file verbatim as base — itself
the hef142/hef141/hef140/hef139/hef138/hef137/hef136/
hef135/hef134/hef133/hef132/hef131/hef130 lineage —
plus the new arms144) sha256
`438451f8e1f0c07cc67ba94bb304a461dbf07c25dded566f01f672599911a4eb`
(633,426 B); arms144 sha256
`d7b0f1710ee128318e38e02844205624e234d5f462608bb9dc017d160698715a`
(24,651 B), its gzip sha256
`d7fc726a2cca157877008bbd8306566602cc09c3becfe1597f353bfecaaa48e7`
(6,528 B). The arms were built locally by the
10-minute continuity worker. The crossing used the
per-part route banked in AES-NUM-141/142/143: the
gzipped arms were split into 440 B parts (15 parts),
each part crossed as its own file.write with its own
sha256 gate — every part's sha256 was verified
on-device; fourteen parts landed clean on their
first attempts, and one part (g_am) was corrupted
in re-emission, was rejected by the gate uncommitted,
and landed clean on a verbatim re-send. The assembled
gzip sha256 matched on-device, the decompressed
arms144 sha256 matched the VM's exactly, the on-device
hef143.py base sha256 matched the VM's
(`ca08a262…`), and the assembled hef144.py sha256
matched the VM's exactly before launch; it compiled
on-device (py_compile OK). Exactly ONE bounded
host-side child was launched, in a detached tmux
session with the contract corpus argv (the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract). The child
finished on-device with DONE144 as the output's last
line, exit marker 0, and the error channel empty
(0 B). The output is 35,712 lines / 6,836,276 B,
sha256
`f68ff73b824463beafdcc5dfc37ce230736b7af167e458aaf8832ebaea913baf`;
the first 34,512 lines are byte-identical to
hef143.out (verified with cmp on-device), the base
having reproduced line-for-line. The 4.144 section
begins at output line 34,513 and is alone 1,200 lines
/ 245,195 B, sha256
`59bbf3605c3ef201ddc8c19353064d820b2e986fa5f7ec74f0e9b491c554e4b3`
(section gz sha256
`9889290ab9e81d216082824d3bab35bfc4221f53aa5f6b78536aa465cf86c311`,
kept on the Pi). Controls reproduce exactly: cells
55,902, observations 527,236, divergent triples
2,171, verdicts CONT 12,411 / BREAK 476 / INDET 2,365;
lane-1 pairs 224 with 222 keys under both control
maps; shared single-positioned acts 689, secondary
runs 103, secondary long runs 7, secondary internal
gaps 431; gap controls 34 / 30 / 87; doubly-wed
families 86 distinct keys, 15 repeating, 200 rows in
repeating families. Raw output kept on the Pi at
~/aesir-build/ (hef144.out, hef144.py, arms144.py,
section144.txt); local lineage in
~/workspace/.verify-tmp/aesir144.

## (i) The occupants against their own families

Every one of the 28 missing-slot occupants (22 rows
of another repeating family, 6 singleton instances
over 5 distinct rows — the cidx 182 row again filling
slots in two families) was read against the family
its own key names, symmetric to the AES-NUM-143 slot
comparison, and the two comparisons cross-tabbed.

Against their own families' modal gap-2 tuples, the
occupants match at positions 0 and 1 in 28 of 28 —
as they did against their slot families — and at
position 2 in 28 of 28, where the slot comparison
matched in only 3. The cross-tab for position 2 over
all 28 occupants is {(slot differs, own matches):
25, (both match): 3} — there is no occupant whose
third act differs from its own family's modal third
act, and no occupant whose third act matches its
slot family's modal but not its own. Over the 22
repeating-row occupants alone the cross-tab is
{(slot differs, own matches): 21, (both match): 1}.

The key-component comparison against an occupant's
own family is identity by construction and is
recorded as such, not as a finding: the doubly-wed
key's components (bet0, loose distances, loose order,
both gap tuples, length, left position) are the same
for every row of a family because they ARE the key,
and the printed own-family d0 distributions confirm
the construction (each occupant's own family carries
a single d0 value across all its rows — 3 of 3, 22 of
22, 2 of 2 in the printed distributions). The loose
d0 cross-tab therefore reads {(slot differs, own
equal): 25, (both equal): 3} over all 28 and
{(slot differs, own equal): 22} over the repeating
occupants, with the own side tautological; the
substantive content of this arm is the modal-tuple
result above and the singleton statement: the six
singleton instances' own families are themselves
alone (1 row each) — slots 181 (family 2), 182
(families 3 AND 4, the same row), 144, 180 and 184
(family 9) — printed in full in the section.

## (ii) The per-gap channel mapping against the bounding acts; gap 8's B-side neighbourhood

For each of the 8 non-unit secondary gaps, the left
and right bounding acts were printed in both
contexts. Every bounding act is the identical act
tuple in context A and in context B — channel in A
equals channel in B at all 16 bounds (derived from
the printed rows: left/right channels (1, 2), (2, 0),
(1, 0), (0, 2), (2, 1), (1, 1), (1, 0), (0, 0) for
gaps 1–8) — so the A-side and B-side bounding-channel
tests coincide exactly.

The mapping is NOT a function of the bounding
channels: the key (left 1, right 0) repeats at gaps
3 and 7 with two different mappings, ((2→0),) and
((1→2),) — 7 distinct keys over 8 gaps, 1 repeating,
1 violating, under either context's channels, and
the same violating key survives wedging the shifts
to the channels (7 distinct, 1 repeating, 1
violating). It is NOT a function of the bounding
shifts either: key (0, 0) covers gaps 3–7 with three
different mappings ((2→0), (0→1), (1→2)) and key
(3, 3) covers gaps 1–2 with two ((1→2), (2→0)) — 3
distinct keys, 2 repeating, both violating. It is
NOT a function of the gap distances: key (2, 2)
covers gaps 3, 5, 6, 7 with three mappings and key
(5, 5) covers gaps 4 and 8 with two — 4 distinct
keys, 2 repeating, both violating. The global paired
channel map over all 19 paired skipped acts is
one-to-many in every channel: {0: [0, 1], 1: [1, 2],
2: [0, 2]} (each gap's own mapping stays a single
channel pair at gaps 1–7 and the identity at gap 8,
as AES-NUM-143 found).

Gap 8's B-side insertion neighbourhood in context B,
in full (B positions 732–741): the context acts
before the insertion are the 24 B acts at offsets
791,775,744 (channel 1) and 791,776,256 (channel 2);
the left bounding act at B position 734 is
(791,776,768, 24, channel 0); the four inserted acts
at B positions 735–738 are 24 B acts at offsets
1,196,444,160 / 1,196,444,672 / 1,196,445,184 /
1,196,445,696 (step 512) with channels 0, 1, 2, 0;
the right bounding act at B position 739 is
(768,609,280, 24, channel 0), followed by context
acts at 768,609,792 (channel 1) and 768,610,304
(channel 2). Against their B neighbours the inserted
acts sit +404,667,392 / +404,667,904 / +404,668,416 /
+404,668,928 above the left bounding offset and
−427,834,880 / −427,835,392 / −427,835,904 /
−427,836,416 below the right bounding offset — a
self-contained block of the same 512-step 24 B form
as its A-side counterparts (whose paired offset
differences are +404,667,368 once and +404,667,392
three times, per AES-NUM-143, re-printed here), in
an offset region neither neighbour occupies.

## (iii) B byte 0 wed to status, group, record count AND cell; the cell's third component as companion

All 224 lane-1 pairs carry exactly one cell (the
distinct-cells-per-pair distribution is {1: 224}),
so the quad wed and the companion tests run over the
full population with no exclusion.

Wed to (status, group, record count, cell) jointly,
all four three-byte sub-keys are injective:
(byte 0, byte 1, byte 2), (byte 0, byte 1, byte 3),
(byte 0, byte 2, byte 3) and (byte 1, byte 2, byte 3)
each give 224 distinct wed values, 0 repeating, 0
agreeing, 0 violating. The cell component therefore
DOES split the two violating repeats that survived
every earlier wed: under the triple wed of
AES-NUM-143 the (byte 1, byte 2, byte 3) repeats are
(('SAME', (14, 9992), 27), (1, 176, 128)) with B byte
0 set {28, 32} and (('SAME', (14, 9992), 27),
(1, 178, 128)) with B byte 0 set {20, 24}; re-read in
full, the first repeat's pairs carry cells
(14, 9992, 1744) with A byte 0 = B byte 0 = 28 and
(14, 9992, 6944) with A byte 0 = B byte 0 = 32, and
the second's carry (14, 9992, 4336) with A byte 0 =
B byte 0 = 20 and (14, 9992, 9832) with A byte 0 =
B byte 0 = 24 (each pair 27 records, cidx span
101..205 step 4, as before). But with zero repeating
wed values under any sub-key, the quad wed earns NO
determination: a function claim from zero repeats
would be vacuous, and none is made. The pattern of
the earlier vacuous weds (context index, quotient)
repeats one level down.

The companion tests close the other direction. B
byte 0 as a function of the cell over the 224
single-cell pairs: 16 distinct cells, 8 repeating,
0 agreeing, 8 violating — NOT A FUNCTION. Every
repeating cell is in group (20, 32720), carries 27
pairs, and its third component runs 6796, 6864,
6932, 7000, 7068, 7136, 7204, 7272 (step 68); their
B byte 0 sets grow from {0, 128} at 6796 to 19 values
at 7272. B byte 0 as a function of the cell's third
component alone is the identical test (16 distinct
thirds, the same 8 violating repeats — the third
component distinguishes these cells completely).
Even (cell, A byte 0) jointly does not determine B
byte 0: 99 distinct keys, 41 repeating, 5 agreeing,
36 violating — NOT A FUNCTION.

## Next

Slice 4.145 — (i) gaps 3 and 7, the sole
bounding-channel violating pair, read in full
against each other (run context, bounding acts'
full identities, skipped acts, and the surrounding
acts in both contexts — what, beyond bounding
channels, shifts and distances, distinguishes
them); (ii) the 8 violating cell repeats (27 pairs
each, group (20, 32720)): B byte 0 against
record-level companions (centre sets, cidx sets,
poscat patterns, record counts by centre) over
those 216 pairs; (iii) the quad-wed injectivity
dissected — the (status, group, record count) wed
with A byte 0 as the added companion against the
same wed with the cell added, over the full 224
pairs (does A byte 0 split exactly what the cell
splits?). Host/artifact analysis only — no
physical child.
