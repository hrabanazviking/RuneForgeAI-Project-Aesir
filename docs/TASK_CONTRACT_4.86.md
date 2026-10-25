# TASK_CONTRACT_4.86 — Slice 4.86 (AES-NUM-086)
**Scope (host/artifact analysis only, no physical child):**
1. Column/block structure of the sibling segments' 544 two-valued positions: group positions by their identical choice-vector across the 26 segments — how many distinct columns, what block sizes, what value pairs, and whether any columns are complements/duplicates; per-slot free choice, a few blocks (like the position-18 Q/P blocks), or one bit?
2. The 39 constant ff offsets' cross-camp drift pattern in the position-18 segments: per offset and per scalar, are offsets start-anchored, end-anchored, or drifted between camps 21392 and 21648 (length difference +256), and does scalar identity follow the offset, the order, or neither?
3. The sibling segments' own 18 ff-words: are their offsets constant across all 26 segments, are their scalars constant or variable, and what is their scalar vocabulary versus the position-18 vocabulary {2, 11, 15, 35, 71}?

**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Controls must reproduce:** 128,787 small actions; 79,001 bursts; 745,849 pointer actions; 1,504 contexts; 2,049 trailing pairs; 75,215 champion bursts.
**Deliverables:** evidence doc, ledger row AES-NUM-086, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
