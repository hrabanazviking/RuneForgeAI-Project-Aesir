# The loose and rigid positions are themselves functions of the doubly-wed key — L0 position, L1 position and R0 position are each CERTIFIED as functions of it (86 distinct keys, 15 repeating, ZERO violating under each certification test) — and wedging any of them further into the key still does not repair gap 2's chain (every further wed still 86 distinct keys, position-1 failing on the same 2 keys, position-2 and the whole tuple on the same 3). The long runs' boundaries are read in full: 16 boundaries, every one flanked, 4 with no shift change and 12 with a change, 6 of the 16 flanking acts themselves large-shift tail acts. The large-shift tail cross-tabbed by A-position band is sign-pure outside the middle: bands 150–349 purely positive (24 acts), bands 450–549 and 600–699 purely negative (25 acts), only bands 350–449 mixed (20 acts). The secondary reading holds exactly 7 runs of length ≥ 20, three of them merging or extending primary long runs. And B byte 0 against the four three-byte sub-keys wed to the group: the three keys that contain byte 0 never repeat a wed value at all (224 distinct wed values of 224 pairs under each), while the one key that omits byte 0, (byte 1, byte 2, byte 3), repeats exactly twice and violates both times — so no three-byte wed key earns a determination, and the 11 wed agreeing repeats of AES-NUM-138 divide by status company as 14 SAME / 8 DIFF over their 22 pairs (7 repeats purely SAME, 4 purely DIFF, all four DIFF repeats the great-group byte-0-key repeats already known) — mechanisms NOT PROVEN (AES-NUM-139)

Slice 4.139, worked under `docs/TASK_CONTRACT_4.139.md`
(contract published in the 4.138 closing commit @
dfee5b63). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef139.py (the hef138 file verbatim as base — itself
the hef137/hef136/hef135/hef134/hef133/hef132/hef131/
hef130 lineage — plus the new arms139) sha256
`0f0a696c0d17953745ed73a3acead4aa090481dccf668be26da991ce48972201`
(553,881 B); arms139 sha256
`69900431cea9d24be7608ff9997359faeffaca4f337fd05660978683f298c4b9`
(19,052 B), its gzip sha256
`c44a11b21ff2c935283221ca0e8cfc557aee89adbff06dfb83da0b12d47d8545`
(5,004 B). The arms were built locally by the
10-minute continuity worker and crossed by the
sha-gated chunked file.write route (14 chunks of
373 B; one chunk's base64 was corrupted in
re-emission in a first attempt, that session was
abandoned uncommitted, and the successful session's
final chunk carried the whole-file sha256 gate,
which passed on-device — two one-shot proxy-receiver
holds in between expired with no POST and saved
nothing); hef139.py was assembled on-device from the
verified hef138 base (on-device sha256 8502588b… ==
VM) plus the arms, and the assembled file's sha256
matched the VM's exactly before the run. The bounded
host-side child was launched in a detached tmux
session on-device with the contract corpus argv
(the six hailo-ollama blobs in glob order, then
MiniLM — the launch law recorded in the contract)
and finished on-device (DONE139 is the output's last
line; the run's exit marker is 0; the error channel
carried nothing). The retrieved output is 32,005
lines / 6,053,414 B, sha256
`439001dc2f65863c566e86165e880eaf568235cddce8c0b722c57e60407abb83`;
retrieved gz sha256
`6f57b6d29a7d404b54d5c3986961ebf36d634f038a197f6b0427503f2ae6fd26`
(624,066 B, fetched through a temporary on-device
HTTP server via the tunnel proxy; the fetched gz
sha256 equals the on-device gz sha256 and
decompresses to exactly the output sha256, verified
on the VM at closing); the 4.139 section begins at
output line 31,228 — exactly one past 4.138's total
line count, and the first 31,227 lines are
byte-identical to hef138.out (verified with cmp both
on-device and on the VM at closing), the base having
reproduced line-for-line. The section alone is 778
lines / 212,498 B, sha256
`46c9977fb83f624ad1d05f85394a51ed7853173fc26eae450576f23b532afbc1`.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared 114×251 acts 168; class-271 acts 30; rigid
context set 271; great group (20, 32720) pairs 216;
gap between-tuple counts 34 / 30 / 87 for gaps 0 / 1 / 2;
contexts indexed 1,504.

