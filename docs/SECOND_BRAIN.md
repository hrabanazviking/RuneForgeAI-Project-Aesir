# Aesir as a Bifröst second-brain chat engine

## What is working, and which engine to choose

The 2026-10-01 integration runs the installed Llama 3.2 3B Q4_K_M model on a
6 GiB RTX 2060 Max-Q, using native Mojo CUDA inference. It has authenticated
local HTTP access and a supervised user service. Bifröst can select it for
HyDE search passages and cluster labels, with an explicitly configured Ollama
fallback and automatic circuit recovery.

**Ollama remains the default Bifröst chat engine on the measured machine.**
Native kernel and prefix improvements now make repeated 32-token passages
competitive: 0.838 s native versus 0.874 s Ollama, and repeated longer prompts
0.876 s versus 0.892 s in the latest small paired series. Observed first passage
requests took 1.306 s versus 0.918 s, and first longer prompts 5.820 s versus
1.003 s. Retained-prefix reuse changes the work, and the providers use different
chat templates and KV formats even though GGUF bytes match. Keep the existing
provider policy for ordinary new prompts; native is a working explicit option.
See [current efficiency evidence](evidence/native-efficiency-2026-10-01.md) and
[reproducible operation](NATIVE_EFFICIENCY.md). Earlier 8.1 s native measurements
in the integration record are historical. No general Ollama-superiority claim.

Embeddings continue using the original Ollama `nomic-embed-text` model. Aesir's
text generation does not implement that embedding space. Existing database
vectors, trusted ingestion, Skein and Skry retain their model configuration.

## Supported boundary

| Item | Exercised configuration |
| --- | --- |
| Host | Linux x86-64, user systemd, frozen Pixi environment |
| GPU | RTX 2060 Max-Q, CUDA target `sm_75`, driver 595.91.07 |
| Model | Installed `llama3.2:3b` GGUF, 2,019,377,376 bytes |
| Weight identity | `sha256:dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff` |
| Model layout | 28 layers, hidden 3072, FFN 8192, 24 query heads, 8 KV heads, head dimension 128 |
| Special handling | Tied output/embedding weights; 64 positive finite F32 GGUF RoPE factors |
| Model admission ceiling | 8192 positions; this deployment allocates 4096 |
| Cache and memory | F16 KV; 469,762,048 KV bytes at 4096; bounded 64 MiB host upload staging |
| Native listener | Authenticated IPv4 loopback, `127.0.0.1:18434` |
| Request policy | 256 new tokens maximum, 45,000 ms cooperative generation deadline |
| Native waiting queue | 2 sockets, 1000 ms queue deadline; one active generation |
| Supervisor | Restart on failure after 10 seconds, 10 starts per 300 seconds, 8G host memory ceiling |

Strict metadata and tensor admission reject mismatched layouts before upload.
The registry describes this 3B variant as `COMPATIBLE`; a matching filename or
READY layout does not certify every quantization, every GPU or whole-model logit
parity. The existing 8B and Qwen profile contracts remain separate.

Llama residual addition now uses a dedicated kernel. This fixes an observed
`CUDA_ERROR_INVALID_PTX` caused by importing a Gemma `tanh` instruction into
Llama's generic element kernel on this toolchain. **Gemma execution on Turing
has not been fixed or established by this work.** Preserve its separate evidence
boundary rather than interpreting Llama's successful run as general support.

## Build and verify the executable

Work from this repository's root. Install Pixi separately if it is absent, then:

```bash
pixi install --frozen
python3 scripts/launch.py --build --target sm_75
python3 scripts/launch.py --check
```

The target above is for the exercised Turing GPU. Choose the actual supported
target for another machine; an `sm_89` build is not a Turing execution proof.
The launcher records source and binary checksums under `.aesir/launch/` and
refuses a stale or modified build. Rebuild after changes to Mojo source, locked
dependencies or the launcher. A restart validates the build before execution;
it does not compile automatically. Keep `.aesir/`, keys and model blobs out of Git.

The running native binary does all model computation. Python only builds,
supervises or independently checks the native implementation.

## Import an existing Ollama GGUF without another download

Read the installed model's Ollama manifest to identify its model-layer blob.
Locations vary by installation; use the actual readable GGUF path. The native
import copies and hashes it into Aesir's own durable catalog, so allow space for
one additional approximately 2 GB copy.

```bash
mkdir -p -m 700 .aesir/second-brain
cat > .aesir/second-brain/Modelfile <<'MODEL'
FROM llama-3.2-3b-Q4_K_M.gguf
PARAMETER num_ctx 4096
PARAMETER num_predict 256
PARAMETER temperature 0.0
MODEL
# Set OLLAMA_GGUF to the real local model-layer blob, not its manifest.
.aesir/launch/aesir create llama3.2:3b \
  --modelfile .aesir/second-brain/Modelfile --model "$OLLAMA_GGUF"
.aesir/launch/aesir inspect llama3.2:3b --format json
.aesir/launch/aesir verify llama3.2:3b
```

