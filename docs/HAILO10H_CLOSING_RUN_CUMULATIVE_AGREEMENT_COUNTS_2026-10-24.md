# The closing-run cumulative agreement-count sequence, the distinct cumulative totals, and the gap cumulative agreement-count sequence (AES-NUM-249)

Slice 4.249, worked under `docs/TASK_CONTRACT_4.249.md`
(contract published in the 4.248 closing commit @
64f2167b). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section249.txt).

## Run and closing record

hef249.py is the verified hef248 base plus
arms249: hef248.py sha256
`36ab3c64ba74a1dc272bdf55309e5b97cc2f3c3e73272ffed7eb70f87f8fb8ef`
(2,077,872 B) on both the VM and the device.
arms249 sha256
`9937372340070fc17f2c106f0b96dbb26f759cfb373a98173080f88397ca65a8`
(15,636 B); hef249.py sha256
`a6a06fa4bcad84ac27bb3e175fc0aba185be230e762385c30f33a29468e03b69`
(2,093,508 B) on both the VM and the device.
Crossing, stated exactly: arms249 was gzipped at
gzip -9 (sha256
`b65339a628f338f935c9fb6970f4cdb1e55f447a756d95f19595e7c705b364cf`,
4,284 B) and split into twelve 373 B parts (last
181 B); each part was written as its own file with
its own sha256 gate — all twelve verified
on-device on the first attempt; no byte was ever
accepted unverified. The assembled gzip, arms and
hef249 shas == VM on-device; hef249 assembled
on-device from hef248.py + arms249.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef249/h249 child; exactly ONE bounded host-side
child ran in detached tmux (session h249, launched
2026-10-31 00:49:06 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef249.exit), err empty, and DONE249 as its last
line. Output hef249.out 58,631 lines /
10,630,990 B sha256
`eda3288b5725ac27638351bcdc110e277dbb90e5b3515d324d8c5327a41423d1`;
prefix against hef248.out: the first 58,588
lines differ from hef248.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison; the second
variance line seen in earlier runs, 42872, did
not differ this run), hef249.out adding exactly
its own 43 section lines (8,161 B, sha256
`b408ba6626447dac5758d613632f9324c0f40aee8d89b1dbe2ea64d0fe5327d5`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef249.out, hef249.py, arms249.py,
section249.txt, hef249.exit, run249.sh, gz249/,
check249.py); local lineage in
~/workspace/.verify-tmp/aesir249.

Definitions: POSITION is 1-based over the eight
acts of a closing run (position 1 = first act).
The A closing run is ranks 741–748 in A-offset
order; the B closing run is ranks 743–750 in
B-offset order. At each act position, the
AGREEMENT SET is the list, in the canonical family
order SIZE, CHANNEL, CLASS, RUN-102, OFFSET,
INDEX, of the families whose A value equals the
B value at that same position. The AGREEMENT
COUNT at a position is the number of families in
that position's agreement set (AES-NUM-248). The
CUMULATIVE AGREEMENT COUNT after a position is
the running total of the agreement counts over
positions 1 up to and including that position.
The GAP at a gap position 1–7 is the next act's
offset minus this act's offset; gap agreement
means the A gap equals the B gap at that
position; the GAP CUMULATIVE AGREEMENT COUNT
after a gap position is the running count of
agreeing gap positions up to and including it.

## (i) The closing-run cumulative agreement-count sequence in full

The running totals of AES-NUM-248's agreement
counts [1, 2, 1, 0, 3, 3, 3, 3], stated position
by position (each printed set equals the
AES-NUM-247 printed set, each printed count
equals the AES-NUM-248 printed count, and each
printed cumulative total equals its expected
value, printed tests True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16.

Cumulative agreement-count sequence: [1, 3, 4, 4,
7, 10, 13, 16] — equals the running totals of the
AES-NUM-248 printed counts (printed test True);
final cumulative total 16.

## (ii) The distinct cumulative totals in full

Distinct values, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 1: position 1 — count 1.
- 3: position 2 — count 1.
- 4: positions 3, 4 — count 2.
- 7: position 5 — count 1.
- 10: position 6 — count 1.
- 13: position 7 — count 1.
- 16: position 8 — count 1.

Seven distinct cumulative totals; the final
cumulative total is 16, equal to AES-NUM-248's
total agreeing family-instances and to
AES-NUM-245's family-count sum.

## (iii) The gap cumulative agreement-count sequence in full

The running count of agreeing gap positions,
stated gap position by gap position (each printed
gap result equals the AES-NUM-247 printed result,
printed test True for all seven): gap position 1
A 512 against B 712 — disagree, cumulative 0; gap
position 2 A 512 against B 26624 — disagree,
cumulative 0; gap position 3 A 512 against B
14848 — disagree, cumulative 0; gap position 4
A 512 against B 33280 — disagree, cumulative 0;
gap position 5 A 512 against B 512 — agree,
cumulative 1; gap position 6 A 512 against B 512
— agree, cumulative 2; gap position 7 A 512
against B 512 — agree, cumulative 3.

Gap cumulative agreement-count sequence: [0, 0, 0,
0, 1, 2, 3] — equals the expected sequence
(printed test True), ends at 3, with agreeing
positions 5, 6, 7 (count 3), equal to AES-NUM-245.

Contract tests: the printed cumulative
agreement-count sequence equals the running
totals of AES-NUM-248's printed counts (1, 3, 4,
4, 7, 10, 13, 16) — True; the distinct cumulative
totals' counts sum to 8 — True; the final
cumulative total equals 16 — True; the gap
cumulative sequence equals (0, 0, 0, 0, 1, 2, 3)
and ends at 3 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
