# The 26 sparse OTHER ff offsets are mostly per-network-group forms (constant in each ng, or the within-ng index in one ng and constant in the other), the camp middles cut into 16-byte units share only units 1–4 verbatim, and a distinguished first's pair is not a function of the consensus pair under any tested key (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.93 (AES-NUM-093).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef93.py
(sha256 a9438c708482d22be243f0ec9d52437d2db4254731dd1941e984f531a32a59e7...)
landed via one-shot proxy-receiver transfer (gz sha256
0faee9ea666906bdc84e878d39d5dbc6e51662e7bf059f35eae287e0bb257a9f...
returned by the receiver, matching; script sha verified
on-device), plus the labelled follow-up hef93b.py
(sha256 040ad04e2ba62511bf59fe83a00636cde6da5884f9352088ebc9184dcf1558c7...,
gz sha256 ab5a3a4a6864bff02fde7d8ea81ec2cd7c298fa715de734557157d2bed0151e4...,
same transfer pattern). Outputs: /tmp/hef93_out.txt
sha256 48eade8ee31c8ef4b74fcd4d053735a79dd3862f76528b02fbb96f7d2673d0c0...,
/tmp/hef93b_out.txt sha256
390dd8f1ae22a80a69cda895e6ac719fbf83fd475961bf8de1672c234ac43c25....
Controls reproduce AES-NUM-029/032...092 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215), and the scanner
re-derives AES-NUM-090/091 exactly (in-band 374
groups, OTHER 4 all STEP; band X 60 / 3,335, OTHER 0;
band Y 27 / 354, OTHER 0; S1 OTHER 16, S2b OTHER 10,
all non-step). Trains reproduce exactly (52 trains;
unique-first 28, unanimous 13, elsewhere 11;
D(cidx 113) = 249; firsts' D-positions 3,089;
control-arm D-positions 176). Definitions (ff scan,
trains, D metric, camps) are as in AES-NUM-086...092.
Contract: docs/TASK_CONTRACT_4.93.md (published
@ 965a1389, before implementation).

## (i) ff OTHER form hunt: no pooled index form covers the 26, but per-network-group forms cover 19 exactly; the residue is 4 near-NGIDX offsets with one deviation each, one value-at-one-instance offset, and 2 uninformative pairs

Pooled forms (hef93, exact on every instance):
affine in cidx passes on 3 offsets, affine in ngidx
on 1, affine in subgroup index (gidx) on 3, plain /
mod-256 arithmetic progression in cidx order on 7 —
but every one of those passes is on a group of
n = 2 instances, where two points fit such forms
near-vacuously; they are recorded, not credited.
No group lies in a single train (train-rank forms
untestable everywhere: instances span several or no
trains). The minority-value predicates separate the
odd instance in 17 two-valued offsets, in most cases
simply because the minority instance is the group's
only member of its network group — which is the
per-ng structure below, not a mechanism.

Per-ng forms (hef93b, exact on every instance of
every ng present in the group):

- per-ng CONST (value constant within each ng,
  constants may differ between ngs): 14 of 26
  offsets — including every well-populated case
  whose pooled form failed this way (0856a10c
  pos 9 / 15488: {ng0: 3, ng1: 11}, n = 7;
  0a0d378c pos 20 / 13664: {0: 45, 1: 15} and
  / 17344: {0: 0, 1: 1}, n = 7 each; the sister
  position-21 offsets 11136 and 20300 in both
  5ab3537d and 773470cd: {0: 5, 1: 1} and
  {0: 5, 1: 15}, n = 10 each).
- mixed per-ng (NGIDX in one ng, CONST in the
  other): 0856a10c pos 10 / 15488 (n = 18: ng0
  values are exactly the within-ng index
  9, 12, ..., 39; ng1 is constant 11 over 9
  instances), and the sister position-21 offsets
  17272 and 32192 in both sisters (n = 10: ng0
  values exactly the index 1, 4, ..., 25; the
  single ng1 instance carries 15 resp. 11).
- Combined per-ng coverage (each ng either CONST
  or NGIDX, exact): 19 of 26 offsets.

The 7 residual offsets:

- 4 are NGIDX with exactly ONE deviating instance:
  0a0d378c pos 21 / 15128 (ngidx 1 carries 3, the
  other two instances match the index), 0a0d378c
  pos 13 / 25552 (17 instances, only ngidx 3
  carries 15 instead of 3), 5ab3537d pos 8 /
  31848 (ngidx 90 carries 0), 773470cd pos 14 /
  29184 (n = 2, ngidx 122 carries 0).
