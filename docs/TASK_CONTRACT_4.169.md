# TASK_CONTRACT_4.169 (AES-NUM-169)

Scope (from AES-NUM-168's NEXT + TODO 4.169):
(i) the 31 correspondence pairs' position-delta law
against neighbouring secondary-run shifts in full —
AES-NUM-168 measured, derived at closing from its
printed 1–1 table, that a pair's position delta
(B position minus A position) equals its preceding
shared act's run shift in 19 of 31 pairs, its
following shared act's run shift in 17 of 31, and
at least one of the two in 21 of 31, with 10
exceptions. Tests: recompute the census directly
(not derived); for each of the 31 pairs, the delta
against the shifts of the secondary runs containing
the preceding and following shared acts AND against
the shifts of the runs immediately before and after
those in run order; the 10 exceptions in full
(their deltas against every neighbouring run shift
within three runs either side); whether the delta
is a function of the channel pair, of the pair's
size, or of the A position band. Any law NOT PROVEN
unless the numbers prove it; never invent one.
(ii) the unmatched residue's head-sequence relation —
AES-NUM-168 measured a 17-act A-only head at
A 0–25 (offsets 778,8xx,xxx) and a 17-act B-only
head at B 5–26 (offsets 1,196,xxx,xxx) at overlapping
positions with near-identical size sequences.
Tests: both heads in full, aligned by position
(size, channel, offset at every position 0–27 in
both contexts, shared and context-only acts alike);
the size/channel agreement count over the aligned
positions; the position-13 split (A carries a
32,728 act, B a 32,768 act); the offset differences
at agreeing positions (constant or not, in full);
the B head's extra (280) act at B 26 against A's
(280) act at A 377. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(iii) runs 68 and 69 in full — AES-NUM-167's run
table measured run 68 as a +0 pair at A 506–507 and
run 69 as a +2 block of 8 at A 508–515, after run
67 in A order. Tests: secondary runs 68 and 69 in
full (acts, A/B extents, shifts, B contiguity);
their B neighbourhoods in full; their A
neighbourhoods in full. Any law NOT PROVEN unless
the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef168.py lineage in ~/workspace/.verify-tmp/aesir168 is the base for hef169 (hef168 = the hef167 base plus arms168, sha256 85c7fbb4…); section168.txt + hef168.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
