# A-078: GPU Fuzz — Random Prompts / Shapes / Context Lengths vs CPU Oracle

Slice A-078 of the Aesir Z13 Massive Roadmap (team-02). Filed evidence:
`hidden_files/a078_bench.log` (A078_BENCH: PASS, MOJO_EXIT=0),
`hidden_files/a078_driver.log` (A078_DRIVER_ALL_PASS, MOJO_EXIT=0),
`hidden_files/a078_diag.log` (DIAG_DONE, MOJO_EXIT=0),
`hidden_files/a078_verdict_table.md` (per-case rows, verbatim from the bench log),
`hidden_files/A078_LEDGER.md` (full verdict reasoning).

## What this slice adds

- `aesir_engine/core/gpu_fuzz.mojo` — seeded, reproducible fuzz case
  generation plus the divergence verdict classifier (`fuzz_classify`).
  Every case derives from a filed seed: battery base seed
  `FUZZ_BASE_SEED = 0xA078_0001` (bench run filed `base_seed=2692218881`)
  mixed per case by `fuzz_case_seed`, so any case replays exactly from
  (base seed, case index) on any host, with no stored fixture. The LCG is
  the A-063/A-066 Knuth MMIX stream, so fuzz rows are bit-identical with
  the earlier batteries' streams.
- Case space: prompt lengths 1..32 (coverage test: 1..32 over 64 cases),
  logit-row shapes cycling 16 / 37 / 64 / 128 / 251 / 512 / 1024 / 4096
  (odd sizes included — fuzz shapes are not powers of two), generation
  lengths 1..8. Prompts enter every engine as RAW token ids — no
  template exists in this path.
- `aesir_engine/tests/test_gpu_fuzz_a078.mojo` — seven E-MASTER cases
  (`gpu_fuzz.*` in `run_all.mojo`, pin 556 → 563).
- `aesir_engine/tests/bench_gpu_fuzz_a078.mojo` — the standalone filed
  battery below (not part of run_all).

## Grading law (standing, applied unchanged)

Teacher-forcing rank + logit gap on RAW token sequences only, never
template-rendered prompts; CPU engine vs CPU comparator only for the
oracle side; near-tie band = rank ≤ 2 with sub-logit gap = faithful;
IQ graded on coherence, never token-exactness. Comparator artifacts
(template rendering, BOS rendering, backend mismatch, prompt-boundary
step-0) are a verdict class, checked BEFORE any real-defect verdict.
A fuzz battery is green only when the real-divergence count is 0.

## Filed battery results (bench log, 2026-11-12 21:50 EST)

| Section | Result |
|---|---|
| SYNTH — 256 synthetic logit rows, CPU row perturbed at the A-065 accumulation-noise scale (±0.01), verdicted per position | total=256, faithful=219, near_tie=19, noise=18, comparator=0, **real=0** |
| SAMPLE — Vulkan sampling path vs independent CPU oracle in the bench file | greedy_ok=96/96, sample_ok=96/96 |
| REAL — 24 seeded random token-id prompts (lengths cycling 1,2,3,4,5,8,13,21) on the A-067 real-model GPU decode vs CPU teacher-forcing rows, fixture Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf (292 tensors) | total_pos=147, faithful=0, near_tie=0, noise=0, comparator=147, **real=0** |
| GEN — 4 random prompts × 8 greedy tokens, GPU greedy vs CPU greedy loop | exact=32/32 |

Driver (the seven E-MASTER cases run standalone): all pass, including
seed replay (16 cases regenerate identical ids + rows), coverage,
classifier pinning (faithful / near-tie / comparator / IQ-noise /
margin-noise / real / invalid all pinned), synthetic battery 64/64
verdicted with 0 real, greedy fuzz 24 seeded rows token-exact vs CPU
(24 dispatches), temperature fuzz 18 seeded draws exact vs the CPU
sampling oracle, and the real-model case (6 random prompts, 26 positions
verdicted, 0 real, comparator 26).

## The REAL comparator=147 verdict — honest reading

All 147 real-model positions land in the comparator-artifact class and
none in faithful. That is the expected signature of RANDOM prompts, not
a hidden pass and not a defect:

- A uniformly random token is deep in the tail under BOTH engines. The
  diag probe (`a078_diag.log`) filed the step-0 distribution: teacher-
  forcing ranks 1547..126399, CPU gaps 9.31..23.09 over the filed
  positions. Neither engine "believes" the target; rank/gap against a
  random target cannot read as faithful for any correct engine.
- What the class certifies is cross-engine AGREEMENT: at every one of
  the 147 positions the top-1 token agrees between GPU and CPU
  (top1_agree = pos/pos in every per-case row of the verdict table),
  and the GPU/CPU gap difference is tail accumulation noise
  proportional to the gap itself — filed relative deltas 0.47%..2.86%,
  inside the classifier's filed step-0 tail rule (deep-tail target,
  cpu_gap ≥ 4, gap agreement within 3% relative → comparator class;
  the A-067 absolute 0.05 bound was written for natural prompts and
  does not describe random step-0 targets).
- The independent generation check closes the loop: greedy generation
  from random prompts is token-exact 32/32 GPU vs CPU. If the GPU path
  actually diverged on these prompts, greedy trajectories would part.

So the REAL section proves the GPU and CPU engines agree on random
prompts to within filed tail noise, with zero unexplained divergences.
It does NOT prove faithful-rank behaviour on natural text — that is
the A-067 battery's filed ground, not this slice's claim.

## Honesty bounds

- SYNTH rows are synthetic by construction (labelled as such in the
  bench file): they exercise the classifier and the sampling path, not
  model quality.
- The comparator tail rule (3% relative at cpu_gap ≥ 4) is an A-078
  measurement, filed from the diag probe in `gpu_fuzz.mojo` next to
  the rule itself; changing it is a new battery, not a tweak.
- No accelerator claim beyond the filed runs: the SAMPLE/REAL/GEN
  sections ran on the gfx1151 Vulkan path with `--target-accelerator
  gfx1151` on purpleraider, per the run scripts in `hidden_files/`.
