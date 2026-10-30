# TASK_CONTRACT_4.174 (AES-NUM-174)

Scope (from AES-NUM-173's NEXT + TODO 4.174):
(i) the eight larger head gaps in full —
AES-NUM-173 measured the 27 consecutive gaps
in the head's A-offset sorted order; exactly
eight exceed the 7,168 gap from the third-
lowest to the fourth-lowest (33,280; 32,768;
32,728; 30,208; 24,848; 14,416; 7,800; 7,712).
Tests: each of the eight in full (its value,
its rank pair in the sorted order, the two
positions it separates with their A/B offsets,
sizes and channels); what crosses each gap in
417-family / diff status (family membership
and diff of the positions below and above);
the eight as a population (which rank pairs,
whether the positions above/below share any
measured status). Any law NOT PROVEN unless
the numbers prove it; never invent one.
(ii) the A 640–660 placement region of the
ninth delta-0 pair in full — AES-NUM-173
measured the ninth pair at A 651 lying in no
run's extent, between run 85 (9 acts, shift
−1, last A position 650) and run 86 (6 acts,
shift +26, first A position 652). Tests:
every A position 640–660 in full (act, class,
run/shift where shared); every B position
640–660 in full; runs 85 and 86 in full
(acts, extents, shifts, B contiguity,
neighbourhoods). Any law NOT PROVEN unless
the numbers prove it; never invent one.
(iii) runs 78 and 79 in full — AES-NUM-173's
run table measured run 78 as a −391 pair at
A 621–622 and run 79 as a +7 pair at
A 623–624, after run 77 in A order. Tests:
secondary runs 78 and 79 in full (acts, A/B
extents, shifts, B contiguity); their B
neighbourhoods in full; their A
neighbourhoods in full. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef173.py lineage in ~/workspace/.verify-tmp/aesir173 is the base for hef174 (hef173 = the hef172 base plus arms173, sha256 1b16333f…); section173.txt + hef173.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef174/h174 child BEFORE launching.
