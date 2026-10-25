# TASK_CONTRACT_4.93 — Slice 4.93 (AES-NUM-093)
**Scope (host/artifact analysis only, no physical child):**
1. ff OTHER form hunt — the 26 non-step OTHER offsets of
   AES-NUM-092 (16 in S1 groups, 10 in S2b groups):
   (a) Re-derive them with the hef92 scanner/classifier
   (controls in (4) must pass exactly, incl. S1 OTHER 16
   and S2b OTHER 10, all non-step). For every OTHER
   offset print in full: artifact, position, size, offset,
   instance count, and per-instance (cidx, ng, ngidx,
   value at offset+1).
   (b) Form tests, each required to hold for EVERY
   instance of the offset (exact, no exceptions):
   - affine in cidx: v == (a*cidx + b) mod 256, (a, b)
     solved from two instances with distinct cidx and
     verified on all; also report the a == 1 and
     a == 255 (-1) special cases separately.
   - affine in ngidx (same construction; the plain
     NGIDX form a == 1, b == 0 already failed in 092).
   - subgroup index: gidx = the instance's 1-based rank
     among the group's instances within its own ng,
     sorted by cidx. Test v == gidx, and affine in gidx.
   - arithmetic progression in cidx order: the values
     in cidx-sorted order form an AP with constant
     difference d (plain integer difference, and
     mod-256 difference reported separately).
   - train rank: using the hef92 train definition,
     if every instance cidx of the group lies in one
     single train of its artifact, test v == rank in
     that train (1-based) and affine in rank. If the
     instances span several/no trains, record that.
   - two-valued offsets: for offsets with exactly 2
     distinct values, test whether the minority-value
     instances are separated exactly by any of:
     ngidx == 1, gidx == 1, min cidx, max cidx,
     first-in-train, ng == 0, ng == 1.
   A form is credited only if it passes exactly on
   every OTHER offset it is claimed for; forms passing
   on a subset are reported per-offset, not pooled
   into a law. If no form covers an offset, that
   offset's form stays NOT PROVEN.
2. Middle 16-byte unit anatomy (76c3a8ff position-18
   camps as in AES-NUM-086..092; consensus middles
   A 168 B / B 232 B, insertion offset k = 111):
   (a) Cut both consensus middles into 16 B units
   anchored at the middle start (A: 10 full units +
   8 B tail; B: 14 full units + 8 B tail). Report
   every unit's bytes (hex) for both middles.
   (b) Aligned comparison: map each A byte through
   the k = 111 alignment of AES-NUM-092; report
   mismatches per A unit (unit index, A-coordinate
   range, mismatch count, positions) — the tail
   crowd of 092 must reappear as per-unit counts.
   (c) Unit vocabulary: distinct units in A, in B;
   units shared verbatim (exact 16 B match at any
   offset, and at the aligned offset); A units whose
   bytes appear nowhere in B; the 8 B tails compared.
   (d) Unit-sequence structure: equality of the unit
   sequence at unit lags 1..9 for each middle
   (matching units / compared), and byte-level
   identity fraction per aligned unit pair.
   An exact period is claimed only for a lag whose
   match is exact over every compared unit; anything
   less is a measured fraction, period NOT PROVEN.
3. Firsts' pair-function test (trains and D metric
   exactly as hef91/hef92; controls in (4)):
   For every D-position of the 28 distinguished
   firsts (3,089 in AES-NUM-092), with own pair =
   the first's (size, channel) and consensus pair =
   the other members' (size, channel), test whether
   own pair is a function of each key:
   (consensus pair), (consensus pair, position),
   (consensus pair, position third), (consensus
   pair, position decile), (consensus pair, train
   step S), (consensus pair, artifact, ng).
   Report per key: distinct keys, multi-instance
   keys, mixed keys (one key, > 1 own pair),
   majority accuracy over all D-positions.
   Repeat the (consensus pair) and (consensus pair,
   position) tests on the control arm (non-first
   outliers, 176 D-positions) for contrast.
   A function is claimed only for a key with zero
   mixed keys AND at least 10 multi-instance keys;
   anything else is recorded as NOT a function /
   NOT PROVEN at that key.
4. **Controls must reproduce:** 128,787 small actions;
   79,001 bursts; 745,849 pointer actions; 1,504
   contexts; 2,049 trailing pairs; 75,215 champion
   bursts; AES-NUM-090 in-band (374 groups, OTHER 4
   all STEP), band X (60 / 3,335, OTHER 0), band Y
   (27 / 354, OTHER 0); S1 OTHER 16, S2b OTHER 10;
   trains 52 (unique-first 28, unanimous 13,
   elsewhere 11), D(cidx 113) = 249, firsts'
   D-positions 3,089, control-arm D-positions 176.
   If a control fails, that arm's results are not
   credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-093, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
