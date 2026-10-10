# NPU Gate Retirement — H011

**Date:** 2026-10-10
**Law:** L1 (pure Mojo ships; the old `npu_gate.mojo` dlopen stub is retired,
never extended).

## What the stub did

`aesir_engine/core/npu_gate.mojo` defined `NPUGate`, a dlopen-based runtime
probe for edge/desktop NPU vendor libraries:

- `get_handle(backend)` — `dlopen` of `libcdsprpc.so` (Qualcomm Hexagon),
  `AppleNeuralEngine.framework` (Apple ANE), `libhailort.so` (Hailo-10),
  `libnvgov_npu.so` (Jetson), `libintel_npu_driver.so` (Intel NPU).
- `is_available(backend)` / `is_hailo_pi5_device_present()` — library
  loadability checks and a `/dev/hailo0` existence probe.
- `get_device_count(backend)` — always returned 0 (honestly).
- `allocate_npu_buffer` / `free_npu_buffer` / `memcpy_host_to_npu` /
  `memcpy_npu_to_host` — always raised "not implemented".
- `launch_gemm_npu(A, B, C, backend)` — validated GEMM shapes, then raised
  "NPU execution is not implemented".

It performed no physical device discovery, allocated no NPU buffers, and
launched no kernels. Per L1 it could not be extended into a driver — the
driver path is HAILBRÚ (pure Mojo, VFIO/UIO), not dlopen.

## What replaced each responsibility

| Former responsibility | Replacement | Superseding slice |
|---|---|---|
| dlopen runtime probing (`get_handle`, `is_available`) | Removed. `MimirWell.probe_npu_realms()` clears the backend list — a documented absence, no probing. | H061+ (HAILBRÚ device discovery) |
| `/dev/hailo0` presence probe | Removed. Device presence is established by the H003 PCIe census and future HAILBRÚ bring-up. | H061+, H081+ |
| NPU buffer alloc/free/copy stubs | Removed. No NPU allocator exists until the driver does. | H066/H067 (DMA buffers) |
| `launch_gemm_npu` dispatch | `gemm_f16_npu()` in `core/compute.mojo` keeps its public signature, performs the shape validation inline, and raises the stable "not implemented" error. Fail-closed; never a CPU fallback under an NPU label. | H121+ (offload dispatch) |
| NPU availability tests | `tests/test_npu_realm.mojo` now asserts the absence contract: probe clears backends, dispatch raises. | H061+ (driver tests) |

## Files touched by the retirement

- Deleted: `aesir_engine/core/npu_gate.mojo`
- `aesir_engine/core/compute.mojo`: import removed; `gemm_f16_npu` rewritten
  with inline shape validation + absence error.
- `aesir_engine/core/mimir_well.mojo`: `probe_npu_realms` rewritten as a
  documented no-op (clears `npu_backends`).
- `aesir_engine/tests/test_npu_realm.mojo`: rewritten to assert the absence
  contract (no `NPUGate` references).
- `aesir_engine/tests/test_hardware_resilience.mojo`: stub references removed;
  NPU checks now go through `gemm_f16_npu`.
- `aesir_engine/tests/test_new_paradigms_suite.mojo`: stub probe call removed.
- `aesir_engine/tests/run_all.mojo`: import + case renamed
  (`npu.npu_gate_availability` → `npu.probe_absence`).
- `scripts/check_doc_drift.py`: `npu_gate.mojo` dropped from the gate
  fail-closed check list.
- `docs/ARCHITECTURE.md`: section 6.1 updated (living architecture reference).

Historical mentions in `DEVLOG.md`, `CAPABILITY_LEDGER.md`, dated milestone
documents, and `TODO.md` are intentionally preserved as history (DEVLOG is
append-only); they describe what existed, not what exists.

## Verification

- `grep -rn "npu_gate"` returns zero hits in `*.mojo`, `*.py`, `*.toml`,
  `*.sh`, `*.json` (build files and source imports).
- Full test suite passes after removal (see H011 test evidence in DEVLOG).
