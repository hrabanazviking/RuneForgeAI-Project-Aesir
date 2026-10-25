# Pair-order vs middle action stream, motif lead exclusivity, variant roles in standard middles (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.49 (AES-NUM-049).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef49.py
(sha256 e1891202…) plus the labelled follow-up
hef49b.py (sha256 9b454b99…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046/047/048 EXACTLY in both scripts
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Transfers were
sha-gated gzipped 373 B-part crossings; both scripts'
whole-file shas verified on-device on the first
attempt. All whole-file shas verified on-device.

Definitions: the MIDDLE of a context is the action
stream between the head and the end block, in the
form used by AES-NUM-045/047/048 — actions
[12 : len−56] (binary contexts: 1,428 contexts,
middle lengths 23–953; the 156-class middle is the
88-action form of AES-NUM-047). The pair, its
members, and the binary population are as in
AES-NUM-045/047/048 (693 normal, 735 reversed; the
76 displaced contexts are excluded from the
function tests).

## No coarse or segment-level middle feature determines the pair order — and the formal combined separations are a single-counterexample artefact

AES-NUM-048 closed the datum stream and left the
size stream beyond the head as the last stream
candidate. Slice 4.49 tests the middle stream at
every granularity below the full sequence (the full
middle sequence formally separates, 1,100 keys /
0 mixed — the uniqueness pattern of AES-NUM-048,
not a law):

- Aggregates — NO. Middle length: 98 keys, 49
  mixed, accuracy 0.857. Middle size sum: 1,057
  keys, 10 mixed (21 contexts), accuracy 0.993 —
  a near-unique key, not a feature. Distinct-size
  count 0.702; maximum size 0.522; first large
  size 0.812; count of 24 B actions 0.690.
- Shape histograms — NO. The nine-bin coarse size
  histogram: 396 keys, 44 mixed, accuracy 0.934.
  The sorted middle multiset: 1,075 keys, 9 mixed
  (19 contexts), accuracy 0.994 — again near-
  uniqueness. The (3856, 32784, 30480) count
  triple: 204 keys, 62 mixed, accuracy 0.849.
- Positions — NO. Any single middle size, aligned
  from the start (positions 0–9) or from the end
  (1–10), leaves 19–45 mixed keys, accuracy
  0.65–0.84. First-3 / first-5 / last-5 size
  tuples: 0.934 / 0.943 / 0.947. First-5 channel
  tuple: 0.763.
- The strongest middle feature is the channel
  COUNT — and it still fails. Grouping by the
  middle's per-channel action counts gives 438
  keys with only 2 mixed groups (8 contexts,
  accuracy 0.9979) — but both mixed groups are
  real counterexamples in 0856a10c, on different
  stacks from the 4.47 triple: cidx 14 (reversed),
  41 (normal), 50 (reversed) at 448 actions, and
  cidx 18/30 (normal) with 48/60/72 (reversed) at
  280 actions. Adding middle length to channel
  counts changes nothing (438 keys, same 2 mixed).
- The combination trap, stated plainly. Grouping
  by the non-pair champion stream (nopair_op)
  alone has exactly ONE mixed group in the whole
  corpus — the 0856a10c cidx 15/27/39 triple —
  among 111 multi-context groups covering 1,156
  contexts. ANY second feature that happens to
  differ inside that one triple therefore yields
  a formal 0-mixed separation, and slice 4.49
  exhibits the whole family: nopair_op + middle
  length (386 keys), + total actions (386 keys —
  the same key, middle length = actions − 68),
  + channel counts (448 keys), + coarse histogram,
  + first-5 middle sizes (492 keys), + middle sum
  (1,086 keys). NONE of these is graded a law:
  no independent population exercises any combined
  key in both orders, so there is nothing to
  generalise from. The triple's normal member is
  a 279-action context against two 280-action
  reversed members; that a 1-action difference
  coincides with the order flip in the corpus's
  only mixed stack is recorded as coincidence-
  grade, NOT PROVEN as determination.
- Inside the triple the middle behaves like the
  other streams: variation without a bit. The two
  reversed members (15, 27) differ at 35 middle
  size positions (multiset symmetric difference
  66) with IDENTICAL coarse histograms and
  IDENTICAL channel counts ((0,74),(1,73),(2,65));
  the normal member (39) differs from 15 at 78
  positions, 34 channel positions, with channel
  counts ((0,75),(1,71),(2,65)), a different
  coarse histogram, and one fewer action. Middle
  differences exist in both orders and within one
  order; no tested reading of them is the bit.

Graded MEASURED, NEGATIVE: the order bit is not a
function of any tested coarse, aggregate,
positional, histogram, multiset, or channel-count
feature of the middle action stream. With the
operand stream (4.47) and the datum stream (4.48)
already closed, every stream-level home tested so
far has failed; the formal full-stream and
combined separations are uniqueness /
single-counterexample artefacts. Where the bit
lives is still NOT PROVEN — the remaining
candidates are fine-grained streams not yet
function-tested (the exact middle CHANNEL
sequence, segment identity at coarse grain) or a
variable outside the action streams entirely.

## The motif leads are exclusive to the lead position — they are not copies of the context's own large sizes

AES-NUM-048 left the 156 motif's lead sizes (312
occurrences, 82 distinct values, band 8104–8832,
all multiples of 8) as private per-(context,
block) values and queued the copy test: is a lead
simply one of the context's own large-action
sizes, reused?

