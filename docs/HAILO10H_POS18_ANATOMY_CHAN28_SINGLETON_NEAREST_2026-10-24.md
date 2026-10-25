# Position-18 segment anatomy, the channel-prefix-28 extension, singleton nearest templates (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.82 (AES-NUM-082).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef82x.py
(sha256 86c0a8e7…) + labelled control follow-up
hef82b.py (sha256 5674bdc8…), both sha-verified
on-device after one-shot proxy-receiver transfers
(the gz bytes never passed through tool re-emission;
the receiver returned the gz sha256 and it matched:
hef82x.py.gz 2253aaa8…, hef82b.py.gz 0f96530f…).
Output files /tmp/hef82x_out.txt sha256 bf5742c7…,
/tmp/hef82b_out.txt sha256 d73a1872…. Controls
reproduce AES-NUM-029/032…081 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed
bursts 75,215). Definitions (region census, classes,
cidx / ngpos) are as in AES-NUM-061…081. Segment byte
identity is over the action's referenced bytes (zero
point as in AES-NUM-013). Provenance note: this slice
was started by one continuity firing (hef82x.py
authored, transfer stalled with the receiver already
landed on-device) and resumed and closed by the next
firing from that exact work product — no analysis was
re-authored or duplicated.

## (i) The position-18 segment is a camp header word, a camp-constant 6,408 B prefix, and a camp-shaped tail — and the +256 lives wholly in the tail, not as an insertion

The len-89 B-main form (76c3a8ff, 25 contexts, cidx
%9 = 4 step-9 train minus the shifted head cidx 112;
camp 21392 ×13: cidx 130, 139, 148, 157, 202, 211,
220, 238, 247, 256, 265, 319, 328; camp 21648 ×12:
121, 166, 175, 184, 193, 229, 274, 283, 292, 301,
310, 337) had its position-18 segments read whole:

- Header (bytes 0–15): constant across all 25
  segments except TWO bytes. Byte 0 is 0x02 (camp
  21392) vs 0x03 (camp 21648); byte 3 is 0xa6 vs
  0xa8; bytes 1–2 are 28 f0 in both camps and bytes
  4–15 are the constant 00 00 00 15 01 00 00 00
  58 01 a0 00 in every segment. As u32 LE the first
  word is 2800756738 vs 2834311171 — the camp word
  differs at byte 0 (+1) AND byte 3 (+2) together;
  no segment mixes the two forms. What the word
  encodes is NOT PROVEN (AES-NUM-081's caution
  stands); its shape — a 4-byte word with two
  camp-locked bytes over an otherwise fixed 16-byte
  header — is now measured.
- Prefix: the GLOBAL common prefix within each camp
  (all 13, resp. all 12, segments at once) is exactly
  6,408 B — the same value AES-NUM-081 measured
  pairwise (min = max = 6,408). The prefix is
  therefore ONE camp template held by every member,
  not a pairwise average.
- Tail (bytes 6,408–end): length 14,984 (camp
  21392) vs 15,240 (camp 21648) — the segment size
  delta of exactly +256 sits ENTIRELY in the tail;
  the prefix is the same length in both camps. The
  tail is not per-context noise: 14,797 of its
  14,984 byte positions (98.8%) are constant across
  camp 21392 and 15,053 of 15,240 (98.8%) across
  camp 21648; the per-context variation concentrates
  in ~187 positions, and the very first tail byte
  (offset 6,408) is distinct in EVERY context (13
  distinct values in camp 21392, 12 in camp 21648).
  Tails are ~83.1% zero bytes (zero fraction 0.8318
  / 0.8310; 140 / 139 distinct byte values) and open
  with a repeating 4-byte pattern word that itself
  differs by camp in the first contexts read
  (3f a2 00 00… in camp 21392, da b3 00 00… in camp
  21648).
- Cross-camp structure: the first context pair
  shares 0 B from byte 0, 2 B when byte 0 is skipped
  (byte 3 breaks the run), and 6,404 B when the
  whole 4-byte camp word is skipped — bytes 4–6,407
  are camp-identical, divergence resumes exactly at
  the tail boundary 6,408.
- Insertion model EXCLUDED: the hypothesis that the
  21648 segment equals the 21392 segment plus one
  inserted 256 B block fails at every tested start
  (0, 1, 4) for the first pair and in 0/156 cross
  pairs under the from-byte-4 form. The +256 is a
  tail-length difference between two camp-shaped
  tails, not a single block inserted at a fixed
  offset.

Verdict: position 18's segment decomposes as
[4 B camp word: bytes 0 and 3 camp-locked] +
[12 B fixed header rest] + [6,408 B camp-constant
prefix, identical length in both camps] +
[camp-shaped tail, ~83% zero, ~98.8% constant
within camp, per-context bytes concentrated at
~187 positions led by offset 6,408]. The camp
choice is written in the header word AND in the
tail's shape and length; there is no inserted
block to find.

## (ii) The channel-prefix-28 extension is a zero plateau: positions 13–27 are channel 0 in the exemplar, in the whole ng 1 train, and everywhere the pattern occurs it occurs only at a head

AES-NUM-081 left one number unexplained: the len-763
ng 1 step-6 train's CHANNEL prefix against exemplar
b (0856a10c cidx 255) runs to 28 while its size
prefix stops at 13. The extension is now measured:

