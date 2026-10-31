# TASK_CONTRACT_4.179 (AES-NUM-179)

Scope (from AES-NUM-178's NEXT + TODO 4.179):
(i) the B-offset-order acts above the window at
ranks 733–736 in full — AES-NUM-178 measured the
extended window ranks 715–735: ranks 733–735 are
B-only acts at B indices 13 (1196224512, 32768, 1),
14 (1196257280, 14416, 1) and 15 (1196271696,
376, 1), and rank 736 is the B-only act at B
index 16 (1196272072, 24, 1), none yet given in
full. Tests: each act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether any of these acts has an A-side
counterpart act in context A, and if so where.
Any law NOT PROVEN unless the numbers prove it;
never invent one.
(ii) runs 100 and 101 in full — AES-NUM-178's
run table measured run 100 as a −452 singleton
at A 680 / B 228, act (791419904, 32784, 2), and
its run-99 A neighbourhood measured run 101 as
a −7 act at A 682 / B 675, act (3446784, 24, 2),
neither yet given in full. Tests: secondary
runs 100 and 101 in full (acts, A/B extents,
shifts, B contiguity); their B neighbourhoods
in full; their A neighbourhoods in full. Any
law NOT PROVEN unless the numbers prove it;
never invent one.
(iii) run 102 in full — the final secondary
run, recorded in earlier slices as 58 acts at
shift +2, not yet given in full in this line.
Tests: secondary run 102 in full (all its acts,
A/B extents, shift, B contiguity); its B
neighbourhoods in full; its A neighbourhoods
in full. Any law NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef178.py lineage in ~/workspace/.verify-tmp/aesir178 is the base for hef179 (hef178 = the hef177 base plus arms178, sha256 450419b7…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef179/h179 child BEFORE launching.
