# Wider lead family, dense-negative vocabulary, cidx-1 anatomy (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.54 (AES-NUM-054).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef54.py
(sha256 5dfdc417…) plus the labelled follow-up
hef54b.py (sha256 ccf0a005…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046/047/048/049/050/051/052/053
EXACTLY in both scripts (128,787 pooled small actions;
79,001 pooled 24 B bursts; 745,849 pointer actions;
1,504 contexts; trailing distinct (channel, operand)
pairs 2,049; champion-headed bursts 75,215). Transfers
were sha-gated: hef54.py via gzipped 373 B parts
(whole-file sha verified on-device first try);
hef54b.py's first 373 B crossing failed its whole-file
sha and was discarded uncommitted, the 300 B re-split
landed clean. Definitions (middle, band, cluster,
window) are as in AES-NUM-049…053: a window is a
3856 action and its lead is the preceding middle size;
band = 8104–8832; core cluster = 9168–9248. The 61
window-dense cc9b9d1c negatives are the cluster-negative
contexts with ≥81 windows (cidx listed in the run
output; the ≥50-window pool is 72).

## The wider family is 9144–9264 — and membership does NOT re-grade

Per-value census of step-8 leads from 9000 to 9400 in
the 19 cc9b9d1c cluster-positive contexts (POS) vs the
61 dense negatives (DENSE) vs the remaining negatives:

- Below the family, values 9000–9136 are a NEGATIVE-side
  ladder: dense negatives carry them throughout (40 at
  9000, 70 at 9064, 73 at 9088, …) while positives carry
  ZERO at 9000–9112 and only sparse counts at 9120 (6),
  9128 (5), 9136 (10).
- The exclusive zone is exactly 9144–9264 (16 step-8
  values: 9144, 9152, 9160, the core 9168–9248, 9256,
  9264): positives carry all 16 (23/34/51 at the lower
  shoulder, 48–85 across the core, 48/56 at the upper
  shoulder), and dense + other negatives carry ZERO at
  every one of the 16 values. Pooled: 900 exclusive-led
  windows in exactly the 19 positive contexts, 0 in all
  252 negative contexts. Corpus-wide the zone appears
  in 21 standard contexts (963 windows): the 19 cc9b9d1c
  positives plus 76c3a8ff cidx 3 (49) and cidx 4 (14) —
  the same two contexts that already break band/cluster
  exclusion in AES-NUM-053.
- Above the family the shoulder flips ownership:
  9272 (POS 48 / DENSE 7) and 9280 (50 / 5) are the
  transition, and from 9288 up the dense negatives take
  over (9288: 43/17, 9296: 47/25, 9304: 21/34, 9312:
  9/41, 9320: 5/54, 9336: 1/55, 9344: 0/60). No
  non-step-8 lead occurs anywhere in 9100–9350.
- Re-grade verdict: widening the counted cluster from
  the core 9168–9248 to the true family 9144–9264
  changes NO membership — the same 19 cc9b9d1c contexts
  (plus the two known 76c3a8ff exceptions corpus-wide).
  What changes is the dose: 900 family windows, not
  688. The naive wider extent 9104–9352 would falsely
  admit 27 negative contexts (17 dense, 10 other) on
  shoulder values alone; the family's edges are sharp
  at 9144 and 9264, not gradual.
- Dose law inside the positives: per-context exclusive
  dose tracks the core dose tightly (correlation
  0.948; exclusive 9–64, mean 47.4, vs core 1–63);
  cidx 14/151 pairs repeat (62,55)/(62,55) and the
  (48,38) pair repeats at cidx 30/167, consistent with
  AES-NUM-053's repeated selection pattern.

Graded MEASURED: the cluster's wider family is the
16-value step-8 band 9144–9264, exclusive to the same
contexts the core defined; the selecting feature
remains NOT PROVEN, but any selector must now explain
a 900-window, zero-leak family, not a 688-window core.

## The dense negatives speak other ladders entirely

Lead vocabulary of the 61 dense negatives (5,842
windows, 109 distinct leads) vs the positives (1,758
windows, 64 distinct):

- The dense negatives' top leads are three ladders the
  positives barely touch: 9408–9488 (9448 ×176, 9456
  ×164, 9464 ×162, 9432 ×149, 9424 ×148, 9440 ×142,
  9472 ×128, 9416 ×127, 9408 ×117, 9480 ×112, 9488
  ×83 — zone share 0.288 of all their windows), the
  low ladder 8960–8984 + the 9000–9136 range (zone
  8960–9136 share 0.194), and the 9696–9792 ladder
  (9760 ×138, 9728 ×134, 9752 ×125, 9768 ×115, 9744
  ×113 — share 0.194). Their upper-shoulder share
  (9272–9352) is only 0.068, their band share is
  0.000 — the dense negatives carry NO band-led
  windows either — and 0.255 of their windows are led
  outside every named zone.
- The positives' zone profile is the mirror image:
  exclusive family 0.512, 9696–9792 ladder 0.159
  (shared with the negatives: 9728 and 9744 sit in
  both top-20s), upper shoulder 0.129, low zone 0.012,
  band 0.000, 94xx ladder 0.000.
- Vocabulary overlap is partial: 48 distinct leads are
  shared, 16 are positive-only — exactly the 16
  exclusive-zone values — and 61 are dense-only,
  including the entire 94xx ladder (its top values,
  9448/9456/9464/8976/9432/9424/8968/9440/9472/9416/
  9408/9480/8984/8960/9488, never lead a positive
  window). Jaccard 0.384. Per-context distinct-lead
  counts are alike (positives mean 21.8, dense mean
  20.2): the two populations run equally rich
  vocabularies — they are simply different vocabularies.
- The sparse other negatives (191 contexts, 1,646
  windows) are a third profile: 32784-led 0.089, band
  0.021, top lead 32784 itself (×147), then the 97xx
  ladder — window-poor contexts, not a dialect.

Graded MEASURED: window-dense cc9b9d1c contexts split
into two disjoint lead dialects — the 9144–9264 family
(19 contexts) and a 94xx/low/97xx ladder population
(61 contexts) sharing only the 97xx ladder and the
upper shoulder; neither dense population uses the
8104–8832 band at all.

## cc9b9d1c cidx 1: a full dialect spoken at family whisper dose

Cidx 1 (738 actions, network group 0, pair order
reversed, 96 windows, champion body count 29 like every
cc9b9d1c context) is the family's edge member:

- Its single CORE-cluster window sits at window
  ordinal 32 (middle position 208): lead 9232, its
  3856 on channel 1, preceded by (…, 32784, 32016,
  9232) and followed by (32784, 32016, 9280, 3856,
  32784, 32784, 32016, 32016) — window class `other`,
  the modal class of positive cluster windows (527 of
  688; their after-1 census is led by 32784 ×265 and
  32016 ×52, channels {1: 293, 0: 218, 2: 177}). The
  lone window is anatomically ordinary in every
  measured respect.
- Its exclusive-family dose is 9 windows (ordinals
  2–88) against a positive mean of 47.4 — by far the
  weakest member — and its 63 windows in the naive
  9104–9352 extent are mostly UPPER SHOULDER: its lead
  census is topped by 9296 (×14), 9288 (×12), 9304
  (×7), 9280 (×7), 9264 (×6), 9272 (×5), with a 97xx
  tail (9768 ×8, 9784 ×6, 9760 ×5, 9776 ×5). Cidx 1
  leans on the shoulder the dense negatives share,
  yet carries 9 family windows they never carry at
  all — membership is binary even at whisper dose.
- Its dialect vocabulary is nonetheless complete: its
  middle holds 32016 exactly 96 times and 30480 ZERO
  times, and its 96 windows split 40 `no30480` / 56
  `other` with no `full` window — the 32016 dialect
  of AES-NUM-053 at full strength in a context whose
  family-lead dose is one fifth of the family mean.

Graded MEASURED: cidx 1 is a genuine but edge member
— one ordinary core window, 9 exclusive-family
windows, a shoulder-heavy lead profile, and an
undiluted 32016 / zero-30480 dialect. Family dose and
dialect strength are separate variables: the dialect
does not fade as the dose falls.

## What this closes and what it queues

- MEASURED: the wider lead family is exactly
  9144–9264 (16 step-8 values, 900 windows), exclusive
  to the core cluster's own 19 cc9b9d1c contexts —
  membership does NOT re-grade; edges are sharp
  (zero counts on both sides in the negative pool).
- MEASURED: the 61 dense negatives run a disjoint
  ladder vocabulary (94xx 0.288, low 8960–9136 0.194,
  97xx 0.194, band 0.000); only the 97xx ladder and
  the 9272+ shoulder are shared ground.
- MEASURED: cidx 1's lone core window is ordinary;
  its membership rides on 9 exclusive windows while
  its 32016 dialect runs at full strength (96
  occurrences, 30480 zero) — dose ≠ dialect.
- NEXT (4.55): the 94xx ladder anatomy (is it a
  family like 9144–9264 — exclusive zone, dose law,
  its own dialect behind its windows?); the shared
  97xx ladder's role in both dialects; the
  exclusive-dose ↔ core-dose gap per context (what
  the shoulder windows 9144–9160/9256–9264 add).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