## (i) The doubly-wed violating families against the loose acts' own positions

The doubly-wed key is the maximal compound joint key
wed to BOTH companions (context length and gap-2 left
position), as established in AES-NUM-138 (86 distinct
over the 271 contexts).

- L0 position as a function of the doubly-wed key:
  CERTIFIED — 86 distinct keys, 15 repeating, 0
  violating keys.
- L1 position as a function of the doubly-wed key:
  CERTIFIED — 86 distinct keys, 15 repeating, 0
  violating keys.
- R0 position as a function of the doubly-wed key:
  CERTIFIED — 86 distinct keys, 15 repeating, 0
  violating keys.
- Every further wed therefore adds NO distinct key,
  exactly as the three certifications require: doubly-
  wed wed further to L0 position, to L1 position, and
  to R0 position each give 86 distinct joint keys, 15
  repeating. Under each of the three further weds,
  position-1 is NOT a function (2 violating keys),
  position-2 is NOT a function (3 violating), and the
  whole gap-2 tuple is NOT a function (the same 3).
- The violating keys under every further wed are
  exactly the doubly-wed key's violating families
  with the one certified position value appended:
  the (33312256, 328, 0) family at distances (1, 3),
  length 245 / left 220, carrying L0 189 / L1 187 /
  R0 190; the (976502784, 328, 0) family at (1, 3),
  length 873 / left 848, carrying L0 817 / L1 815 /
  R0 818; and the (1255547392, 328, 0) family at
  (2, 9), length 606 / left 581, carrying L0 549 /
  L1 542 / R0 551 and violating only at position-2 /
  the whole tuple with 3 alternatives differing only
  at position-2.

Three more companions are now proven redundant, not
merely observed constant — the loose acts' and the
rigid act's own positions are all determined by the
key that already fails. No companion tested —
distances, order, either sister, both sisters,
length, left position, both together, or any of the
three positions — repairs the chain. What varies
the fill inside a maximal family is NOT PROVEN.

## (ii) The long-run boundaries, the tail by band, and the secondary runs ≥ 20

The exception is (791774208, 328, 0), at 5ab3537d
cidx 86 position 725 and cidx 210 position 727 (689
shared acts, every shared act single-positioned in
both contexts — reproduced exactly; 118 primary runs,
103 secondary runs).

- Boundaries of the 8 primary long runs: all 16
  boundaries (left and right of each run) carry a
  flanking shared act, printed in full with the run's
  first and last acts. The flank-minus-run shift
  changes are: run 7 (158/+2) −2 left, +430 right;
  run 11 (20/−2) +436 left, −2 right; run 24 (29/0)
  −2 left, +2 right; run 33 (37/+2) +105 left, +4
  right; run 71 (41/+3) 0 left, −157 right; run 83
  (25/0) −239 left, 0 right; run 88 (34/0) 0 left,
  −111 right; run 116 (50/+2) −9 left, 0 right.
  Totals: 16 boundaries, 4 with zero shift change,
  12 with a nonzero change; absolute changes {0 ×4,
  2 ×4, 4, 9, 105, 111, 157, 239, 430, 436}.
- 6 of the 16 flanking acts are themselves
  large-shift tail acts (derived at closing): the
  +432 act right of run 7, the +434 act left of
  run 11, the +107 act left of run 33, the −154 act
  right of run 71, the −239 act left of run 83, and
  the −111 act right of run 88. The flanks' A-gaps
  to their runs (read from the printed flank rows)
  are 1 at 10 of the 16 boundaries, 2 at three, and
  3, 5 and 6 at one each.
