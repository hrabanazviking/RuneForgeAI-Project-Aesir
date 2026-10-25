# Aligned grouped control backing — host qualification (2026-10-24)

Contract: `TASK_hailo10h_aligned_grouped_control.md` (published at be9db5d6).
Branch: `yrsa/finish-line-roadmap`. Scope: **host-only**. No physical child was
built, run, or authorized under this contract; the physical grouped lifecycle
retry remains a separate future one-shot contract (roadmap slice 1.4).

## What was built

The grouped control owner gained an explicit aligned backing path behind new
entry points. The logical wire is unchanged (20-byte header + 2048-byte padded
body = 2068 bytes). Physical USERPTR spans now start at descriptor-page-aligned
map offsets: header at offset 0, body at offset `page`, map extent
`page + 2048` (observed policy page 512 → body at 512, extent 2560).

- `hailbru/soc_storage.mojo` — typed `SocRpcLayout` (legacy `(0, 20, 2068)` and
  aligned `(page, page, page + 2048)`), admitted only when `page` is a
  power of two in [64, 32768]; refusal leaves storage untouched.
  `allocate_aligned` / `allocate` (legacy) share one sizing path driven by the
  admitted layout. `write_message` on an aligned storage clears the whole
  mapped extent, then scatters header at 0 and body at `body_offset`;
  `read_bytes` gathers the exact 2068-byte logical projection. Legacy
  write/read loops are byte-for-byte the original code paths.
- `hailbru/soc_session.mojo` — `allocate_rpc_storage_aligned()` opens the
  input storage with the session's descriptor page size; output stays legacy.
- `hailbru/soc_group_rpc.mojo` — `open_soc_group_rpc_aligned()` captures the
  admitted layout; `input_group()` places the body span at
  `input_address + body_offset`; `_owned()` re-verifies the layout for the
  client's whole life. Legacy `open_soc_group_rpc` defaults are unchanged.
- `hailbru/soc_group_device.mojo` — `run_group_device_aligned()` runs the same
  create(20) → identify(22) → destroy(21) lifecycle over the aligned client;
  the legacy `run_group_device` is unchanged.

New host-mock consumers: `smidr/tools/group_rpc_aligned.mojo` (mode
`host-mock-aligned`) and `smidr/tools/group_rpc_device_aligned_mock.mojo`.

## Qualification evidence (all runs on this VM, Mojo 1.0.0 ed45d567)

Baselines from the pristine tree (be9db5d6) were captured first:
grouped control suite 10 tests OK; grouped device suite 12 tests OK.

Aligned suites (new tests, independent oracles):

- `tests/test_hailo_aligned_storage.py` — **6 tests OK.** Layout admission for
  pages {64, 128, 256, 512, 4096, 32768} with exact offsets/extents; refusal of
  {0, 1, 2, 20, 32, 63, 96, 100, 1000, 65536, 2^40, 2^64−1}; scatter/gather
  projection at pages {0 (legacy), 64, 512} over payload sizes
  {0, 1, 19, 20, 21, 100, 2047, 2048} with the gap asserted byte-zero in the
  backing and the deterministic pattern recovered exactly; oversize (2069)
  refused; 7 storage guard refusals.
- `tests/test_hailo_group_control_rpc_aligned.py` — **10 tests OK** (394 s).
  The full legacy control battery (sync/launch/reply faults, IRQ atomicity and
  correlation, total deadline at every observed stage, partial construction,
  uncertain close, poison + recovery, argument guards) over aligned backing.
  The C oracle asserts the input map extent 2560, sync counts of 2560, the H2D
  body span at map offset 512, gap bytes [20, 512) zero at launch, and compares
  the gathered canonical wire before any copy.
- `tests/test_hailo_group_device_aligned.py` — **12 tests OK** (2034 s). The
  full typed lifecycle battery (create/identify/destroy, typed reply presence
  and corruption, per-phase wire and effect faults, one total deadline, cleanup
  deadline, partial IRQs, uncertain close retaining 2 views) over aligned
  backing; every good lifecycle asserts map effects [(0, 2560), (1, 2068)].

Legacy regression on the edited tree:

- Grouped control suite **10 tests OK** and grouped device suite **12 tests
  OK** rebuilt from the edited sources. Per-run stdout, stderr, and return
  codes are byte-identical to the pristine baseline evidence for all 574
  control runs and all 784 device runs. (Event streams themselves carry
  timestamps, ASLR addresses, and thread interleavings and are not
  cross-run stable in either tree.)
- `tests/test_hailo_soc_storage_bytes.py` — **4 tests OK**.
- `tests/test_hailo_session_finalization.py` — **6 tests OK**, with the frozen
  side historically correct (pre-correction `soc_storage` tool built at
  715862b7, the parent of afa6d080; all other frozen consumers at be9db5d6).
  Edited consumers' normal-path outputs are byte-identical to frozen.
- `tests/test_hailo_soc_group.py` — substantive codec vectors pass; 5 of 8
  methods fail only the refusal-stream assertion (`stdout == ''`): this VM's
  Mojo build prints unhandled-exception notices to stdout, while the suite
  expects them on stderr. The pristine codec tool fails the **identical** 5
  methods in this environment; the codec files are untouched by this slice.
- `test_hailo_soc_storage.py`, `test_hailo_soc_session.py`,
  `test_hailo_soc_rpc.py` are hardware suites: they skip without an explicit
  `--hardware` flag and were not run; no physical work is in this slice's
  scope.

One transient: the first full legacy-control run on edited builds reported a
single failure while three heavy suites and builds shared the VM; every test
then passed individually, and the full suite passed on rerun (629 s). Recorded
as contention flakiness, not a code defect.

## PROVEN

- HOST-VERIFIED: an aligned backing layout (page ∈ [64, 32768], power of two)
  is admitted, sized, mapped, synced, scattered, and gathered with the logical
  2068-byte wire preserved exactly and the inter-span gap deterministically
  zero.
- HOST-VERIFIED: the grouped control exchange and the typed grouped lifecycle
  complete over aligned backing under the full fault/deadline/IRQ/poison
  battery, with the body span launched at map offset 512 under the 512 policy.
- HOST-VERIFIED: legacy grouped behavior is unchanged (byte-identical
  observable outputs across 574 + 784 baseline scenarios), and legacy storage /
  session-finalization consumers are unaffected.

## NOT PROVEN

- No physical Hailo ioctl, DMA, descriptor acceptance, IRQ completion, or
  device lifecycle has been attempted on aligned backing. The 2026-10-24
  rejection (AES-CONTROL-016) stands as the only physical grouped evidence.
- Nothing here establishes numerical configuration, packing, placement,
  program execution, or source-model support.
- The soc_group stream-placement failures are an environment artifact of this
  VM's Mojo build, recorded above; they are not resolved by this slice.

## Next gate

Roadmap slice 1.4: a separately published one-shot physical contract for
exactly one grouped lifecycle on the aligned backing, taken only at the
owner's word.
