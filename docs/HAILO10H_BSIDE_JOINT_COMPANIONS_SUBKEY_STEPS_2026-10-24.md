# The channel mapping is not a function of the second side's skipped acts either — not of their sizes (the single size 32784 carries both (2→0) and (0→1) at gaps 3, 5 and 6), not of their offset residues mod 512 (residue 0 carries all three mappings at gaps 3, 5, 6 and 7), and not of their count (one skipped act carries all three mappings; four carry both the identity set and (0→1)) — while the B-side channels and the paired (size, channel) tuples earn exactly one agreeing repeat and no violating one (gaps 5 and 6, channel (1,) → (0,1)), the mirror of the A-side result, a single repeat on eight gaps from which no determination is claimed; the joint (A channel, B channel) tuple's identical verdict is tautological, its value being the mapping's full paired sequence itself. Read channel-blind, gaps 3 and 7's skipped (offset, size) pairs are not corpus-unique but corpus-paired: each occurs exactly twice in the whole seven-artifact corpus, both times in blob 5ab3537d at the same position (549 for gap 3, 580 for gap 7), in contexts 86 and 210 — the two occurrences are the gap's own A-side and B-side acts (gap 3: channel 2 in context 86, channel 0 in context 210; gap 7: channel 1 in context 86, channel 2 in context 210). The 216 violating-cell pairs earn no determination from the joint companions either: the two joints built on the constant in37 pattern collapse exactly onto their single companions ((in37, A byte 0) = A byte 0 alone, 33 distinct / 22 repeating / 0 agreeing / 22 violating; (idx, in37) = idx alone, 27 / 27 / 0 / 27), and the two genuinely refining joints, (idx sequence, A byte 0) and ((cidx, idx) sequence, A byte 0), give identical verdicts to each other (167 distinct, 42 repeating, 7 agreeing, 35 violating) — they are the first companions of any kind over this population to earn an agreeing repeat, and they still violate. And the byte-0 step, tested over every pair-pair sharing the (byte1, byte2, byte3) sub-key alone over the full 224 pairs, has exactly the same population as the wed base groups: 2 sub-key groups, 2 pair-pairs, byte 0 rising by exactly +4 in both (B byte 0 difference also +4; B-minus-A byte 0 is 0 in all four pairs), cell thirds rising by 5,200 and 5,496 — no further pair-pair shares the sub-key alone, so the step's whole measured population is those two — mechanisms NOT PROVEN (AES-NUM-147)

Slice 4.147, worked under `docs/TASK_CONTRACT_4.147.md`
(contract published in the 4.146 closing commit @
b5d31958). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef147.py (the corrected hef146b file verbatim as base
plus the new arms147) sha256
`363ba7d3289a0173c31896ef05a0e22945fd04efc54e859f2593269bfde608dc`
(677,032 B); arms147 sha256
`b16f549c541ab7871fa791eec8612c1f9534c39508e4bbe8e85b4bc618a815e1`
(13,779 B), its gzip sha256
`9bdaed4c2b85e811abbd58466eb6d2405019a6bcb229bece471f69a66e93c46b`
(3,965 B). The arms were built locally by the
10-minute continuity worker on the hef146b lineage
(the contract-named base; the uncorrected hef146 main
file was NOT used). The crossing used the per-part
sha-gated route banked in AES-NUM-141…146: the
gzipped arms were split into 440 B parts (10 parts),
each part crossed as its own file.write with its own
sha256 gate — five parts verified on-device first
try; one part (g_af) was corrupted in re-emission
(invalid base64, rejected by the schema gate
uncommitted) and healed by the banked boundary-change
rule: the five remaining parts (g_af…g_aj) were
re-split into 220 B halves, each half sha-gated and
verified on-device first try, and the 440 B parts
reassembled on-device with their original whole-part
sha256 values matching exactly. The assembled gzip,
arms and hef147 sha256 all matched the VM exactly
on-device, and the script compiled on-device
(py_compile OK). Exactly ONE bounded host-side child
was launched for the contract, in a detached tmux
session with the contract corpus argv (the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract). That child
finished with DONE147 as its output's last line, exit
marker 0, and the error channel empty. Its output is
40,401 lines / 7,764,290 B, sha256
`d627229256c7e7bd8519d321f068237972ff56ad9175519dc41c6481bf4e617e`;
the first 39,137 lines are byte-identical to
hef146b.out (cmp verified on-device), and the 4.147
section begins at output line 39,138 and is 1,264
lines / 261,393 B, sha256
`ec7783addb5205784f3dee6f4bb4e352a0132e9386ebbd9e35b49e9b54627a2a`
(section gz sha256
`1820bf59e953f9fc75ac43a0c0a86196b899cb4e9b0bb58a710295684703ecbd`,
kept on the Pi). Controls reproduce exactly: cells
55,902, observations 527,236, divergent triples
2,171, verdicts CONT 12,411 / BREAK 476 / INDET
2,365; lane-1 pairs 224 with 222 keys under both
control maps; shared single-positioned acts 689,
secondary runs 103, secondary long runs 7, secondary
internal gaps 431; gap controls 34 / 30 / 87; gap
records 8. Raw output kept on the Pi at
~/aesir-build/ (hef147.out, hef147.py, arms147.py,
section147.txt); local lineage in
~/workspace/.verify-tmp/aesir147.

