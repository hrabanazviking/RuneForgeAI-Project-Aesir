# Gaps 3 and 7, read in full, are the same gap twice over in everything that bounds them — same secondary run (74), same shift (0), same run length (83) and extent (positions 524–614 in both contexts), same bounding channels (1, 0), same distances (2 in A, 2 in B), one skipped act a side — and they differ only in where in the run they sit (steps 24 and 48; A/B positions 548/550 against 579/581), in the identities of the acts themselves, and in the skipped acts they carry: gap 3's skipped act is (788357120, 32784, channel 2 in A → 0 in B), gap 7's is (789100544, 26128, channel 1 in A → 2 in B). Of the 32 features the printed rows support, 13 are equal and 19 differ, and every differing feature is a location, an identity, or a property of the skipped acts — no bounding-side feature distinguishes the two mappings ((2→0) against (1→2)), so the mapping's home is not at the bounds; mechanism NOT PROVEN. The 8 violating cell repeats earn no rescue from any record-level companion: over their 216 pairs, B byte 0 is not a function of the centre set (a single key — every pair's centre set is {127} — violating over all 216), not of the cidx set (27 distinct keys, all 27 repeating and violating), not of the poscat pattern (3 distinct keys, all violating), and not of the per-record (cidx, centre) sequence (27 distinct, all violating); the per-cell B byte 0 sets run 2, 4, 7, 8, 11, 13, 17, 19 values across the eight cells (third components 6796…7272). And the quad-wed injectivity, dissected, belongs to neither added companion: under the three sub-keys that contain byte 0 the base (status, group, record count, sub-key) wed is already injective (224 distinct base values, no multi-pair group at all, so both additions are vacuous there), and under (byte1, byte2, byte3) — the one sub-key with any work to do, 222 base values and 2 multi-pair groups — the two pair-pairs are separated by BOTH the cell and A byte 0 (both separate 2; cell-only 0; A-byte-0-only 0; neither 0), and each completed wed is injective (224 distinct, 0 repeating) — mechanisms NOT PROVEN (AES-NUM-145)

