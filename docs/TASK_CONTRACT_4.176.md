# TASK_CONTRACT_4.176 (AES-NUM-176)

Scope (from AES-NUM-175's NEXT + TODO 4.176):
(i) the 873-prefix trio's B-side placement —
AES-NUM-175 measured the head's three non-identity
non-417 positions (0, 1, 27) carrying B offsets
873,199,104 / 873,198,592 / 873,199,616 (a span of
1,024) against A offsets spanning 193,040, with
positions 0/1 in reversed B order. Tests: each of
the three B acts' index in context B in full; its
B neighbourhood in full (the acts around that
index in B order, their classes, runs and A
positions); whether any other head B act carries
an 873-prefix offset; the B-side order of the
three against their A order; the reversed pair
(0, 1) against the wider B-side pattern around
their B indices. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(ii) runs 82, 83 and 89 in full — AES-NUM-175's
run table 79–89 measured run 82 as a +49 singleton
at A 635 (B 684), run 83 as a +24 singleton at
A 636 (B 660) and run 89 as a −277 singleton at
A 665 (B 388), none yet given in full. Tests:
secondary runs 82, 83 and 89 in full (acts, A/B
extents, shifts, B contiguity); their B
neighbourhoods in full; their A neighbourhoods
in full. Any law NOT PROVEN unless the numbers
prove it; never invent one.
(iii) runs 90 and 91 in full — AES-NUM-175's
neighbourhoods measured run 90 as a +1 act at
A 666 (B 667) and run 91 as a −255 act at A 667
(B 412) without giving those runs in full. Tests:
secondary runs 90 and 91 in full (acts, A/B
extents, shifts, B contiguity); their B
neighbourhoods in full; their A neighbourhoods
in full. Any law NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef175.py lineage in ~/workspace/.verify-tmp/aesir175 is the base for hef176 (hef175 = the hef174 base plus arms175, sha256 c5f45c73…; the retry output hef175r.out + section175.txt are on the Pi at ~/aesir-build/). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef176/h176 child BEFORE launching.
