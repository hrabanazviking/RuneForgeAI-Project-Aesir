# TASK_CONTRACT_4.91 — Slice 4.91 (AES-NUM-091)
**Scope (host/artifact analysis only, no physical child):**
1. Grown-region middles under camp-consensus alignment
   (76c3a8ff position-18 camps, AES-NUM-086..090: len-89
   segments at position 18, cidx %9 == 4, cidx != 112;
   camp 21392 = 13 segments, camp 21648 = 12; regions by
   the hef89/090 definition; grown ranks 2/8/22/26, each
   A -> B +64, common prefix 132/148/204/204, common
   suffix 172, A middle 168 B, B middle 232 B):
   (a) Per grown rank, per camp: region bytes of every
   camp segment; per-position variability inside each
   camp's region (number of variable positions in prefix,
   middle, suffix windows, windows cut at the AES-NUM-090
   representative prefix/suffix lengths); camp-consensus
   region = majority byte per position (ties recorded).
   (b) Middle alignment on the consensus middles: left-
   aligned common prefix and right-aligned common suffix
   of (A consensus middle, B consensus middle); for every
   insertion offset k in 0..168, mismatch count of
   B_consensus_middle minus its 64 B at k against the A
   consensus middle (positions where either camp is
   variable inside its own camp are masked and counted
   separately); report the best k per rank, its unmasked
   mismatch count, and the full k-profile minimum set.
   (c) Home search for the best-k extra chunk (B consensus
   middle[k:k+64]) per rank: exact occurrences in every
   individual camp segment of BOTH camps (count + segment
   cidx + offset), in each camp's consensus segment if
   constructible, and whether the chunk equals any 64 B
   window of the A consensus middle / A consensus region.
   Verdicts duplicated / displaced / new are decided only
   by exact occurrence counts; anything else NOT PROVEN.
2. ngidx==1 step pairs elsewhere:
   (a) Extended ff scan, re-deriving the corpus identically:
   groups keyed by (artifact, action position, size) with
   >= 8 and <= 600 instances in EITHER extension band —
   band X: position > 30, size 8,000-40,000 B; band Y:
   position <= 30, size 2,000-7,999 B or 40,001-120,000 B —
   aligned ff words as in hef90 (offsets p step 4 with
   s[p]=0xff, s[p+2]=0, s[p+3]=0 in EVERY instance);
   groups with >= 3 common ff offsets.
   (b) Classify every common ff offset CONST / NGIDX /
   OTHER exactly as hef90 (NGIDX uses each instance's own
   ng_start). For every OTHER offset test the step form:
   value == v1 for instances with ngidx == 1 and == v0
   (v0 != v1) for all others (group must contain at least
   one ngidx==1 and one ngidx>1 instance). Report totals,
   per-band/per-artifact breakdown, every step offset in
   full, and every non-step OTHER offset in full.
   (c) In-band control: the original hef90 band must still
   reproduce its OTHER count (4) under the same classifier
   when restricted to >= 10 common offsets — reported as
   a scan sanity line, not recomputed as a new result.
3. First-in-train mechanism test (trains as hef90: maximal
   constant-step cidx runs >= 8 inside one (artifact, ng,
   n_actions) group; D(m) schedule metric as AES-NUM-087/090):
   (a) Recompute all 52 trains and D for every member;
   controls: sibling D(113) = 249, first-outlier trains 28,
   unanimous 13, outlier-elsewhere 11.
   (b) Cross-train comparison inside each (artifact, ng):
   for each train report its first member's cidx, ngidx,
   D(first), rank, and whether it is a unique first outlier;
   then per (artifact, ng) pool: number of trains, number
   with unique-first outliers, and whether ALL / SOME /
   NO trains in the pool share the property.
   (c) Separator tests over the 52 first members, each
   reported as (distinguished count / total) x feature:
   ngidx == 1; ngidx <= train step; first member is the
   ng's first context overall; train is the first train
   (lowest first-cidx) of its (artifact, ng, n_actions)
   group or of its (artifact, ng) pool; train step == 9;
   n_actions parity / size bands. A feature is a separator
   only if it holds for ALL distinguished firsts and NO
   undistinguished firsts; otherwise record the exact
   confusion counts and grade mechanism NOT PROVEN.
   (d) Cross-train first agreement: within each (artifact,
   ng) pool with >= 2 trains, pairwise schedule agreement
   of the trains' first members (positions where their
   (size, channel) pairs agree / total positions where
   n_actions match is NOT assumed — only trains with equal
   n_actions are compared, position by position), reported
   per pool; distinguished firsts vs undistinguished
   firsts compared as groups (mean agreement to the other
   firsts of their pool).

**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Controls must reproduce:** 128,787 small actions; 79,001 bursts; 745,849 pointer actions; 1,504 contexts; 2,049 trailing pairs; 75,215 champion bursts.
**Deliverables:** evidence doc, ledger row AES-NUM-091, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
