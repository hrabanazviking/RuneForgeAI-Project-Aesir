# AES500-191 — temperature distribution oracle

## Objective and owners

Define correctness evidence for non-greedy temperature sampling. CPU owner:
`sample_token_from_logits` in `aesir_engine/core/sampler.mojo`. Native CUDA
owners: `sampling_merge` and `NativeCUDASampler.select` in
`aesir_engine/core/cuda_sampling.mojo`.

## Inputs and outputs

Inputs are finite logits, a positive vocabulary, positive finite temperature,
sampling filters/configuration, a seed, and a draw index. Output is one token ID
and, for CUDA, an updated draw counter. The intended unfiltered distribution is
softmax(logit / temperature); actual implementation ordering additionally
applies vocabulary admission, top-k, top-p, min-p, and repetition policy.

## Invariants and limits

- Raising temperature should flatten the unfiltered categorical distribution;
  lowering it should concentrate mass on higher logits.
- A fixed seed and draw index reproduce a CPU/CUDA-specific sample stream; do
  not claim CPU and CUDA PRNG parity.
- At positive temperature, a valid distribution over admitted tokens returns
  only an admitted ID; zero-temperature/greedy behavior is outside this task.
- This work does not claim probability-calibration, model-quality improvement,
  statistical validity for a full model, or parity with third-party libraries.
- Physical CUDA evidence may be unavailable because the local PTX JIT currently
  fails; synthetic CPU tests do not substitute for it.
- No runtime probability-vector API is added. CPU oracle evidence observes the
  existing `sample_token_from_logits` return IDs over a fixed deterministic seed
  range and compares frequencies to an independent analytic probability.

## Acceptance

Capture the existing CPU and CUDA-specific baseline formulas/source hashes;
publish interface and failure boundaries; compare CPU empirical frequencies to
an independently calculated small categorical oracle using deterministic seeds
and a predeclared tolerance. Include equal-logit, two-logit known-ratio, and
temperature monotonicity cases. If CUDA is runnable, add a separate seeded
physical test and record device/runtime identity; otherwise preserve the exact
failure. Run the pinned master suite, documentation checks, and release gate.


## Progress receipts

- AES500-192 baseline: formulas, hashes, and the physical CUDA PTX JIT failure
  are recorded in `docs/evidence/temperature-oracle-baseline-2026-10-10/README.md`.
- AES500-193 interface: core interface documents CPU filtering/temperature
  order and distinct CUDA PRNG/filter semantics.
- AES500-194 implementation: existing CPU behavior matches the selected
  softmax-temperature contract; no algorithm change was needed.
- AES500-195 unit evidence: 4,096 paired seeds produced lower-token mass
  0.12768555 vs 0.11920292 expected at T=0.5, and 0.2775879 vs 0.26894143
  expected at T=1.0. Both are within 0.025; higher T increases lower-token
  mass. Master suite 233/0/1 (234 total).
- AES500-196 integration: validated `GenerationConfig` feeds the CPU sampler;
  output remains within the admitted two-token vocabulary. CUDA stays unverified
  after PTX JIT failure.
- AES500-197 adversarial evidence: negative temperature rejects before use,
  extreme finite F16 logits select the maximum at low temperature, and NaN
  sanitization returns an in-range token. Master suite 235/0/1 (236 total).
- AES500-198 primary review confirms the oracle formulas, deterministic seed
  boundaries, engine-specific differences, and lack of calibration claims. An
  independent Auditor was unavailable at the service thread cap.
- AES500-199 syncs numeric vectors, tolerances, integration, runtime, and CUDA
  limitations across task, interface, roadmap, TODO, and devlog.
- AES500-200 release gate: pinned CI-targeted CLI build and binary help pass;
  master suite 235/0/1 (236 total); docs drift/tests and whitespace pass. Hosted
  workflow result is reported separately; no CUDA run or model claim is implied.
