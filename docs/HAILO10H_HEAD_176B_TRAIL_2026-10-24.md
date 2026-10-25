# Context head census, 176 B head anatomy, the trailing 28 (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.35 (AES-NUM-035).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef35.py
(sha256 815f2ffc…). Controls: the walk reproduces
AES-NUM-029/032/033/034 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts).

## The head — a rigid burst prefix, then decay

- The first pointer action of every context is a 24 B
  burst (1,504/1,504), and positions 0–3 are 24 B in
  every context (one distinct size each). The head opens
  with a guaranteed run of at least four bursts.
- Rigidity then decays monotonically: position 4 is
  24 B in 1,490/1,504 (304 B in 14); distinct sizes per
  position grow 2 (pos 4), 4 (pos 5), 8 (pos 6), 19
  (pos 7), 37 (pos 8), 75 (pos 9), 97 (pos 10), 111
  (pos 11). The modal size flips from 24 B to 304 B at
  position 9 (708 vs 230). Only 24 distinct first-8
  size sequences exist (the all-24 sequence leads at
  983 contexts), but 242 distinct first-12 sequences —
  there is NO fixed head block rivalling the trailer;
  the head is a burst-run prefix whose length varies.
- Channels at head positions are NOT fixed: all three
  channels appear at every one of positions 0–11, in
  varying proportions. Size rigidity at the head does
  not extend to channel rigidity (contrast the tail).

## The 176 B class — four fixed heads, two fixed segments

- 6,016 segments = exactly 4 per context in all 1,504
  contexts. Exactly 4 distinct position-0 head words
  exist, each occurring exactly 1,504 times — once per
  context — and every context holds exactly the same
  multiset of the four heads (one distinct multiset
  corpus-wide). All four heads end in `002c` (they are
  four of the AES-NUM-034 19-word vocabulary).
- Two heads head exactly ONE distinct segment each
  (`01283001f80a002c`, `032830013014002c`): those two
  176 B segments are byte-fixed corpus-wide (1,504
  occurrences each). The other two heads vary:
  `032830013801002c` heads 99 distinct segments,
  `03283001b809002c` heads 98 — and 99+98+1+1 = 199 =
  the total distinct-segment count, so the four head
  pools are disjoint and the head word partitions the
  class completely.
- Anatomy (22 words): position 18 is always the zero
  word (rate 1.000, 1 distinct value); positions 14–17
  are near-always zero (0.944–0.982); position 0 is
  never zero (4 distinct = the heads) and position 21
  never zero with 199 distinct values — the trailer
  word is distinct for every distinct segment, a
  per-segment identifier. Mid-body positions carry
  the variety (p11: 33 distinct, p19: 25, p20: 26).
  The class is a framed sparse form: fixed head, a
  mostly-zero tail frame (p14–18), and a unique
  trailer word.

## The trailing 28 — a single invariant end block

- Exactly 28 pointer actions follow the skeleton
  quartet's last element in every context (1,504/1,504),
  and their size sequence is a SINGLE sequence in all
  1,504 contexts (one distinct sequence): forward order
  24, 64, 24, 216, 328, 328, 328, then twenty-one 24 B
  bursts.
- Channels are likewise fixed per position: the seven
  leading forms (offsets 21–27 from the end) are all
  channel 0, and the 21 trailing bursts follow a fixed
  per-position channel pattern repeating every four
  positions from the end (0, 2, 1, 0). The tail is as
  rigid as the quartet itself — together they form one
  fixed end-anchored block of 5 + 28 = 33 actions with
  invariant sizes, channels, gaps and end-offsets;
  only what precedes the block varies.

## What this closes and what it queues

- MEASURED, corpus-wide: the context head is a
  guaranteed ≥4-burst prefix with monotonically
  decaying size rigidity and no channel rigidity and
  no fixed head block; the 176 B class is four
  once-per-context heads partitioning 199 segments,
  two of them byte-fixed, with an always-zero p18 and
  a segment-unique trailer word; the 28 actions after
  the quartet are a single invariant size+channel
  sequence — a fixed end block with the quartet.
- NOT established: the meaning of the head burst run,
  of any 176 B word beyond the measured structure, or
  of the end block.
- NEXT (4.36): the end block's burst content — do the
  21 trailing bursts obey the frozen datum encoders
  (family census + cross-prediction on this fixed
  population)? The 176 B variable heads' segment
  structure (99/98 pools: what varies, co-variation
  with context/layer?); head burst-run length
  distribution (where the all-24 prefix ends).
  Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
