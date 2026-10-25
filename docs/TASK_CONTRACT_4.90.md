# TASK_CONTRACT_4.90 — Slice 4.90 (AES-NUM-090)
**Scope (host/artifact analysis only, no physical child):**
1. Constant ff offsets and the 0a0d exception under the unified
   within-ng law (AES-NUM-089: variable ff scalar = cidx -
   ng_start + 1 in all 372 variable populations):
   (a) Re-derive the AES-NUM-088/089 population scan identically
   (segment groups keyed by (artifact, action position, size),
   >= 8 and <= 600 instances, positions <= 30, sizes
   8,000–40,000 B, aligned ff words = offsets p step 4 with
   s[p]=0xff, s[p+2]=0, s[p+3]=0 in EVERY instance; groups
   with >= 10 common ff offsets — ALL such groups, including
   constant-only ones, not just the 372 variable ones).
   For every common ff offset in every group classify the
   byte-1 values across instances as exactly one of:
   CONST (one distinct value), NGIDX (value == cidx -
   ng_start + 1 for every instance, using each instance's
   own network group), OTHER (anything else — dumped in
   full: group key, offset, distinct values, per-instance
   values vs cidx/ngidx). Report totals per class,
   per-artifact breakdown, and the CONST scalar vocabulary
   (distinct values with counts, pooled and per artifact).
   (b) Per group, whether all its variable offsets carry one
   repeated per-segment scalar (the hef89 alleq property):
   counts of groups alleq true / false, and for every
   alleq-false group a full per-offset dump (see (c)).
   (c) The 0a0d exception deep-dive (0a0d378c, position 25,
   size 32,632 — the sole alleq-false group in AES-NUM-088):
   its common offsets and variable offsets; per instance
   (cidx, ng, ngidx, scalar at each variable offset);
   per-offset classification CONST / NGIDX / OTHER with,
   for OTHER offsets, exact fitted relations tested:
   value == cidx + C (single C), value == ngidx + K
   (single K), value - (first variable offset's scalar)
   constant, value == first scalar (equality count);
   anything unmatched is NOT PROVEN.
2. Camp stream alignment (position-18 camps of 76c3a8ff,
   AES-NUM-086/088/089: len-89 segments at position 18,
   cidx %9 == 4, cidx != 112; camp 21392 = 13 segments,
   camp 21648 = 12):
   (a) Representatives = lowest-cidx segment of each camp.
   ff offset sets per camp (offsets ff-pattern in ALL camp
   segments, as hef89). Regions by the hef89 definition
   (region k = bytes from previous ff word end to ff word
   k's start; final region to segment end). Per region
   rank: lenA, lenB, byte-equal when lengths match, common
   prefix length, common suffix length.
   (b) For every grown region (lenB - lenA == 64): tail =
   last 64 B of the B region. Report: B region prefix test
   (B[:lenA] == A region?), B region suffix test
   (B[64:] == A region?), offset of A region inside B
   region (find, -1 if absent); the tail's occurrences in
   the A representative (count + segment offsets) and in
   the B representative (count + segment offsets); for
   the tail's A occurrence: containing A region rank and
   offset within that region.
   (c) Verdict tests: INSERTION — B representative with the
   four tails removed at their region-end positions equals
   A representative byte-for-byte? DISPLACEMENT — A
   representative with each tail's A-home 64 B chunk
   removed AND B representative with its four tails
   removed: equal? Report first differing byte for any
   failed equality. Duplicated vs displaced is decided
   only by these exact tests; anything else is NOT PROVEN
   with the residuals recorded.
3. First-in-train distinction test in other artifacts/trains:
   (a) Train candidates corpus-wide: within each artifact,
   group contexts by (ng, n_actions); inside each group
   sorted by cidx, maximal runs of constant consecutive
   cidx step with run length >= 8 are trains. Record per
   train: artifact, ng, n_actions, step, count, cidx range.
   (b) Schedule distinction metric (AES-NUM-087 style): for
   member m, D(m) = number of action positions where all
   OTHER members share one (size, channel) pair and m's
   pair differs. Per train report D(first member by cidx),
   first's rank, max D and its holder, median D, number of
   members with D > 0. Control: the 76c3a8ff sibling train
   (ng 1, 400 actions, step 9, cidx 113–338) must reproduce
   D(cidx 113) = 249.
   (c) Content metric (AES-NUM-087 style, sha256 of every
   action's segment bytes): for any train whose first
   member ranks strictly first by D, and for the sibling
   control train, count positions where the other members
   are hash-unanimous and the first member's hash differs
   (control expectation: 23 for the sibling train).
   (d) Position-18 camp controls (byte metric of
   AES-NUM-086/087): two-valued byte positions per camp;
   deviation count of each camp's first segment (control
   expectations: 36 of 72 in both camps) and the maximum
   deviation in each camp with its holder.

**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Controls must reproduce:** 128,787 small actions; 79,001 bursts; 745,849 pointer actions; 1,504 contexts; 2,049 trailing pairs; 75,215 champion bursts.
**Deliverables:** evidence doc, ledger row AES-NUM-090, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
