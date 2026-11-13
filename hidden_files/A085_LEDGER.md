# A-085 Ledger - The bake-off: HIP vs Vulkan (team-15)

- Slice: A-085, Wave 10 close. Acceptance (roadmap): verdict
  doc with numbers; one road declared primary, the other
  parked with written re-open criteria (never silently
  dropped).
- Base: 82591e7c (82 of 216 banked, A-082 closure), branch
  yrsa/aesir-team-15, worktree /home/volmarr/aesir-team-15.
  A-083 has since banked at the seat (de415271, 83 of 216);
  this branch predates A-083, so the HIP Q4_K bench/shim
  symbols exist only in the seat tree - the keeper composes
  the union at banking, as for A-083 (run_all 586 -> 589).
- Banks only after A-084, in roadmap order, by the keeper at
  the seat. Never merge/push from this worktree.

## Continuation note

The first team-15 lead was cancelled mid-work, leaving a
draft docs/bench/A085_BAKEOFF.md, the two stripped fresh
bench logs (08:06), and the muster CAMPAIGN_STATE.md. This
lead kept the draft's verdict and structure, audited every
number against the filed logs, corrected three defects in
the draft (below), and re-ran both benches with full
provenance before committing.

## Deliverable

- docs/bench/A085_BAKEOFF.md - the verdict doc (only code-
  tree deliverable; doc-only slice, +0 suite cases, run_all
  pin untouched). Verdict: Vulkan PRIMARY GPU road; HIP
  PARKED probe-only with 4 written re-open criteria.
- hidden_files/a085_hip_q4k_fresh.log (sha256 498f636d...)
  and a085_vulkan_q4k_fresh.log (697c3132...) - previous
  lead's paired fresh run, 2026-11-13 ~08:06 EST.
- hidden_files/a085_hip_q4k_verify.log (57197b6e...) and
  a085_vulkan_q4k_verify.log (bcf5c225...) - this lead's
  paired verify run, 2026-11-13 ~08:29 EST, built/run in
  the seat tree at de415271, BUILD_EXIT=0, RUN_EXIT=0, both
  PASS, full headers.
- hidden_files/run_a085_suite.sh + a085_run_all.log
  (a77705e9...) - suite evidence, below.

## Head-to-head evidence (Q4_K GEMV, per-call medians)

Fresh (08:06): Vulkan 0.237/0.175/0.382/0.429/0.454 ms vs
HIP 5.20/1.76/2.89/3.69/6.92 ms (shapes 1x256, 7x512,
64x1024, 33x2048, large 4096x4096 vs 1024x4096).
Verify (08:29): Vulkan 0.208/0.173/0.547/0.448/0.507 ms vs
HIP 5.399/1.841/3.079/3.617/7.699 ms. Same ordering/scale.
Bandwidth (large, fresh): Vulkan ~20.8 GB/s vs HIP
~0.34 GB/s per-call; verify ~18.6 vs ~0.31 GB/s.
Parity: on each road both runs reproduce that road's filed
errors bit-identically (Vulkan = A-057 filed; HIP = A-083
filed); both inside the filed band |err| <= 0.02*sqrt(K) +
0.02*|want| at every shape (worst 0.835 / 0.824 at K=4096
vs floor 1.28). Device identity asserted both roads
(Vulkan vendor 0x1002 RADV=1; HIP name=AMD Radeon 8060S
Graphics, dispatch counters +3/+5 per shape).

## Draft defects found and corrected (never hidden)

1. Draft claimed parity errors "identical" across roads.
   False: within-road fresh-vs-filed is bit-identical, but
   cross-road errors differ (1x256: HIP 0.07287598 vs
   Vulkan 0.0014190674) - different accumulation/rounding
   paths, both in band. Doc now states this precisely.
2. Draft claimed the fresh window was "machine idle (load
   0.19)". No log contains 0.19; the fresh logs' own uptime
   lines read 0.28/1.42/1.59 and 0.35/1.36/1.56. Corrected
   to "quieting, not idle".
3. Draft claimed filed Vulkan medians 0.19-0.42 ms with no
   outlier: the filed A-057 1x256 median is 2.99 ms under
   load 2.63/2.93/2.86. Now filed honestly. Draft also
   understated HIP context floor for Q8_0 as ~13-16 (filed
   per-call max 16.93) - now ~13-17 ms.

Also scoped explicitly: the verdict chooses the GPU road
only and does not disturb A-081 (CPU remains primary for
8B decode today). Coverage extended with filed A-063/
A-064/A-071/A-072; A-082 signal warning paired with the
A-083 bench's 1,335 (reproduced in the verify run).

## Suite evidence

Solo run in this worktree (team-14's A-084 suite had
finished; ps-verified no other suite/gate live; an earlier
launch at 08:30 was killed within seconds when team-14's
suite was seen running, and re-run solo at 08:34):
583 passed / 1 failed / 2 skipped / 586 total =
exactly the base baseline (seat gate A-082). Sole failure
= pre-existing gguf.tensor_directory_interface (J-022
drift, tolerated). Skips = the 2 pre-declared. Both known
intermittents (resilience.state_vault_rejects_growth,
gpu.amd_hip_stream_async_round_trip) PASSED this run.
MOJO_EXIT=1 is the J-022 failure alone.

## Bugs

None discovered in engine code in scope. The previous
lead's HIP staging failure (team-15 shim missing A-083
symbols) is a branch-age staging issue, documented in the
verdict doc; no engine change needed.
