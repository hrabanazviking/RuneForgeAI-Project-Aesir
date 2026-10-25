# Full-corpus walk — universality at seven artifacts (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.16 (AES-NUM-016):
the remaining four hailo-ollama store blobs walked with the
same schema-guided method (mmap walker; header-derived zero
point per blob; the MiniLM control and the worker's two
blobs in AES-NUM-015 are the method's provenance). The
corpus is now **fully walked: 7 of 7 artifacts**.

## Per-blob results (this slice)

| blob (sha prefix) | size | contexts | ptr actions | 24 B bursts | champion share | lane-2 tail | max cluster / LCU |
|---|---|---|---|---|---|---|---|
| 5ab3537d | 1.70 GB | 219 | 129,664 | 5,546 | 4,819 (86.9%) | zero 5,546/5,546 | 4 / 15 |
| 0856a10c | 2.46 GB | 256 | 131,262 | 5,836 | 5,632 (96.5%) | zero 5,836/5,836 | 4 / 15 |
| 76c3a8ff | 2.29 GB | 353 | 123,746 | 8,089 | 7,772 (96.1%) | zero 8,089/8,089 | 4 / 15 |
| cc9b9d1c | 2.88 GB | 271 | 137,800 | 6,287 | 5,962 (94.8%) | zero 6,287/6,287 | 4 / 15 |

Zero points per blob (header + proto + padding): 3,805,184 /
3,928,064 / 3,981,312 / 4,243,456 — each produced structured
lanes, re-confirming the header formula at four more points.

## Corpus-wide laws (empirical)

1. **The lane-0 champion is universal.** `0528000000000000`
   is the dominant first word of the 24-byte burst in every
   one of the seven artifacts — MiniLM, both worker-walked
   GenAI blobs, and all four here — at 86–97% of bursts
   (24,185 of 25,758 in this slice alone).
2. **Lane 2 is a ≤3-byte field, corpus-wide, no exceptions.**
   Bytes 3–7 of lane 2 are zero in **25,758 of 25,758**
   bursts this slice; with the worker's 9,757 from
   AES-NUM-015, the law holds across every burst tested in
   the corpus.
3. **The census floor did not move — and that is now
   information.** Seven artifacts, ~660,000 pointer actions
   and ~48,000 LCU trigger pairs in total, and *none*
   addresses a cluster above 4 or an LCU above 15. Graded
   still as a floor (usage is not silicon), but the
   hypothesis **census = 5 clusters × 16 LCUs** is now the
   leading candidate: it predicts every future artifact
   caps at 4/15 until one breaks it.

## Evidence boundary

Universality claims cover the walked corpus (7 artifacts,
GenAI LLM + embedding families). Blob model identities are
still not claimed (sizes + sha prefixes only). No word is
*named*; lane 1 remains the unopened operand — next slice
(4.17) is its structure hunt, including the byte-entropy
anatomy of champion-headed bursts.
