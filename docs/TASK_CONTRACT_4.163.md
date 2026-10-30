# TASK_CONTRACT_4.163 (AES-NUM-163)

Scope (from AES-NUM-162's NEXT + TODO 4.163):
(i) the top offset region's thirteen B-only acts
against context A in full — AES-NUM-162 measured
context B's offset ranks 738–750 as thirteen acts
that are NOT shared single-positioned acts (B
positions 19, 20, 22, 23, 25, 26, 229, 272, 674,
735–738). Tests: each of the thirteen acts in
full against context A — does the identical act
(offset, size, channel) occur in A at all (any
position, any multiplicity), does its offset
occur in A under any size/channel, where does
its offset sit in A's own offset order (rank,
neighbours), and what does A hold at the top of
its own offset order (A's ranks 738..end in
full). Any law NOT PROVEN unless the numbers
prove it; never invent one.
(ii) the 6864/6932 split against the pairs'
record-level fields — AES-NUM-161 tested group,
status, byte0s, class, census and record count;
AES-NUM-162 tested the value fields (single
bytes and the byte3 difference fail; every
separating field was near-pair-identity).
Tests: membership (6864 vs 6932) as a function
test over the full 224 pairs and a membership
table over the 54, against the per-record
fields not yet used as membership keys in this
form — per-record cidx sequence, idx sequence,
n sequence, centre sequence, poscat sequence,
in37 sequence, record count wed to each of
those sequences, and the full per-record tuple
sequence. Any law NOT PROVEN unless the numbers
prove it; never invent one, and record a
near-identity field's verdict as trivial, as
AES-NUM-162 did.
(iii) run 20's full context and the B 280
singleton's home runs — AES-NUM-162 measured
run 20 as sixteen +5 acts, A 280–295, contiguous
at B 285–300, A-adjacent to run 19 yet landing
far from it in B; and the singleton's A
neighbourhood as runs 92 (+1), 94 (+1) and 95
(+2) flanking two A-only acts. Tests: run 20's
A neighbourhood in full (A positions 276–300,
every act's B position, shift and secondary
run); what follows run 20's B block (context-B
positions 301–310 in full); secondary runs 92,
94 and 95 in full (acts, A/B extents, shifts,
B contiguity). Any law NOT PROVEN unless the
numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef162.py lineage in ~/workspace/.verify-tmp/aesir162 is the base for hef163 (hef162 = the hef161 base plus arms162, sha256 e9305082…); section162.txt + hef162.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