- Exemplar b's channels at positions 13–27 are ALL
  ZERO (its chans[0:40] = 2,1,2,1,2,1,2,1,2,1,0,1,2,
  then 0 ×15, then 1,1,1,0,0,0,2,2,0,0,0,0), and the
  ng 1 group's channels at positions 13–32 are all
  zero in all 16 contexts. The 15 extra positions of
  agreement are agreement on channel 0 — silence,
  not signal.
- The subsequence test shows the degeneracy
  directly: b's chans[13:28] (fifteen zeros) occurs
  as a contiguous subsequence 48,146 times across
  the corpus — it matches any run of fifteen
  channel-0 actions anywhere.
- The FULL 28-channel head chans[0:28] is rare and
  head-bound: exactly 27 occurrences corpus-wide,
  ALL at offset 0 — MiniLM cidx 1, 2, 4, 5; 0856a10c
  cidx 0 and 255 (b itself); the 0a0d378c ng 1 train
  (cidx 76–166 step 6, 16 contexts); 76c3a8ff cidx
  92, 109, 352. It never occurs mid-context.
- Inside the ng 1 group the channels stay constant
  far past 28: the first channel-variable position
  within the group is 54, while SIZES at positions
  13–27 already vary per context (distinct counts
  3–7 at most positions; size prefix vs b is 13 in
  16/16). The ng 0 half is the contrast: channel
  prefix vs b is 0 in 16/16 and its first
  channel-variable position is 4.

Verdict: nothing carries channel signal 15
positions past the size break. Positions 13–27 are
a channel-0 plateau shared by the exemplar and the
train (and the train's channel sequence is
group-constant to position 53); the prefix-28
figure counts a shared silence after a shared
13-action head. The head itself, where it occurs,
occurs only at offset 0.

## (iii) Singleton templates are 1–2 size-edit neighbours of resident templates — with exactly one quantitative foreigner, cidx 97

Nearest-template distances for the singleton tails
of the len-496 census (AES-NUM-081), distance =
(size-sequence Hamming, nearest template index,
its cluster size, channel-sequence Hamming, L1):

- 5ab3537d singletons (T4 cidx 105, T5 113, T6 121,
  T7 125, T8 149): best size Hamming 2, 1, 1, 2, 1
  respectively; channel Hamming 0 in every listed
  nearest triple; best L1 3,264 / 1,632 / 1,632 /
  3,264 / 1,632. Every 5ab singleton is one or two
  size positions away from a multi-context template
  with its channel sequence untouched.
- 773470cd singletons except T3 (T4 cidx 125, T5
  129, T6 153, T7 157, T8 193): best size Hamming
  1, 1, 2, 2, 1; channel Hamming 0 throughout; best
  L1 1,632–4,896. The same local-edit character as
  5ab's tail.
- 773470cd T3 = cidx 97, the AES-NUM-081 transplant:
  its nearest RESIDENT 773 template is size Hamming
  314 of 496, channel Hamming 193, L1 4,641,152 —
  roughly three orders of magnitude farther than
  any other singleton's nearest (pooled other best
  L1 ≤ 4,896, size Hamming ≤ 2). Measured against
  its own artifact's family it is not a variant of
  anything; its kinship is entirely cross-artifact
  (5ab's modal template, AES-NUM-081).

Verdict: both sisters' singleton tails are local
1–2-edit variants of resident templates (size edits
only, channels invariant) — the tails are the
family's own jitter, not imports. The single
exception in either family is cidx 97, whose
nearest-template distance (314 / 193 / 4,641,152)
quantifies its foreign origin rather than merely
asserting it.

## What this closes and what it queues

- MEASURED: the position-18 segment's anatomy —
  camp word 02 28 f0 a6 vs 03 28 f0 a8 (bytes 0
  and 3 camp-locked, rest of the 16 B header
  fixed), a single camp-constant 6,408 B prefix
  (global, both camps, same length), and a
  camp-shaped tail carrying the whole +256
  (lengths 14,984 / 15,240; ~83% zero; ~98.8% of
  tail positions constant within camp; first tail
  byte per-context distinct); the one-block
  insertion model is excluded (0/156 cross pairs).
- MEASURED: the channel-prefix-28 extension is a
  zero plateau — b's chans[13:28] are all zero,
  occur 48,146 times as a subsequence corpus-wide,
  and the full chans[0:28] occurs exactly 27 times,
  always at offset 0; the ng 1 group's channels are
  group-constant to position 54 while its sizes
  diverge from position 13.
- MEASURED: singleton nearest-template distances —
  ten of eleven singletons sit 1–2 size edits
  (channel Hamming 0, L1 ≤ 4,896) from a resident
  template; 773's cidx 97 sits 314 size positions /
  193 channel positions / L1 4,641,152 from its
  nearest resident template.
- NEXT (4.83): the position-18 tail's per-context
  anatomy (the ~187 variable positions — their
  distribution and the repeating pattern word per
  camp/context); a corpus census of the 16 B header
  pattern (does the header, or the camp-word byte
  pair, occur at other positions or artifacts?);
  the ng 1 channel plateau past 28 (the group's
  constant channels 28–53 vs exemplar b's channels
  there — where does b rejoin or leave the
  plateau?). Host/artifact analysis only — no
  physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