Slice 4.145, worked under `docs/TASK_CONTRACT_4.145.md`
(contract published in the 4.144 closing commit @
6522e679). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef145.py (the hef144 file verbatim as base — itself
the hef143/hef142/hef141/hef140/hef139/hef138/hef137/
hef136/hef135/hef134/hef133/hef132/hef131/hef130
lineage — plus the new arms145) sha256
`22d15f197a67cd8b254a04d2ee64c409a317f5e892b18c63406672fd8840015e`
(650,278 B); arms145 sha256
`3f4f63de5b60be661b01d204e0c3240bb478cff2dc2d2d3da10205c8d955265e`
(16,852 B), its gzip sha256
`a73a07310d7f98417bb2d4f3641ce007860e16580f5700093b98660c675ca007`
(4,778 B). The arms were built locally by the
10-minute continuity worker. The crossing used the
per-part route banked in AES-NUM-141/142/143/144: the
gzipped arms were split into 440 B parts (11 parts),
each part crossed as its own file.write with its own
sha256 gate — every part's sha256 was verified
on-device and all eleven landed clean on their first
attempts. The assembled gzip sha256 matched on-device,
the decompressed arms145 sha256 matched the VM's
exactly, the on-device hef144.py base sha256 matched
the VM's (`438451f8…`), and the assembled hef145.py
sha256 matched the VM's exactly before launch; it
compiled on-device (py_compile OK). Exactly ONE
bounded host-side child was launched for the main
arms, in a detached tmux session with the contract
corpus argv (the six hailo-ollama blobs in glob
order, then MiniLM — the launch law recorded in the
contract). That child ran arms (i) and (ii) in full
and the first sub-key's two wed reports in arm (iii),
then crashed on a typo in the separation dissection
(`status145(p)` for `status145(p145)`; TypeError,
exit marker 1, error channel 692 B) — recorded here
honestly, not reconstructed. Its output is 37,186
lines / 7,147,309 B, sha256
`f0613b1160e98f9f1092c2c6daf17458d6faa310fec6dd72064ef53ea4dd4310`;
the first 35,712 lines are byte-identical to
hef144.out (verified with cmp on-device), the base
having reproduced line-for-line. The 4.145 section
begins at output line 35,713 and is 1,474 lines /
311,033 B, sha256
`aa1fb946b31bda91666de8b795921523177829b866763dc0acad44b6c0b5f33b`
(section gz sha256
`9d9533826e30c78269e9f2f645d0e446613267bd78b535537cd1a629e30fb170`,
kept on the Pi). The missing dissection was completed
by a labelled follow-up in the established
hefXXb pattern: hef145b.py (the hef144 base plus
arms145b, arm (iii) only, corrected) sha256
`cc405f08aff108bc8ba8b4f0b43f19bda4baeee573dc0e2f28d900b49601e196`;
arms145b sha256
`ec45e46a0faca468cbed26bd400ad04091d007ad5a379d32b67b0b70d0ed88e6`
(6,794 B), its gzip sha256
`25f2335dfaba5cbb75e8a9dc5b80b71df64c96bb81898fd4d282c2f00f83c087`
(2,172 B), crossed as 5 individually sha-gated 440 B
parts, all landing clean first try, assembled and
assembled-script sha256 verified on-device == VM,
compiled on-device. The follow-up child finished
with DONE145B as its output's last line, exit marker
0, and the error channel empty. Its output is 35,746
lines / 6,841,088 B, sha256
`84d56fc9987969ee01fec1c808a7f4a04d8d20004125eab159bc5df1f14e8564`;
the first 35,712 lines are byte-identical to
hef144.out (cmp verified on-device). The 4.145b
section is 34 lines / 4,812 B, sha256
`1f46d52eea4f575ade4dbf1b3133427d0fa5eb1af658f9261d8f93f0cef07dda`
(section gz sha256
`4920c4a938b9ab72fa192c47896f33488c84bfbc06354f5b6185067786f4824c`,
kept on the Pi). Controls reproduce exactly in both
runs: cells 55,902, observations 527,236, divergent
triples 2,171, verdicts CONT 12,411 / BREAK 476 /
INDET 2,365; lane-1 pairs 224 with 222 keys under
both control maps; shared single-positioned acts
689, secondary runs 103, secondary long runs 7,
secondary internal gaps 431; gap controls 34 / 30 /
87; gap records 8. Raw output kept on the Pi at
~/aesir-build/ (hef145.out, hef145.py, arms145.py,
section145.txt, hef145b.out, hef145b.py, arms145b.py,
section145b.txt); local lineage in
~/workspace/.verify-tmp/aesir145.

## (i) Gaps 3 and 7 in full against each other

Both gaps sit in the same secondary run — run 74,
shift +0, 83 acts, A extent and B extent both
positions 524–614 — at steps 24 (gap 3) and 48
(gap 7). Their bounding acts are identical in both
contexts, as AES-NUM-144 found at all sixteen bounds:
gap 3 is bounded by (788330544, 26128, 1) at A/B
position 548 and (788390400, 32784, 0) at A/B
position 550; gap 7 by (789067376, 32784, 1) at
579 and (789127168, 1552, 0) at 581 — bounding
channels (1, 0) in both gaps, bounding shifts 0
and 0, distances 2 in A and 2 in B, one skipped act
on each side of each gap.

The skipped acts are the gaps' own: gap 3's A-side
skipped act is (788357120, 32784, 2) and its B-side
twin the same offset and size at channel 0 — the
mapping ((2→0),); gap 7's A-side skipped act is
(789100544, 26128, 1) and its B-side twin the same
offset and size at channel 2 — the mapping
((1→2),). The two-act surrounding windows in both
contexts were printed in full for both gaps.

The side-by-side table over every candidate feature
the printed rows support (32 features) reads 13
EQUAL — run, run shift, run length, both run
extents, both bounding shifts, both gap distances,
both skipped counts — and 19 DIFFERS: step, both
bounding acts' identities (offsets and sizes; their
channels are equal), both gaps' A and B positions,
the skipped acts' sizes (32784 against 26128),
offsets and channels on both sides, the channel
mapping itself, and both surrounding windows. No
feature of the bounding side separates the two
gaps; the features that differ are the gaps'
locations in the run, the acts' identities, and
properties of the skipped acts themselves. Any
relation between those and the mapping is NOT
PROVEN — with two gaps, a differing feature is a
candidate, never a law.

