# TASK_CONTRACT_4.209 (AES-NUM-209)

Scope (from AES-NUM-208's NEXT + TODO 4.209).
Run 102's walk continues in index order on both
sides; this slice takes the next two shared acts
of run 102 and then the measured divergence of
the two index orders, all measured in
AES-NUM-208's own output:
(i) the shared run-102 act at A 731 / B 733 in
full — (791776256, 24, 2), measured in
AES-NUM-208 at A-offset rank 738 and B-offset
rank 718, the forty-ninth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
forty-eighth run-102 act at A 730 immediately in
both index orders and both offset orders.
Tests: the act in full on both sides (indices,
both offset ranks, class, run and shift,
occurrences); its neighbourhoods in both index
orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 732 / B 734
in full — (791776768, 24, 0), measured in
AES-NUM-208 at A-offset rank 739 and B-offset
rank 719, the fiftieth act of run 102, following
the act in (i) immediately in both index
orders. Tests: as in (i), for this act.
(iii) the index-order divergence in full —
the act at A 733, (791776792, 24, 0), measured
in AES-NUM-208 as A-only distinct at A-offset
rank 740 with no B occurrence, and the act at
B 735, (1196444160, 24, 0), measured in
AES-NUM-208 as B-only distinct at B-offset
rank 747 with no A occurrence. Tests: both acts
in full on the side where they occur (indices,
offset ranks, class, occurrences, correspondence
keys); their neighbourhoods in both index orders
and both offset orders; whether the first fifty
run-102 acts are identical in order on both
sides, and exactly where the identical-order
sequence ends.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef208.py lineage in ~/workspace/.verify-tmp/aesir208 is the base for hef209 (hef208 = the hef207 base plus arms208, sha256 bc46537d…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef209/h209 child BEFORE launching.
