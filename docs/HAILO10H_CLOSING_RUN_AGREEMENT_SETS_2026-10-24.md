# The closing-run agreement-set sequence, the distinct agreement sets, and the gap-agreement sequence (AES-NUM-247)

Slice 4.247, worked under `docs/TASK_CONTRACT_4.247.md`
(contract published in the 4.246 closing commit @
1952f813). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section247.txt).

## Run and closing record

hef247.py is the verified hef246 base plus
arms247: hef246.py sha256
`19d779cc99fcd63e6a122d8e72f9d116b8b8a5fb2812d5c5a4c69d78752f3d1c`
(2,047,143 B) on both the VM and the device.
arms247 sha256
`3c12cceec8d1abe295650911e25f96225b4d06b71d9341757c255e9ee10f41e4`
(15,283 B); hef247.py sha256
`bbc3c446b244d6a04af03c1c2b55f2b9f128de02be8e62584b78b51b6e411ed3`
(2,062,426 B) on both the VM and the device.
Crossing, stated exactly: arms247 was gzipped at
gzip -9 (sha256
`9eebed2ac387b104891e42d132fc167ce4868f60cec5ecf890c625de939df01e`,
4,214 B) and split into twelve 373 B parts (last
111 B); each part was written as its own file with
its own sha256 gate — all twelve verified
on-device on the first attempt; no byte was ever
accepted unverified. The assembled gzip, arms and
hef247 shas == VM on-device; hef247 assembled
on-device from hef246.py + arms247.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef247/h247 child; exactly ONE bounded host-side
child ran in detached tmux (session h247, launched
2026-10-31 ~00:06 EDT, output file timestamp) with
the contract corpus argv (glob order, MiniLM
last), unbuffered (`python3 -u`), and finished
with exit marker 0 (hef247.exit), err empty, and
DONE247 as its last line. Output hef247.out
58,547 lines / 10,615,697 B sha256
`fddef4317560d9e0cbbdaa9e6d69a1925f580fedfc168b9b3477339f82841abf`;
prefix against hef246.out: the first 58,500
lines differ from hef246.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, each verified by
same-sorted-characters comparison), hef247.out
adding exactly its own 47 section lines (7,356 B,
sha256
`7e44bdac6cf2ac70f2df7daba696368f195be61d660ca4556ce9eee4afd5b009`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef247.out, hef247.py, arms247.py,
section247.txt, hef247.exit, run247.sh, gz247/,
check247.py); local lineage in
~/workspace/.verify-tmp/aesir247.

Definitions: POSITION is 1-based over the eight
acts of a closing run (position 1 = first act).
The A closing run is ranks 741–748 in A-offset
order; the B closing run is ranks 743–750 in
B-offset order. At each act position, the
AGREEMENT SET is the list, in the canonical family
order SIZE, CHANNEL, CLASS, RUN-102, OFFSET,
INDEX, of the families whose A value equals the
B value at that same position. The GAP at a gap
position 1–7 is the next act's offset minus this
act's offset; gap agreement means the A gap
equals the B gap at that position.

## (i) The closing-run agreement-set sequence in full

The eight per-position agreement sets of
AES-NUM-246, stated as one sequence (each printed
set equals the AES-NUM-246 printed set, printed
test True for all eight):

- Position 1 (A rank 741 / B rank 743): [RUN-102] — count 1 of 6.
- Position 2 (A rank 742 / B rank 744): [CHANNEL, RUN-102] — count 2 of 6.
- Position 3 (A rank 743 / B rank 745): [RUN-102] — count 1 of 6.
- Position 4 (A rank 744 / B rank 746): [] — count 0 of 6.
- Position 5 (A rank 745 / B rank 747): [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 6 (A rank 746 / B rank 748): [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 7 (A rank 747 / B rank 749): [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 8 (A rank 748 / B rank 750): [SIZE, CHANNEL, RUN-102] — count 3 of 6.

Agreement-set sequence: [[RUN-102],
[CHANNEL, RUN-102], [RUN-102], [],
[SIZE, CHANNEL, RUN-102], [SIZE, CHANNEL,
RUN-102], [SIZE, CHANNEL, RUN-102],
[SIZE, CHANNEL, RUN-102]] — equals the
AES-NUM-246 sequence (printed test True).

## (ii) The distinct agreement sets in full

Distinct forms, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- [RUN-102]: positions 1, 3 — count 2.
- [CHANNEL, RUN-102]: position 2 — count 1.
- []: position 4 — count 1.
- [SIZE, CHANNEL, RUN-102]: positions 5, 6, 7, 8 — count 4.

Per-family position lists re-derived from the
sets alone (for each family, the positions whose
set contains it), each equal to AES-NUM-245's
agreeing-position list (printed test True for
all six families):

- SIZE: positions 5, 6, 7, 8 — count 4.
- CHANNEL: positions 2, 5, 6, 7, 8 — count 5.
- CLASS: no positions — count 0.
- RUN-102: positions 1, 2, 3, 5, 6, 7, 8 — count 7.
- OFFSET: no positions — count 0.
- INDEX: no positions — count 0.

## (iii) The gap-agreement sequence in full

The seven gap positions' agreement results of
AES-NUM-246, stated as one sequence (each printed
result equals the AES-NUM-246 printed result,
printed test True for all seven): gap position 1
A 512 against B 712 — disagree; gap position 2
A 512 against B 26624 — disagree; gap position 3
A 512 against B 14848 — disagree; gap position 4
A 512 against B 33280 — disagree; gap position 5
A 512 against B 512 — agree; gap position 6
A 512 against B 512 — agree; gap position 7
A 512 against B 512 — agree.

Gap-agreement sequence: [False, False, False,
False, True, True, True]; agreeing positions
5, 6, 7; agreeing count 3 — re-sums to 3, as in
AES-NUM-245 (printed test True).

Contract tests: the printed agreement-set
sequence equals the sequence of sets printed in
AES-NUM-246 — True; the distinct-set counts sum
to 8 — True; the per-family position lists
re-derived from the sets equal AES-NUM-245's
agreeing-position lists — True for all six
families; the gap-agreement sequence equals
AES-NUM-246's printed gap results and its count
re-sums to 3 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
