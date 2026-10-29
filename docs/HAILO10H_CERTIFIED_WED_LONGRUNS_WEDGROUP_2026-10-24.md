# The two wed redundancies are now CERTIFIED directly — the context length IS a function of the maximal compound joint key, and the gap-2 left position IS a function of it (86 distinct keys, 15 repeating, ZERO violating keys under either certification test, over all 271 contexts) — and wedging the maximal key to BOTH companions together still does not repair gap 2's chain (86 distinct keys, position-1 failing on the same 2 keys, position-2 and the whole tuple on the same 3). The shift anatomy's long runs are read act by act: exactly 8 primary runs of length ≥ 20 (158 at +2 over A 26–183; 50 at +2 over 683–732; 41 at +3 over 457–497; 37 at +2 over 305–341; 34 at 0 over 581–614; 29 at 0 over 242–270; 25 at 0 over 524–548; 20 at −2 over 192–211), the |shift| ≥ 100 tail is 69 acts over 40 distinct shifts (38 positive, 31 negative), and shift class by A-position band of width 50 shows whole bands of one class (50–149 purely +1..+9 apart from the first band's 9 zeros; 550–599 purely zero on 43 acts; 700–749 purely +1..+9 on 41), class totals ≤−10: 44, −9..−1: 53, zero: 126, +1..+9: 395, ≥+10: 71. And B byte 0 against the six two-byte sub-keys WED TO THE GROUP still violates under every key (60 repeating wed values in all, 11 agreeing and 49 violating), while the 13 agreeing full-population repeats' status company is counted exactly: 27 pairs with multiplicity across keys, 19 SAME and 8 DIFF — the 8 DIFF pairs belong to exactly 4 repeats, all in the great group, each repeat's two pairs both DIFF at one shared nonzero diff (+128, −128, +96, +64) — mechanisms NOT PROVEN (AES-NUM-138)

