# Platform entry: Cloud Hypervisor VM on AMD EPYC (x86-64, CPU-only)

Branch: `platform/cloud-hypervisor-epyc`. First platform entry for Aesir on a
virtualized x86-64 host with no accelerator. Everything below was measured on
the machine itself; estimates are labelled as estimates.

## Machine facts (read from the host)

- x86_64, Cloud Hypervisor guest (DMI product `cloud-hypervisor`; the guest
  itself runs under systemd-nspawn) on an AMD EPYC 9D64 host.
- 2 vCPU, ~8 GB RAM, 200 GB disk, no GPU, no Hailo device, no CUDA.
- CPU flags include AVX-512 (incl. BF16). The current GGUF host kernels do
  not yet exploit it (see Performance).
- Toolchain: the repo's own Pixi environment (Mojo/MAX 26.5.0 observed in
  the env). Nothing was installed system-wide; no Docker.

## What was broken on this platform class, and what this branch changes

1. **The launcher build could not link anywhere without HailoRT.**
   `aesir_engine/main.mojo` reaches the `aesir_hailo10h_*` C ABI
   (`hailo10h_direct.mojo`), but `scripts/launch.py` never linked the
   bridge library, so `launch.py --build` failed with undefined references
   to `aesir_hailo10h_open/close/generate/describe/clear_context/free_text`.
   Fix (`scripts/launch.py`, `aesir_engine/hailo10h_stub.c`): the launcher
   now stages a real bridge built by `scripts/build_hailo10h.sh` when one
   is available (`work/libaesir_hailo10h.so` or `$AESIR_HAILO_LIB_DIR`),
   and otherwise compiles a small fail-closed stub implementing the same
   C ABI. The binary then builds on CPU-only hosts, and Hailo commands
   fail at runtime with a clear "backend is unavailable on this platform"
   error instead of failing to link. The stub source is part of the
   launcher build fingerprint.
2. **The launcher build could not see the repo-root `hailbru` package.**
   `aesir_engine/loader/gguf.mojo` imports `hailbru.*`; the build now
   passes `-I <repo root>` (and `scripts/build_hailo10h.sh` gained the
   same `-I` for consistency, since the general CLI also reaches it).
3. **The canonical CLI and the GGUF engine were Hailo-only by construction.**
   Between 2026-10-12 commits `8a97f8ea`, `0d369f9a`, `cee85886`, and
   `4b1552b0` (slice 137), the entry point was rewired to the Hailo-only
   command module, the engine's backend validator was made to raise for
   every configuration, the forward paths gained an unconditional
   Hailo-only gate, and `run` was rewritten to accept only
   `--accel hailo10h --model-path <model.hef>`. The CPU GGUF machinery
   (single-shot runner, K-quant decoders, F16 forward pass, the project's
   own tests) was left in the tree but unreachable. This branch restores
   the pre-lock-in behaviour, adapted so the Hailo direct GenAI session
   stays available through the general CLI:
   - `aesir_engine/main.mojo`: canonical entry is again the general CLI
     (`cli.commands`) with the terminal home and chat/serve preparation.
     (`aesir.mojo` returns to its exact pre-`8a97f8ea` content.)
   - `aesir_engine/aesir.mojo`: `validate_runtime_backend_config` again
     admits single-device CPU and GPU-realm configurations and rejects
     multi-device and NPU requests as "not implemented"; engine defaults
     are `enable_npu=False`, `target_backend=ARM_NEON` again.
   - `aesir_engine/core/inference.mojo`: the `_require_hailo_only_inference`
     gate and its three call sites are removed; forward-path defaults are
     host execution again.
   - `aesir_engine/cli/commands.mojo`: `run` dispatches by `--accel`:
     `hailo10h` → direct Hailo GenAI session via `--model-path` (unchanged
     behaviour), `cuda` → native CUDA single-shot, otherwise the verified
     CPU GGUF single-shot (`require_verified_cpu_backend` +
     `run_single_shot`). Help text documents all routes.
   The Hailo-only module (`cli/hailo_commands.mojo`) is untouched and
   remains in the tree for Hailo hosts.

## Verification on this machine

- `python3 scripts/launch.py --build` succeeds; `--check` passes
  (fingerprint + checksum match).
- Project tests (built with the same pixi/mojo invocation as the
  launcher, `-I . -I aesir_engine`, linked against the staged bridge):
  `aesir_engine/tests/test_inference.mojo` — full pass, including
  `unsupported runtime configurations: PASS`, the validator contract the
  Hailo-only gate had made uncompilable (it calls the validator with the
  restored three-argument signature). `aesir_engine/tests/test_cli.mojo`
  compiles against the restored dispatch and passes its suites.
- Model exercised end to end:
  `Creative_Writing-Heretic-3.2-1B` Q4_K_M GGUF (Llama 3.2 1B,
  807,691,680 bytes, sha256
  `d4417c345257e7a9e90146d0ce27df2234801b00a851d18edadaa5b6efca517a`):
  `create` (recipe + `--model` blob import, digest verified), `verify`
  pass, `inspect` reads architecture/quantization/context (131,072) from
  the GGUF, and `run --accel cpu` loads it (147 tensors validated;
  MimirWell pool 4,295,498,240 derived bytes; ~4.7 GB RSS) and generates
  greedily with a KV cache.

## Performance — the honest headline

**Correct, but slow.** On this 2-vCPU VM one forward pass over the 1B
model costs roughly a minute (~0.01–0.02 generated tokens/sec observed on
a 2-token prompt; three tokens in ~3 minutes after a ~15 s load). Two
structural reasons, both pre-existing engine properties rather than
platform defects:

- The host kernels are correctness-grade: the block forward uses scalar
  `gemm_f16` (weights are converted to F16 in the pool at load); the
  AVX-512 hardware goes unused, and generation runs effectively on one
  core.
- Prefill is one `forward_pass` per prompt token, so prompt cost scales
  linearly at the same ~1 min/token: a 224-token prompt needs ~4 hours
  before the first generated token. Long-prompt work is impractical on
  this engine path today regardless of host.

Follow-ups a future performance slice should take, in order: a
vectorized x86 GEMM (AVX2/AVX-512) or direct Q4_K GEMM
(`gemm_q4_k_m` already exists in `core/compute.mojo`), batched prefill,
and only then thread scaling. Until one of those lands, this platform is
suited to engine/CLI development, correctness tests, and short-prompt
experiments — not interactive inference.

One fidelity caveat: in the short diagnostic run the greedy decoder
repeated token 0 (`!`) — whether that is this model's behaviour on a
bare prompt or a conversion artefact is NOT established by these runs;
the engine's verified-generation claim remains scoped to its own small
fixtures (see the capability ledger).

## Reproduce

```bash
PATH="$HOME/.pixi/bin:$PATH" python3 scripts/launch.py --build
python3 scripts/launch.py --check
python3 scripts/launch.py -- create heretic-3.2-1b:latest \
    --modelfile Modelfile --model model.Q4_K_M.gguf
python3 scripts/launch.py -- verify heretic-3.2-1b:latest
python3 scripts/launch.py -- run heretic-3.2-1b:latest --accel cpu \
    --max-tokens 32 "<prompt>"
```
