# TASK_CONTRACT_4.210 (AES-NUM-210)

Scope (from AES-NUM-209's NEXT + TODO 4.210).
Run 102's walk continues past the measured
index-order divergence; this slice takes the
next side-only act on each side and then the
measured resync of the two index orders, all
measured in AES-NUM-209's own output:
(i) the A-only act at A 734 in full —
(791777280, 24, 1), measured in AES-NUM-209
at A-offset rank 741 with no B occurrence,
following the divergent A-only act at A 733
immediately in both A index order and A
offset order. Tests: the act in full on the
A side (index, offset rank, class, run and
shift, occurrences); its neighbourhoods in
A index order and A offset order; its
correspondence key in full.
(ii) the B-only act at B 736 in full —
(1196444672, 24, 1), measured in
AES-NUM-209 at B-offset rank 748 with no A
occurrence, following the divergent B-only
act at B 735 immediately in both B index
order and B offset order. Tests: as in (i),
for this act on the B side.
(iii) the shared resync act at A 737 / B 739
in full — (768609280, 24, 0), measured in
AES-NUM-209 at A-offset rank 33 and B-offset
rank 34, following the four side-only acts
on each side (A 733–736 / B 735–738).
Tests: the act in full on both sides
(indices, both offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
whether it is the fifty-first act of run
102; and whether the identical-order
sequence resumes after the divergence, and
exactly how far the resumed sequence runs.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef209.py lineage in ~/workspace/.verify-tmp/aesir209 is the base for hef210 (hef209 = the hef208 base plus arms209, sha256 de2b2cf1…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef210/h210 child BEFORE launching.
