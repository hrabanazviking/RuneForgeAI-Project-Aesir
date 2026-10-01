# Second-brain native CUDA evidence — 2026-10-01

## Result and scope

The installed Llama 3.2 3B Q4_K_M model executes through Aesir's native Mojo
CUDA path on an RTX 2060 Max-Q. Strict tied-weight and scaled-RoPE admission,
a Turing residual-kernel repair and compile-time packed matvec specialization
are connected to the actual session and authenticated HTTP service.

The specialization improves the measured native short/passage latency by
16.8%/15.5%. **Aesir still trails Ollama.** Bifröst therefore retains Ollama as
its live default while Aesir is supervised and explicitly selectable. No general
speed superiority, whole-model logit parity or production-readiness claim follows.

## Hardware and data identity

- Linux x86-64; RTX 2060 with Max-Q Design, 6144 MiB; driver 595.91.07.
- Frozen repository Pixi lock, Mojo 1.0.0 (`ed45d567`); explicit `sm_75` build.
- Native and installed Ollama GGUF bytes: 2,019,377,376 bytes,
  `sha256:dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
- Native 28 layers, 3072 hidden, 8192 FFN, 24 query/8 KV heads, dimension 128;
  255 tensors, tied output and 64 F32 RoPE divisors.
- Both request context 4096, greedy sampling, 32 maximum output tokens, the same
  user/system strings. Native uses F16 KV; the installed Ollama uses its configured
  q8_0 KV and normal prefix reuse. Chat templates differ: native/Ollama prompt
  counts are 30/50 (short), 37/57 (passage), and 237/257 (longer prompt).
- Ollama's actual local server identifies version `0.0.0`; no numbered public
  Ollama release is inferred. Its system service runs `/usr/local/bin/ollama serve`.

These are actual application-level requests rather than identical formatted-token
or independent logits comparisons. The arithmetic answer uses 2 native versus
3 Ollama generated tokens; passage/longer cases reach 32 in both engines. The
same native template and reply count were retained for the optimization pair.

## Paired timings

Each series has one excluded warmup plus three warm samples per case/provider.
Other GPU tests had ended before these successful series. Two earlier runs that
overlapped GPU probes were interrupted and are not included as valid timings.

| Case | Native generic packed reader | Native specialized reader | Paired Ollama before / after |
| --- | ---: | ---: | ---: |
| Short arithmetic | 4.237 s | 3.525 s | 0.347 / 0.343 s |
| 32-token passage | 9.596 s | 8.107 s | 0.963 / 0.930 s |

All eight observed native replies (warmup plus samples across both cases) retain
the same text SHA-256 and generated-token count across that pair. The original
working-tree measurements are preserved in [the annotated comparison JSON](second-brain-comparison-2026-10-01.json).
The recorded Git revision there is the preimplementation task-contract commit,
not the revision of committed implementation. Both runs used uncommitted patches;
the generic executable was not archived, so a baseline binary hash is unavailable.
This provenance limitation is explicit rather than retroactively inventing a pin.

A later repeat includes binary/source fingerprints, dirty-worktree state and
independent hashing of the actual comparator GGUF. All 24 samples completed:

| Case | Native optimized median | Ollama median |
| --- | ---: | ---: |
| Short arithmetic | 3.497 s | 0.388 s |
| 32-token passage | 8.107 s | 1.535 s |
| Longer prompt (237 / 257 input tokens) | 30.202 s | 1.566 s |

See [the final raw benchmark](second-brain-final-2026-10-01.json). Ollama latency
varies between series; both measurements are retained. These observations do not
establish thermal control, varied-query latency, cold disk load, peak memory,
first-token time, long-context quality or model-output equivalence. Repeated
prefix reuse is a provider difference, not an Aesir implementation achievement.

Reproduce with both actual servers running and no other GPU test:

```bash
python3 scripts/benchmark_second_brain.py \
  --ollama "$OLLAMA_ORIGIN" --ollama-gguf "$OLLAMA_GGUF" \
  --key-file .aesir/second-brain/service.key --model llama3.2:3b \
  --context 4096 --samples 3 --output .aesir/second-brain/benchmark-new.json
```

## Independent arithmetic checks

The physical CUDA kernel inspector and NumPy checker pass **52,210 values** for
RoPE, scaled RoPE, residual addition with alias/tail cases, SiLU and GQA operations.
Scaled positions include 0, 1, 127 and 8191. Maximum observed primitive difference
is approximately 2.75e-6. These are constructed operation inputs, not full-model
logits. The oracle is implemented independently from the Mojo kernels.

```bash
pixi run --frozen mojo run --target-accelerator sm_75 \
  aesir_engine/tests/inspect_llama3_kernels.mojo > /tmp/aesir-kernel-values.csv
uv run --with numpy==2.4.4 python scripts/check_llama3_kernels.py \
  /tmp/aesir-kernel-values.csv
```

The real-weight oracle parses the actual GGUF independently with `gguf==0.19.0`
and NumPy, selecting five rows across each of seven model matrices. **35 CUDA
dot products pass**, maximum absolute error `2.9802322e-7`, both before and after
specialization. The generalized strict profile probe also rejects incorrect
RoPE shape/storage. Do not substitute generated model-looking fixtures for these
real weights.

```bash
uv run --with gguf==0.19.0 --with numpy==2.4.4 python scripts/gemma4_quant_oracle.py \
  --profile llama3.2-3b --model "$AESIR_GGUF" --output /tmp/aesir-3b-oracle.csv
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 \
  aesir_engine/tests/test_llama3_quant_parity.mojo \
  "$AESIR_GGUF" /tmp/aesir-3b-oracle.csv
