# TASK_CONTRACT_4.133 (AES-NUM-133)

Scope (from AES-NUM-132's NEXT + TODO 4.133):
(i) gap 2's chain against joint keys — AES-NUM-132
established gap 2's chain is broken for every
single-act key (position-1 as a function of
position-0 fails 7 of 70, position-2 as a function
of position-0 8 of 70, position-2 as a function of
position-1 10 of 73), while every violating key's
carrying contexts are homogeneous in context length
(and, the widest key apart, in their gap-0 and
gap-1 tuples). Tests: position-1 and position-2
tested as functions of the joint keys
(position-0 act, context length), (position-0 act,
gap-0 tuple), (position-0 act, gap-1 tuple), and
(position-0 act, loose order), computed exactly
over the 271 contexts (distinct joint keys,
repeating joint keys, violating joint keys named
in full with their alternatives and contexts);
and the whole gap-2 tuple tested as a function of
(context length, position-0 act) the same way. Any
relation NOT PROVEN unless the numbers prove it;
never invent one.
(ii) the offset-120529920 collision in full —
AES-NUM-132 established exactly one of the 333 gap
acts has its offset carried by another distinct
act: the gap-2 position-0 act (120529920, 328, 0)
(12 gap occurrences, cc9b9d1c cidx 14–102 step 8)
shares offset 120529920 with the large act
(120529920, 32784, 0), which stands in 5ab3537d
cidx 12 and 112. Tests: the large act read in full
in both of its contexts (its position, its
neighbours in full, what else stands in those
contexts, whether either context is otherwise
related to the gap act's 12 contexts); the gap
act's 12 contexts read against them (shared
features counted exactly); and a census of every
other offset in the corpus carried by acts of
different sizes whose smaller act is a size-328
act (is the cross-size pattern unique to this
offset, counted exactly). Any relation NOT PROVEN
unless the numbers prove it; never invent one.
(iii) B byte 0's three-byte tests beyond the great
group — AES-NUM-132 established all four three-byte
sub-keys of the A word separate the great group's
216 pairs only by unique identification (216
distinct values, zero repetition, zero violating,
under every key). Tests: the same four tests
computed exactly over the full 224-pair lane-1
population (all groups together) and over each
other group separately (distinct values, values
with repetition named in full, violating values
named in full with their B byte 0 sets); and, for
any key value that repeats anywhere in those
populations, its pairs read in full. Any
determination NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef132.py lineage in ~/workspace/.verify-tmp/aesir132 is the base for hef133; section132.txt + hef132.out are there.

One bounded host-side child per contract.
