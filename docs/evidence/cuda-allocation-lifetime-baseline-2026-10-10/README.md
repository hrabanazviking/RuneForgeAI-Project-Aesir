# CUDA allocation lifetime baseline — 2026-10-10

AES500-022 ran the existing opt-in GPU-2 resource lifecycle test without source
changes. This is an observation of the current synchronized path and test
contract, not proof of asynchronous teardown safety or driver-level memory
return.

## Bound run

- Source revision: `42b41df862a939f9502dd102fa2aa30604f320e2`.
- Source: `aesir_engine/core/cuda_resources.mojo`, SHA-256
  `3d92296e00c79f26233005d26ef38e39f1b4c7f1c84abf9f65278e4f2edea9ab`.
- Test binary SHA-256:
  `29f6e4094a08e207b60577bf8c71f25c98502cebe9ccbc33b05d28fdf497aa3c`.
- Toolchain: Mojo 1.0.0 (`ed45d567`).
- Device: NVIDIA GeForce RTX 2060 with Max-Q Design, stable ID
  `cuda:max-id:0`.

## Observed baseline

The positive physical run returned 0. Two allocation sessions each created two
F16 allocations, performed three synchronized H2D/D2H rounds per allocation,
rejected zero-sized and over-budget requests without changing committed
accounting, and passed after the previous session left scope. Positive stdout
SHA-256 is `757dae3a233e086b4f8c870e1f53509f25527d506cb7535dd87b33c969ad4bd1`.

The deliberate negative control returned 1 at the injected last-transfer value
mismatch (`session 1, allocation 1, round 2`). This confirms that the selected
mismatch is detected; it is not a cleanup failure. Its stdout SHA-256 is
`20a0f591963dcf776f7382cad2a57afba6a629799930af5c0e91a20a3c85851d`.
Both full logs and the machine-local receipt remain outside Git; neither is
needed to reproduce the bounded public summary.

## What this does and does not establish

Current tests explicitly synchronize each transfer and then prove a second
resource session succeeds after lexical scope cleanup. Allocation reservations
are monotonic within a session and failed budget requests preserve counters.
They do not record per-allocation identity or release counts and cannot show
that wrapper destruction waits for outstanding asynchronous work. The public
API currently relies on MAX-managed reference-counted `Deinitable` buffer
lifetimes; no direct MAX teardown guarantee or driver-return behavior was
captured here. Those are open questions for the AES500-023 interface gate.

No leak-freedom, immediate allocator reuse, driver-memory return, crash recovery,
concurrent teardown or performance claim is made.
