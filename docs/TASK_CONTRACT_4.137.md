# TASK_CONTRACT_4.137 (AES-NUM-137)

Scope (from AES-NUM-136's NEXT + TODO 4.137):
(i) gap 2's chain against the maximal compound
joint key wed to the two companions it does not
yet carry — AES-NUM-136 established the maximal
compound key (position-0 act, loose distances
(d0, d1), loose order, gap-0 tuple, gap-1 tuple)
gives 86 distinct keys and adds NO key over
(position-0, loose distances, one sister tuple)
alone, with position-1 failing on exactly 2 keys
and position-2 on exactly 3, and the whole tuple
failing on the same 3 keys under either sister.
Tests: position-1 and position-2 tested as
functions of the maximal compound joint key wed
to the context length, and of the maximal
compound joint key wed to the gap-2 left position,
computed exactly over the 271 contexts (distinct
joint keys, repeating joint keys, violating joint
keys named in full with their alternatives and
contexts); and the whole gap-2 tuple tested as a
function of the maximal compound joint key wed to
the context length, and of the maximal compound
joint key wed to the gap-2 left position, the
same way. Any relation NOT PROVEN unless the
numbers prove it; never invent one.
(ii) the exception contexts' shared-act
position-shift anatomy — AES-NUM-136 read the
exception (791774208, 328, 0)'s two contexts
against each other (5ab3537d cidx 86, 749 distinct
acts; cidx 210, 751 distinct acts): 689 distinct
acts are shared, 60 are A-only, 62 are B-only, and
of the shared acts only 126 stand at the same
position in both contexts while 563 stand at
different positions. Tests: the exact position
shift (position in B minus position in A)
distribution over all 689 shared acts, counted
exactly; the 126 same-position acts' position
distribution in full (positions in A, counted and
ranged exactly); and the shared acts in A's
position order read as shift runs (maximal runs of
consecutive A-positions carrying one constant
shift, counted exactly with their lengths and
shift values). Any relation NOT PROVEN unless the
numbers prove it; never invent one.
(iii) B byte 0 against the six two-byte sub-keys
over the FULL 224-pair population — AES-NUM-136
tested the two-byte keys inside each group
separately (the great group violates under all
six keys; group (14, 9992)'s byte-0 keys never
repeat; group (19, 7712) holds the one agreeing
repeat (20, 1)), and AES-NUM-134 counted the
cross-group two-byte sharings. Tests: for each of
the six two-byte sub-keys of the A word over the
full 224 pairs, every key value carried by more
than one pair, counted exactly, with each repeated
value's pairs printed in full (A and B words,
B byte 0, status, records) and its agreeing /
violating verdict, and each repeated value's
group composition (the groups of its pairs,
counted exactly). Any determination NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef136.py lineage in ~/workspace/.verify-tmp/aesir136 is the base for hef137; section136.txt + hef136.out are there.

One bounded host-side child per contract.
