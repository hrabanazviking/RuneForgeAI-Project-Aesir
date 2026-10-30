# TASK_CONTRACT_4.172 (AES-NUM-172)

Scope (from AES-NUM-171's NEXT + TODO 4.172):
(i) the full run-table shift census against the
31 pair deltas — AES-NUM-171 proved the deltas
−205 (A 417/418) and −212 (A 430/431) are shifts
of NO run in the full 103-run table, that +170
and +30 each occur as exactly one run's shift,
and that delta 0 occurs as six runs' shifts.
Tests: every distinct shift in the full run
table with its run count and run indices in
full; every one of the 31 pair deltas against
that census (occurs / never occurs, count of
runs carrying it); the distinct-shift count and
the shift range; whether the set of pair deltas
is a subset of, disjoint from, or mixed against
the set of run shifts, stated exactly. Any law
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the 417-family A-offset ordering with
position 16 removed + the (5, 6) reversal in
full — AES-NUM-171 measured eight reversals
among the family's 120 position-ordered pairs:
seven involving position 16 and one, (5, 6),
not involving it. Tests: with position 16
removed, the fifteen remaining family positions
in A-offset order against their position order
(concordance and every reversal in full);
whether the (5, 6) reversal is then the family's
only reversal; positions 5 and 6 in full (their
A/B acts, offsets, diffs, sizes, channels, and
their neighbours in both orders). Any law NOT
PROVEN unless the numbers prove it; never
invent one.
(iii) runs 74 and 75 in full — AES-NUM-171's
run table measured run 74 as an 83-act +0 block
at A 524–614 and run 75 as a −111 singleton at
A 615 / B 504, after run 73 in A order. Tests:
secondary runs 74 and 75 in full (acts, A/B
extents, shifts, B contiguity); their B
neighbourhoods in full; their A neighbourhoods
in full. Any law NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef171.py lineage in ~/workspace/.verify-tmp/aesir171 is the base for hef172 (hef171 = the hef170 base plus arms171, sha256 b63a8c4e…); section171.txt + hef171.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef172/h172 child BEFORE launching.
