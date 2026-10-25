# Head-pattern trains vs exemplars, camp content at position 18, len-496 template census (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.81 (AES-NUM-081).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef81.py
(sha256 770a004e…) + labelled follow-up hef81b.py
(sha256 fdfe962b…), both sha-verified on-device after
sha-gated chunked transfers (one 1,000 B chunk of
hef81.py.gz corrupted in re-emission, rejected and
healed by a 500 B re-split; one hef81b.py.gz attempt
failed its whole-file sha and was discarded, the retry
landed clean; output files /tmp/hef81_out.txt sha256
fd04ec37…, /tmp/hef81b_out.txt 0f803e54…). Controls
reproduce AES-NUM-029/032…080 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (region census, classes, cidx /
ngpos) are as in AES-NUM-061…080. Segment byte identity
is sha256 over the action's referenced bytes (zero
point as in AES-NUM-013).

## (i) The head is a 13-action prefix and nothing more: the len-623 train shares it whole, the len-763 population is two trains and only the ng 1 step-6 half carries it

AES-NUM-080 found 0856's two head-13 channel patterns
recurring as heads of 0a0d378c context trains. The
whole-context relation to the exemplars (0856 a cidx
99, len 85; b cidx 255, len 91) is now measured:

- Len-623 (0a0d, ng 0, 16 contexts cidx 3–63 step 4):
  every context carries 0856 a's head-13 EXACTLY
  (joint size+channel 16/16), and the joint prefix
  against the exemplar is exactly 13 in all 16 — the
  agreement ends at the head boundary, never inside
  it, never past it. Against exemplar b the size
  prefix is also 13 but the channel prefix is 1.
  Beyond the head the train is its own population:
  16 distinct size sequences (every context unique),
  4 distinct channel sequences (clusters 7/4/3/2),
  sizes constant through position 31 (first
  size-variable position 32; 534 size-variable
  positions in all), channels constant through
  position 187 (first channel-variable 188; only 10
  channel-variable positions: 188, 322, 323, 325,
  505, 506, 525, 526, 561, 562), 548 hash/offset-
  variable positions. The exemplar's full size
  sequence occurs as a contiguous block in the
  train's modal sequence NOWHERE, and position 13
  onward the two diverge in kind: the exemplar runs
  its (9144, 184) motif region (24, 12224, 200, 24,
  9144, 184, …) while the train runs weights-class
  sizes (32784, 2824, 328, 24, 32784, 21408, 424, …).
- Len-763 is NOT one train. 0a0d holds 32 len-763
  contexts in two network groups: ng 0, 16 contexts
  cidx 1–61 step 4, and ng 1, 16 contexts cidx
  76–166 step 6. Only the ng 1 step-6 half carries
  0856 b's head (joint 16/16, joint prefix exactly
  13 in all 16; its CHANNEL prefix against exemplar
  b runs to 28 — the channel sequence keeps agreeing
  15 positions past the size agreement). The ng 0
  step-4 half shares NO head with either exemplar
  (joint prefix 0/16; size prefix 8; size-constant
  prefix 8, vs 13 on the ng 1 half). Each half holds
  16 distinct size sequences; channel sequences
  number 5 (ng 0) and 4 (ng 1) per half, 9 pooled.
  Size-variable positions: 638 (ng 0) vs 358 (ng 1);
  channel-variable 447 vs 200.

Verdict: a shared head pattern is a shared PREFIX,
not a shared context. The trains borrow the
exemplars' 13-action head as vocabulary and then run
entirely different bodies (weights-class interiors,
per-context size sequences); the len-763 length
class itself splits by network group into a carrier
train (ng 1, step 6) and a non-carrier train (ng 0,
step 4) that happens to share the length.

## (ii) Camp choice IS written at position 18: its segment's first byte separates the camps perfectly; the other ten variable positions carry no camp signal in content, hash or offset

