# A-116 - First-divergence localisation

**Machine:** purpleraider (ASUS ROG Flow Z13, Ryzen AI Max+ 395, Radeon 8060S gfx1151, XDNA 2, 128 GB unified LPDDR5X)
**Base:** 57f2e2da (banked main, 114 of 216, A-114 closure)
**Gate question (roadmap):** "Tooling that, given a failing row, finds the first layer/op where outputs separate. Acceptance: demonstrated on a seeded divergence; used in anger at least once in Wave 14 or the slice re-opens."

## The localiser

`aesir_engine/core/divergence_localiser.mojo` is the ONE encoding of
the first-divergence walk. Before this slice the tree could grade a
row (A-111's near-tie gate), refuse a fake one (A-112's
comparator-artifact checklist), and lay the filed rows out as a
matrix (A-114) -- but when a row filed DIVERGENT, the next question
had no tool: WHICH layer, WHICH op, first separated?

- The caller states A-112's comparison account unchanged (exact
  prompt bytes, both sides' BOS handling, both backend names, the
  row's per-step teacher-forcing rank + logit gap in milli-logits)
  plus the probe records: one probe per checkpoint in execution
  order, each carrying layer index, op name, and the teacher-forcing
  rank + logit gap graded at that checkpoint. Probes are stated
  records; the localiser executes nothing.
- The rule is pre-registered in the module header (L1-L6):
  - L1: every probe and row record is validated by A-111's gate
    (`validate_step_record` / `step_class`); an inconsistent record,
    an empty probe list, an empty or negative-layer probe, a
    duplicate (layer, op) probe, or decreasing layer order is
    REFUSED, not localised.
  - L2: A-112's checklist runs over the row account BEFORE any probe
    is read for a location. Any hit files COMPARATOR_ARTIFACT with
    the kind named by K1-K4 precedence and NO location (first_index
    / first_layer stay -1): template rendering, BOS rendering,
    backend mismatch, and step-0 boundary effects each fake
    divergences that are in neither engine's maths. Probe class
    counts are still computed, so the filing shows what the invalid
    comparison would have hidden.
  - L3: a stated row with no records files NOT_GRADED.
  - L4: a clean row with no divergent record files NO_DIVERGENCE.
  - L5: a clean, divergent row is localised by the scan: probes are
    classified by A-111's `step_class` in execution order (EXACT and
    NEAR_TIE are faithful -- a near-tie probe never localises; the
    band's BOTH conjuncts bind, so rank 2 with a full-logit gap and
    rank 3 with a sub-logit gap are each divergent); the FIRST
    DIVERGENT probe files LOCALISED with its index, layer, op, rank
    and gap as witness. Later divergent probes are counted, never
    reported as the location.
  - L6: a clean, divergent row whose probes are all faithful files
    NO_DIVERGENCE with the probe counts as witness: the stated
    checkpoints do not cover the separating op, and the honest
    filing says so instead of naming a wrong layer.

## Evidence

- Module: `aesir_engine/core/divergence_localiser.mojo` (20,122 B,
  sha256 62087f8ef6bac6530a156868fcf1809ef4e1554c7d0d0d9ccc9f06bfb9b8d0cb).
- Tests: 12 cases `oracle.localise_*` in
  `tests/test_divergence_localiser_a116.mojo` (13,870 B, sha256
  3de9b9aa46e947d4855c4ad3428644f5afa40a4bf1dd67d4eb07bb869e321be6),
  all PASS: constants/names, identical row, near-tie probes faithful,
  first divergence at layer 0, mid-stack first-exact, the seeded
  trace exact, band edges (rank 2 / gap 1000 divergent, rank 3 /
  gap 10 divergent, rank 2 / gap 999 faithful), artifact blocking
  for template / backend / step-0 accounts, deterministic digest,
  invalid traces refused.
- Seeded demonstration (the roadmap acceptance; driver
  `tests/bench_localise_a116.mojo`, 1,615 B, sha256
  27f656b5969b00e6ef83be09152acd4dfda350b32b752a0ef61d480f61a00a5c;
  `hidden_files/a116_seeded_demo.log`, MOJO_EXIT=0, on this Z13):
  the canonical trace is 12 layers x the four per-layer ops
  (attn.q_proj, attn.out_proj, mlp.up_proj, mlp.down_proj) plus the
  final lm_head probe = 49 probes; every probe before the seed is
  exact or near-tie (a near-tie every fifth probe, proving the band
  is respected, not just the exact case); the seed sits at layer 7,
  mlp.down_proj, probe index 31, rank 3 / gap 1450 milli-logits, and
  every later probe is divergent. Filed verdict:
  `A116_VERDICT verdict=LOCALISED kind=NONE first_index=31
  first_layer=7 first_op=mlp.down_proj exact=25 near_tie=6
  divergent=18`, digest 5253384345653559561,
  `A116_BENCH_DONE localised layer= 7 op= mlp.down_proj index= 31`.
  The seeded row account is clean under A-112 (RAW prompt, BOS on
  both sides, CPU vs CPU, divergence past step 0).
- Suite: E-MASTER solo run, `hidden_files/a116_run_all.log`:
  736 passed / 1 failed / 2 skipped / 739 total = baseline
  724 / 1 / 2 / 727 + 12 new cases, all 12 oracle.localise_* PASS.
  Sole failure is the pre-existing J-022
  `gguf.tensor_directory_interface`; skips are the 2 pre-declared.
  GREEN-TO-BASELINE. run_all finish pin 727 -> 739.

## Honest scope

- CARRIED CONDITION (the roadmap's own words): the acceptance also
  requires the tool be "used in anger at least once in Wave 14 or
  the slice re-opens". That use cannot happen inside Wave 13; it is
  carried, named, exactly as the roadmap states it, in
  `hidden_files/A116_LEDGER.md`, and the first Wave 14 divergence
  investigation owes this tool its first real filing. This slice
  does NOT claim the condition met.
- A-115 (IQ coherence policy encoding, team-25) was building in
  parallel and had NOT banked at build time; this module takes no
  dependency on it. IQ rows stay graded on coherence, never
  token-exactness; when A-115 banks, its policy names how an IQ
  row's probes are filed, without changing this rule's shape. The
  matrix runner's DIVERGENT cells (A-114) are this tool's natural
  input queue: a divergent cell's row account plus per-checkpoint
  probes is exactly one `localise_divergence` call.
- The localiser executes no model and opens no device: it is pure
  arithmetic on stated records (teacher-forcing rank + logit gap on
  RAW prompts, CPU engine vs CPU comparator only, band applied by
  A-111's gate, artifacts verdicted by A-112's checklist). No speed
  and no accelerator execution is claimed.

## Capability Ledger

Section 26 entry Z13-P5-116 added; E-MASTER registered count
advanced 727 -> 739 on this team branch (the banking seat
reconciles the union if A-115 banks first).

## Verdict

GO - the seeded-divergence half of the acceptance is demonstrated
on the Z13 and the tool is filed for Wave 14 use; the "used in
anger" half is carried as the roadmap's re-open condition, not
claimed. Keeper banks A-116 after A-115 in roadmap order.
