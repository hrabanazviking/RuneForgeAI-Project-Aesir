# Provider baseline refresh attempt — 2026-10-10

## Scope

This receipt checks whether the paired native/Ollama benchmark described in
[`NATIVE_PERFORMANCE.md`](../NATIVE_PERFORMANCE.md) can be rerun against the
current Aesir checkout. It does not publish new provider timings or change
provider policy.

## Exact attempted environment

- Repository: `RuneForgeAI-Project-Aesir`, branch `docs/cross-cutting-500-slice-roadmap`
- Pre-change revision: `06c2124e01825cd836d0b15e27303ac14146d09c`
- Frozen toolchain: Mojo `1.0.0 (ed45d567)`, command `pixi run --frozen mojo --version`
- Native launch binary: `.aesir/launch/aesir` exists locally; it is ignored and
  is not the registered `llama3.2:3b` model store
- GPU inventory: NVIDIA GeForce RTX 2060 Max-Q is visible via `nvidia-smi -L`
- Ollama client: `/usr/local/bin/ollama` exists
- Ollama service: `ollama list` failed to connect, reporting that the server
  must be started with `ollama serve`
- Model artifact gate: this checkout has no `.aesir/models` registry directory;
  `ollama list` could not provide a registered model or blob identity

## Result

The provider baseline is **not refreshed**. The required second provider is not
reachable and the current checkout has no admitted model artifact identity to
bind both providers to. The historical [2026-10-01 provider report](native-efficiency-2026-10-01.md)
and its raw `paired-providers.json` remain historical only: they describe a
different Aesir revision/binary, a dirty measurement worktree, and a service
snapshot from that date. Their values are not represented as current results.

No timing was collected, no provider ranking was changed, and no workload was
sent to a provider. There is no implementation or benchmark interface change
in this slice.

## Rerun gate

On an idle GPU host, start the intended Ollama service, register the same
verified GGUF with both providers, verify the Aesir model digest and Ollama blob
digest, ensure the native service and competing GPU workloads are stopped, then
run the documented `benchmark_second_brain.py` command with a new output path.
Retain the complete raw JSON, including errors and tool/model identities. A
successful run must record current source revision and binary SHA, clean/dirty
state, model digest equality, provider/tool versions, context, sampling policy,
prompt/output counts, residency and the complete sample schedule. Different
templates or outputs remain a comparability limitation even when weight bytes
match; a small paired run is not a general provider lead certificate.

## Acceptance commands

```sh
command -v ollama
ollama list
pixi run --frozen mojo --version
python3 scripts/benchmark_second_brain.py --help
python3 scripts/check_doc_drift.py
```

The first three environment checks were run for this receipt. The benchmark
help path and documentation drift check are included in the slice release gate.
