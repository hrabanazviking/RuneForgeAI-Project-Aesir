# TASK_CONTRACT_4.228 (AES-NUM-228)

Scope (from AES-NUM-227's NEXT + TODO 4.228).
AES-NUM-227 closed the B-offset order at its
last measured rank (750), but the closure was
stated from the three final acts' own sections;
it has not itself been given in full on closure
terms, and no census over the whole B-offset
order has been taken in this sequence:
(i) the B-offset-order closure in full —
ranks 745–750, each with B index, act, class
and gap to the next rank where a next rank
exists in the measured list (B acts 751, max
rank 750, so rank 750 has no next rank and its
gap is None); followed by the closing run of
ranks 743–750 in full on the same terms.
Tests: every rank in 743–750 stated exactly;
no rank beyond 750 may be requested.
(ii) the full-order census over B-offset
order — B acts 751, ranks 0–750; the act at
rank 0 and the act at rank 750; the class
census over all 751 acts in that order
(counts per class as defined in the
controls); the run-102 membership count over
that order.
Tests: the census counts sum to 751; first
and last acts stated exactly.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef227.py lineage in ~/workspace/.verify-tmp/aesir227 is the base for hef228 (hef227 = the hef226 base plus arms227, sha256 b92f1f17…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef228/h228 child BEFORE launching.