- NO — the negative is total. A lead value occurs
  NOWHERE else in its own context: 0 of 312 lead
  occurrences appear in the same context's other
  action sizes, 0 of 312 in its middle's non-lead
  sizes, and 0 of 312 in its head + trailer sizes.
  Inside the 26 contexts of the 156 class, actions
  in the whole 8104–8832 band number exactly 312
  — the leads themselves, and nothing else.
- The control is equally empty: the leads of one
  156 context appear in the NEXT 156 context's
  other sizes 0 of 312 times. Lead values are not
  a per-context pool at all.
- Yet the band is ordinary vocabulary elsewhere.
  Each of the 82 distinct lead values occurs
  somewhere in the other 76c3a8ff contexts, and
  the band as a whole is common in standard
  contexts: 16,112 actions in the band across 799
  of the 1,476 standard contexts, 16,105 of them
  in middles. The lead values are drawn from the
  corpus's shared large-size vocabulary and then
  assigned EXCLUSIVELY to lead positions in the
  156 class — what selects a block's lead value
  remains NOT PROVEN (AES-NUM-048's private-value
  grade stands), but it is not a copy of anything
  else the same context carries.

Graded MEASURED, NEGATIVE for the copy hypothesis:
motif leads are position-exclusive in their own
contexts (0/312 on every arm, control included),
while the values themselves are ordinary shared
vocabulary in standard contexts.

## The variant block forms are generic window forms — in standard middles they are scattered; only the 156 motif pins them to fixed ordinals

AES-NUM-048 established that, in the 156 motif,
block 0 is always the no-30480 form (window
(lead, 3856, 32784, 32784), the next lead follows)
and block 4 always the no-32784 form ((…,
3856, 30480, …)), in 26 of 26 contexts each.
Slice 4.49 censuses the same three window classes
at every 3856 in every middle — full
(32784, 32784, 30480 follows), no30480 (the 32784
pair follows, 30480 does not), no32784 (30480
follows immediately), other (everything else):

- The 156 class, as control: 312 windows — full
  259 (83.0%), no30480 26 (8.3%), no32784 26
  (8.3%), other 1 (the truncated final block).
  At 3856-ordinal 0 the class is no30480 in
  26/26; at ordinal 4, no32784 in 26/26.
- Standard middles are a different world: 20,411
  windows over the 1,476 contexts outside the
  156/173 classes — full 2,977 (14.6%), no30480
  4,632 (22.7%), no32784 877 (4.3%), other 11,925
  (58.4%). Both variant forms occur, at scattered
  ordinals: at ordinal 0 the standard population
  splits full 7 / no30480 39 / no32784 30 / other
  273; at ordinal 4, full 52 / no30480 106 /
  no32784 2 / other 154. The commonest standard
  follow-tuples after the full form are
  (32784, 32784, 32016) ×2,149 — counted in the
  no30480 class — and (32784, 32784, 32784) ×983.
  311 standard contexts carry ≥12 middle 3856
  windows (counts 14–140), so motif-sized runs
  are themselves not exclusive to the 156 class.
- The 173 class carries no 3856 at all (0 windows
  in both contexts) — the variant question is
  vacuous there; its middle is a different
  species (AES-NUM-045).

Graded MEASURED: the no30480 / no32784 forms are
NOT roles invented by the 156 motif — they are
generic 3856-window forms that occur throughout
standard middles at unfixed ordinals, alongside a
majority of other forms. What is special to the
156 motif is the PINNING: ordinal 0 is no30480
and ordinal 4 is no32784 in 26 of 26 contexts,
against a standard background where those
ordinals are mixed. An encoder for standard
contexts therefore cannot import the motif's
fixed-ordinal variant rule; and the motif's rule
cannot be explained as "what 3856 windows
usually do".

## What this closes and what it queues

- MEASURED, NEGATIVE: pair order is not a
  function of any tested feature of the middle
  action stream — aggregates, coarse histogram,
  sorted multiset, count triples, single
  positions from either end, head/tail tuples,
  or channel counts (the strongest, 0.9979, with
  two real mixed groups in 0856a10c). Combined
  keys with the non-pair champion stream separate
  formally (0 mixed) only by resolving the
  corpus's single mixed group; they are recorded
  as artefacts, NOT laws. Three stream homes are
  now closed (operand, datum, middle sizes);
  the bit's home is NOT PROVEN.
- MEASURED, NEGATIVE: motif leads are not copies
  of their contexts' own large sizes — 0/312 on
  every same-context arm and on the cross-context
  control; band actions inside 156 contexts are
  exactly the 312 leads. The 82 values are shared
  vocabulary, common in standard middles
  (16,105 occurrences).
- MEASURED: the block-0/block-4 variant forms are
  generic — full 14.6% / no30480 22.7% /
  no32784 4.3% / other 58.4% of 20,411 standard
  middle windows, at scattered ordinals. The 156
  motif's distinction is fixed-ordinal pinning
  (0 → no30480, 4 → no32784, 26/26 each).
- NEXT (4.50): pair-order vs the middle CHANNEL
  sequence (per-position channel function tests
  + the triple's channel-stream detail); the
  lead-band's role in standard middles (is a
  band action a 3856 lead there too — neighbour
  census around band actions); variant-ordinal
  concentration in the 311 standard contexts
  with ≥12 middle 3856 windows. Host/artifact
  analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