Inspect and verify are separate from successful inference. Do not import under
an existing identity without reviewing the catalog behavior in [MODEL_STORE.md](MODEL_STORE.md).
Keep the real blob path and any private host configuration out of published logs.

## Create a private service credential

```bash
.aesir/launch/aesir keygen --output .aesir/second-brain/service.key
```

Native `keygen` exclusively publishes a random 256-bit credential in a private
file. It refuses an existing destination. Keep the directory owner-only and the
key mode 0600. The native loader and Bifröst reject symlink, special-file,
wrong-owner and public-permission credentials. Never put this key in a URL,
browser storage, shared AI instructions, Git or chat logs.

This credential authenticates Bifröst to Aesir. The owner launcher token and
individual external-AI keys are separate Bifröst credentials. For outside AIs,
use Bifröst's authorized gateway and [AI connection guide](https://github.com/hrabanazviking/bifrost-viewer/blob/main/AI_CONNECT.md).

## Install the supervised local service

The complete deployment policy is data in `scripts/second_brain_service.json`.
Review it before generating a unit. The helper validates the native model/settings
and current build, then writes a new private unit. It refuses overwrites and does
not start the service itself.

```bash
python3 scripts/second_brain_service.py \
  --model llama3.2:3b --api-key-file .aesir/second-brain/service.key
systemd-analyze --user verify "$HOME/.config/systemd/user/aesir-brain.service"
systemctl --user daemon-reload
systemctl --user enable --now aesir-brain.service
systemctl --user status aesir-brain.service --no-pager
```

The default destination respects `XDG_CONFIG_HOME`. `--output` selects a new
unit destination; `--settings` selects a policy with the same exact field set.
This version requires the exercised 8G host ceiling. Native settings enforce
model/context/port limits; this helper does not establish arbitrary hardware or
memory-policy support. It uses explicit argv and escaped systemd arguments.

Service startup rehashes catalog content, checks allocation admission and loads
one CUDA session. `Type=simple` becoming active is not readiness: check the
authenticated health endpoint. Restart handles process failure; an intentional
`systemctl stop` stays stopped. Repeated startup failures eventually hit the
start limit. Correct the underlying build, key or resource issue, then:

```bash
systemctl --user reset-failed aesir-brain.service
systemctl --user start aesir-brain.service
```

The service starts with the user's systemd manager. Unattended startup without a
login additionally depends on that host's user-manager/linger configuration;
this helper does not change it. In-flight stateless requests can fail during a
crash. A restart creates a new session; it does not replay a lost request.

## Make an authenticated local request without displaying the key

This example reads the private file in memory. It does not print headers or put
the bearer credential in process arguments. Run from the repository root:

```bash
python3 - <<'PY'
import http.client, json
from pathlib import Path
key = Path('.aesir/second-brain/service.key').read_text().strip()
conn = http.client.HTTPConnection('127.0.0.1', 18434, timeout=50)
headers = {'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'}
conn.request('GET', '/health', headers=headers)
health = conn.getresponse()
assert health.status == 200
print(json.loads(health.read()))
conn.request('POST', '/v1/generate', json.dumps({
    'prompt': 'What is two plus two? Answer with one word.',
    'system': 'You are concise.', 'max_tokens': 16, 'temperature': 0
}).encode(), headers)
response = conn.getresponse()
assert response.status == 200
reply = json.loads(response.read())
assert reply['model'] == 'llama3.2:3b'
assert reply['backend'] == 'cuda' and reply['finish_reason'] in ('eos', 'length')
print(reply['text'])
conn.close()
PY
```

`GET /health` now reports the loaded model name and SHA-256, context, token and
deadline ceilings, queue limit, actual healthy status, and capabilities.
`text_generation=true`, `embeddings=false`. Nonstreamed `/v1/generate` adds
`model` and `model_digest` to its existing text/count/finish fields. Streaming's
terminal schema is unchanged. HTTP 200 alone is insufficient: consumers must
check completion and provider identity before using text.

## Configure Bifröst

