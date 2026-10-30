# TASK_CONTRACT_4.177 (AES-NUM-177)

Scope (from AES-NUM-176's NEXT + TODO 4.177):
(i) the 873-prefix trio's B-offset-order flank
acts in full — AES-NUM-176 measured the trio's
three B acts as consecutive in B-offset order at
ranks 724–726 of 751 (order 1, 0, 27; gaps 512,
512), flanked below by rank 723 (B index 749,
(800053760, 24, 2)), rank 722 (B index 747,
(791781888, 24, 0)) and rank 721 (B index 748,
(791781376, 24, 1)), and above by rank 727
(B index 750, (973679616, 24, 0)) and the
1,196-prefix head acts at ranks 728–729
(B indices 5, 6). Tests: each flank act in full
(its act, B index, B-offset rank, class,
occurrences in both contexts); its B-index
neighbourhood in full; its position in context
B's tail (indices 745–750) in full; whether any
of the flank acts has an A-side counterpart act
in context A, and if so where. Any law NOT
PROVEN unless the numbers prove it; never
invent one.
(ii) runs 92 and 93 in full — AES-NUM-176's run
table measured run 92 as a +1 pair at A 668–669
/ B 669–670, not yet given in full; run 93 not
yet measured in this line. Tests: secondary
runs 92 and 93 in full (acts, A/B extents,
shifts, B contiguity); their B neighbourhoods
in full; their A neighbourhoods in full. Any
law NOT PROVEN unless the numbers prove it;
never invent one.
(iii) runs 94 and 95 in full — not yet measured
in this line. Tests: secondary runs 94 and 95
in full (acts, A/B extents, shifts, B
contiguity); their B neighbourhoods in full;
their A neighbourhoods in full. Any law NOT
PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef176.py lineage in ~/workspace/.verify-tmp/aesir176 is the base for hef177 (hef176 = the hef175 base plus arms176, sha256 2da4745e…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef177/h177 child BEFORE launching.
