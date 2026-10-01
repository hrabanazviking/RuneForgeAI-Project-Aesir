# Second-brain native inference integration

Authorization: Volmarr requested a more stable, reliable and faster Aesir backend
for the existing Bifröst second brain, and previously authorized publishing the
improved owning projects. Work follows the active main workflow and reality-first
law. Architect, Forge Worker, Auditor and Scribe roles run sequentially.

## Current boundary

The native CUDA service already provides serialized stateless generation,
authenticated native/OpenAI routes, bounded socket queues, deadlines and reset.
It has no compatible nomic-bert embedding implementation. Bifröst couples chat
and corpus embeddings to one unauthenticated Ollama address. This machine has a
6 GiB Turing GPU and an existing Llama 3.2 3B Q4_K_M GGUF; existing Ada evidence
does not prove this combination. The locked Mojo environment is installed; a
baseline sm_75 build and physical model admission are the first gates.

## Owning domains and changes

Native CLI/service owns truthful loaded-model capability discovery, deployment
instructions and physical fault/performance evidence. Loader/compute changes
are permitted only for reproduced supported-model defects, with parity checks.
Bifröst owns separate authenticated chat routing, deadlines, bounded concurrency,
observable permitted fallback and automatic circuit recovery. Its ingestion,
Skein and Skry continue using the original nomic embeddings until a real
equivalent embedding backend exists. No source database migration is authorized.

## Acceptance

Build and run Aesir against the same installed model bytes used by Ollama.
Exercise actual authenticated sockets, invalid requests, timeouts, next-request
recovery and supervised process restart. Benchmark cold load and warm short/long
prompts with equal context, generation limits and greedy sampling; report actual
counts and timings, including slower results. Do not claim numerical model parity
from fluent text alone. Add focused default-suite cases and update the canonical
service interface, ledger, TODO and DEVLOG. Publish a portable second-brain manual.
Deploy only a working backend, keeping embedding identity, source documents,
authorization scopes and ingestion limits intact. Validate Bifröst search and
downstream outage behavior without adding test data to the production corpus.

The result must distinguish integration/recovery improvements from remaining
native compute bottlenecks. No blanket speed or production-readiness claim.

## Recorded outcome — 2026-10-01

Implemented and physically checked native 3B admission, scaled RoPE, Turing
residual repair, packed-weight specialization, truthful model/capability health,
private supervised service and separate Bifröst chat routing. Bifröst native HyDE,
outage fallback/circuit recovery and native SIGKILL restart passed without source
changes. Detailed commands and measurements are in docs/SECOND_BRAIN.md and
its evidence report. Cold process readiness was measured with existing OS/driver
caches; warm short/passage/237-prompt-token requests were compared.

The faster-than-Ollama objective remains unmet. The 32-token native passage fell
from 9.596 to 8.107 seconds, but the corresponding Ollama measurement was 0.930
seconds (1.535 seconds in a later repeat). Default Bifröst chat remains Ollama;
Aesir is supervised and explicitly selectable. Batched prefill, prefix caching,
further packed-weight optimization and representative varied-query measurement
remain required before claiming or deploying a native speed advantage.

## CI follow-through contract — 2026-10-01

The implementation's hosted build/master/native checks passed, but the existing
PowerShell launcher contract harness left its intentionally injected native
failure code in global LASTEXITCODE after its assertions passed. The earlier
task-contract workflow also failed. Repair the harness's per-case reset, preserving
its assertion that real launcher status 19 propagates. Do not clear production
launcher failures or force unconditional success. Acceptance is the entire hosted
workflow succeeding with the negative-control and all subsequent gates executed.
This is mocked WSL argv/status evidence, not physical Windows/WSL GPU execution.