- The |shift| ≥ 100 tail cross-tabbed by A-position
  band of width 50 (band counts sum to exactly 69;
  sign totals 38 positive / 31 negative, as in
  AES-NUM-138): bands 0–149 hold no tail act; band
  150–199 holds 6, all positive (+432 ×4, +434 ×2);
  200–249 holds 10, all positive; 250–299 holds 4,
  all positive; 300–349 holds 4, all positive;
  350–399 holds 13 (10 positive, 3 negative);
  400–449 holds 7 (4 positive, 3 negative);
  450–499 holds 2, both negative (−154 ×2);
  500–549 holds 6, all negative; 550–599 holds none;
  600–649 holds 7, all negative (−393 ×4, −391 ×2,
  −111); 650–699 holds 10, all negative; bands
  700–799 hold none. Derived at closing: the tail is
  sign-pure in every occupied band outside 350–449 —
  positive before A-position 350, negative from 450
  on, and only the two middle bands mix signs.
- Secondary runs of length ≥ 20: exactly 7 of the
  103 secondary runs — 158 at +2 over A 26–183 (the
  primary long run itself); 20 at −2 over 192–211
  (likewise); 29 at 0 over 242–270 (likewise); 37 at
  +2 over 305–341 (likewise); 53 at +3 over A
  438–497 (span 59 — it reaches 19 shared acts
  before primary run 71's start at 457, across
  A-position gaps); 83 at 0 over A 524–614 (span
  90 — primary runs 83 and 88 read as one secondary
  run across the gap between them); and 58 at +2
  over A 683–744 (span 61 — it extends 12 A-positions
  past primary run 116's end at 732).

## (iii) B byte 0 against the four three-byte sub-keys wed to the group; the 11 wed agreeing repeats' status company

Wed key = (group, three-byte value), over the full
224 pairs. Every repeated wed value is printed in
full with its pairs.

- (byte 0, byte 1, byte 2): 224 distinct wed values,
  0 repeating — no wed value is carried by more than
  one pair.
- (byte 0, byte 1, byte 3): 224 distinct, 0 repeating.
- (byte 0, byte 2, byte 3): 224 distinct, 0 repeating.
- (byte 1, byte 2, byte 3): 222 distinct, 2
  repeating — 0 agreeing, 2 violating. Both repeats
  sit in the small group (14, 9992): wed value
  (1, 176, 128) carried by pairs with A byte 0 = 28
  and 32 (B byte 0 set {28, 32}), and wed value
  (1, 178, 128) carried by pairs with A byte 0 = 20
  and 24 (B byte 0 set {20, 24}). In all four pairs
  B byte 0 equals A byte 0 (status SAME, diff 0) —
  the key omits exactly the byte it would have to
  determine, and it does not determine it.
- The three byte-0-containing keys are injective on
  this population: with no repeated wed value there
  is no agreeing or violating repeat, so no
  determination is earned either way — a function
  claim from zero repeats would be vacuous, and none
  is made. B byte 0 is NOT a function of the
  (byte 1, byte 2, byte 3) wed key (2 violating
  repeats), and its determination by any three-byte
  wed key is NOT PROVEN.
- The 11 wed agreeing repeats of AES-NUM-138,
  re-read with status company: 22 pairs in all — 14
  SAME, 8 DIFF. Seven repeats are purely SAME (the
  small-group ((19, 7712), (20, 1)) and the
  great-group (byte 0, byte 1) repeats (0, 3) and
  (128, 68) and (byte 0, byte 3) repeats (0, 184),
  (0, 186), (128, 184), (128, 210)). Four repeats
  are purely DIFF, all great-group, exactly the four
  already known from AES-NUM-138's full-population
  reading: (byte 0, byte 2) = (0, 87) → B 128;
  (byte 0, byte 3) = (128, 222) → B 0, (64, 235) →
  B 160, (96, 245) → B 160 — each repeat's two pairs
  both DIFF. No wed agreeing repeat mixes SAME and
  DIFF pairs.

Mechanisms NOT PROVEN.

## Next

Slice 4.140 — the violating families against the
contexts' own identities (artifact and context index
as further companions, each also tested as a
function of the doubly-wed key); the secondary long
runs' internal A-position gaps in full, and the 16
long-run flanking acts classified (tail /
same-position / neither); B byte 0 against the four
three-byte sub-keys UNWED over the full 224 pairs,
with the two (byte 1, byte 2, byte 3) wed violating
repeats re-read against A byte 0. Host/artifact
analysis only.
