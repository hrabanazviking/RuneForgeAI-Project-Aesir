# TASK_CONTRACT_4.192 (AES-NUM-192)

Scope (from AES-NUM-191's NEXT + TODO 4.192):
(i) the B-only act at B 737 in full — the act
(1196445184, 24, 2), measured in AES-NUM-191
at B-offset rank 749, following B 736 (rank
748) in B-offset order by +512 and in B-index
order as the third act of the four-act B-only
stretch B 735–738. Tests: the act in full
(its act, B index, B-offset rank, class,
occurrences in both contexts); its B-index
neighbourhood in full; its B-offset-order
neighbourhood in full; whether it has an
A-side counterpart act in context A; its
correspondence key in full (any act in A or
B under its (offset, size) key).
(ii) the B-only act at B 738 in full — the act
(1196445696, 24, 0) at B-offset rank 750,
measured in AES-NUM-191, the LAST rank in
B-offset order (context B has 751 acts, ranks
0–750, so it has no successor in that order).
Tests: as in (i), for this act, on the B side
(B index, B-offset rank, A-side counterpart,
correspondence key); plus the two acts at
ranks 749–750 in rank order with their offset
gap and (size, channel) sequence, and the
statement of the end of B-offset order.
(iii) the shared run-102 act that follows
the run-101 act in A-index order in full —
(791479296, 32784, 1) at A 683 / B 685,
measured in AES-NUM-191 at A-offset rank
719 as the first act of run 102 (length 58,
shift +2, A 683–744 / B 685–746). Tests: the
act in full on both sides (indices, both
offset ranks, class, run and shift,
occurrences); its neighbourhoods in both
index orders and both offset orders. Any
law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef191.py lineage in ~/workspace/.verify-tmp/aesir191 is the base for hef192 (hef191r = the hef190 base plus the patched arms191, sha256 db8f0970…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef192/h192 child BEFORE launching.
