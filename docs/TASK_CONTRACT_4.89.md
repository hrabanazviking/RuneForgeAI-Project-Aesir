# TASK_CONTRACT_4.89 — Slice 4.89 (AES-NUM-089)
**Scope (host/artifact analysis only, no physical child):**
1. What separates the C = +1 ff populations from the negative-C ones
   (AES-NUM-088: 372 variable ff populations, scalar = cidx + C in
   every one; C = +1 in 181 groups in every blob, one negative
   per-artifact constant in 191), and what sets each artifact's
   negative constant:
   (a) Re-derive the AES-NUM-088 population scan identically
   (segment groups keyed by (artifact, action position, size),
   >= 8 instances, positions <= 30, sizes 8,000–40,000 B, aligned
   ff words common to every instance, >= 10 common ff offsets)
   and record per variable group: artifact, position, size,
   instance count, C, cidx min/max/count/spacings, the network
   group(s) (ng index) its contexts belong to, common/variable
   ff offset counts, and scalar min/max.
   (b) Separator tests: cross-tabulate C class (+1 vs negative)
   against position, size, cidx range, ng membership, instance
   count, and scalar range — report any feature (or combination)
   that separates the classes exactly, and every feature that
   does not, with counts.
   (c) Constant candidates: per artifact, test the negative
   constant against artifact-level quantities — total contexts,
   ng boundary cidx values (first cidx of each ng), contexts
   per ng, the minimum cidx / minimum scalar of its negative
   groups, and the cidx at which negative populations begin —
   exact equalities only; anything unmatched is NOT PROVEN.
2. Cidx 113 vs 302/311 kinship anatomy (the two partial exceptions
   in AES-NUM-088's re-grouping test: 22 and 16 matched boundary
   groups from position 41):
   (a) For 113 vs 302 and 113 vs 311, list every matched
   boundary group from position 41 (position span, summed size)
   and every per-position (size, channel) agreement from
   position 41 on, with their distribution (head/middle/tail).
   (b) The same counts for 302 vs 311 and for each of 302/311
   against the consensus schedule, as controls.
   (c) For matched boundary groups, whether the segment content
   inside the group is byte-identical between the two contexts
   (per-action hashes compared in order), reported per group.
3. The four extra 64 B tails byte-for-byte (position-18 camps,
   AES-NUM-088 (iii): the inter-ff regions before ff ranks
   2/8/22/26 in camp 21648 each carry a 64 B tail beyond camp
   21392's region length, and the four tails share a 32 B
   opening):
   (a) Extract each region's extra tail (the bytes of the
   longer camp's region beyond the shorter camp's length)
   from camp 21648's representative segment and compare the
   four tails pairwise byte-for-byte (equal / first differing
   byte / shared prefix length).
   (b) Whether each extra tail is identical across ALL camp
   21648 segments at its region, and whether anything equal
   to a tail occurs in camp 21392 (any region) or elsewhere
   in the representative segments.
   (c) Shift tests: each tail vs the 64 B immediately before
   it, the 64 B immediately after it (the following ff word
   + following region head), and the corresponding region's
   own first 64 B.

**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Controls must reproduce:** 128,787 small actions; 79,001 bursts; 745,849 pointer actions; 1,504 contexts; 2,049 trailing pairs; 75,215 champion bursts.
**Deliverables:** evidence doc, ledger row AES-NUM-089, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