## (ii) The 8 violating cell repeats against record-level companions

The eight cells are (20, 32720, 6796), (6864),
(6932), (7000), (7068), (7136), (7204) and (7272) —
27 pairs each, 216 pairs in all, every pair carrying
exactly one record (reccount 1 in this population's
printed records; the pairs are the AES-NUM-144
companion population restricted to the repeating
cells). Their B byte 0 sets carry 2, 4, 7, 8, 11,
13, 17 and 19 distinct values respectively, in cell
order; their SAME/DIFF splits run from 17/10 in the
6796 cell to 1/26 in the 7000, 7068, 7136 and 7204
cells.

Over the 216 pairs, B byte 0 was tested as a
function of each record-level companion the
contract named, counted exactly:

- centre set: 1 distinct key, 1 repeating, 0
  agreeing, 1 violating — every pair in the
  population carries centre set {127}, so the
  companion is constant here and the single key
  violates over all 216 pairs;
- cidx set: 27 distinct keys, 27 repeating, 0
  agreeing, 27 violating;
- poscat pattern (the record-order tuple): 3
  distinct keys, 3 repeating, 0 agreeing, 3
  violating;
- per-record (cidx, centre) sequence: 27 distinct
  keys, 27 repeating, 0 agreeing, 27 violating —
  the same partition as the cidx set, the centre
  being constant.

No companion earns a determination; no companion
even earns an agreeing repeat. By the stated
strongest-companion rule (fewest violating keys,
then most distinct keys) the centre set ranks first
with its single violating key — a ranking artefact
of its constancy, recorded as such, not a finding.
Each cell's 27 pairs were printed in full once
under that companion in the raw section. Mechanisms
NOT PROVEN.

## (iii) The quad-wed injectivity dissected

For each three-byte sub-key, B byte 0 was tested
against (status, group, record count, cell, sub-key)
— the AES-NUM-144 quad wed — and against (status,
group, record count, A byte 0, sub-key), the same
wed with A byte 0 added instead of the cell; and
the pairs sharing a base (status, group, record
count, sub-key) value were dissected by which added
companion separates them. The main child's two
reports for the first sub-key and the corrected
follow-up's full run agree exactly.

Under (byte0, byte1, byte2), (byte0, byte1, byte3)
and (byte0, byte2, byte3): both completed weds are
injective (224 distinct wed values, 0 repeating,
0 agreeing, 0 violating), and the base wed is
already injective — 224 distinct base values and
no multi-pair base group at all — so there is no
pair-pair for either companion to separate, and
the separation lists are empty in full. The
injectivity under these sub-keys is earned by the
base wed alone; neither addition does any work.

Under (byte1, byte2, byte3): both completed weds
are again injective (224 distinct, 0 repeating).
The base wed has 222 distinct values and exactly
2 multi-pair groups — the two AES-NUM-143
violating repeats — holding 2 unordered pair-pairs.
Both pair-pairs are separated by both companions
(both separate 2; cell separates but A byte 0 does
not 0; A byte 0 separates but the cell does not 0;
neither separates 0), and the two separation lists
are therefore empty in full: in the only case in
the whole dissection where an added companion has
work to do, the cell and A byte 0 do exactly the
same work. Per sub-key, the statement is uniform:
neither added companion leaves any repeating wed
value — and for three of the four sub-keys, neither
was needed. Any determination of B byte 0 from
either completed wed would be a claim from zero
repeats and is NOT made; mechanisms NOT PROVEN.

## Next

Slice 4.146 — the per-gap channel mapping as a
function of the A-side skipped acts themselves
(their sizes, channels, and offset residues) over
all 8 gaps, with gaps 3 and 7's skipped acts read
against the corpus (their occurrence counts
elsewhere); B byte 0 over the 216 violating-cell
pairs against the remaining record-level companions
(the per-record idx sequence, the in37 pattern,
A byte 0 as a companion, and the per-record
(cidx, idx) sequence); and the two (byte1, byte2,
byte3) base-group pair-pairs read in full against
each other, record by record. Host/artifact
analysis only — no physical child.
