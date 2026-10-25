# TASK_CONTRACT_4.95 — Slice 4.95 (AES-NUM-095)
**Scope (host/artifact analysis only, no physical child):**
1. Sparse-form census — the 26 non-step OTHER ff offsets
   of AES-NUM-092/093/094 (the OTHER habitat; 19 of them
   per-ng-covered, 7 residue), re-derived with the
   hef92/hef93/hef94 scanner (controls in (4) must pass
   exactly, incl. per-ng CONST 14, combined coverage 19,
   residue exactly the T1–T5 targets plus the 2
   uninformative n = 2 pairs):
   Neighbourhood of an instance at an aligned offset p
   in its segment = the five aligned 4 B words at
   p-8, p-4, p, p+4, p+8 (an offset whose neighbourhood
   would leave the segment is recorded as BOUNDARY and
   excluded from form counts). Zero count z = number of
   those words equal to 00000000. Form classes:
   SPARSE z >= 3; MID z == 2; DENSE z <= 1.
   (a) Common-offset arm: for every one of the 26
   groups and every common ff offset of the group,
   print per instance (cidx, ng, ngidx, value, z, form,
   the 5 words hex). Report per group and pooled:
   instance counts by form; contingency of form vs
   value == 0, value == ngidx, and — where a per-ng
   law exists for the offset (per-ng CONST constant
   or per-ng NGIDX) — value == per-ng prediction vs
   value != prediction. Report how many of the 26
   groups have exactly one common offset: if that is
   all of them, the common-offset arm can speak only
   about the target offsets, and that limit is stated.
   (b) Whole-segment arm (the "every offset, not only
   the target" test): for every instance of the 26
   groups, scan every aligned offset q in that
   instance's own segment whose word is an ff word
   (byte0 ff, byte2 0, byte3 0); the segment's value
   at q is byte q+1. For each such (instance, q):
   z and form at q, value, and whether q is one of
   the group's common offsets. Report pooled and
   per-group: candidate count, counts by form,
   contingency of form vs value == 0 at common
   offsets vs at non-common candidate offsets
   separately. A sparse-predicts-value law is
   credited only if it is exact (no counterexample)
   in the stated population; anything less is a
   measured rate, law NOT PROVEN.
2. Middle unit-0 byte hunt (76c3a8ff position-18 camps
   as in AES-NUM-086..094; CPFX {2:132, 8:148, 22:204,
   26:204}, suffix 172; consensus middles per grown
   rank; rank-2 controls in (4)):
   (a) Per grown rank r and camp: unit 0 (first 16 B
   of the middle) hex; whether A unit 0 == B unit 0;
   bytes 6–7 per rank (expect A/B 8780 / 8900 / 8500 /
   8b80 at ranks 2 / 8 / 22 / 26 — re-derived, not
   assumed).
   (b) Individual-segment arm: at the exact unit-0
   position in every individual camp segment (13 A,
   12 B), per rank and camp: the distribution of
   bytes 6–7 and of the full unit 0 (distinct values
   with counts); is the consensus value the majority?
   (c) Recurrence: each rank's full 16 B unit 0 and
   its 6 B window bytes 4–9 searched verbatim at
   every offset in both consensus camp segments —
   hit positions listed in full. The 2 B rank values
   counted (occurrences, distinct positions not
   required) in: the whole consensus segments, the
   grown regions' prefixes (region start to middle
   start), the middles outside unit 0, and the
   regions' suffixes (middle end to region end),
   per rank and camp.
   (d) Verdict rule: unit 0 is a per-rank form of a
   wider family only if a fuller pattern than the
   2 bytes (the 6 B window or the 16 B unit) recurs
   at a stated second position, or the individual
   segments show the rank value is not
   consensus-only; 2-byte recurrence alone is
   recorded as a count, never as a family.
3. B06/B11 recurrence anatomy (same middles):
   (a) Per grown rank: B unit 6 and B unit 11 hex and
   equality (byte ranges 96–111 and 176–191 of the
   B middle); all offsets at which that 16 B unit
   occurs in the B middle and in the A middle.
   (b) Aligned spans: at insertion offsets k = 111
   and k = 112 (A[i] vs B[i] for i < k, A[i] vs
   B[i+64] for i >= k), the mismatch count and
   positions of copy 1 (B bytes 96–111, aligned to
   A bytes 96–111) and of copy 2 (B bytes 176–191,
   aligned to A bytes 112–127); whether each copy
   lies before, inside, or after the skipped chunk
   B[k:k+64] (overlap in bytes reported).
   (c) The skipped chunks at k = 111 and k = 112
   printed in full (hex), and each chunk searched
   for the repeated unit (occurrences at any
   offset).
   (d) Neighbours: B units 5, 7, 10, 12 hex per the
   rank-2 middle (units are rank-invariant beyond
   unit 0 per AES-NUM-094 — re-derived for these
   indices across ranks before quoting rank 2 only).
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
   coverage 19; residue exactly T1–T5 plus the 2
   uninformative n = 2 pairs of AES-NUM-093; trains
   52 (28 / 13 / 11), D(cidx 113) = 249, firsts' D
   3,089, control D 176; camps A 21392 x13 / B 21648
   x12; rank-2 middles lenA 168 / lenB 232 with 21
   aligned mismatches at k = 111 and 4 shared
   distinct units (indices 1–4).
   If a control fails, that arm's results are not
   credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-095, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
