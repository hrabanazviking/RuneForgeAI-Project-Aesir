# TASK_CONTRACT_4.88 — Slice 4.88 (AES-NUM-088)
**Scope (host/artifact analysis only, no physical child):**
1. The cidx − 92 law beyond the three measured 76c3a8ff populations:
   (a) Context 92 itself, in every artifact: which network group holds
   it, its action count and form census vs its neighbours (cidx 91/93),
   and whether anything in its own segments marks it (first/last forms,
   skeleton completeness, any ff population it carries).
   (b) Other ff populations corpus-wide: segment groups keyed by
   (artifact, action position, size) with >= 8 instances, restricted to
   positions <= 30 and sizes 8,000–40,000 B (the band holding both known
   ff populations), scanned for aligned ff words (ff <scalar> 00 00)
   common to every instance; for each group with >= 10 common ff
   offsets, report the variable offsets, whether the variable slots
   repeat one scalar per segment, and test that scalar against
   cidx − 92, against cidx + C for the best-fit constant C, and against
   a + b x rank. Groups that fail the common-ff threshold are reported
   as counts only.
2. Cidx 113's schedule vs the consensus schedule: the consensus is the
   per-position (size, channel) pair unanimous among the other 25
   sibling contexts where it exists (249 distinguished + 82 unanimous
   positions from AES-NUM-087). Compare (a) the joint (size, channel)
   multiset of cidx 113 vs the consensus positions' multiset and vs
   each other context's full multiset; (b) size-only and channel-only
   multisets; (c) total referenced bytes; (d) the re-grouping test —
   from position 41 on, whether consecutive-sum partitions of one
   schedule reproduce the other's action boundaries (permutation /
   re-grouping / different multiset verdict, with counts).
3. Where the staircase +64 insertions live: rank-aligned byte diff of
   the two position-18 camps — align each camp's representative segment
   by its 43 ff-word ranks, compute each inter-ff region's length in
   both camps and the per-region length difference (the staircase says
   exactly four regions carry +64 and the rest 0); for each carrying
   region report its rank span, length in both camps, zero fraction,
   distinct-byte count, variability across the camp's segments, and
   what content differs (byte-diff summary vs the other camp's region).

**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Controls must reproduce:** 128,787 small actions; 79,001 bursts; 745,849 pointer actions; 1,504 contexts; 2,049 trailing pairs; 75,215 champion bursts.
**Deliverables:** evidence doc, ledger row AES-NUM-088, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
