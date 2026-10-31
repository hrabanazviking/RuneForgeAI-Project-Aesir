# TASK_CONTRACT_4.141 (AES-NUM-141)

Scope (from AES-NUM-140's NEXT + TODO 4.141):
(i) the cidx sets inside the 15 repeating
doubly-wed families — AES-NUM-140 certified the
artifact identity as a function of the doubly-wed
key, showed the context index is NOT a function
(all 15 repeating keys violate, each family's
contexts spread over many indices, e.g. 13, 21,
29, …, 109), and showed the cidx wed makes every
row its own key (271 distinct, 0 repeating).
Tests: for each of the 15 repeating families, its
cidx set printed in full (size, sorted indices,
consecutive differences, residue/step structure
stated exactly as measured); and cidx-derived
companions — the cidx residue and the cidx
quotient under the step measured for that family
— each tested as a function of the doubly-wed
key, and position-1, position-2 and the whole
gap-2 tuple tested as functions of the doubly-wed
key wed further to each derived companion (each
separately, over the 271 contexts; distinct keys,
repeating keys, violating keys named in full with
alternatives and contexts). Any relation NOT
PROVEN unless the numbers prove it; never invent
one.
(ii) the acts occupying the 8 skipped A-positions
inside the secondary long runs — AES-NUM-140
printed every internal gap (431 gaps, 423 unit,
8 larger: run 62 steps 5 (gap 3) and 11 (gap 6),
run 74 steps 24 (2), 31 (5), 33 (2), 37 (2) and
48 (2), run 102 step 49 (5)). Tests: for each
non-unit gap, every A-position strictly between
the gap's left and right acts, with the act at
that position printed in full (its identity, its
position in A, whether it is a shared act at all,
and if shared its position in B and its shift;
if not shared, whether it occurs in B's context
at another position or not at all). Any relation
NOT PROVEN unless the numbers prove it; never
invent one.
(iii) B byte 0 against the four three-byte
sub-keys wed to the pair's status, over the full
224 pairs — AES-NUM-140 tested the unwed keys
((byte 0, byte 1, byte 2) and (byte 0, byte 2,
byte 3) injective with 0 repeats; (byte 0,
byte 1, byte 3) 223 distinct, 1 repeating and
AGREEING, the cross-group repeat (20, 1, 128)
-> B byte 0 = 20; (byte 1, byte 2, byte 3) 222
distinct, 2 repeating, both VIOLATING, the same
values as wed). Tests: for each of the four
three-byte sub-keys, B byte 0 tested against the
value wed to the pair's status (SAME / DIFF) —
every wed value carried by more than one pair
counted exactly, with each repeated value's pairs
printed in full (A and B words, B byte 0, status,
group, records) and its agreeing / violating
verdict; and the (byte 0, byte 1, byte 3) unwed
agreeing repeat's two pairs re-read record by
record (each pair's records printed in full, with
its group). Any determination NOT PROVEN unless
the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef140.py lineage in ~/workspace/.verify-tmp/aesir140 is the base for hef141; section140.txt + hef140.out are there.

One bounded host-side child per contract.
