# TASK_CONTRACT_4.142 (AES-NUM-142)

Scope (from AES-NUM-141's NEXT + TODO 4.142):
(i) the missing lattice slots inside the 15
repeating doubly-wed families, read against the
whole gap-2 population — AES-NUM-141 printed every
family's cidx set, measured step and residues, and
found missing quotient slots in the step-4
families (family [145…] residue 1: quotient 45,
slot cidx 181; family [146…] residue 2: quotients
39/44/45/60, slots 158/178/182/242; family [140…]
residue 0: quotients 36/40/45/46, slots
144/160/180/184). Tests: for each of the 15
repeating families, every lattice position
(residue + step x k, k from the family's minimum
quotient to its maximum) not occupied by the
family, printed exactly; and for each such missing
slot, what occupies that cidx among artifact
cc9b9d1c's gap-2 rows — another repeating family's
row (which family, named by its key), a singleton
family's row (its key in full), or no gap-2 row at
that cidx at all — counted exactly per family and
in total. Any relation NOT PROVEN unless the
numbers prove it; never invent one.
(ii) the B-side mirror of the skipped positions —
AES-NUM-141 found all 19 acts at the skipped
A-positions of the secondary long runs' 8 non-unit
gaps are A-only (not in context B at all), and the
B-side distance between the same run acts equals
the A-side distance in all 8 gaps. Tests: for each
non-unit gap, every B-position strictly between
the gap's left and right acts in context B, with
the act at that position printed in full (its
identity, its occurrences in B, whether it occurs
in context A at all, and if shared its position in
A and its shift; if not shared, whether it occurs
in A's context at another position or not at all),
classified and counted exactly as the A side was;
and the 19 A-side skipped acts' corpus-wide
occurrence lists printed in full (every artifact /
context / position at which each act occurs in the
loaded corpus). Any relation NOT PROVEN unless the
numbers prove it; never invent one.
(iii) B byte 0 against the four three-byte
sub-keys wed to the pair's status AND group
jointly, over the full 224 pairs — AES-NUM-141
tested the status wed ((byte 0, byte 1, byte 2)
and (byte 0, byte 2, byte 3) injective;
(byte 0, byte 1, byte 3) one agreeing repeat;
(byte 1, byte 2, byte 3) the same two violating
repeats). Tests: for each of the four three-byte
sub-keys, B byte 0 tested against the value wed to
(status, group) jointly — every wed value carried
by more than one pair counted exactly, with each
repeated value's pairs printed in full (A and B
words, B byte 0, status, group, records) and its
agreeing / violating verdict; the four status-wed
tests re-run inside the SAME-only subset (44
pairs) and inside the DIFF-only subset (180 pairs)
separately, with the same full printing of every
repeat; and the two (byte 1, byte 2, byte 3)
status-wed violating repeats re-read against A
byte 0 (each pair's A byte 0, B byte 0, status and
diff printed). Any determination NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef141.py lineage in ~/workspace/.verify-tmp/aesir141 is the base for hef142; section141.txt + hef141.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
