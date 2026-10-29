# TASK_CONTRACT_4.136 (AES-NUM-136)

Scope (from AES-NUM-135's NEXT + TODO 4.136):
(i) gap 2's chain against the maximal compound
joint key — AES-NUM-135 established the loose order
adds no key beside the distances (84 distinct,
violations unchanged, every violating key under
L1-before-L0), while a sister fill beside the
distances gives 86 distinct keys and silences
exactly the widest key's (2, 4) branch (position-1
fails 2, position-2 fails 3 under either sister),
and the whole tuple as a function of (position-0,
distances) fails on exactly 4 of 84 keys. Tests:
position-1 and position-2 tested as functions of
the single maximal compound joint key (position-0
act, loose distances (d0, d1), loose order, gap-0
tuple, gap-1 tuple), computed exactly over the 271
contexts (distinct joint keys, repeating joint keys,
violating joint keys named in full with their
alternatives and contexts); and the whole gap-2
tuple tested as a function of (position-0 act,
loose distances (d0, d1), gap-0 tuple) and of
(position-0 act, loose distances (d0, d1), gap-1
tuple) the same way. Any relation NOT PROVEN
unless the numbers prove it; never invent one.
(ii) an end-anchoring census over the 19 size-328
acts and their 21 partners — AES-NUM-135 read
every occurrence's position, context length and
position-from-end in full: 18 of the 19 small acts
are position-fixed, the sole exception
(791774208, 328, 0) is position-from-end-fixed
(23 in both its contexts, lengths 749 / 751), and
the five twice-occurring partners are fixed
neither by position nor from the end. Tests: each
of the 19 acts and each of the 21 partners
classified exactly as start-fixed (one position),
end-fixed (one position-from-end), both, or
neither, counted exactly over the two populations;
and the exception's two contexts read against each
other (every act either context shares with the
other, with its positions in both, counted
exactly). Any relation NOT PROVEN unless the
numbers prove it; never invent one.
(iii) B byte 0 against the two-byte sub-keys
INSIDE each group — AES-NUM-135 established that
inside a single group no three-byte value ever
repeats agreeing, and the agreeing cross-group
two-byte values' whole company is exactly their
carriers. Tests: for each of the six two-byte
sub-keys of the A word and each of the three
groups separately, every key value carried by more
than one pair of that group, counted exactly, with
each repeated value's pairs printed in full (A and
B words, B byte 0, status, records) and its
agreeing / violating verdict. Any determination
NOT PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef135.py lineage in ~/workspace/.verify-tmp/aesir135 is the base for hef136; section135.txt + hef135.out are there.

One bounded host-side child per contract.
