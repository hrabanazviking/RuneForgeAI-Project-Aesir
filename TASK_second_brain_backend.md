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
