# TASK_CONTRACT_4.92 — Slice 4.92 (AES-NUM-092)
**Scope (host/artifact analysis only, no physical child):**
1. Middle-mismatch anatomy (76c3a8ff position-18 camps as in
   AES-NUM-086..091: len-89 segments at position 18,
   cidx %9 == 4, cidx != 112; camp 21392 = 13 segments,
   camp 21648 = 12; regions by the hef89/090 ff-offset
   definition; grown ranks 2/8/22/26, common prefix
   132/148/204/204, common suffix 172, A middle 168 B,
   B middle 232 B; camp consensus = majority byte per
   position, AES-NUM-091 found 0 variable positions in
   every grown region):
   (a) For every grown rank and each best insertion
   offset k in {111, 112} (the AES-NUM-091 tie): the
   mismatch positions i (A-middle coordinates) where
   A_middle[i] != B_middle[i if i < k else i + 64];
   report the full position list per (rank, k), the
   byte pair (A byte, aligned B byte) at each, the
   region offset of each (region start + prefix + i),
   and whether the four ranks give identical lists.
   (b) Clustering: runs of consecutive mismatch
   positions, gaps between successive positions, max
   run, count per middle third; pooled byte-pair
   vocabulary (Counter over (A, B) pairs and over
   A XOR B) across all ranks at k = 111, and whether
   any byte pair or XOR value dominates.
   (c) Shift tolerance / period: (i) self-overlap of
   the 64 B chunk at k = 111 and at k = 112 — for
   shift d in 1..63, matches between chunk[0:64-d]
   and chunk[d:64], plus every border length L where
   chunk[:L] == chunk[64-L:]; (ii) autocorrelation
   of the full B consensus middle and of the A
   consensus middle as control — for shift d in
   1..167, matches / compared, reporting the top
   shifts by match fraction for each; (iii) the
   insertion-offset mismatch profile for k' in
   96..127 (extending AES-NUM-091's full profile
   around its minimum) for rank 2.
   A period is claimed only for a shift whose match
   fraction is exact (1.0) over its full overlap;
   anything less is recorded as measured fraction,
   period NOT PROVEN.
2. Sparse-group ff scan — the remainder below every
   floor used so far, completing the ff census.
   Groups keyed by (artifact, action position, size)
   over ALL pointer actions of all 7 artifacts:
   (a) S1: instance count 2..7, any position, any
   size, with >= 1 common aligned ff offset (aligned
   as hef90/91: offsets p step 4 with s[p] = 0xff,
   s[p+2] = 0, s[p+3] = 0 in EVERY instance).
   (b) S2: instance count >= 8 whose common offsets
   no earlier scan classified, any position, any
   size — i.e. NOT (in a previously scanned band
   with a common count at or above that band's
   floor). This covers 1..2 common offsets outside
   the original band (position <= 30, size
   8,000-40,000 B), 1..9 inside it, >= 3 common
   offsets in territory neither the original band
   nor bands X/Y reached (position > 30 with size
   outside 8,000-40,000 B; position <= 30 with
   size < 2,000 B or > 120,000 B), and groups over
   the earlier scans' 600-instance cap.
   (c) Also count, without classifying: singleton
   groups (1 instance; classification is undefined,
   every value is trivially constant), groups with
   0 common ff offsets in S1/S2's instance ranges,
   and groups already classified by AES-NUM-090/091.
   (d) Classify every common ff offset in S1 + S2
   CONST / NGIDX / OTHER exactly as hef90 (NGIDX
   uses each instance's own ng_start: value ==
   cidx - ng_start + 1 in every instance). For
   every OTHER offset test the step form (value
   == v1 at ngidx == 1, == v0 != v1 for all
   others; group must contain both kinds). Report
   totals per class per S-band per artifact, every
   STEP offset in full, and every non-step OTHER
   offset in full in the run output.
   (e) Scanner controls: the new scanner must
   reproduce, under the same classifier, the
   AES-NUM-090 in-band totals (374 groups at >= 10
   common; CONST 17,351, NGIDX 3,290, OTHER 4, all
   4 STEP) and the AES-NUM-091 extension totals
   (band X 60 groups / 3,335 offsets, band Y 27 /
   354, OTHER 0 in both). If a control fails, the
   sparse results are not credited.
   Candidate generation may use a byte-find scan
   for 0xff instead of a step-4 index loop only if
   the controls in (e) pass exactly.
3. D-position anatomy of distinguished firsts
   (trains and the D metric exactly as hef91:
   maximal constant-step cidx runs >= 8 inside one
   (artifact, ng, n_actions) group; D(m) counts
   positions where exactly two distinct (size,
   channel) pairs occur across members and one
   occurs once):
   (a) Recompute all 52 trains; controls: unique-
   first trains 28, unanimous 13, outlier-elsewhere
   11, sibling D(cidx 113) = 249.
   (b) For each of the 28 distinguished firsts: its
   D-positions (positions where the first member
   is the singleton); at each, the first member's
   (size, channel), the consensus (size, channel)
   carried by all other members, the position
   index and its band (first / middle / last
   third of the action list; also first / last
   decile flags).
   (c) Aggregate over all distinguished firsts:
   total D-positions; counts by third and by
   decile band; transition table consensus pair ->
   first pair (top entries in full); channel-only
   changes (same size, channel differs), size-only
   changes, both-changed counts; the distinct
   consensus pairs and first pairs involved.
   (d) Control arm: the same anatomy for every
   non-first unique outlier member (in outlier-
   elsewhere trains and any other train where a
   non-first member is a unique outlier at a
   position set) — total D-positions, thirds
   distribution, channel-only fraction — reported
   beside the firsts' numbers so first-specific
   structure, if any, is visible against it.
   A mechanism is claimed only if a stated
   statistic separates firsts from the control
   arm exactly; otherwise NOT PROVEN.

**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Controls must reproduce:** 128,787 small actions; 79,001 bursts; 745,849 pointer actions; 1,504 contexts; 2,049 trailing pairs; 75,215 champion bursts; plus the arm-specific controls above.
**Deliverables:** evidence doc, ledger row AES-NUM-092, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
