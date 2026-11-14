# Aesir Qwen35 Adapter Campaign — MAP

Opened 2026-11-14 on Volmarr's word in chat: "yes make the adopter for
that kind" — the adapter for the `qwen35` hybrid architecture, so the
27B heretic can load, generate, and serve on Aesir.

## Seat and rules

- Worktree: `/home/volmarr/aesir-hipserve`, branch **`yrsa/hip-serve`
  only — never push to main.** Bank every slice: commit, push with
  explicit refspec `HEAD:refs/heads/yrsa/hip-serve`, verify with
  `git ls-remote` that the remote branch moved.
- This folder (`hidden_files/qwen35-adapter/`) is the campaign's home:
  this MAP + `LEDGER.md` (running record, updated in the same session
  as the work it describes).
- Method: Mythic Engineering — coordinated crews, per-worker worktrees
  for parallel writers, bank incrementally with remote verification,
  capture durable lessons in the ledger.

## Target

- File: `/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-
  Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf`, 28,596,003,296 B.
- SHA-256 **verified on-device 2026-11-14** (full):
  `1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e`
  — matches the gate doc's `1fca6eef…186f08e`. This is the exact file
  the 27B gate examined.
- Architecture `qwen35`: 64 blocks, hidden 5120, FFN 17408, 24 heads /
  4 KV heads, head dim 256, context 262,144. HYBRID: 48 recurrent
  Gated-DeltaNet (SSM) layers + 16 full-attention layers (interval 4);
  partial rotary (64 of 256). Real delta-net geometry: q/k = 16 groups
  × 128 state = 2048 each, v = 48 time-step-rank heads × 128 = 6144 =
  ssm.inner_size; qkv width = 10240 (full census in the plan).

## Ground truth (read before believing any summary)

- `hidden_files/hip-serve/QWEN35_PLAN.md` — the verified recon + slice
  plan, banked at a8215e29. **This campaign executes that plan.**
- `hidden_files/hip-serve/GATE_AND_27B_RESULTS.md` — the 27B gate
  verdict (NOT RUNNABLE today) + full-suite gate: 901/905, the only
  failures the two proven pre-existing ones
  (`gguf.tensor_directory_interface`, `gpu.hip_q4k_gemv_no_leak`).
- `hidden_files/hip-serve/inspect-27b.log` — `aesir inspect` refusal:
  UNSUPPORTED, "No architecture adapter is registered."

## Slices (from the adopted plan; each banked on this branch)

- **Q35-1 — Loader truth.** Fix `_validate_qwen35_tensors`
  (aesir_engine/loader/gguf.mojo) formulas to the real layout; settle
  validator type enforcement by test. Proof: engine loader accepts the
  real 27B (probe reaches tensor materialization); a new small
  synthetic qwen35 fixture with correct SSM geometry loads; a mutated
  fixture (wrong qkv width) is rejected.
- **Q35-2 — Registry + profile + inspect.** qwen35 branch in
  `ModelArchitectureRegistry.classify()`, `core/qwen35_profile.mojo`,
  `inspect()` dispatch, `qwen35_memory_plan`; Q8_0 admitted. Proof:
  `aesir inspect` on the real file returns READY/COMPATIBLE with
  tensor_validation passed and a sane footprint.
- **Q35-3 — CPU forward correctness.** Repair delta-net geometry in
  `core/inference.mojo` + `aesir.mojo` (qkv split, conv width,
  v-head recurrence with q/k broadcast, per-v-head ssm_a/dt/beta,
  state sizing). Proof: (a) synthetic fixture load/forward/greedy +
  per-token vs batched state equality; (b) real 27B on CPU graded
  against a CPU comparator (llama.cpp, same file) by teacher-forcing
  rank + logit gap on RAW prompts; near-tie band rank ≤2, sub-logit
  gap = faithful.
- **Q35-4 — Serve session (CPU first).** Qwen35 session over the
  engine-core path; runtime_plan admission (api=cpu), native_serve
  dispatch. Proof: serve fixture then real 27B on a side port;
  two-turn chat end to end; honest capabilities (residency true,
  prefix reuse per Q35-5, anchor/injection true).
- **Q35-5 — Residency + prefix snapshots.** Snapshot/restore of
  Qwen35State (recurrence + conv rings) at token boundaries; reuse =
  KV prefix + SSM snapshot at the same boundary, or no reuse. Proof:
  state-equality test; HS-3-style two-turn bench; diverged-history
  case reuses only the shared head.
- **Q35-6 — HIP execution.** (a) projections via the existing Q8_0
  HIP GEMV (+ measured prefill strategy); (b) full-attention layers
  on device with partial rotary; (c) delta-net recurrence + conv1d
  device kernels, state resident on device, proven equal to the CPU
  state trajectory. Honest hybrid fallback only if measured faster
  than CPU serve and labelled as such. Proof: HIP serve of the real
  27B, rank/gap agreement vs CPU path, two-turn bench, tok/s with
  contention noted.
- **Q35-7 — Gate swap + close.** At a quiet moment swap aesir-gate to
  the 27B on :18434 (llama3-3b stays the documented fallback in
  VOXTA_SWITCHOVER.md); verify health + completion + two-turn chat;
  full matrix fenced; QWEN35_RESULTS.md filed.

## Hard unknowns (from the plan; what settles each is in the plan)

U1 recurrence semantics beyond layout (settled by Q35-3 oracle
grading) · U2 validator type enforcement (Q35-1 probe) · U3 CPU-serve
memory vs fences (named exception or proof-only) · U4 Q8_0 prefill
throughput on HIP (Q35-6 measures) · U5 Seer pool sizing for a
64-layer F16 model (Q35-3 load probe).

## Safety fences (this box OOM-crashed repeatedly on 2026-11-14)

- Check MemAvailable before EVERY heavy run. At campaign start:
  ~27 GB available; aesir-gate (llama3-3b on HIP, :18434), Ollama and
  Voxta are LIVE for Volmarr's own testing.
- Heavy runs fenced via systemd-run (MemoryHigh=24G/MemoryMax=32G),
  ONE heavy run at a time, subsets over full suites while memory is
  tight. The Q35-3 CPU real-file proof (F16 materialization ~57 GB)
  needs its own explicitly-sized unit, recorded in the ledger when
  used — never a silently dropped fence.
- NEVER kill, stop, or restart aesir-gate, Ollama, or Voxta. If a
  proof needs the 27B resident and it cannot fit beside what is live,
  STOP that step and report the blocker — never evict.
- The HIP device context claims the whole graphics pool while a
  session lives; every load plan accounts for that.
- Forge pause-lines stand: no main pushes, no public publishing, no
  data destruction, no cost, no sending as Volmarr, no weakening
  security. Any bug found is fixed in scope or recorded in the ledger
  as named next work — never silently left.

## Milestones (report as they land)

1. QA-0 plan banked (this MAP + ledger) · 2. first proven load of the
27B file · 3. first coherent CPU generation · 4. recurrent session
proven across two turns · 5. HIP execution live · 6. serve bench
numbers · 7. any genuine blocker, the moment it is proven.