## (i) The mapping against the B-side and joint skipped acts

All eight gaps were printed in full (run, step,
skipped acts on both sides, mapping set and paired
sequence). Each candidate feature was tested as a
determinant of both the mapping set and the full
paired sequence, counted exactly over the 8 gaps; the
two targets give identical verdicts for every feature:

- B skipped sizes tuple: 6 distinct keys, 1
  repeating, 0 agreeing, 1 violating — the size
  tuple (32784,) is carried by gaps 3, 5 and 6 with
  targets ((2,0),) and ((0,1),): NOT a function.
- B skipped channels tuple: 7 distinct, 1
  repeating, 1 agreeing, 0 violating — the channel
  tuple (1,) repeats only at gaps 5 and 6, both
  ((0,1),). No violating repeat, but a single
  agreeing repeat on eight gaps earns no
  determination. This is the exact mirror of the
  A-side channels result in AES-NUM-146.
- B skipped offsets tuple: 8 distinct, 0 repeating
  — vacuous on these 8 gaps.
- B skipped offset residues mod 512: 5 distinct, 1
  repeating, 0 agreeing, 1 violating — the residue
  tuple (0,) is carried by gaps 3, 5, 6 and 7 with
  all three targets ((2,0),), ((0,1),), ((1,2),):
  NOT a function.
- B skipped offset residues mod 32784: 8 distinct,
  0 repeating — vacuous.
- B skipped paired (size, channel) tuples: 7
  distinct, 1 repeating, 1 agreeing, 0 violating —
  the pair tuple ((32784, 1),) repeats only at gaps
  5 and 6, both ((0,1),): the same single agreeing
  repeat as the B channels alone.
- B skipped count: 4 distinct, 2 repeating, 0
  agreeing, 2 violating — count 1 is carried by
  gaps 3, 5, 6 and 7 with all three targets, and
  count 4 by gaps 4 and 8 with ((0,1),) against the
  identity set: NOT a function.
- Joint (A act, B act) paired tuples: 8 distinct, 0
  repeating — vacuous on these 8 gaps.
- Joint (A channel, B channel) paired tuples: 7
  distinct, 1 repeating, 1 agreeing, 0 violating —
  the agreeing repeat is the key ((0,1),) at gaps 5
  and 6. Recorded as TAUTOLOGICAL: this feature's
  value at each gap is the mapping's full paired
  sequence itself, so its verdict restates the
  target's own repetition pattern and earns nothing.
- Joint (A size, B size) paired tuples: 6 distinct,
  1 repeating, 0 agreeing, 1 violating — the tuple
  ((32784, 32784),) is carried by gaps 3, 5 and 6
  with ((2,0),) and ((0,1),): NOT a function.

Channel-blind corpus read of gaps 3 and 7's skipped
(offset, size) pairs (index over the whole corpus:
542,050 distinct (offset, size) pairs, 745,849
occurrences, 7 artifacts). Because the A-side and
B-side skipped acts of each of these gaps share the
same (offset, size), each gap contributes one
channel-blind key:

- Gap 3, (788357120, 32784): exactly 2 corpus
  occurrences, in 2 contexts, both in blob 5ab3537d,
  both at position 549 — context 86 on channel 2
  (the A-side act) and context 210 on channel 0
  (the B-side act). Channels distribution {0: 1, 2: 1}.