The len-89 B-main form (76c3a8ff, 25 contexts, cidx
121–337 step 9; camps 21392 ×13 / 21648 ×12 at
position 18; AES-NUM-079/080) was tested against its
11 byte-variable positions (12, 13, 16, 18, 19, 22,
26, 29, 30, 31, 32):

- Hashes: at EVERY variable position all 25 contexts
  carry distinct segment hashes (25/25) — hash
  identity is per-context everywhere, so a
  hash-to-camp lookup is trivially consistent and
  proves nothing.
- Offsets: the offset is a per-position constant at
  all 78 non-variable positions (one offset shared
  by all 25 contexts), and per-context unique at
  exactly the 11 variable positions (25 distinct
  offsets each) — so offset sets are camp-disjoint
  at the variable positions only trivially, and the
  offsets are not cumulative (neighbouring offsets
  are unrelated ~1e9 pointer values).
- Sizes/channels at the variable positions are
  camp-invariant except at 18 itself (12: 13048;
  13: 200; 16: 80; 19: 264; 22/26: 80 on channel
  0 resp. 2; 29–32: 6160 each) — position 18 is the
  ONLY position whose size set differs by camp.
- Content (hef81b, full segment bytes): pairwise
  common-prefix lengths are camp-blind at ten of
  the eleven positions — identical distributions
  within and across camps (pos 12: exactly 7,585 B
  for all 300 pairs; pos 13: 153; pos 16/22/26: 33;
  pos 19: 217; pos 29–32: 8–9, means equal). At
  position 18 the split is TOTAL: within-camp pairs
  share exactly 6,408 B of common prefix (144/144
  pairs, min = max = 6,408), cross-camp pairs share
  exactly 0 B (156/156). The first byte itself
  separates: camp 21392 segments begin 02 28 f0 a6…,
  camp 21648 segments begin 03 28 f0 a8… (bytes 0
  and 3 differ; the last-32-bytes test matches
  0/300 pairs in both classes). Camp is not a
  function of the train index (k mod m fails for
  every m = 2…8; runs 1,4,4,3,1,4,5,2,1 stand).

Verdict: the camp bit lives in the position-18
segment alone — in its size (Δ 256) AND in its
content from byte 0, over a 6,408 B within-camp
shared prefix. The other ten variable positions are
per-context payload in the strong sense: unique
hashes, unique offsets, camp-identical prefix
structure. WHAT the byte-0 word encodes (02/03 with
byte 3 a6/a8) and where the +256 sits past the
shared prefix are NOT PROVEN — that is the 4.82
anatomy question, not a licence to name the field.

## (iii) Len-496 template census: nine templates per sister, one dominant, a singleton tail; tuple follows template almost bijectively; cidx 97 in 773 is a full joint transplant of 5ab's modal template

Clustering the sisters' 28 len-496 contexts each by
full size sequence (hef81; frames and channels from
hef81/81b):

- 5ab3537d — T0 modal n=13 (cidx 101, 109, 117, then
  165–197 step 4, 205; tuple (18648, 328, 24, 32776,
  15304), pos-9 size 31288); T1 n=6 (97, 129, 137,
  141, 157, 161; tuple (15384, 328, 24, 29528,
  12024), pos 9 = 29656); T2 n=2 (133, 153; tuple
  (17016, …, 32776, 13672), pos 9 = 31288); T3 n=2
  (145, 201; (17016, …, 31160, 12024), 29656); T4–T8
  five singletons (105, 113, 121, 125, 149). Cluster
  sizes 13/6/2/2/1/1/1/1/1.
- 773470cd — T0 n=13 (cidx 101–117 step 4, then
  173–205 with a gap at 193; the modal tuple on the
  sister-variant sequence of AES-NUM-080); T1 n=5
  (121, 133, 137, 149, 165; (17016, …, 29528,
  12024), pos 9 = 29656); T2 n=4 (141, 145, 161,
  169; (17016, …, 31160, 12024), 29656); T3 n=1 =
  cidx 97 ALONE, carrying the modal tuple on 5ab's
  modal size sequence; T4–T8 five singletons (125,
  129, 153, 157, 193). Cluster sizes 13/5/4/1/1/1/1/1/1.