Slice 4.138, worked under `docs/TASK_CONTRACT_4.138.md`
(contract published in the 4.137 closing commit @
27a752ce). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef138.py (the hef137 file verbatim as base — itself
the hef136/hef135/hef134/hef133/hef132/hef131/hef130
lineage — plus the new arms138) sha256
`8502588b2bc8d6620d06d92e5d3dc00a367ec91c1c436bf29a117dcaf2502e23`
(534,829 B); arms138 sha256
`f93ed6f5de36f62d7dc3f6b39756cd154e1e97ebb8257c1dafbdb46719aab570`
(15,359 B), its gzip sha256
`70d29e2f360b53d6c5a803ce701154ef035933831c39ea4bb38d710ec41bf950`
(4,402 B). The arms were built locally by the
10-minute continuity worker and crossed by the
sha-gated chunked file.write route (12 chunks of
373 B; the final chunk's whole-file sha256 gate
passed on-device — the proxy receiver route was NOT
used this slice); hef138.py was assembled on-device
from the verified hef137 base (on-device sha256
a1b115e6… == VM) plus the arms, and the assembled
file's sha256 matched the VM's exactly before the
run. The bounded host-side child was launched in a
detached tmux session on-device with the contract
corpus argv (the six hailo-ollama blobs in glob
order, then MiniLM — the launch law recorded in the
contract) and finished on-device (DONE138 is the
output's last line; the run's exit marker is 0; the
error channel carried nothing but that marker). The
retrieved output is 31,227 lines / 5,840,916 B,
sha256
`9d4665f6aa8130c3ecc4c3ee8edf47d997ad6d5d8d03c9a5e9b411bc17f4d9cb`;
retrieved gz sha256
`98ed87003b8c179efa5c547a6dd45f8ee46893ad67c709285ca8cbcb81d2283a`
(610,988 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.138 section begins at output line
30,309 — exactly one past 4.137's total line count,
and the first 30,308 lines are byte-identical to
hef137.out (verified with cmp both on-device and on
the VM at closing), the base having reproduced
line-for-line. The section alone is 919 lines /
173,106 B, sha256
`63bf21785bbc6d83c99c1cb34dfa06cb6cb701b76deb8731d0c944d91813148c`.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared 114×251 acts 168; class-271 acts 30; rigid
context set 271; great group (20, 32720) pairs 216;
gap between-tuple counts 34 / 30 / 87 for gaps 0 / 1 / 2;
contexts indexed 1,504.

## (i) The two wed redundancies certified directly; the maximal key wed to BOTH companions

The maximal compound joint key is (position-0 act,
loose distances (d0, d1), loose order, gap-0 tuple,
gap-1 tuple), as established in AES-NUM-136 (86
distinct, 15 repeating over the 271 contexts).

- Context length as a function of the maximal key:
  CERTIFIED — 86 distinct keys, 15 repeating, 0
  violating keys. Every maximal-key family carries
  exactly one context length (each repeating key is
  printed in full with its single length value).
- Gap-2 left position as a function of the maximal
  key: CERTIFIED — 86 distinct keys, 15 repeating, 0
  violating keys. Every maximal-key family carries
  exactly one left position.
- Maximal key wed to BOTH companions together
  (context length AND gap-2 left position): 86
  distinct joint keys, 15 repeating — the double wed
  adds NO distinct key over the maximal key alone,
  exactly as the two certifications require.
  Position-1 is NOT a function of the doubly-wed key
  (2 violating keys), position-2 is NOT a function of
  it (3 violating), and the whole gap-2 tuple is NOT
  a function of it (the same 3 violating keys).
- The violating keys under the double wed are exactly
  the maximal key's violating keys with both wed
  values appended: the (33312256, 328, 0) key at
  distances (1, 3) carrying length 245 and left
  position 220 (2 alternatives at each position; the
  rare alternative at position-1 stands in exactly 1
  of its 22 contexts); the (976502784, 328, 0) key at
  (1, 3) carrying 873 and 848 (2 and 2, its two
  contexts carrying different fills); the
  (1255547392, 328, 0) key at (2, 9) carrying 606 and
  581, violating only at position-2 / the whole tuple
  with 3 alternatives differing only at position-2.

The chain's last two contextual companions are now
proven redundant, not merely observed constant: no
companion tested — distances, order, either sister,
both sisters, length, left position, or both together
— repairs the chain. What varies the fill inside a
maximal family is NOT PROVEN.

## (ii) The shift anatomy's long runs, large-shift tail, and shift class by band

The exception is (791774208, 328, 0), at 5ab3537d
cidx 86 position 725 and cidx 210 position 727 (689
shared acts, every shared act single-positioned in
both contexts — reproduced exactly).

- Primary runs of length ≥ 20: exactly 8 of the 118
  primary runs, every act of each printed in full
  (act, A-position, B-position, shift): run 7 — 158
  acts at +2 over A 26–183; run 116 — 50 at +2 over
  683–732; run 71 — 41 at +3 over 457–497; run 33 —
  37 at +2 over 305–341; run 88 — 34 at 0 over
  581–614; run 24 — 29 at 0 over 242–270; run 83 —
  25 at 0 over 524–548; run 11 — 20 at −2 over
  192–211 (the only negative long run). Together the
  8 long runs carry 394 of the 689 shared acts
  (derived at closing).
- The |shift| ≥ 100 tail: 69 acts printed in full,
  over 40 distinct shift values (derived at closing:
  38 acts at positive shifts, 31 at negative; the
  extremes −455 and +434 occur once and twice; the
  heaviest tail values are −393 ×4, +432 ×4, −391
  ×3, −238 ×3, +234 ×3, +240 ×3, +241 ×3).
- Shift class by A-position band of width 50 (bands
  0–49 through 750–799, the last empty — no shared
  act has A-position ≥ 750; band counts sum to
  exactly 689): totals ≤−10: 44, −9..−1: 53, zero:
  126, +1..+9: 395, ≥+10: 71. Whole bands are pure:
  50–99 and 100–149 carry only +1..+9 (50 acts each);
  550–599 carries only zero (43 acts — the solid
  same-position stretch that contains the 581–614
  block's start); 700–749 carries only +1..+9 (41).
  The large-shift classes concentrate mid-context:
  bands 350–449 hold 31 of the 71 ≥+10 acts and 19
  of the 44 ≤−10 acts (derived at closing), and the
  200–249 band is the negative heartland (26 of its
  44 acts at −9..−1, none at +1..+9).

## (iii) B byte 0 against the six two-byte sub-keys wed to the group; the 13 agreeing repeats' status company

Wed key = (group, two-byte value), over the full 224
pairs. Every repeated wed value is printed in full
with its pairs.

- (byte 0, byte 1): 216 distinct wed values, 8
  repeating — 3 agreeing, 5 violating.
- (byte 0, byte 2): 215 distinct, 8 repeating — 1
  agreeing, 7 violating.
- (byte 0, byte 3): 176 distinct, 34 repeating — 7
  agreeing, 27 violating (heaviest wed value the
  great-group (128, 187), 6 pairs, B set {0, 128}).
- (byte 1, byte 2): 221 distinct, 3 repeating — 0
  agreeing, 3 violating.
- (byte 1, byte 3): 218 distinct, 4 repeating — 0
  agreeing, 4 violating.
- (byte 2, byte 3): 221 distinct, 3 repeating — 0
  agreeing, 3 violating.
- Totals (derived at closing): 60 repeating wed
  values, 11 agreeing and 49 violating — every key
  still HAS VIOLATING REPEATS, so B byte 0 is NOT a
  function of any (group, two-byte) wed key. The wed
  splits exactly the cross-group unwed repeats
  (AES-NUM-137: 63 repeating, 13 agreeing, 50
  violating): the unwed (20, 1) repeat (3 pairs across
  the two small groups) survives as a wed repeat only
  inside (19, 7712) (2 pairs), its (14, 9992) pair
  becoming a wed singleton, and likewise (68, 1) and
  the cross-group agreeing (20, 128).
- Wed agreeing repeats live only under the three
  byte-0 keys, and 10 of the 11 are great-group
  internal; the one small-group wed repeat is
  ((19, 7712), (20, 1)).
- The 13 agreeing full-population repeats of
  AES-NUM-137, re-read with status company: 27 pairs
  counted with multiplicity across keys — 19 SAME,
  8 DIFF. Nine repeats are purely SAME (every
  (byte 0, byte 1) agreeing repeat, including the
  cross-group (20, 1) with 3 pairs and (68, 1) with
  2; the (byte 0, byte 3) repeats (0, 184), (0, 186),
  (128, 184), (128, 210) and the cross-group
  (20, 128)). Four repeats are purely DIFF, all
  great-group, all under byte-0 keys, and in each
  both pairs share one nonzero diff: (byte 0,
  byte 2) = (0, 87) → B 128, diff +128 on both;
  (byte 0, byte 3) = (128, 222) → B 0, diff −128 on
  both; (64, 235) → B 160, diff +96 on both;
  (96, 245) → B 160, diff +64 on both. No agreeing
  repeat mixes SAME and DIFF pairs.

Mechanisms NOT PROVEN.

## Next

Slice 4.139 — the doubly-wed violating families
against the loose acts' own positions (L0 / L1 / R0
positions as further companions); the long-run
boundaries (the acts flanking each ≥20 run, and the
run-boundary shift changes), with the tail acts
cross-tabbed by band; B byte 0 against the four
three-byte sub-keys wed to the group over the full
224 pairs, with the 11 wed agreeing repeats' status
company. Host/artifact analysis only.
