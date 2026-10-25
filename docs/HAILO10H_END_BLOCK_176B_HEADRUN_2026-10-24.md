# End-block burst datum treatment, 176 B variable pools, head burst-runs (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.36 (AES-NUM-036).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef36.py
(sha256 e8a217ba…) plus the labelled follow-up hef36b.py
(sha256 bce0d080…). Controls: the walk reproduces
AES-NUM-029/032/033/034/035 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts).

## The 21 trailing bursts — entirely champion, fully covered

- All 31,584 trailing bursts (21 per context × 1,504
  contexts) carry the champion lane-0 word
  `0528000000000000` — a single lane-0 family, split by
  channel into three (channel, lane-0) families
  (ch0: 16,544 bursts; ch1: 7,520; ch2: 7,520). There is
  NO non-champion burst anywhere in the end block.
- The three laws hold in all three families with zero
  exceptions: operand→datum is a function (0 violations),
  the affine fit is consistent (0 inconsistencies), and
  the lane-2 width law holds (0 breaks). Affine ranks
  fitted on this population alone: ch0 13, ch1 11, ch2 11.
- Cross-prediction against the ALREADY-FROZEN encoders
  (AES-NUM-026 linear for channels 1/2, AES-NUM-031
  linear rank-27 for channel 0) is PERFECT: 31,584/31,584
  bursts predicted correctly, 2,049/2,049 distinct
  (channel, operand) pairs correct, ZERO wrong, ZERO
  out-of-span refusals, ZERO bursts in an unfrozen family.
  The end block's datum content is 100% inside the frozen
  encoder coverage — no new basis is needed for it.
- The pooled distinct segment count is also 2,049, equal
  to the distinct (channel, operand) count: in this
  population the segment is fully determined by
  (channel, operand) under the fixed champion lane-0.
- Position anatomy: position t0 is ONE invariant segment
  in all 1,504 contexts — the burst
  `0528000000000000 002000005002802d aade2f0000000000`,
  whose lane-1 word is the AES-NUM-019 special-slot
  operand `0x2d80025000002000` (the 0x2d80 slot and the
  0x0250 constant) with datum 0x2fdeaa — the very operand
  AES-NUM-030 recorded as the channel-0 champion map's
  single in-span representative (1,504 bursts). The end
  block opens, on channel 0 in every context, with the
  special-slot burst.
- Positions t1–t20 fall into five 4-position groups
  (t1–4, t5–8, t9–12, t13–16, t17–20 — the channel cycle
  0,1,2,0 of AES-NUM-035). Each group has a constant
  distinct-operand count (98, 104, 103, 100, 107), but
  the operand SETS are not shared: sets differ between
  positions inside a group, the five groups' operand
  pools are pairwise DISJOINT (0 shared operands in all
  10 cross-group pairs), and within a single context the
  same operand NEVER repeats across a group's positions
  (0/1,504 for every pair). Each group position draws
  from its own group pool, without reuse inside a context.

## The 176 B variable pools — sparse frames, unique trailer

- Both fixed heads keep exactly one byte-fixed segment
  each (1,504 occurrences, in all 7 artifacts). The two
  variable pools are `032830013801002c` (99 distinct
  segments, 1,504 occurrences) and `03283001b809002c`
  (98 distinct, 1,504 occurrences); each context holds
  exactly one segment from each pool (AES-NUM-035).
- Pool structure (22 words): in the 3801 pool, positions
  1–10 are small-vocabulary `0200…` words (1–6 distinct;
  p8 is the constant `0200000002000000`), p11–13 carry
  the mid variety (26/20/16 distinct, zero rates
  0.33/0.59/0.66), p14–17 are near-always zero
  (0.89–0.99), p18 is always zero, p19/p20 carry 24/19
  distinct values, and p21 is distinct for every segment
  (99/99). In the b809 pool, positions 1–8 decay to zero
  (zero rates 0.11 → 1.00; p8 is always ZERO here, where
  the 3801 pool's p8 is a constant nonzero word), p9/p10
  are structured small sets, p11–13 mid variety, p14–17
  near-always zero, p18 always zero, p19 mostly zero
  (6 distinct), p20 11 distinct, p21 distinct for every
  segment (98/98).
- Determinism: the only position that determines all
  others in either pool is p21, and it does so trivially
  — it is unique per segment (a per-segment identifier,
  AES-NUM-035). All other perfect-determinism pairs
  involve constant or near-constant columns (p0 by pool
  definition, p8, p18; the 98/99-valued p6/p7/p16/p17 in
  the 3801 pool). No pair of genuinely varying positions
  determines each other. The varying positions vary
  jointly without a measured pairwise law — graded
  OBSERVED structure, not a generating rule.
- Sharing: the pools are mostly private to one artifact
  (3801: 73/99 segments in exactly 1 artifact, none in
  all 7, one in 6; b809: 72/98 in 1, none in 7, two in
  6). MiniLM holds exactly 6 distinct segments of each
  pool; the blobs hold 17–33 each. Occurrence counts per
  segment range 1–172 with heavy repeats of a few
  segments (b809 has segments occurring 155× and 172×).

## Head burst-runs — always 4 to 10, modal break at 304 B

- The initial all-24 B run length distribution over
  1,504 contexts is: 4:14, 5:86, 6:149, 7:272, 8:393,
  9:447, 10:143. Minimum 4 (the AES-NUM-035 guarantee),
  maximum 10, mean 7.90, median 8, p90 9. The head burst
  run ALWAYS ends by position 10 — no context opens with
  11 or more consecutive bursts.
- The run is broken by a 304 B action in 1,066/1,504
  contexts (70.9%); the remaining breaks are large forms
  (32,776 B ×76, 32,784 B ×58, 30,936 B ×56, …).
- Per artifact: MiniLM's 6 contexts run longest (9 ×1,
  10 ×5); the blob artifacts span the full 4–10 range
  (context counts 180–353 per artifact).

## What this closes and what it queues

- MEASURED, corpus-wide: the end block's 21 bursts are
  entirely champion-headed and their datum content is
  fully and exactly predicted by the frozen encoders
  (31,584/31,584; no new basis needed); the block opens
  with the invariant special-slot burst; its remaining
  positions form five disjoint operand pools with no
  intra-context reuse. The 176 B variable pools are
  sparse framed forms whose only universal identifier
  is the unique trailer word; no pairwise generating
  law between varying positions was measured. Head
  burst-runs are bounded 4–10 with a modal 304 B break.
- NOT established: the meaning of the end block, of the
  five operand pools, of any 176 B varying word, or of
  the head run; whether the pools' joint variation is
  generated by a higher-order rule.
- NEXT (4.37): the five trailing operand pools — are
  they slices of one global pool (compare against the
  corpus-wide champion operand population) or end-block
  only? The 176 B pools' joint structure (segment
  clustering by the p11–13/p19–20 varying block);
  304 B break-form anatomy at head positions 4–10.
  Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