- Tuple mapping: 8 distinct tuples per sister. In
  5ab the tuple follows the template bijectively
  except (15384, 328, 24, 31160, 12024), which spans
  two singleton templates (T6 cidx 121, T8 cidx 149);
  in 773 the modal tuple spans two templates (T0's
  13 and T3's cidx 97) and every other tuple is
  template-unique. Position-9 size follows the
  tuple's X-slot class in the large clusters (31288
  with the modal tuple, 29656 with (15384/17016,
  29528/31160) tuples) but not in singletons (T7 in
  773 carries the modal X 18648 with pos 9 = 31288
  on a (31160, 13656) tuple; T4 in 5ab carries 31288
  with a (29528, 13656) tuple).
- Frames: every template in both sisters carries
  its (…, 328, 24, …) frames at exactly positions
  (18, 22, 473) — 28/28 contexts per sister, no
  template exception.
- Channels: 5ab holds ONE channel sequence across
  all 28 contexts and all 9 templates. 773 holds
  TWO: the main sequence on 27 contexts (cidx
  101–205) and a second sequence on cidx 97 alone —
  and that second sequence is 5ab's (the one shared
  channel sequence between the sisters). Combined
  with AES-NUM-080's shared size sequence, cidx 97
  is a FULL joint transplant: it carries 5ab's
  modal template whole — size sequence, channel
  sequence and tuple — inside 773's family, where
  it participates in no localized region hit.

Verdict: each sister's len-496 family is one
dominant template (13/28), a small mid tier
(6/2/2 in 5ab; 5/4 in 773) and a five-singleton
tail; the (X, 328, 24, Y, Z) tuple is a template
property with exactly one leak per sister, and the
two families are bridged by exactly one context,
773's cidx 97, which is 5ab's modal template
transplanted whole (sizes + channels + tuple).

## What this closes and what it queues

- MEASURED: the head-pattern trains' relation to
  the exemplars — len-623 (ng 0, step 4, 16 contexts)
  carries 0856 a's head-13 exactly in all 16 with
  joint prefix exactly 13 and per-context bodies
  (16 size sequences, 4 channel sequences, sizes
  fixed to position 31, channels to 187); len-763
  splits by network group into a carrier train
  (ng 1, step 6, 16/16 head, channel prefix 28) and
  a non-carrier train (ng 0, step 4, prefix 0) of
  the same length.
- MEASURED: camp choice is readable at position 18
  alone — segment size Δ 256 AND content from byte
  0 (within-camp common prefix exactly 6,408 B,
  144/144; cross-camp exactly 0 B, 156/156; first
  bytes 02 28 f0 a6… vs 03 28 f0 a8…); the other
  ten variable positions are camp-blind in size,
  channel, hash-sharing, offset-sharing and content
  prefix (identical within/cross distributions).
- MEASURED: the len-496 template census — 9
  templates per sister (13/6/2/2/1×5 in 5ab;
  13/5/4/1×6 in 773 counting the transplant), tuple
  ↔ template bijective but for one leak per sister,
  frames fixed at (18, 22, 473) in all 56 contexts,
  one channel sequence per family (5ab) / two (773,
  the second being 5ab's, on cidx 97 alone), and
  cidx 97 established as a full joint transplant of
  5ab's modal template into 773.
- NEXT (4.82): position-18 segment anatomy (the
  byte-0/byte-3 camp word; the 6,408 B shared prefix
  vs the per-context tail; where the +256 sits);
  the ng 1 channel-prefix-28 extension vs exemplar
  b (what carries channels 15 positions past the
  size break?); sister singleton templates'
  nearest-template distances. Host/artifact analysis
  only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