- 773470cd pos 15 / 29184 (n = 5, the same offset
  as its sister's pos-15 group): the value equals
  the within-ng index at exactly one instance
  (ngidx 38 -> 38) and is 0 at the other four.
- 2 are single-ng pairs of n = 2 with no tested
  form (MiniLM pos 23 / 9272: values 127, 0;
  0856a10c pos 16 / 28136: values 15, 6) —
  uninformative at this population size.

Verdict: MEASURED — the ff vocabulary grows from
{CONST, NGIDX, the 4 step offsets} to include
per-ng CONST and the mixed per-ng CONST/NGIDX
form, covering 19 of the 26 sparse OTHER offsets
exactly; the remaining 7 are characterised above
(4 one-deviation near-NGIDX, 1 index-at-one-
instance, 2 uninformative pairs). What any of
these forms MEAN — why a word is constant per
network group, or index-like in one group only —
is NOT PROVEN. No within-train form exists to
test: no OTHER group lies in one train.

## (ii) Middle 16-byte units: the middles share exactly units 1–4 verbatim; the mismatch crowd lives in units 7–10; no unit repeats at any lag

Rank 2 consensus middles (as in AES-NUM-092, the
mismatch list is rank-invariant; the middles
themselves are not byte-identical across ranks,
in 092 as here), A 168 B / B 232 B, cut into 16 B
units from the middle start (A: 10 full units +
8 B tail; B: 14 full units + 8 B tail; all unit
bytes are printed in full in the run output):

- A has 11 distinct units (every unit distinct),
  B has 14 distinct of 15; exactly 4 distinct units
  are shared: A units 1–4 equal B units 1–4 byte
  for byte at the same index. No other A unit
  appears anywhere in B, and no other B unit
  appears anywhere in A.
- Under the k = 111 alignment of AES-NUM-092 the
  21 mismatches fall per A unit as: unit 0: 1
  (position 0), units 1–4: 0, unit 5: 2, unit 6: 2,
  unit 7: 4, unit 8: 7 (byte-identity 0.5625),
  unit 9: 2, tail unit 10: 3 — the tail crowd of
  092 is units 7–10, with unit 8 the worst.
  Exactly 4 of A's 10 full units are exact at
  their aligned offset (units 1–4, the shared
  ones). The 8 B tails differ (A 010000800080000b,
  B 00000000008000a4).
- Unit-sequence repetition: at unit lags 1–9,
  A matches 0 units at every lag; B matches 0
  except a single unit at lag 5 (1/10). No lag
  is exact in either middle.

Verdict: MEASURED — at 16-byte granularity the
two middles are a common 4-unit block (units 1–4,
bytes 16–79) followed by unrelated material in
which the insertion-aligned mismatches crowd
into units 7–10. The 16-byte autocorrelation
rhythm of AES-NUM-092 is NOT a repetition of
16-byte units (no unit repeats at any lag in
either middle); what carries the rhythm is
NOT PROVEN.

## (iii) Firsts' pair-function test: a distinguished first's pair is not a function of the consensus pair under any tested key

Over the 3,089 D-positions of the 28 distinguished
firsts (own pair = the first's (size, channel) at
the position, consensus pair = the other members'):

- key (consensus pair): 178 keys, 123 multi-
  instance, 113 mixed — majority accuracy 0.2298.
- key (consensus pair, position): 2,560 keys,
  440 multi, 242 mixed — accuracy 0.9068.
- key (consensus pair, third): 334 keys, 252
  multi, 221 mixed — accuracy 0.2998.
- key (consensus pair, decile): 594 keys, 405
  multi, 349 mixed — accuracy 0.3788.
- key (consensus pair, train step S): 254 keys,
  178 multi, 161 mixed — accuracy 0.2648.
- key (consensus pair, artifact, ng): 331 keys,
  208 multi, 200 mixed — accuracy 0.2894.

No key reaches zero mixed keys; the finest key's
0.9068 accuracy is the uniqueness effect seen
before (2,560 keys over 3,089 positions), not a
law — its 440 multi-instance keys are mixed in
242 cases. Control arm contrast (176 D-positions):
(consensus pair) 54 keys / 22 multi / 20 mixed,
accuracy 0.5114; (consensus pair, position) 168
keys / only 5 multi / 3 mixed, accuracy 0.9830 —
the control population is too sparse at that key
to test anything.

Verdict: MEASURED — a distinguished first's
action at a distinguishing position is NOT
determined by the consensus action together
with position, position band, train step, or
artifact/network group, in any combination
tested. Where the choice is made remains
NOT PROVEN, consistent with AES-NUM-047...050's
pair-order negatives on the champion stream.

## Next (slice 4.94)

- Residual ff offsets: the 4 one-deviation
  near-NGIDX offsets — what distinguishes the
  deviating instance (position in its context,
  neighbouring words, its segment's other ff
  words); the index-at-one-instance offset
  (773470cd pos 15 / 29184) vs its sister twin.
- Middle units beyond rank 2: per-rank unit
  anatomy (which ranks share units 1–4; unit 8
  crowd across ranks) and the B-middle units
  5–14 vocabulary vs the A middle's tail.
- Per-ng ff forms at scale: does the per-ng
  CONST/NGIDX distinction classify any offsets
  inside the already-classified CONST/NGIDX
  population (i.e. are pooled CONST groups
  per-ng constants with equal constants)?
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts within the stated bands and floors; blob
identities are sha prefixes only. Every count,
occurrence, alignment and distribution above is
MEASURED as stated; every meaning — what the
per-ng forms encode, what carries the middle
rhythm, where a first's pair choice is made — is
NOT PROVEN and nothing here invents one.
