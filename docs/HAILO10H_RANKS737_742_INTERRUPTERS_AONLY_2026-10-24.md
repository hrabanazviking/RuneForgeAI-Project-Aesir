# All six B-offset-order acts at ranks 737–742 are B-only distinct with no A-side counterpart, the four B-only interrupters at B 735–738 are the last four acts in B-offset order (ranks 747–750), and the four A-only acts at A 733–736 are A-offset ranks 740–743 with the same (size, channel) sequence as the interrupters but no shared act, key or offset (AES-NUM-180)

Slice 4.180, worked under `docs/TASK_CONTRACT_4.180.md`
(contract published in the 4.179 closing commit @
c1b3e47b). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef180.py is the verified hef179 base plus arms180 —
sha256
`14bc4c1d5bda32ec07981bade075d626f29237157ed086bbbcfb98b164dec54b`
(1,160,194 B) on both the VM and the device; arms180
sha256
`009e87055b97d7d93765571a141ddc3fe2e22de38d46450a44c879ae57ca4614`
(14,390 B), gzip sha256
`fd9ff8aefb0c07808a4bbfe1ec3d5a3a8ffa2307c30228f9400dfba0ebd39a7c`.
Crossing: ten sha-gated 373 B gz parts (last 21 B),
all ten verified on-device first try; assembled arms
and hef180 shas == VM on-device, py_compile OK.
Before launching, `tmux ls` and `ps` on Mimir were
checked for an existing hef180/h180 child (none —
only the old h142/h147 sessions): exactly ONE
bounded host-side child was launched in detached
tmux (session h180, 2026-10-30 03:45:28 EDT) with
the contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`), and it finished with
DONE180 as its last line, exit marker 0
(hef180.exit), err empty (0 B). Output hef180.out:
50,521 lines / 9,452,270 B, sha256
`4db633e7d7c47704d67671b499d7bd85c41e49c8684888e83d9994cad0e51010`.
Prefix check: its first 50,166 lines against
hef179.out differ in exactly TWO lines (41,611 and
42,872, both frozenset element order only — same
sorted content, the AES-NUM-150 variance); all
other 50,164 lines byte-identical. Section 180:
355 lines / 47,241 B, sha256
`8798609cb56aba5076303b5d4106d0b4a972e483cb858522f32fdee089cc7266`,
read in full on-device. Controls EXACT (context
counts 749 / 751, shared 689, A-only 60, B-only
62, union 811; both-side keys 31; channel census
{(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6};
run table 103 secondary runs; run 102 length 58,
shift +2, A 683–744 / B 685–746 — all as expected;
the ranks 737–742 acts at B indices 17, 19, 20,
22, 23, 25 and their ranks [737, 738, 739, 740,
741, 742] reproduced exactly; the interrupter acts
at B 735–738 and the A-only acts at A 733–736
reproduced exactly; head size sequences reproduced
exactly on both sides). Raw output kept on the Pi
at ~/aesir-build/ (hef180.out, hef180.py,
arms180.py, section180.txt, hef180.exit, run180.sh,
gz180/); local lineage in
~/workspace/.verify-tmp/aesir180.

## (i) The acts at ranks 737–742 in full

Definitions (stated in the output, followed
exactly): B-offset order is context B's acts sorted
by offset, ranks 0-based of 751; occurrences are
all indices of the exact act tuple in a context
list.

Each rank 737–742 act in full — all six are
B-only distinct, each occurs exactly once in B and
nowhere in A, so NONE has an A-side counterpart
act:

- Rank 737: B index 17, act (1196272096, 32728, 1), channel 1.
- Rank 738: B index 19, act (1196304896, 7712, 0), channel 0.
- Rank 739: B index 20, act (1196312608, 328, 0), channel 0.
- Rank 740: B index 22, act (1196313088, 24848, 1), channel 1.
- Rank 741: B index 23, act (1196337936, 264, 1), channel 1.
- Rank 742: B index 25, act (1196338688, 30008, 2), channel 2.

In B-index order the six are interleaved with the
shared run-0 acts at B 18 (offset rank 44), B 21
(rank 45) and B 24 (rank 46), and are followed by
a further B-only act at B 26 (rank 743). In
B-offset order they are consecutive ranks with no
shared act interleaved.

Offset gaps from rank 736 on: 736→737 is +24
(exactly rank 736's size, so the contiguous offset
chain of AES-NUM-179 extends one step to rank
737), then 737→738 is +32,800 (rank 737's size is
32,728 — an excess of 72, the chain ends), 738→739
is +7,712 (exactly rank 738's size), 739→740 is
+480 (rank 739's size is 328 — an excess of 152),
740→741 is +24,848 (exactly rank 740's size),
741→742 is +752 (rank 741's size is 264 — an
excess of 488) and 742→743 is +30,008 (exactly
rank 742's size). Contiguous steps and excess
steps therefore alternate irregularly; no uniform
step law is measured.

The full B-offset-order range ranks 733–748 is
B-only throughout: rank 743 (B 26, (1196368696,
280, 2)), rank 744 (B 229, (1196369408, 26128,
2)), rank 745 (B 272, (1196396032, 14352, 1)),
rank 746 (B 674, (1196410880, 32784, 2)), rank
747 (B 735) and rank 748 (B 736) — the last two
are the first two interrupters of (ii). Together
with AES-NUM-178/179, every act from rank 721 to
rank 750 in B-offset order is B-only distinct —
ranks 747–750, measured in (ii), complete that
range at the top of the order.

## (ii) The four B-only interrupter acts at B 735–738 in full

Each interrupter in full — all four are B-only
distinct, each occurs exactly once in B and
nowhere in A, so NONE has an A-side counterpart
act, and their B-offset ranks are measured here
for the first time:

- B index 735: act (1196444160, 24, 0), channel 0 — B-offset rank 747.
- B index 736: act (1196444672, 24, 1), channel 1 — B-offset rank 748.
- B index 737: act (1196445184, 24, 2), channel 2 — B-offset rank 749.
- B index 738: act (1196445696, 24, 0), channel 0 — B-offset rank 750.

Ranks 747–750 are the LAST four ranks of the
B-offset order (751 acts, ranks 0–750): the
interrupters are context B's four highest-offset
acts, consecutive in both B-index order (735–738)
and B-offset order (747–750). In B-offset order
they follow the B-only acts at ranks 744–746
(B 229, B 272, B 674); there is no rank after 750.

In B-index order they sit exactly where
AES-NUM-179 placed them: after run 102's first
block closes at B 733–734 (the shared acts
(791776256, 24, 2) at rank 718 and (791776768,
24, 0) at rank 719) and before run 102's second
block opens at B 739–740 (ranks 34–35). The
B-index offset step from B 734 to B 735 is
+404,667,392, the three internal steps are +512
each, and the step from B 738 down to B 739's
act is −427,836,416 (B-index order is not offset
order here).

## (iii) The four A-only acts at A 733–736 in full

Each A-only act in full — all four are A-only
distinct, each occurs exactly once in A and
nowhere in B, so NONE has a B-side counterpart
act, and NONE has any B-only act under its
correspondence key (offset, size):

- A index 733: act (791776792, 24, 0), channel 0 — A-offset rank 740.
- A index 734: act (791777280, 24, 1), channel 1 — A-offset rank 741.
- A index 735: act (791777792, 24, 2), channel 2 — A-offset rank 742.
- A index 736: act (791778304, 24, 0), channel 0 — A-offset rank 743.

The four are consecutive in both A-index order
(733–736) and A-offset order (740–743). In
A-offset order they are preceded by the shared
run-102 acts at ranks 738–739 (A 731, A 732) and
followed by the shared run-102 act at rank 744
(A 744, (791778816, 24, 0)) and the A-only acts
at ranks 745–746 (A 745, A 746). In A-index
order they sit between run 102's blocks exactly
as in AES-NUM-179: after A 731–732, before the
second block at A 737–738. The A-index offset
step from A 732 to A 733 is +24, the internal
steps are +488, +512, +512, and the step from
A 736 down to A 737's act is −23,169,024.

Correspondence to the B interrupters of (ii),
paired by sequence position: the two sets have
IDENTICAL (size, channel) sequences — [(24, 0),
(24, 1), (24, 2), (24, 0)] on both sides — and
identical channel sequences [0, 1, 2, 0], but
they share NO exact act, NO (offset, size)
correspondence key and NO offset. The
per-position offset differences (B minus A) are
[404667368, 404667392, 404667392, 404667392]:
constant at 404,667,392 for positions 1–3, and
24 less at position 0 — the 24 being exactly the
A-side step from A 732's act into A 733 (where
the B side's corresponding step, from B 734's
act into B 735, is the full 404,667,392). No
correspondence-key on either side contains an
act from the other side.

## Grades

All statements above are measured from the
complete populations. Mechanisms NOT PROVEN; any
offset, prefix or position law NOT PROVEN; the
heads' scaffold mechanism NOT PROVEN; the
rank 737–742 acts' meaning NOT PROVEN; the
interrupters' meaning NOT PROVEN; and the
A-only acts' meaning NOT PROVEN.

## Next

Slice 4.181 — the B-offset-order acts at ranks
743–746 in full (B indices 26, 229, 272, 674);
the A-only acts at A 745–747 in full (including
their A-offset ranks); the A-offset-order acts
at ranks 744–748 in full. Host/artifact analysis
only — no physical child.
