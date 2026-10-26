# TASK_CONTRACT_4.110 (AES-NUM-110)

Scope (from AES-NUM-109's NEXT + TODO 4.110):
(i) the mixed 0a0d378c @17344 cell's second common offset, and cidx 44's cross-group profile — AES-NUM-109(i) established the cell holds exactly two neighbourhoods: cidx 44 alone vs the other six byte-identical instances; the 6 total-disagreement pairs are exactly 44 x each other and the 15 identical pairs are within the six. Test: at the cell's second common offset, whether cidx 44 is again the singleton against the same six (same neighbourhood identity, form, zero pattern and per-position words), and cidx 44's profile across the other groups it sits in — is the @17344 singleton the same kind of instance elsewhere, or is its singleton status confined to this cell?;
(ii) the cc9b9d1c rare-containing segments' referencing-action profile — AES-NUM-109(ii) established the 929 rare-containing segments are a distinct subpopulation (fd/f6/e9 set overlaps 37-1,325x independence; only 11 segment sizes; offset quartiles Q2+Q4 = 91.8% of the class), but their referencing-action profile was NOT MEASURED. Test: which (pos, size, channel) pointer actions and which contexts reference the 929 segments, vs all cc9b9d1c references — the class's identity from the pointing side; is the class distinguished by its referrers, or only by its contents?;
(iii) the sister cidx-95 SPARSE singleton's per-offset differing positions and cross-group profile — AES-NUM-109(iii) established cidx 95 is unique at all 4 common offsets of its group in both sister artifacts, with equality vs its partners 2/0/2/1 per offset and total disagreement confined to @17272. Test: which of the 5 neighbourhood positions carry cidx 95's distances 2/0/2/1 at the four common offsets, and cidx 95's profile in the other groups of its artifacts — unique elsewhere too, or only in this group?

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
