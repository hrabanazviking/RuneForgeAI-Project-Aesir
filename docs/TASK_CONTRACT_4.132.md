# TASK_CONTRACT_4.132 (AES-NUM-132)

Scope (from AES-NUM-131's NEXT + TODO 4.132):
(i) gap 2's broken chain in full — AES-NUM-131
established gap 2's position-1 act is NOT a function
of its position-0 act (7 violating first acts of 70),
position-2 is NOT a function of position-0 (8 of 70)
nor of position-1 (10 of 73), while gaps 0 and 1 are
exact functions. Tests: every violating key of the
three gap-2 tests read in full (each alternative act,
every context carrying it, printed entire); the
contexts carrying a violating key read against the
contexts that do not (what else differs there — the
other gap positions, the loose pair's distances and
order, the context length, counted exactly); and
gaps 0 and 1 re-tested with the same wider lens for
contrast (their exactness is already proven; the
test is whether their first acts ever repeat with
any contextual difference at all). Any relation
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the gap-only acts read at offset and size
level — AES-NUM-131 established all 333 distinct
gap acts are gap-only corpus-wide as whole acts.
Tests: for each distinct gap act, its offset read
corpus-wide (in how many acts of any size or
channel does that offset stand, in which contexts);
its (offset, size) pair read the same way (any
channel); and the outlier run's 31 corpus-unique
acts read the same two ways (offset-level and
(offset, size)-level recurrence counted exactly,
contexts named). Any recurrence NOT PROVEN unless
the numbers prove it; never invent one.
(iii) B byte 0 against the three-byte sub-keys,
with the shared identity pair read in full —
AES-NUM-131 established B byte 0 is NOT a function
of any two-byte sub-key of the A word, failing for
the three near-miss keys on exactly their named
collisions ((249, 44) and (252, 84) under
(byte 3, byte 1), (249, 181) under (byte 3, byte 2),
(128, 146) under (byte 1, byte 2)). Tests: B byte 0
itself (not only the identity status) tested as a
function of each three-byte sub-key of the A word —
(byte 3, byte 1, byte 2), (byte 0, byte 1, byte 2),
(byte 0, byte 3, byte 1), (byte 0, byte 3, byte 2) —
computed exactly over the great group's 216 pairs
(distinct values, values with repetition, violating
values named in full with their B byte 0 sets);
and the identity pair A 682cb5f9 -> B 6884f5f8,
which carries both status collisions, read in full
(its records, its cell, every other collision or
test in the 4.124–4.131 line in which that pair
appears, counted from the run's own tables). Any
determination NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

One bounded host-side child per contract.
