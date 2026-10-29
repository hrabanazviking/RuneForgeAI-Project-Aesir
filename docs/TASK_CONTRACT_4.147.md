# TASK_CONTRACT_4.147 (AES-NUM-147)

Scope (from AES-NUM-146's NEXT + TODO 4.147):
(i) the per-gap channel mapping as a function of
the B-side skipped acts themselves and of the joint
A/B skipped tuples — AES-NUM-146 found the mapping
is not a function of the A-side skipped sizes,
offset residues mod 512, or skipped count, and that
the A-side channels and paired (size, channel)
tuples earn exactly one agreeing repeat (gaps 5/6)
and no violating one. Tests: over all 8 gaps, the
mapping (the set of paired A→B channels and the
full paired sequence) tested as a function of each
B-side skipped-act feature the printed rows support
— the B-side skipped acts' sizes, their B channels,
their offsets, their offset residues (offset mod
512 and mod 32784), the paired (size, channel)
tuples, and the joint A/B tuples (A act, B act)
and (A channel, B channel) per paired position —
each printed with distinct / repeating / agreeing /
violating counts exactly; and gaps 3 and 7's skipped
(offset, size) pairs read against the corpus
channel-blind (every act in the corpus sharing the
(offset, size), at any channel, with its contexts).
Any relation NOT PROVEN unless the numbers prove
it; never invent one.
(ii) B byte 0 over the 216 violating-cell pairs
against the JOINT companions of the eight exhausted
singles — AES-NUM-145/146 found centre set, cidx
set, poscat pattern, (cidx, centre) sequence, idx
sequence, in37 pattern, A byte 0 and the (cidx, idx)
sequence all fail singly, with zero agreeing repeats
in total. Tests: B byte 0 as a function of each
joint companion — (per-record idx sequence, A byte
0), (per-record (cidx, idx) sequence, A byte 0),
(per-record in37 pattern, A byte 0), and (per-record
idx sequence, per-record in37 pattern) — each
printed with distinct / repeating / agreeing /
violating counts exactly, and the population's pairs
printed in full once under the strongest of the
four (fewest violating, then most distinct). Any
determination NOT PROVEN unless the numbers prove
it; never invent one.
(iii) the two pair-pairs' byte-0 step and
cell-third step tested corpus-wide — AES-NUM-146
found both (byte1, byte2, byte3) base groups rise
byte 0 by exactly +4 from pair 1 to pair 2 (B byte 0
== A byte 0 in all four pairs), with cell third
components rising by 5,200 and 5,496. Tests: over
all 224 pairs, every unordered pair-pair sharing
the (byte1, byte2, byte3) sub-key alone (any status,
group, or record count) printed with its byte-0
difference, its B-minus-A byte-0 differences, and
its cell-third difference where both pairs carry a
single cell; the distributions of byte-0 differences
and of (byte-0 difference, cell-third difference)
pairs printed exactly. Any relation NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef146b.py lineage in ~/workspace/.verify-tmp/aesir146 is the base for hef147 (hef146b = the typo-corrected hef145 base plus arms146, sha256 879a193e…; the uncorrected hef146 main file crashes in the inherited arms145 dissection before any new arms can run and must NOT be used as the base); section146.txt + hef146b.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
