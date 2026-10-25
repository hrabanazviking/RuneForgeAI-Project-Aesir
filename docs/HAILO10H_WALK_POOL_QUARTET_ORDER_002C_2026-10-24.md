# Walking-pool sharing, quartet ordering, the 002c vocabulary (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.34 (AES-NUM-034).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef34.py
(sha256 f998a9b8…) plus the labelled follow-up hef34b.py
(sha256 217f8554…). Controls: the walk reproduces
AES-NUM-029/032/033 EXACTLY (128,787 pooled small actions;
79,001 pooled 24 B bursts; 745,849 pointer actions;
1,387,111,605 referenced words in total).

## The walking pool — mostly private, never universal

- The 148 distinct walking segments (AES-NUM-033) split
  across artifacts as: MiniLM 2 distinct, the six blobs
  49 / 27 / 41 / 41 / 40 / 52 distinct each. Sharing
  histogram (artifacts per segment): **81 segments occur
  in exactly 1 artifact, 37 in 2, 23 in 3, 7 in 4, and
  none in 5, 6 or 7** — there is no universal walking
  segment, and 54.7% of the pool is private to a single
  artifact (private counts per artifact: 1 / 20 / 10 / 2 /
  25 / 0 / 23).
- Pairwise sharing is uneven: the sister pair
  5ab3537d / 773470cd shares **36** segments (of their
  41 / 40) — by far the largest overlap; most other blob
  pairs share 3–15. MiniLM's 2 segments: one is private,
  the other is shared with exactly the sister pair
  (present in artifacts 0, 3, 5 and nowhere else).
- Reuse within the pool is skewed: 39 segments occur
  exactly once corpus-wide; the top segment occurs 109×
  (the AES-NUM-033 top pair). The pool is a per-network
  working set with a shared core, not a fixed table.

## The skeleton quartet — anchored to the context's end

- The intra-context order is a **single invariant
  pattern in all 1,504 contexts**: 72 B, 416 B, 96 B,
  96 B, 120 B (pointer-action sequence order). The two
  96 B variants always appear in the same order —
  `02289000d007002c`-headed first, `002890009013002c`-
  headed second (1,504/1,504).
- The gaps between consecutive skeleton actions are the
  **same sequence in every context**: 7, 1, 11, 4
  pointer actions (hef34b, distinct gap sequences = 1).
- Strongest form: measured from the context's END, every
  skeleton element sits at a **fixed offset in all 1,504
  contexts** — 72 B at 51 actions from the end, 416 B at
  44, the 96 B pair at 43 and 32, 120 B at 28 (so exactly
  28 pointer actions always follow the quartet). What
  varies is only how much precedes it (head gap 33–969,
  103 distinct values; contexts hold 85–1,021 pointer
  actions). The quartet is an end-anchored trailer block,
  not a header.

## The 002c fragment — a fixed 19-word per-context vocabulary

- Across all words in the small+burst surface
  (1,526,734 words), exactly **28,576 words end in the
  stored bytes `002c`**, and they are only **19 distinct
  words**. 28,576 = 19 × 1,504: **every one of the 1,504
  contexts contains each of the 19 words exactly once**
  (hef34b: per-context 002c set equals the global 19-word
  set in 1,504/1,504 contexts). The fragment AES-NUM-033
  noticed on two skeleton headers is one member of a
  fixed per-context vocabulary.
- The 19 words live at rigid (size, position) slots:
  eight are burst lane-1 words (24 B, position 1; 8
  distinct, 12,032 occurrences), four head 176 B segments
  (position 0), two are the 96 B variant heads, and one
  each heads the 120 B, 248 B, 256 B, 344 B and 416 B
  classes. No 002c-ending word occurs at any other
  position in the small surface (positions 0 and 1 only),
  and only 8 of the 42 small size classes carry any.
- In the large forms (>512 B, 1,385,584,871 words) the
  same suffix occurs 125,918 times (~9.1×10⁻⁵ of words,
  ~6× the 1/65536 chance rate for a fixed 16-bit suffix)
  with no fixed vocabulary measured — the rigid 19-word
  law is a small-form/context-structure fact, not a
  bulk-data fact. Distinct-word counting was not run on
  the large population (recorded honestly).

## What this closes and what it queues

- MEASURED, corpus-wide: the walking pool is
  mostly-private with a small shared core and no
  universal member; the skeleton quartet is a fixed
  end-anchored trailer (order, gaps, and end-offsets all
  invariant in 1,504/1,504 contexts); the `002c` suffix
  marks a fixed vocabulary of exactly 19 header/lane
  words, each appearing exactly once per context.
- NOT established: the meaning of any of the 19 words,
  of the end-anchored trailer, or of the walking pool's
  sharing structure.
- NEXT (4.35): the other end — what anchors the HEAD of
  each context (first-N pointer actions' form census;
  is there a head block as rigid as the trailer?); the
  176 B four 002c heads' segment anatomy; per-context
  non-skeleton form sequence around the trailer (the
  28 following actions' forms). Host/artifact analysis
  only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
