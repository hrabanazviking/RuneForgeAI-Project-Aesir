# TASK_CONTRACT_4.118 (AES-NUM-118)

Scope (from AES-NUM-117's NEXT + TODO 4.118):
(i) thickness-graded continuation verdicts for the mirror pair's 2,171
membership-divergent triples — AES-NUM-117 established verdicts CONT
12,411 / BREAK 476 / INDET 2,365 over 15,252 extras, with the banked
caveat that UNANIMOUS includes common sequences of length 1 and the
printed BREAK examples are exactly such thin-common triples. Tests:
re-grade every extra's continuation verdict by the thickness of its
triple's common sequence (common-instance count strata, e.g. 0 / 1 /
2 / 3-5 / 6+), reporting CONT/BREAK/INDET per stratum and per
structure class (UNANIMOUS / NONAP / AP / SINGLE); anatomise the
AP-common extras' 103 breaks and the 72 any-BREAK triples in full
(every such triple listed with its group, common length, extra
positions and centres, and why the verdict is BREAK). Grade thin-
common verdicts honestly — a verdict resting on a length-1 common
sequence is not evidence of the same weight as a thick one.
(ii) the 37/96 differing words identified across artifacts —
AES-NUM-117 established the 37 in three exact families (535 breakers,
lanes 0/3 only, centres equal 535/535), the 96 with 1,971 differing
instances (centre lane differs 0/1,971; 60 cells differ at all 27
instances), and differing words occurring elsewhere in the corpus
neighbourhood pool for 766/1,971 (B word) vs 791 (A word). Tests:
for each differing B word in the 37/96 populations, determine
whether that exact word occurs in another corpus artifact at the
same group (same (pos, segsize) group / same cell coordinates where
the other artifact carries that group), and in how many artifacts;
test whether the 28-instance first-instance pattern (B's word
differs at all but instance idx 0) appears in other artifact pairs
over their shared cells (all pairs among the 7 artifacts that share
cells, same test); determine whether the 60 whole-cell differing
cells coincide with the 37's groups (group overlap counts, exact).
(iii) the three unshifted heads' unique acts searched corpus-wide
in cc9b9d1c — AES-NUM-117 established train 48 ranks 1-2 share no
head material (two independent anomalies, shifts NOT PROVEN) and
train 50 rank 26's head is one act shorter in count with an empty
deletion alignment (-1 mechanism NOT PROVEN). Tests: collect the
unique head acts of the three ranks (acts occurring in those heads
and in no steady train-48/50 member head, plus their first acts,
opening pairs and prev_acts), and search each act corpus-wide in
cc9b9d1c's contexts — does the act head any other context (position
0 of a context's act sequence), does it occur anywhere else in a
context, and at what positions/counts; report per act, graded
measured / NOT PROVEN, never invent a shift or a mechanism.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