Read [Bifröst's backend manual](https://github.com/hrabanazviking/bifrost-viewer/blob/main/AESIR_BACKEND.md).
Its private root `.env` can select:

```dotenv
VIEWER_CHAT_BACKEND=aesir
VIEWER_CHAT_URL=http://127.0.0.1:18434
VIEWER_CHAT_API_KEY_FILE=/absolute/private/path/to/service.key
VIEWER_CHAT_MODEL=llama3.2:3b
VIEWER_CHAT_FALLBACK=ollama
```

Keep `VIEWER_OLLAMA_URL` and `VIEWER_EMBED_MODEL` as the existing embedding
configuration. Restart Bifröst after changing chat configuration. This connection
requires Aesir and Bifröst on the same host. It is not a public Aesir listener.

Bifröst's `inference.json` controls one active chat call, a 0.2-second admission
wait, response-size limit, timeouts, two-failure circuit threshold and 30-second
cooldown. Fallback is opt-in and remains visible in authenticated health. Input
or authentication rejection does not fall back. After cooldown, a subsequent
request tests the primary and closes the circuit on success. No background retry
storm or automatic destructive repair is introduced.

For the existing default policy, set `VIEWER_CHAT_BACKEND=ollama`, set its chat
origin to the actual Ollama address, and use `VIEWER_CHAT_FALLBACK=none`.
Aesir's service can remain available for explicitly selected native work.

## Verify changes and measure performance

Hosted CI has no GPU. These commands have distinct evidence boundaries:

```bash
# Namespace isolation avoids colliding with a real listener used by a socket test.
unshare -Urn pixi run --frozen mojo run --target-accelerator sm_75 \
  aesir_engine/tests/run_all.mojo
python3 scripts/test_native_keygen.py --binary .aesir/launch/aesir
python3 scripts/test_native_service_settings.py --binary .aesir/launch/aesir
python3 scripts/test_api_contract_v1.py --binary .aesir/launch/aesir --model llama3.2:3b
python3 scripts/check_fixture_manifest.py
python3 scripts/check_doc_drift.py
```

The opt-in API harness starts its own listener and CUDA sessions. Stop the
supervised Aesir service first to free GPU memory; restart it after testing.
Kernel/reference and real-weight parity commands are recorded in the linked
evidence report. The counted suite's external F16 fixture skip is explicit.

For a paired real-socket benchmark, keep both providers running, stop other GPU
tests, choose a new output path, and use the actual local Ollama origin and blob:

```bash
python3 scripts/benchmark_second_brain.py \
  --ollama "$OLLAMA_ORIGIN" --ollama-gguf "$OLLAMA_GGUF" \
  --key-file .aesir/second-brain/service.key --model llama3.2:3b \
  --context 4096 --samples 3 --output .aesir/second-brain/benchmark-new.json
```

The script hashes the optional comparator blob against native health, records
the executable/source identity and dirty-worktree flag, excludes one warmup per
case/provider from medians, and preserves failed sample categories with nonzero
exit. Check failures before interpreting successful-sample medians. It measures
HTTP wall time for short, passage and longer-prompt cases. It does not establish
uncached model load, first-token latency, full-logit parity, long-context quality,
peak memory or broad superiority. Native F16 KV and Ollama's configured cache and
prefix reuse must be disclosed when comparing results.

## Troubleshooting and safe recovery

- **Stale build:** stop the unit, rebuild using the GPU target, check freshness,
  then start. A source edit is not applied to an already running binary.
- **CUDA allocation admission failed:** inspect `nvidia-smi`, reduce optional
  competing model residency or choose a validated smaller context. Admission is
  a snapshot, not a reservation against another process. Preserve the corpus
  embedding model identity.
- **401/403:** check the private key and local Host/origin contract. Do not expose
  the listener or disable checks. Rotate to a newly generated private file, update
  both service and Bifröst paths, then restart both.
- **503/busy:** honor queue/cooldown signals; cap concurrency. Raising limits does
  not add GPU capacity.
- **504 or timeout finish:** discard partial output. Check prompt size and budget,
  then retry a bounded request after recovery. Cooperative deadlines cannot
  preempt an individual running GPU kernel.
- **Aesir unavailable but search works:** normal search uses original embeddings
  and can degrade to keyword search. HyDE can use configured fallback or the raw
  query. View the chat and embedding health fields separately.
- **Crash loop:** inspect `journalctl --user -u aesir-brain -n 60 --no-pager`
  locally. Logs and host paths are private operational data. Resolve the named
  failure before resetting the supervisor limit.

Next performance gates are batched prefill, measured packed-weight kernel work
and prefix caching, each with independent numerical checks and a quiescent
same-weight comparison. The current optimization preserves reduction order and
all eight observed native baseline/optimized reply counts and text hashes.

## Native performance update

The newer block projections, prepared layer plan and bounded exact-prefix reuse
are documented in [NATIVE_PERFORMANCE.md](NATIVE_PERFORMANCE.md). They preserve
existing providers, embeddings, authentication and service APIs. Keep fresh-prefill
and repeated-prefix speed claims separate. The supervised native unit uses the
new defaults after rebuilding/restarting; Bifröst provider policy is independent.
