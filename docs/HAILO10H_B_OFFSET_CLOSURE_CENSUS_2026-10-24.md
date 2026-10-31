# The B-offset-order closure in full and the full-order census over B-offset order (AES-NUM-228)

Slice 4.228, worked under `docs/TASK_CONTRACT_4.228.md`
(contract published in the 4.227 closing commit @
5f6aac85). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section228.txt).

## Run and closing record

hef228.py is the verified hef227 base plus
arms228: hef227.py sha256
`b92f1f179e83934e2eecc6183d2f05660d1527c882b75ca18e987d18ac86c84e`
(1,785,103 B) on both the VM and the device.
arms228 sha256
`9064abd3b9d22941d92ead8ebdfbad0bc339ce272a46be12e19678c5f186dd76`
(12,769 B); hef228.py sha256
`6d89b8ab2e918755546d32c1400cf3a4fafd841194e40a704293a22deee22762`
(1,797,872 B) on both the VM and the device.
Crossing, stated exactly: arms228 was gzipped at
gzip -9 (sha256
`c53fe09692477ffc21e3f35b2db89db3cff9729c528764a4c9de4ec4353ce346`,
3,097 B) and split into nine 373 B parts (last
113 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef228
shas == VM on-device; hef228 assembled on-device
from hef227.py + arms228.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef228/h228 child; exactly ONE bounded host-side
child ran in detached tmux (session h228, created
2026-10-30 18:07:15 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef228.exit), err empty, and DONE228 as
its last line. Output hef228.out 57,348 lines /
10,415,666 B sha256
`d4b7381bbd7dbf6569cc28a714151251ff65a7d5b58d7132903275e3232a23c3`;
prefix against hef227.out: the first 57,309
lines differ from hef227.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified this run by
same-sorted-characters comparison), hef228.out
adding exactly its own 39 section lines
(6,931 B, sha256
`746338ea1bf641d1db833a87e1dce8652cd1201d99b07292d9bc52d1d4839dde`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef228.out, hef228.py, arms228.py,
section228.txt, hef228.exit, run228.sh, gz228/,
check228.py); local lineage in
~/workspace/.verify-tmp/aesir228.

## (i) The B-offset-order closure in full

Ranks 745–750, each once on the B side only,
each B-only distinct, none a member of run 102:

- 745: B 272 (1196396032, 14352, 1), gap to
  next rank +14,848; occurrences in A none,
  in B [272].
- 746: B 674 (1196410880, 32784, 2), gap
  +33,280; occurrences in A none, in B [674].
- 747: B 735 (1196444160, 24, 0), gap +512;
  occurrences in A none, in B [735].
- 748: B 736 (1196444672, 24, 1), gap +512;
  occurrences in A none, in B [736].
- 749: B 737 (1196445184, 24, 2), gap +512;
  occurrences in A none, in B [737].
- 750: B 738 (1196445696, 24, 0), gap None —
  rank 750 is the last measured rank and no
  rank beyond 750 was requested; occurrences
  in A none, in B [738].

The closing run of ranks 743–750 in full on
the same terms adds: 743: B 26 (1196368696,
280, 2), gap +712; 744: B 229 (1196369408,
26128, 2), gap +26,624; then ranks 745–750
exactly as above. Every act in the closing
run is B-only distinct and none is a member
of run 102.

## (ii) The full-order census over B-offset order

B acts 751, ranks 0–750. The act at rank 0 is
(262144, 376, 0) at B 696 — shared
single-positioned (run 102, shift +2),
occurrences in A [694], in B [696], a member
of run 102. The act at rank 750 is
(1196445696, 24, 0) at B 738, as above.

Class census over all 751 acts in B-offset
order: shared single-positioned 689; B-only
distinct 62; shared distinct but NOT
single-positioned 0; A-only distinct 0; in
neither context list 0. The census counts
sum to 751, exactly as the contract's test
requires.

Run-102 membership count over B-offset
order: 58 acts are members of run 102; 693
acts are not.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
