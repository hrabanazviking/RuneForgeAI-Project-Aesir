# TASK_CONTRACT_4.130 (AES-NUM-130)

Scope (from AES-NUM-129's NEXT + TODO 4.130):
(i) the rigid block's three wide gaps, read in every
context — AES-NUM-129 established all 27 successive
spacings of the 28 rigid acts are constant across
their 271 contexts, with difference 3 at the pairs
(173040, 24, 0) -> (173568, 816, 0) (from-end 50 ->
47) and (174968, 24, 0) -> (175616, 176, 0)
(from-end 41 -> 38), and difference 4 at the closing
pair (178792, 216, 0) -> (2817536, 24, 0) (from-end
24 -> 20). Tests: for each wide gap, in every one of
the 271 contexts, the acts standing between the two
rigid neighbours printed in full (act, position,
from-end); whether the gap contents are the same
acts in the same order in every context, and their
own occurrence classes corpus-wide. Any template
claim NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the loose pair's joint behaviour —
AES-NUM-129 established L0 (2727936, 24, 2) takes
distances 1-33 to the first rigid act (13 distinct,
including a single distance-33 / from-end-87 case)
and L1 (2774016, 24, 1) distances 1-14 (12
distinct), both always before the block, with order
L1-before-L0 in 170 contexts and L0-before-L1 in
101. Tests: both distances read together per
context in full (the joint distribution over the
271 contexts); whether the two distances co-vary
(exact tests: distance L1 as a function of distance
L0 and vice versa, violating contexts named);
whether the pair's order is a function of either
distance or of their difference (tested exactly,
violating contexts named); and the single
distance-33 context read in full (its cidx, both
loose acts' positions and from-ends, the acts
standing between the loose act and the block, and
how that context differs from the modal contexts).
Any relation NOT PROVEN unless the numbers prove
it; never invent one.
(iii) the great group's byte-0 rewriting against
sub-keys of the full A word — AES-NUM-129
established that in group (20, 32720) B byte 0 ==
A byte 0 in 36 of 216 pairs and differs in 180,
and that the full A word determines B byte 0 on
this population with no repeated key. Tests: the
identity/difference status tested as a function of
each proper sub-key of the A word — (byte 3),
(byte 1), (byte 2), (byte 0), (byte 3, byte 1),
(byte 3, byte 2), (byte 1, byte 2), (byte 3,
byte 1, byte 2), (byte 0, byte 1), (byte 0,
byte 3) — computed exactly over the 216 pairs
(for each sub-key: does one sub-key value carry
both identity and differing pairs, and does it
carry two different B byte 0 values among the
differing pairs; violating values named in full);
and the differing pairs' B byte 0 minus A byte 0
read against A byte 0 itself (difference as a
function of A byte 0, tested exactly). Any
determination NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

One bounded host-side child per contract.
