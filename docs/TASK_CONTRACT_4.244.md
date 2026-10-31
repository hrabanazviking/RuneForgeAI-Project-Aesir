# TASK_CONTRACT_4.244 (AES-NUM-244)

Scope (from AES-NUM-243's NEXT + TODO 4.244).
AES-NUM-240 stated the two closing runs' internal
gap sequences in aggregate and AES-NUM-241..243
compared their size/channel, class/run-102 and
offset/index sequences position by position; the
gap sequences have not been compared position by
position:
(i) the A closing run's internal gap sequence in
full — the seven gaps between consecutive acts at
A-offset ranks 741-748 in rank order (each gap =
the next act's offset minus this act's offset),
stated exactly.
(ii) the B closing run's internal gap sequence
in full — the seven gaps between consecutive
acts at B-offset ranks 743-750 in rank order,
stated exactly.
(iii) the closing-run gap comparison — position
by position (first through seventh gap): gap on
each side and whether the gaps agree at that
position; the agreement count over the seven
positions stated exactly.
Tests: each run's printed gap sequence equals
the sequence stated in AES-NUM-240 as measured
in AES-NUM-231 (A gaps [512, 512, 512, 512, 512,
512, 512]; B gaps [712, 26624, 14848, 33280, 512,
512, 512]), and each printed gap equals the
difference of the corresponding printed offsets
from AES-NUM-243.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef243.py lineage in ~/workspace/.verify-tmp/aesir243 is the base for hef244 (hef243 = the hef242 base plus arms243, sha256 29bd382a…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef244/h244 child BEFORE launching.
