# TASK_CONTRACT_4.240 (AES-NUM-240)

Scope (from AES-NUM-239's NEXT + TODO 4.240).
AES-NUM-232..239 walked the two closing runs
act by act in paired form; the two runs have
not been set side by side in full in this
sequence since AES-NUM-231:
(i) the A closing run in full — all eight acts
at A-offset ranks 741-748 in rank order, with
the run's internal gap sequence stated exactly
(seven gaps, between consecutive acts in
A-offset order) and each act's class and
channel.
(ii) the B closing run in full — all eight acts
at B-offset ranks 743-750 in rank order, with
the run's internal gap sequence stated exactly
(seven gaps, between consecutive acts in
B-offset order) and each act's class and
channel.
(iii) the closing-run full comparison — the two
runs side by side: act-by-act position table
(first through eighth act: rank, index, act,
class, channel on each side), gap sequences
side by side, terminal status on each side.
Tests: each run's printed gap sequence equals
its AES-NUM-231 measured sequence (A
[512, 512, 512, 512, 512, 512, 512]; B
[712, 26624, 14848, 33280, 512, 512, 512]);
each act's stated rank/index/act/class equals
its per-act statement in AES-NUM-232..239.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef239.py lineage in ~/workspace/.verify-tmp/aesir239 is the base for hef240 (hef239 = the hef238 base plus arms239, sha256 b6b7ff56…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef240/h240 child BEFORE launching.
