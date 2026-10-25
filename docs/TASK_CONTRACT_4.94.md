# TASK_CONTRACT_4.94 — Slice 4.94 (AES-NUM-094)
**Scope (host/artifact analysis only, no physical child):**
1. Residual ff deviating-instance anatomy — the residue
   of AES-NUM-093: the 4 one-deviation near-NGIDX offsets
   and the 1 index-at-one-instance offset, re-derived
   with the hef92/hef93 scanner (controls in (4) must
   pass exactly, incl. the 26 non-step OTHER offsets,
   per-ng CONST 14, combined per-ng coverage 19/26):
   - T1 0a0d378c pos 21 / off 15128 (NGIDX, exactly one
     deviating instance); T2 0a0d378c pos 13 / off 25552
     (NGIDX, exactly one deviation); T3 5ab3537d pos 8 /
     off 31848 (NGIDX, exactly one deviation); T4
     773470cd pos 14 / off 29184 (NGIDX, n = 2, exactly
     one deviation); T5 773470cd pos 15 / off 29184
     (value == ngidx at exactly one instance, 0 at all
     others).
   - TWIN: the 5ab3537d group at T5's (position, size)
     and offset 29184 — print its full instance list
     and its pooled + per-ng classification beside
     T5's, and the two groups' cidx sets / value lists.
   (a) For every target and the twin print in full:
   artifact, position, size, offset, instance count,
   and per-instance (cidx, ng, ngidx, value).
   (b) For T1–T4 the distinguished instance D is the
   one with value != ngidx; for T5, D is the one with
   value == ngidx. For D and for every conforming
   instance C of the same group collect:
   - rank in the group by cidx (first / last /
     interior), ng, ngidx;
   - train membership under the hef93 train
     definition (in a train? train rank? train-first?);
   - the aligned 4 B words at off-8, off-4, off,
     off+4, off+8 of that instance's segment (hex);
   - at every OTHER common ff offset of the same
     group: the instance's value vs the group's pooled
     law there (CONST value, or its own ngidx) — count
     per instance of other offsets where it deviates;
   - the neighbouring actions (size, channel) at
     position-1 and position+1 in its context.
   (c) Separator tests: a feature separates D exactly
   if it holds for D and for no conforming instance:
   first-by-cidx, last-by-cidx, unique ng in group,
   train-first, in-no-train, unique word neighbourhood
   (the 5-word tuple occurs once in the group),
   deviates at >= 1 other common offset while no C
   does, unique (prev, next) action-pair in group.
   Report every exact separator per target; if none,
   the distinction is NOT PROVEN for that target.
2. Per-rank middle unit anatomy (76c3a8ff position-18
   camps as in AES-NUM-086..093; CPFX {2:132, 8:148,
   22:204, 26:204}, suffix 172; consensus middles per
   grown rank; rank-2 controls in (4)):
   (a) For each grown rank r in {2, 8, 22, 26}: cut
   that rank's A and B consensus middles into 16 B
   units anchored at the middle start; report
   lenA / lenB, distinct units in A / in B, the
   distinct units shared verbatim and their indices
   in each middle, whether A units 1–4 equal B units
   1–4 at the same index, aligned mismatches per A
   unit at k = 111 and at k = 112 (A[i] vs B[i] for
   i < k, B[i+64] for i >= k), full A units exact at
   their aligned offset, and the 8 B tails compared.
   (b) Cross-rank: byte-identity fraction of A_r vs
   A_r' and B_r vs B_r' for every rank pair; unit
   indices whose unit is identical across all 4
   ranks, per camp; per-rank unit-lag matches at
   lags 1..9 (as AES-NUM-093 (ii)(d)).
   (c) B-tail vocabulary: every full 16 B unit of
   the rank-2 B middle at indices 5..14 searched
   verbatim in every A middle (all ranks, any
   offset), and every full unit of the rank-2 A
   middle at indices 5..10 searched verbatim in
   every B middle; report hits in full. Repeat the
   search pooled over all ranks' B units at indices
   >= 5 against all A middles.
   An exact period is claimed only for a lag whose
   match is exact over every compared unit; anything
   less is a measured fraction, period NOT PROVEN.
3. Per-ng forms inside the classified CONST/NGIDX
   population — the five disjoint scan populations
   of AES-NUM-093 (INBAND 8..600 inst / >= 10 common;
   BANDX pos > 30 / >= 3; BANDY / >= 3; S1 2..7 inst /
   >= 1; S2b in-band / 1..9 common), pooled OTHER
   counts as controls in (4):
   For every common ff offset classified pooled CONST
   or pooled NGIDX in those populations:
   (a) CONST arm: per-ng distinct value sets. Report
   per population and pooled: offsets by ng-presence
   (single-ng / both-ng), offsets where the per-ng
   constants DIFFER (list in full if any), offsets
   where some present ng contributes exactly 1
   instance.
   (b) NGIDX arm: per present ng report instance
   count, distinct ngidx count, NGIDX-exact in that
   ng, CONST-in-ng (all values equal). Classify each
   offset: BOTH-NONDEG (every present ng has >= 2
   distinct ngidx and is NGIDX-exact), ONE-DEG
   (exactly one present ng is CONST-in-ng or has a
   single distinct ngidx), SINGLE/ALL-DEG (one ng
   present, or every present ng degenerate). Report
   counts per population and pooled, and list in
   full any offset where a present ng is neither
   NGIDX-exact nor CONST-in-ng.
   (c) Verdict rule: the per-ng lens adds a form
   inside the classified population only if (a)
   finds differing per-ng constants or (b) finds a
   ng that is CONST with >= 2 distinct ngidx values;
   otherwise the finding is the degeneracy census
   itself, recorded as measured.
4. **Controls must reproduce:** 128,787 small actions;
   79,001 bursts; 745,849 pointer actions; 1,504
   contexts; 2,049 trailing pairs; 75,215 champion
   bursts; INBAND (374 groups, OTHER 4 all STEP),
   band X (60 / 3,335, OTHER 0), band Y (27 / 354,
   OTHER 0); S1 OTHER 16, S2b OTHER 10; 26 non-step
   OTHER with per-ng CONST 14 and combined per-ng
   coverage 19; residue exactly T1–T5 plus the 2
   uninformative n = 2 pairs of AES-NUM-093; trains
   52 (28 / 13 / 11), D(cidx 113) = 249, firsts' D
   3,089, control D 176; rank-2 middles lenA 168 /
   lenB 232 with 21 aligned mismatches at k = 111
   and 4 shared distinct units (indices 1–4).
   If a control fails, that arm's results are not
   credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-094, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
