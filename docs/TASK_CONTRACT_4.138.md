# TASK_CONTRACT_4.138 (AES-NUM-138)

Scope (from AES-NUM-137's NEXT + TODO 4.138):
(i) the two wed redundancies certified directly,
and the maximal compound joint key wed to BOTH
remaining companions together — AES-NUM-137
established that wedging the maximal compound key
(position-0 act, loose distances (d0, d1), loose
order, gap-0 tuple, gap-1 tuple) to the context
length alone, or to the gap-2 left position alone,
gives 86 distinct keys under either wed (no key
added over the maximal key alone), with position-1
failing on exactly 2 keys, position-2 and the
whole tuple on exactly 3, and the derived reading
that each wed component is constant on every
maximal-key family. Tests: the context length
tested as a function of the maximal compound joint
key, and the gap-2 left position tested as a
function of the maximal compound joint key,
computed exactly over the 271 contexts (distinct
keys, violating keys named in full with their
alternative values and contexts); position-1 and
position-2 tested as functions of the maximal
compound joint key wed to BOTH companions together
(context length and gap-2 left position), and the
whole gap-2 tuple tested as a function of that
doubly-wed key, the same way. Any relation NOT
PROVEN unless the numbers prove it; never invent
one.
(ii) the shift anatomy's long runs and large-shift
tail in full — AES-NUM-137 read the exception
(791774208, 328, 0)'s two contexts (5ab3537d cidx
86 and cidx 210; 689 shared acts, every shared act
single-positioned in both) and counted the shift
distribution exactly (69 distinct shifts, −455 to
+434; +2 on 283 acts, 0 on 126, +3 on 55; 118
primary runs of consecutive A-positions at one
constant shift, 103 secondary runs ignoring
A-position gaps; the longest primary run 158 acts
at shift +2 over A-positions 26–183). Tests: every
primary run of length ≥ 20 printed act by act (each
act with its positions in A and B and its shift);
every shared act with |shift| ≥ 100 printed in
full (act, positions in A and B, shift), counted
exactly; and the shift class (negative / zero /
+1..+9 / ≥ +10 / ≤ −10) counted exactly inside
each A-position band of width 50 (bands from
position 0 to the contexts' end), over the shared
acts whose A-position falls in the band. Any
relation NOT PROVEN unless the numbers prove it;
never invent one.
(iii) B byte 0 against the six two-byte sub-keys
wed to the group, over the full 224 pairs —
AES-NUM-137 tested the six two-byte keys over the
full population (63 repeated values, 13 agreeing,
50 violating; no key a function) and AES-NUM-136
tested them inside each group separately.
Tests: for each of the six two-byte sub-keys, B
byte 0 tested against the wed key (group, two-byte
value) over the full 224 pairs — every wed value
carried by more than one pair, counted exactly,
with each repeated wed value's pairs printed in
full (A and B words, B byte 0, status, records)
and its agreeing / violating verdict; and the 13
agreeing full-population repeats of AES-NUM-137
re-read with their pairs' status (SAME / DIFF)
company counted exactly. Any determination NOT
PROVEN unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef137.py lineage in ~/workspace/.verify-tmp/aesir137 is the base for hef138; section137.txt + hef137.out are there.

One bounded host-side child per contract.
