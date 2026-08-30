# Native hardware and runtime controls

The runtime-expansion work connects the heterogeneous proposal to the existing
native model sessions. This is a single-device implementation, not completion
of the proposed AMD/Metal/NPU/multi-device backend matrix.

## Inspect before loading

```bash
aesir hardware list
aesir compute explain model.gguf --profile auto --context 8192
aesir compute plan model.gguf --device 0 --reserve-mib 512
aesir chat model.gguf --accel cuda --profile auto --device auto \
  --context 8192 --max-tokens 256 --reserve-mib 256
aesir run model.gguf --accel cuda --max-tokens 32 "Hello"
```

`hardware list` reads the Linux CPU model and `MemTotal`/`MemAvailable` from
procfs, then enumerates CUDA through MAX. Missing CUDA is reported separately
from the usable CPU path. GPU memory values are attributed to
`DeviceContext.get_memory_info`; they need not equal an advertised board size
or whole-machine `nvidia-smi` readings. Memory sharing is reported unknown
because this adapter has not probed it. Other backends are not probed or
represented as working.

`compute plan` and `compute explain` have the same checked behavior. They map
GGUF metadata, validate one implemented tensor profile, calculate explicit
weight/KV/activation/output bytes, inspect available memory and select a fitting
CUDA device. They do not upload weights or promise tokenizer compatibility.
`auto` selects the compatible fitting device with the most reported free
memory, breaking ties in enumeration order; this is not a speed benchmark.
An explicit device never falls through to another device or to CPU.

The same buffer calculation runs immediately before either CUDA session
allocates. The default reserve is 256 MiB. Driver, allocator and tokenizer
overhead are not exact model-buffer counts; memory observations can race with
other processes, so allocation errors still propagate. Host admission accounts
for both the mapped model and a full pinned upload copy. Linux procfs memory
does not yet account for stricter container/cgroup limits.

`run --accel cuda` now detects either supported CUDA profile. `chat` preserves
its default Gemma profile for compatibility; `--profile auto` inspects metadata
and chooses the corresponding defaults. Model-specific shapes and tokenizers
still have to pass admission. Unsupported GGUFs do not become supported merely
because their architecture string says `llama`.

## Verification

Five counted hardware-independent cases cover malformed memory observations,
exact profile byte counts, overflow/reserve/host-budget rejection, injected
multi-device policy and invalid CLI options. The opt-in physical test is:

```bash
python scripts/test_native_planning.py --binary ./aesir \
  --llama models/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --gemma models/gemma-4-E4B-it-Q4_K_M.gguf
```

This test passed on Linux/WSL2, Intel i7-12700H and NVIDIA RTX 4070 Laptop GPU,
with locked Mojo 1.0/MAX 26.5: both profiles were planned and executed, and
impossible reserve/device requests were rejected before upload. Multi-device
selection is tested with injected records; physical execution was checked only
on CUDA device 0. The master suite passed 152 cases with one external skip.
After integrating concurrent Gemma 3 development, the pinned 32-token CPU
oracle still passes. Restored mandatory download identity checks and failure
assertions, bounded CPU token/shape handling and stable CUDA tanh. CPU packed
Q4_K/Q6_K matmul now also matches 25 independent Stheno weight-row references
(maximum absolute difference 0.00018817186 after F16 output rounding).

The new Gemma 3 CPU development paths are retained, but this task has not
verified their full-model output. Existing CPU block objects with SIMD fields
are not canonical packed GGUF layouts; the repaired raw-byte matmul tests no
longer reinterpret those padded objects as wire-format model data.
Independent model/kernel references and earlier conversations remain in
[the Gemma guide](GEMMA4_CUDA.md) and [the Stheno guide](STHENO_CUDA.md).
