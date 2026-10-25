# TASK_CONTRACT_4.96 — Slice 4.96 (AES-NUM-096)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.95 / hef95.py:
neighbourhood of an aligned offset p in a segment = the
five aligned 4 B words at p-8, p-4, p, p+4, p+8; zero
count z = number of those words equal to 00000000;
SPARSE z >= 3, MID z == 2, DENSE z <= 1. Camps are the
76c3a8ff position-18 camps (A 21392 x13, B 21648 x12);
CPFX {2:132, 8:148, 22:204, 26:204}, suffix 172.
1. Sparse zero-enrichment anatomy — the whole-segment
   arm of AES-NUM-095 re-derived (the 18 unique
   (artifact, position, size) groups behind the 26
   non-step OTHER offsets; every aligned ff-pattern
   candidate q in every instance's own segment, i.e.
   byte0 ff, byte2 0, byte3 0; common offsets = the
   group's common ff offsets as in hef95):
   Focus population F = candidates that are SPARSE,
   non-common (q not a common offset of the group),
   and value == 0 (value = byte q+1). AES-NUM-095
   measured |F| = 144 over 2,280 sparse non-common
   candidates of 7,484 non-common candidates; those
   counts must reproduce exactly or the arm is not
   credited.
   (a) z-split: for z in {3, 4, 5} report sparse
   non-common candidate count, F count, and zero rate;
   also the same split restricted to value != 0 as the
   complement (implied, printed for check).
   (b) Offset sharing: group F and all sparse
   non-common candidates by (group key, q). For each
   distinct (group, q) report: number of instances of
   the group in which q is a candidate at all, number
   in which it is sparse, number in which its value
   is 0. Report pooled histograms: distinct (group, q)
   by candidate-instance count (1 / 2 / >= 3), by
   zero-instance count, and the zero rate at (group, q)
   shared by >= 2 instances vs singleton (group, q).
   Per-group table: F count, distinct q in F, sparse
   non-common total, zero rate.
   (c) Neighbourhood anatomy of F: distribution of the
   position of the target word inside its own
   neighbourhood zero pattern (which of the 5 words
   are zero, as a 5-bit mask, target word included) —
   mask counts pooled; and whether the target word
   itself (at q) is zero in F (it cannot be: it is
   an ff word — recorded as a consistency check).
   A law is credited only if exact (no counterexample)
   in the stated population; anything less is a
   measured rate, law NOT PROVEN.
2. Second 8900 pair structure (consensus camp
   segments consA / consB as in hef95; rank-8 unit 0
   window = its bytes 4-9, which recurs at segment
   offset 1510 in both camps, placing a second 8900
   pair at 1512):
   (a) For each camp: the ff-region (hef95 regions()
   over the camp's common ff offsets) containing
   offset 1510 — region index, start, end, length;
   offset of 1510 from the region start and from the
   region end; whether 1510 lies in that region's
   prefix (first CPFX bytes, per the region's rank
   if the region is a grown region), its middle, or
   its suffix (last 172 bytes) — or, if the region
   is not a grown region, its plain position.
   (b) Bytes: segment bytes 1496-1544 hex in both
   camps, camp equality over that span; the five
   aligned words centred on the aligned offset 1512
   (words at 1504, 1508, 1512, 1516, 1520) hex in
   both camps; the 16 B at 1506-1521 and at 1510-1525
   hex in both camps beside rank-8 unit 0 hex.
   (c) Individual segments: at offset 1510 in every
   individual camp segment (13 A, 12 B): distribution
   of the 6 B window and of bytes 1512-1513; is the
   consensus window the unanimous value?
   (d) Comparison vs rank-8 unit 0: which bytes of
   the window's 32 B surrounding span (1496-1527)
   equal the corresponding unit-0 surrounding span
   in the same camp (unit 0 sits at its grown
   region's middle start; its surrounding span is
   middle start -14 .. +18), counted per camp.
   What the pair encodes is NOT PROVEN unless an
   exact stated law passes with no counterexample.
3. Copy-span byte anatomy (consensus middles per
   grown rank as in hef95; repeated B unit =
   010000801080003e2000000000002000 at B middle
   offsets 96 and 176):
   (a) Copy spans in full: per grown rank, A bytes
   96-111 vs B bytes 96-111 (copy 1 span) and A
   bytes 112-127 vs B bytes 176-191 (copy 2 span),
   hex; mismatch positions with A byte and B byte
   at each; whether each span and each mismatch
   byte pair is identical across all four ranks
   (re-derived; middles differ only in unit 0 per
   AES-NUM-094, so rank-invariance is expected but
   never assumed).
   (b) Mismatch-byte census: the copy-1 mismatch
   unit bytes (7 and 15, i.e. A positions 103 and
   111) and copy-2 mismatch A positions (116, 119,
   125, 126): each mismatching byte value (A side
   and B side) counted across the whole consensus
   A and B middles (occurrences at any offset) and
   across both consensus camp segments.
   (c) Chunk / unit alignment: for k in {111, 112},
   the skipped chunk B[k:k+64] hex (rank 2, plus
   rank-invariance check across ranks); the chunk's
   coverage of B units: which B unit indices it
   touches, the byte count taken from each unit,
   its first byte's offset inside its unit and its
   last byte's offset inside its unit; byte equality
   of the chunk against B units 7-10 concatenated
   at every shift -16..+16 (match counts per shift);
   occurrences of each of B units 7, 8, 9, 10 inside
   the chunk (any offset) and of the chunk's first
   and last 16 B inside the B middle.
   An exact period is claimed only for a lag whose
   match is exact over every compared unit; anything
   less is a measured fraction, period NOT PROVEN.
4. **Controls must reproduce:** 128,787 small actions;
   79,001 bursts; 745,849 pointer actions; 1,504
   contexts; 2,049 trailing pairs; 75,215 champion
   bursts; INBAND (374 groups, OTHER 4 all STEP),
   band X (60 / 3,335, OTHER 0), band Y (27 / 354,
   OTHER 0); S1 OTHER 16, S2b OTHER 10; 26 non-step
   OTHER with per-ng CONST 14 and combined per-ng
   coverage 19, residue exactly 7; trains 52
   (28 / 13 / 11), D(cidx 113) = 249, firsts' D
   3,089, control D 176; camps A 21392 x13 / B 21648
   x12; rank-2 middles lenA 168 / lenB 232 with 21
   aligned mismatches at k = 111 and 4 shared
   distinct units (indices 1-4); AES-NUM-095 headline
   counts: whole-arm candidates 7,690, boundary 0,
   non-common candidates 7,484 with SPARSE zero
   144/2,280, DENSE zero 64/2,898, MID zero 21/2,306;
   rank-8 window6 hits exactly [own position, 1510]
   in both camps; B06/B11 copy mismatches 2 (A 103,
   111) and 4 (A 116, 119, 125, 126) at both k.
   If a control fails, that arm's results are not
   credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-096, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
