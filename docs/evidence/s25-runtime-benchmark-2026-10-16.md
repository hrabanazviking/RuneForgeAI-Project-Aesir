# S25 bounded native runtime baseline — 2026-10-16

The retained [machine-readable run](s25-gemma4-e2b-rtx4070-2026-10-16.json)
has `status: passed`: two supervised process launches followed by one warmup
and five measured streamed requests for each of two fixed public prompts.
`scripts/validate_runtime_baseline_v1.py` independently recomputed the summary
from all 12 raw samples and accepted the fixed public prompt hashes, identity,
completeness and memory
fields. This is one physical run, not a cross-machine performance claim.

- Host: WSL2 x86_64; NVIDIA GeForce RTX 4070 Laptop GPU, driver 610.88,
  reported total 8188 MiB. The resident service reported CUDA with no CPU
  offload, context 512, and a 24-token output ceiling.
- Model: `gemma4-e2b:latest`, catalog and post-run blob SHA-256
  `740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8`.
  Native binary SHA-256:
  `e11ea802a0ff82a3c91f2cae7c813dd747c51025fd0baea63bffa4f5e981996e`.
- First/repeat process readiness: 36.426/37.605 s. These are two fresh
  processes, **not** verified cold/warm host, filesystem-cache or driver states.
- Arithmetic prompt (41 tokens; each reply one token): request wall p50/p95
  2.137/2.142 s, first visible text p50 2.088 s, prefill median 20.21
  prompt tokens/s. Its one-token decode throughput is not a useful sustained
  decoding estimate.
- Long prompt (247 tokens; each reply 24 tokens): request wall p50/p95
  14.041/14.043 s, first visible text p50 12.593 s, prefill median 19.71
  prompt tokens/s, decode median 15.90 generated tokens/s.
- Process VmHWM: 4,619,064/4,620,008 KiB. Sampled device-wide VRAM
  peaks: 3483/3485 MiB against 370 MiB before each launch. Per-process VRAM
  is `null` because NVIDIA process telemetry was unavailable under this WSL
  driver. Device-wide use may include unrelated GPU activity.

Run from the repository root with an explicit CUDA-targeted native binary:

```sh
python3 scripts/benchmark_runtime_v1.py --binary BUILD --model gemma4-e2b:latest --store .aesir/models --context 512 --max-tokens 24 --samples 5 --output NEW-REPORT.json
python3 scripts/validate_runtime_baseline_v1.py NEW-REPORT.json
```

The report records only fixed public prompts, decoded replies and timing data;
the temporary service key is excluded. First-text time is observed by the
loopback client, not the model's internal first-token event. Phase timers are
service wall time, not GPU kernel time. Periodic telemetry and host scheduling
can perturb results. A controlled cold/warm host experiment and attributable
per-process GPU-memory reading remain unverified; do not promote this baseline
into those claims.
