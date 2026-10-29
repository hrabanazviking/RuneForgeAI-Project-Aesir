# TASK_CONTRACT_4.129 (AES-NUM-129)

Scope (from AES-NUM-128's NEXT + TODO 4.129):
(i) byte 0 with A byte 0 admitted to the key —
AES-NUM-128 established B byte 0's non-determination
by the full (byte 3, byte 1, byte 2) key is localized
to group (14, 9992)'s two narrow keys, whose pairs
differ only in byte 0, and that all eight narrow
pairs copy byte 0 (B byte 0 == A byte 0). Tests:
B byte 0's determination by the extended key
(byte 3, byte 1, byte 2, A byte 0) computed globally
over the 224 pairs and separately inside each of the
map's three groups, violating keys named in full;
and the byte-0 map's identity status beyond the
narrow population: over the 216 non-narrow pairs,
the count and full list of pairs with B byte 0 !=
A byte 0, read by group. Any determination NOT
PROVEN unless the numbers prove it; never invent one.
(ii) the deviation sign patterns paired across the
two sides of each cidx, and the step against sum and
level together — AES-NUM-128 established 15 deviation
sign patterns over the 54 sequences (no sequence
monotone in k) and that the pooled step is not a
function of the sum under either anchoring. Tests:
for each of the 27 cidxs, its A and B patterns
printed side by side, with equality, sign-complement
and reversal (pattern B == reverse of pattern A,
and B == complement of reverse) tested exactly and
the relation census over the 27 pairs in full; and
the pooled 161 steps tested as a function of
(starting sum, starting diff) exactly (violating
keys named in full), with the companion
(starting sum, byte 3) anchoring also tested.
Any form NOT PROVEN unless the numbers prove it;
never invent one.
(iii) the class-271 end block's position-from-end
structure and its two loose lead acts —
AES-NUM-128 established the before-flank stands at
position-from-end exactly 20 in all 271 of its
contexts, that the 30 class-271 acts hold identical
relative order in contexts 114 and 251, and that 28
of them take exactly 20 distinct corpus positions
while the first two — (2727936, 24, 2) and
(2774016, 24, 1) — take 51 and 54. Tests: each of
the 30 acts' position-from-end in every one of its
271 contexts in full (from-end distribution per act;
whether each act's from-end is constant, and if not
its distinct values in full); the rigid block's
internal from-end spacing (successive acts' from-end
differences within contexts, tested for constancy);
and the two loose lead acts' positions measured
against the block in every context (their from-end
distributions, their distance to the block's first
rigid act, and their order relative to each other
and to the block). Any mechanism NOT PROVEN unless
the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

One bounded host-side child per contract.
