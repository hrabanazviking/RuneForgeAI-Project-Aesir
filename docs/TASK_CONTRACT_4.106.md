# TASK_CONTRACT_4.106 (AES-NUM-106)

Scope (from AES-NUM-105's NEXT + TODO 4.106):
(i) the singleton-only neighbourhood values themselves — the values at each relative position (-8, -4, +4, +8) that occur in the 5 singleton DENSE zeros' neighbourhoods and in no run-member neighbourhood (AES-NUM-104 disjointness, controlled in AES-NUM-105): their identity across the 5 singletons' groups/offsets, and whether they recur anywhere else in the corpus populations;
(ii) the cidx-3 counterpart at 9272 word-by-word — (MiniLM, 23, 32768) cidx 3 record value 127, z 1, DENSE, mask 00001, word ff7f0000, neighbourhood (ff7f0000, ffffff7f, ff7f0000, d30b0000, 00000000) vs the cidx-5 DENSE zero's neighbourhood (62470000, 00000000, ff000000, 02000000, 01000000), position by position;
(iii) label values vs the segments' own block positional structure — the fam1/fam2 label pair of the 25 camp segments against in-segment block positions (the last untested in-segment determiner class; cidx/segidx/rank, ngidx/ng, and the label pair itself are all closed), under the AES-NUM-100 degeneracy ruling.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