pixi run --frozen mojo run -I aesir_engine --target-accelerator sm_75 \
  aesir_engine/tests/test_llama3_profile.mojo "$AESIR_GGUF"
```

Stop the resident Aesir service before loading a second full GPU test session.
One overlapping parity attempt correctly rejected insufficient observed device
memory; the quiescent optimized rerun passed. The admission snapshot is not a
memory reservation against competing processes.

## Counted build and live protocol checks

The optimized CLI builds through `scripts/launch.py --build --target sm_75`.
The counted suite reports **185 passed, 0 failed, 1 explicitly skipped external
F16 fixture, 186 total**. The negative control exits 1 specifically for
`negative_control.intentional_failure`, proving failed expectations affect status.
A private network namespace avoids the legacy socket test's fixed-port collision
with a real service.

```bash
unshare -Urn pixi run --frozen mojo run --target-accelerator sm_75 \
  aesir_engine/tests/run_all.mojo
# Expected nonzero result with the named intentional failure:
unshare -Urn pixi run --frozen mojo run --target-accelerator sm_75 \
  aesir_engine/tests/test_fail_closed_runner.mojo
python3 scripts/test_native_keygen.py --binary .aesir/launch/aesir
python3 scripts/test_native_service_settings.py --binary .aesir/launch/aesir
python3 scripts/test_api_contract_v1.py --binary .aesir/launch/aesir --model llama3.2:3b
python3 scripts/test_fixture_manifest.py
python3 scripts/check_fixture_manifest.py
python3 scripts/check_doc_drift.py
```

The private-key publication and seven-flag settings harnesses pass. All **29
independently authored actual HTTP compatibility cases** pass using the installed
3B model, including native, supported OpenAI SSE and Ollama NDJSON routes. This
does not establish complete third-party API conformance or embeddings.

The existing real native service harness was run specifically for available
`llama3.2:3b` with profile `llama3`. It passed arithmetic, stateless seeded replay,
Unicode/header/framing rejection, 401/403/408/413 controls, a forced 1 ms deadline
with HTTP 504 and subsequent successful identical replay, reset-peer handling and
active shutdown. No Gemma physical test on this machine is claimed.

```bash
python3 - <<'PY'
from pathlib import Path
from scripts.test_native_service import check
check(str(Path('.aesir/launch/aesir').resolve()),
      'llama3.2:3b', 'llama3', '/tmp/aesir-service-evidence')
PY
```

## Supervision and actual Bifröst integration

The generated native user unit passes `systemd-analyze --user verify` and runs
through the existing launch freshness gate. It allocates 4096 context, accepts a
private native credential, bounds its queue and runs with `NoNewPrivileges`,
`RestrictSUIDSGID`, mode mask 0077, 8G host ceiling and finite restart policy.
Fresh process startup reaches authenticated readiness in **4.218 seconds** with
existing OS/driver caches. A deliberate SIGKILL of this owned service causes a new
PID and increased restart count; readiness returns in **14.406 seconds**, followed
by a fresh real answer. These are process-recovery observations, not sudden-power
loss or replay of an interrupted request. Type=simple active state alone is not
readiness.

Bifröst's complete isolated suite passes **127 tests**, including 22 controlled
provider-contract cases and four DB/worker integrations. Mock providers establish
failure-state behavior separately from the following actual network evidence:

1. Authenticated native HyDE completes; ordinary search and original semantic
   embeddings remain healthy.
2. The native unit is deliberately stopped. Three HyDE reads use explicitly
   permitted Ollama fallback; the primary circuit opens after two failures and
   reports unavailable/last-provider state.
3. Native startup and cooldown allow a subsequent HyDE request to use Aesir again;
   the circuit closes and last-provider changes back to Aesir.
4. The native unit recovers through the separately measured SIGKILL restart.
5. The final private Bifröst settings return to default Ollama, with an actual
   healthy HyDE read. Native remains available under its supervisor.

Throughout these read-only probes, source counts and fingerprint remain exactly
**1237 documents / 49006 chunks / `v3_49006_49006`**. No test documents, vectors,
append jobs, source migrations or externally exposed model listener are added.
The sanitized [live integration witness](second-brain-integration-2026-10-01.json)
contains statuses and counts, not credentials or source passages.

The native service is same-host and authenticated. Outside AIs use Bifröst's
existing scoped gateway, finite queues and individual keys; they do not receive
the native credential or a direct database connection. Detailed operations are in
[SECOND_BRAIN.md](../SECOND_BRAIN.md) and the upstream
[Bifröst backend guide](https://github.com/hrabanazviking/bifrost-viewer/blob/main/AESIR_BACKEND.md).

## Remaining performance and safety gates

Native token-by-token prefill, kernel throughput/launch overhead and absent prefix
reuse remain performance work. A next optimization must preserve independent
numeric checks, completion/recovery behavior and corpus identity, then measure
varied actual queries with controlled residency. The current unit and router
bound/recover defined failures; they do not make every crash, malformed model,
GPU, hostile public workload or memory race impossible. Gemma's Turing PTX path,
whole-model parity, public native serving and general speed leadership remain
explicitly unestablished.
