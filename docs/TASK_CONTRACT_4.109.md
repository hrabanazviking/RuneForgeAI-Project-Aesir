# TASK_CONTRACT_4.109 (AES-NUM-109)

Scope (from AES-NUM-108's NEXT + TODO 4.109):
(i) the mixed 0a0d378c @17344 cell pair by pair — AES-NUM-108(i) found this single (group, offset) cell holds both classes: 6 total-disagreement (0/5) pairs (one identical word-pair repeated) and 15 identical (5/5) pairs of its 21. Test: enumerate all 21 pairs in the cell exactly; for each, the two neighbourhoods' forms, zero patterns and word values; test every measured property (form pair, zero counts, per-position values, instance identity) as a separator of the 0/5 vs 5/5 classes within the cell — or record the within-cell separator as NOT PROVEN;
(ii) the cc9b9d1c rare-containing segments as a class — AES-NUM-108(iii) found 929 of cc9b9d1c's 112,884 distinct referenced segments (0.82%) hold all 3,680 cc9 rare-word occurrences (fd000000 in 569 segments, f6000000 in 497, e9ff0000 in 170). Test: the fd/f6/e9 containing-segment sets' overlaps (pairwise and triple intersections vs chance under the cc9 segment census), and the class's joint size/offset structure (size distribution, occurrence-count distribution, offset quartiles per word and pooled) vs the cc9 census as a whole — is the class a distinct subpopulation or a density artefact?;
(iii) the sister cidx-95 SPARSE singleton's uniqueness in its group — AES-NUM-108(i) found the sisters' @17272 zero pairs are one identical SPARSE B neighbourhood against 9 DENSE label-variants. Test: for that SPARSE singleton's group, whether its 9 DENSE partners agree with it (or among themselves) at any other common offset of the group (neighbourhood position-equality at every other shared offset), and whether the singleton is unique in its group on any other measured property — or record uniqueness as confined to @17272.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
