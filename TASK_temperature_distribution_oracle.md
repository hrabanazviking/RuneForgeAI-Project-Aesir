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

## Acceptance

Capture the existing CPU and CUDA-specific baseline formulas/source hashes;
publish interface and failure boundaries; compare CPU empirical frequencies to
an independently calculated small categorical oracle using deterministic seeds
and a predeclared tolerance. Include equal-logit, two-logit known-ratio, and
temperature monotonicity cases. If CUDA is runnable, add a separate seeded
physical test and record device/runtime identity; otherwise preserve the exact
failure. Run the pinned master suite, documentation checks, and release gate.
