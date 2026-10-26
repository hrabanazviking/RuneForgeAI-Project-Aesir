# TASK_CONTRACT_4.108 (AES-NUM-108)

Scope (from AES-NUM-107's NEXT + TODO 4.108):
(i) the 25 total-disagreement (0/5) instance pairs as a class — AES-NUM-107(iii) found 789 same-group instance pairs at common offsets with position-equal distribution {0:25, 1:172, 2:88, 3:2, 4:246, 5:256} (mean 3.318, the 9272 target pair one of the 25). Test: enumerate all 25 (group, offset, instance pair) exactly; their groups/offsets distribution, per-position differing-byte counts, forms and zero patterns of both neighbourhoods, compared against the 256 identical (5/5) pairs as the control class — is there any measured property that separates the 0/5 class, or is its separator NOT PROVEN?;
(ii) the near-empty exactly-3 band and the bimodality's group structure — exactly-3 occurs only twice in 789 while 0–2 and 4–5 carry the mass. Test: agreement distribution per group (all 18 groups, all common offsets): per-group means, per-group 0/5 and 5/5 counts, whether agreement grades as a per-group property (groups concentrated at one pole) or a per-offset/per-pair property within groups, and the two exactly-3 pairs identified in full;
(iii) the cc9b9d1c rare-word concentration — AES-NUM-107(ii) found fd000000 (3,223 distinct-segment occurrences; cc9b9d1c 1,878) and f6000000 (2,286; cc9b9d1c 1,622) concentrated in cc9b9d1c. Test: per-artifact density of fd000000, e9ff0000 and f6000000 per referred byte (distinct referenced bytes per artifact as the denominator, AES-NUM-107(ii) population), per-artifact share vs byte share, and whether the concentration is uniform across cc9b9d1c's segments or carried by a subpopulation (segments containing the words: their sizes and counts vs the artifact's segment census).

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