- Gap 7, (789100544, 26128): exactly 2 corpus
  occurrences, in 2 contexts, both in blob 5ab3537d,
  both at position 580 — context 86 on channel 1
  (the A-side act) and context 210 on channel 2
  (the B-side act). Channels distribution {1: 1, 2: 1}.

So the channel-blind pairs are not corpus-unique
(the AES-NUM-146 exact-act uniqueness refines to
this): their only other occurrence is the gap's own
opposite-side act — no third context in the corpus
carries either (offset, size) pair at any channel.

## (ii) B byte 0 against the joint companions over the 216

The violating-cell population was re-identified
exactly (8 cells (20, 32720, 6796…7272 step 68), 27
pairs each, 216 pairs). Each joint companion was
tested as a determinant of B byte 0 over the 216,
counted exactly:

- Joint (per-record idx sequence, A byte 0): 167
  distinct keys, 42 repeating, 7 agreeing, 35
  violating — NOT a function, but the first
  companion test of any kind over this population
  (single or joint) to earn agreeing repeats.
- Joint (per-record (cidx, idx) sequence, A byte 0):
  167 distinct, 42 repeating, 7 agreeing, 35
  violating — identical in every count to the
  (idx, A byte 0) joint on this population (derived
  count, computed at closing from the run's printed
  test lines).
- Joint (per-record in37 pattern, A byte 0): 33
  distinct, 22 repeating, 0 agreeing, 22 violating —
  identical in every count to A byte 0 alone
  (AES-NUM-146): the in37 pattern is the constant
  (False,) over this population, so the joint
  collapses onto its other component and adds
  nothing.
- Joint (per-record idx sequence, per-record in37
  pattern): 27 distinct, 27 repeating, 0 agreeing,
  27 violating — identical in every count to the
  idx sequence alone (AES-NUM-146), by the same
  constancy.

Strongest joint companion by the contract rule
(fewest violating repeats, then most distinct keys):
(per-record in37 pattern, A byte 0), stats
(33, 22, 0, 22) — recorded with its collapse noted
above: its first place is A byte 0's own single
result carried through a constant, not a joint
refinement. The population's 216 pairs were printed
in full once, grouped by cell, under that companion.
No joint companion determines B byte 0; the two
genuinely refining joints leave 35 violating repeats
each. Mechanisms NOT PROVEN.

## (iii) The byte-0 and cell-third steps over the full 224

Grouping all 224 pairs by the (byte1, byte2, byte3)
sub-key alone (any status, group or record count):
222 distinct sub-keys, exactly 2 multi-pair groups,
holding 4 pairs — the same two groups as the wed
base groups of AES-NUM-145/146:

- Sub-key (1, 176, 128): pair 1c01b080 → 1c01b000
  (byte 0 28, SAME, group (14, 9992), 27 records,
  cell (14, 9992, 1744)) against 2001b080 → 2001b000
  (byte 0 32, cell (14, 9992, 6944)): A byte 0
  difference +4, B byte 0 difference +4, B-minus-A
  byte 0 differences (0, 0), cell-third difference
  5,200.
- Sub-key (1, 178, 128): pair 1401b280 → 1401b200
  (byte 0 20, SAME, group (14, 9992), 27 records,
  cell (14, 9992, 4336)) against 1801b280 → 1801b200
  (byte 0 24, cell (14, 9992, 9832)): A byte 0
  difference +4, B byte 0 difference +4, B-minus-A
  (0, 0), cell-third difference 5,496.

Totals: 2 pair-pairs over the full 224. Distributions
over those pair-pairs: A byte 0 difference {4: 2};
B byte 0 difference {4: 2}; (A byte 0 difference,
cell-third difference) {(4, 5200): 1, (4, 5496): 1};
both pair-pairs carry single cells on both sides
(2 of 2). Dropping the status/group/record-count wed
therefore admits NO further pair-pair: the +4 step
and the two cell-third steps are the whole measured
population of the sub-key alone, not an artefact of
the wed. Whether the step is a law beyond these two
pair-pairs is NOT PROVEN — there is no third
pair-pair in the corpus to test it against.

## Next

Slice 4.148 — the two refining joints dissected
(their 7 agreeing repeats in full; the 35 violating
repeats of (idx sequence, A byte 0) wed further to
the cell over the 216); the +4 step tested across
every pair-pair sharing each of the other three
three-byte sub-keys alone over the full 224; the
B/A channel tuples wed to count and to sizes as
determinants of the mapping over all 8 gaps.
Host/artifact analysis only — no physical child.
