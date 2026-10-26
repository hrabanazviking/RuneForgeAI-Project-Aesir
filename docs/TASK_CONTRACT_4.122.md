# TASK_CONTRACT_4.122 (AES-NUM-122)

Scope (from AES-NUM-121's NEXT + TODO 4.122):
(i) the varying centres as sequence members, and the other
single-centre anchors — AES-NUM-121 established the six
varying centres {32, 40, 43, 51, 85, 122} never anchor a
unanimous triple anywhere in the corpus (0 at every stratum
beyond thin length 1, 0 of 18,286 unanimous >=8 cells, 0
unanimous-word cells in any artifact, at most once per
cell), occurring as common members only in NONAP/AP
sequences (32: 36 mid + 44 thick; 51: 29 mid + 1 thick;
43: 19 mid; 40: 8 mid; 85/122: none beyond length 1),
with extras never equal to them. Tests: for each varying
centre that occurs as a sequence member, read its position
inside each mid/thick common sequence that contains it
(index within the sequence, the sequence's step/structure
around it, its neighbours in the sequence, and whether it
sits at an end, a start, or interior), counted exactly over
every containing sequence; and read the other single-centre
anchors {7, 11, 95, 139} (the remaining centres recorded in
the inherited enumeration that are neither varying nor
constant) against the varying six on the same terms used in
4.121 — unanimous-centre counts by stratum, >=8-cell
unanimous counts, per-cell occurrence ceilings, extras
behaviour — are they varying-like, constant-like, or
neither? Every claim counted exactly over its full
population, never inferred from a sample. Why any centre
has the membership it has: grade measured / NOT PROVEN;
never invent a cause.
(ii) lane 1's 224 pairs split by cell/group, and byte 3's
small-difference law — AES-NUM-121 established lane 1's
224-pair bijection carries no closed form (218 distinct
differences, 217 distinct XORs, GF(2)-affine residuals
193/223), that most pairs differ in all four bytes, and
that byte 3 carries only 24 distinct signed differences
(top -1 x43, -7 x17, -8 x16). Tests: split the 224 pairs
by the cell and group each differing lane belongs to
(per-cell and per-group pair counts, and whether the
pair distribution inside a single cell/group is narrower
than the pooled distribution — distinct diffs/XORs per
cell/group against the pooled 218/217); and tabulate byte
3's signed difference as a function of A's byte-3 value
exactly over all 224 pairs (for each A byte-3 value: the
set/counts of signed differences) — is the difference
determined by A's byte 3, confined to a band per value,
or unstructured? A determination claim needs zero
counterexamples over the full 224; anything short is
graded as measured distribution only. Source of the
bijection NOT PROVEN unless the numbers prove it.
(iii) the +597 aligned region read in full, and cidx 267's
own occurrence profile — AES-NUM-121 established cidx 267
(842 acts, all distinct, ng 1, start 6, in no train) shares
36 acts with cidx 144, with shared runs >=3 only at four
places, the first three on ONE +597 alignment (144 pos
190-220 <-> 267 pos 787-817: runs of 15 at 206<->803, 7 at
197<->794, 5 at 190<->787). Tests: read the aligned region
in full in both contexts (144 positions 190-220 and 267
positions 787-817, act by act, marking exactly which
positions agree and which differ, and the acts at the
differing positions on both sides); and cidx 267's own
occurrence profile — for each of its 842 acts, its
corpus-wide occurrence count, tabulated as a distribution
(how many of its acts are corpus-unique, how many occur
2x, 3x, ...), its occurrence profile against cidx 144's
own profile computed on the same terms, and where its
non-unique acts occur (which artifacts/contexts). Any
mechanism NOT PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
