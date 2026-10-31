# TASK_CONTRACT_4.184 (AES-NUM-184)

Scope (from AES-NUM-183's NEXT + TODO 4.184):
(i) the B-only act at B 392 in full — the act
(791266816, 32784, 2), measured in AES-NUM-183
at B-offset rank 693, whose (offset, size) key
is held on the A side by the A-only act at
A 675 (791266816, 32784, 1) at A-offset rank
712. Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence-key relation to
the A-side act at A 675 in full (that act's
A index, A-offset rank, class and key).
(ii) the two B-only acts at B 5 and B 6 in
full — (1196182016, 24, 2) at B-offset rank
728 and (1196182528, 24, 0) at B-offset rank
729, measured in AES-NUM-183 following the
offset triplet in both B-index order (B 5, B 6
after B 0–B 4) and B-offset order (ranks 728,
729 after rank 727). Tests: as in (i), for
these acts, on the B side (B index, B-offset
rank, A-side counterpart, correspondence key).
(iii) the shared run-94 act that follows the
run-93 act in both offset orders in full —
(791173632, 32784, 0) at A 672 / B 673,
measured in AES-NUM-183 at A-offset rank 709
and B-offset rank 691; AES-NUM-183's run table
places run 94 immediately after run 93.
Tests: the act in full on both sides (indices,
both offset ranks, class, run and shift,
occurrences); its neighbourhoods in both
index orders and both offset orders. Any law
NOT PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef183.py lineage in ~/workspace/.verify-tmp/aesir183 is the base for hef184 (hef183 = the hef182 base plus arms183, sha256 956e4b72…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef184/h184 child BEFORE launching.
