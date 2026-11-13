# A-090 Ledger - HIP soak or instability verdict (team-20)

- Slice: A-090, Wave 10 closer. Acceptance (roadmap):
  one-hour decode soak on the HIP path if integrated; else
  the instability evidence is filed as the verdict - soak
  log OR verdict doc, one of the two, honestly.
- Base: 6396cd62 (banked main, 86 of 216, A-086 closure).
- Worktree: /home/volmarr/aesir-team-20, branch
  yrsa/aesir-team-20. Banks only in roadmap order after
  A-087/A-088/A-089, by the keeper at the seat. Never
  merge/push from this worktree.

## Verdict (one line)
HIP is NOT integrated (A-085/A-086 stand); no soak was run
or claimed; the instability evidence is filed as the
verdict in docs/bench/A090_HIP_INSTABILITY_VERDICT.md.

## Deliverable
- docs/bench/A090_HIP_INSTABILITY_VERDICT.md (8,190 bytes,
  sha256 474ac312b2a57dd7cd64ade25f75cd6c64b4d88d51bfa
  b535f7d55b56594b1c4) - the verdict doc (doc-only slice).

## Evidence trail (all read back from banked sources)
- A-085 verdict + numbers (hidden_files/A085_LEDGER.md,
  docs/bench/A085_BAKEOFF.md): Vulkan PRIMARY, HIP PARKED
  probe-only. Bake-off Q4_K per-call medians HIP 5.20 /
  1.76 / 2.89 / 3.69 / 6.92 ms vs Vulkan 0.237 / 0.175 /
  0.382 / 0.429 / 0.454 ms; bandwidth at large shape HIP
  ~0.34 GB/s vs Vulkan ~20.8 GB/s (verify ~0.31 vs ~18.6);
  gap is context setup, not silicon. Four re-open
  criteria set; at this filing NONE met (see verdict doc).
- A-082 ledger (hidden_files/A082_LEDGER.md): HIP Q8_0
  GEMV per-call 16.93 / 13.41 / 13.22 ms (flat ~13-17 ms
  fresh-context floor); resident loop 1.02 ms at
  512x4096; SharedSignalPool leak 5,874 signals in bench.
- A-083 ledger + probes (hidden_files/A083_LEDGER.md,
  a083_retention_probe.log, a083_attr_probe.log): HIP
  Q4_K GEMV per-call medians 7.14 / 2.01 / 2.99 / 3.87 /
  6.99 ms; every buffer-bearing MAX DeviceContext
  retains exactly 8,388,608 B (8 MiB) of GTT until
  process exit, unbounded per-context (free GTT fell
  exactly 10 x 8 MiB per 10 calls across 120 calls, no
  plateau); attribution: bare buffer+copy and vec_add
  contexts each retain 10 x 8 MiB per 10 after the first
  kernel context pins the arena - MAX DeviceContext
  buffer-pool behaviour, pre-existing, shared with the
  A-029 MojoNative path, NOT an A-083 operand leak;
  SharedSignalPool leaks 1,335 (bench) / 1,780
  (retention probe).
- A-081 soak contrast (hidden_files/A081_LEDGER.md):
  Vulkan carries the stability evidence HIP lacks -
  A-077 one-hour soak 4,590 steps in 3,600 s, 0 errors
  (per the A-081 gate filing), A-078 GPU fuzz 0 real
  divergences, A-079 device-lost recovery, A-080
  equivalence gate. HIP: no soak, no fuzz, no recovery
  evidence at all.
- HIP coverage (A-085): exactly two kernels - Q8_0 GEMV
  (A-082) and Q4_K GEMV (A-083), both naive/untuned. No
  HIP RMSNorm, RoPE, attention, full layer or prefill;
  the decode loop of record (A-066) is Vulkan. There is
  no HIP decode loop to soak.
- A-086 registry state (hidden_files/A086_LEDGER.md,
  core/backend_registry.mojo): the A-085 verdict is
  banked into the live registry - Vulkan first-class,
  HIP probe-only.
- Intermittents/crash class on file: gpu.amd_hip_stream
  _async_round_trip is a known pre-existing intermittent
  (A-072/A-075/A-076/A-078 ledgers); the A-019 comgr-heap
  finding and the 2026-11-12 seat crash artifact belong
  to the HIP-road lifecycle fragility family (filed in
  docs/AESIR_Z13_PART_I_EVIDENCE.md item 9).

## Suite result (E-MASTER, this worktree, solo)
- Run: hidden_files/run_a090_suite.sh, log
  hidden_files/a090_run_all.log (sha256 629f4c726f3453
  f02a8d72d503c8ecd3d90b41e147b9cab240df73ae3082a2c5).
  Launched detached after ps-verifying no other suite
  or gate was live; counts read from the log SUMMARY.
- Result: 597 passed / 1 failed / 2 skipped / 600 total
  = exactly the base baseline (seat gate A-086). Sole
  failure: gguf.tensor_directory_interface, the
  pre-existing J-022 drift, unchanged. Skips: the 2
  pre-declared. None of the known intermittents
  (resilience.state_vault_rejects_growth, gpu.amd_hip_
  stream_async_round_trip, gguf.weight_residency_gpu_
  visibility) appeared. Doc-only slice: +0 cases, pin
  stays 600. MOJO_EXIT=1 is the J-022 failure alone.

## Bugs / next work
- None discovered in engine code in scope. The defects
  filed are upstream MAX/ROCm runtime lifecycle
  behaviours already recorded by A-082/A-083/A-085.
- Standing next work (carried from A-083/A-085):
  persistent-context HIP launcher (<0.5 ms median per
  call at 64x1024 Q4_K) or a MAX pool cap for the 8 MiB
  per-context GTT retention - re-open criterion 1/2.
  HIP stays probe-only until all four A-085 re-open
  criteria are met and a fresh bake-off is run.
