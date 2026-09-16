# Project A.E.S.I.R. × Msty

## Total Ollama-Replacement Compatibility Roadmap

**Document purpose:** Make Project A.E.S.I.R. a complete,
application-proven replacement for Ollama inside Msty, with the target
that every Msty feature that normally depends on Msty Local AI/Ollama
works with A.E.S.I.R. at least equivalently, and eventually better where
A.E.S.I.R.'s architecture permits.

**Roadmap role:** This is a **side-quest roadmap** that runs alongside,
rather than replacing, `BEST_IN_CLASS_GAMEPLAN.md` and the main
A.E.S.I.R. roadmap.

**Target platform for first certification:** Windows 11 Msty → WSL2
A.E.S.I.R. → native Mojo/CUDA → NVIDIA RTX 4070 Laptop GPU.

**Primary compatibility rule:**

> Msty should not need to know that Ollama has been replaced.

------------------------------------------------------------------------

# 1. Mission

A.E.S.I.R. already has the beginnings of an Ollama-compatible service.
The next goal is to turn that compatibility surface into a **complete
Msty backend contract**.

The project succeeds when a normal Msty user can use A.E.S.I.R. for:

-   local model discovery
-   model installation/import
-   model metadata
-   model editing/configuration
-   text chat
-   streaming generation
-   multi-turn conversations
-   stop/cancel
-   regeneration and continuation
-   system prompts
-   model templates
-   per-chat and per-model parameters
-   context configuration
-   model loading/unloading
-   multiple installed models
-   model switching
-   Knowledge Stack embeddings
-   Knowledge Stack retrieval workflows
-   local embedding models
-   model deletion/copying/renaming where Msty expects them
-   model download progress
-   Hugging Face/GGUF import workflows
-   local service health/version checks
-   service configuration
-   Msty Remote/Ollama Remote use where applicable
-   concurrency controls
-   keep-alive semantics
-   vision/multimodal features once A.E.S.I.R. supports suitable models
-   tool/function calling where Msty routes it through the local backend
-   metrics and completion metadata expected by Msty

The compatibility objective is **behavioral**, not merely
endpoint-shaped. Returning HTTP 200 is not enough. Msty must behave
correctly.

------------------------------------------------------------------------

# 2. Current Starting Point

As of the current A.E.S.I.R. repository state, native Ollama-compatible
serving already provides the core foothold:

-   `GET /api/version`
-   `GET /api/tags`
-   `POST /api/show`
-   `POST /api/generate`
-   `POST /api/chat`
-   standard Ollama loopback port `127.0.0.1:11434`
-   model aliases such as `gemma4-e2b:latest`
-   native CUDA inference
-   content-addressed model storage
-   Ollama-like generation options
-   native model discovery
-   OpenAI-compatible text APIs
-   persistent loaded model execution underneath stateless HTTP requests

Current important gaps include:

-   NDJSON streaming
-   embeddings
-   full model-management API
-   `/api/ps`
-   tool calling
-   multimodal messages
-   broader Ollama request/response compatibility
-   concurrency behavior
-   complete keep-alive semantics
-   application-level Msty certification
-   direct Windows/native packaging strategy if desired later

This means the project is **past the architectural proof stage**. The
task is now compatibility engineering.

------------------------------------------------------------------------

# 3. Compatibility Philosophy

## 3.1 Ollama is the protocol oracle, Msty is the application oracle

Two references matter:

1.  **Ollama behavior** defines the compatibility protocol.
2.  **Msty behavior** defines whether that compatibility is actually
    useful.

A.E.S.I.R. should therefore maintain two test classes:

-   `ollama_compat_*`
-   `msty_compat_*`

A feature is not considered Msty-compatible merely because an isolated
curl command works.

## 3.2 Black-box compatibility first

Do not depend on Msty internals.

Observe:

-   requests Msty sends
-   headers
-   endpoint order
-   JSON shapes
-   streaming expectations
-   error handling
-   retries
-   cancellation behavior
-   model lifecycle calls
-   embedding requests
-   configuration values
-   startup/shutdown behavior

Then reproduce the expected external behavior.

## 3.3 Strict internally, tolerant at the compatibility boundary

A.E.S.I.R.'s native APIs can remain strict.

The Ollama compatibility layer should emulate Ollama's accepted input
closely enough that applications do not fail because A.E.S.I.R. rejects
harmless fields that Ollama accepts.

Use a compatibility translation layer:

``` text
Msty
  │
  ▼
Ollama Compatibility Gateway
  │
  ├─ request normalization
  ├─ Ollama option translation
  ├─ model-name resolution
  ├─ lifecycle translation
  ├─ streaming encoder
  ├─ response normalization
  └─ compatibility quirks
  │
  ▼
A.E.S.I.R. Native Runtime
```

Do **not** contaminate the inference core with GUI-specific quirks.

------------------------------------------------------------------------

# 4. Definition of Done

A.E.S.I.R. earns **Msty Total Compatibility v1** only when all
applicable Msty Local AI features pass a reproducible certification
suite.

The golden acceptance test is:

> Install/configure Msty on a clean Windows test profile, substitute
> A.E.S.I.R. for its Ollama-compatible backend, and complete the entire
> local-AI feature matrix without launching an Ollama inference server.

The certification must include a packet/API trace proving which
A.E.S.I.R. endpoints were used.

------------------------------------------------------------------------

# 5. Phase 0: Freeze the Baseline

**Goal:** Preserve today's working state before compatibility work
changes the service.

Tasks:

-   Tag current A.E.S.I.R. state.
-   Record current `BEST_IN_CLASS_GAMEPLAN.md` slice.
-   Record current Ollama-compatible endpoints.
-   Record supported model families and quantizations.
-   Preserve known-good Gemma/Qwen/Llama fixtures.
-   Capture current service tests.
-   Record RTX 4070 driver/CUDA/WSL versions.
-   Record current Msty version.
-   Record the exact Msty Local AI/Ollama version currently bundled.
-   Export Msty Local AI settings relevant to the experiment.
-   Create `docs/msty/BASELINE.md`.

**Gate:** Existing A.E.S.I.R. tests remain green before any
Msty-specific work starts.

------------------------------------------------------------------------

# 6. Phase 1: Build the Msty Compatibility Observatory

This is the highest-leverage early work.

## 6.1 Create an Ollama protocol recorder

Build a local proxy capable of sitting between Msty and real Ollama:

``` text
Msty → Recorder Proxy → Ollama
```

Capture:

-   timestamp
-   method
-   route
-   headers
-   request body
-   response status
-   response headers
-   streamed chunks
-   chunk timing
-   connection close behavior
-   cancellation/disconnect
-   latency
-   retry behavior

Redact:

-   user prompts when requested
-   document contents
-   secrets
-   personal paths

Store fixtures as sanitized JSON/NDJSON.

## 6.2 Exercise every Msty feature against real Ollama

Create a controlled test notebook/checklist and touch every local
feature.

Do not infer what Msty probably does. **Observe it.**

## 6.3 Build a protocol corpus

Suggested structure:

``` text
tests/
  compatibility/
    msty/
      fixtures/
        startup/
        discovery/
        chat/
        streaming/
        embeddings/
        knowledge-stack/
        model-pull/
        model-import/
        model-delete/
        model-copy/
        model-show/
        model-ps/
        cancellation/
        keepalive/
        errors/
        vision/
        tools/
```

**Gate:** We can answer, with captured evidence, exactly which Ollama
calls Msty makes for every tested feature.

------------------------------------------------------------------------

# 7. Phase 2: Compatibility Matrix

Create `MSTY_COMPATIBILITY_MATRIX.md`.

Recommended columns:

  --------------------------------------------------------------------------------------------------
  Msty         Ollama            A.E.S.I.R.       Fixture    Test       Hardware   Notes
  capability   endpoint(s)       status                                 verified   
  ------------ ----------------- ---------------- ---------- ---------- ---------- -----------------
  Model list   `/api/tags`       Working          yes        yes        yes        

  Chat         `/api/chat`       Partial          yes        yes        yes        streaming missing

  Generate     `/api/generate`   Partial          yes        yes        yes        streaming missing

  Model info   `/api/show`       Working/verify   yes        yes        yes        schema parity

  Running      `/api/ps`         Missing          yes        no         no         
  models                                                                           

  Embeddings   embedding API     Missing          yes        no         no         Knowledge Stack
                                                                                   blocker

  Pull         `/api/pull`       Missing          yes        no         no         GUI model
                                                                                   downloads

  Create       `/api/create`     Missing          yes        no         no         model import/edit

  Delete       `/api/delete`     Missing          yes        no         no         

  Copy         `/api/copy`       Missing          yes        no         no         

  Streaming    chat/generate     Missing          yes        no         no         critical

  Tools        `/api/chat`       Missing          yes        no         no         

  Vision       `/api/chat`       Missing          yes        no         no         model-dependent
  --------------------------------------------------------------------------------------------------

Never mark a row `verified` without a test and evidence.

------------------------------------------------------------------------

# 8. Phase 3: NDJSON Streaming

**Priority: P0**

Msty must receive tokens naturally rather than waiting for an entire
completion.

Implement Ollama-compatible streaming for:

-   `/api/chat`
-   `/api/generate`

Requirements:

-   one valid JSON object per line
-   incremental text/message chunks
-   correct `done` state
-   final statistics object
-   correct content type
-   immediate flushing
-   graceful client disconnect
-   cooperative generation cancellation
-   no invalid partial UTF-8
-   bounded buffering
-   no accumulating full answer before sending
-   no corruption on multibyte Unicode
-   no stale chunks after cancellation

Architecture:

``` text
CUDA decode
   │ token
   ▼
UTF-8 incremental decoder
   │ safe text fragment
   ▼
Ollama stream event encoder
   │ NDJSON
   ▼
socket flush
```

Tests:

-   1-token response
-   1,000+ token response
-   Unicode
-   markdown
-   code blocks
-   cancellation halfway through
-   Msty Stop button
-   timeout
-   EOS
-   context exhaustion
-   disconnect
-   reconnect
-   immediate second request

**Gate:** Msty displays A.E.S.I.R. generation progressively and Stop
behaves normally.

------------------------------------------------------------------------

# 9. Phase 4: Exact Discovery and Metadata Compatibility

Implement/complete:

-   `/api/version`
-   `/api/tags`
-   `/api/show`
-   `/api/ps`

Match Ollama's practical schemas closely.

Model metadata should expose enough information for Msty to determine:

-   model name
-   family
-   parameter size
-   quantization
-   context capability
-   format
-   modification time
-   digest
-   model purpose where representable
-   running/resident state
-   memory footprint where expected

Avoid fabricated metadata. Unknown values should follow
Ollama-compatible omission/default behavior discovered from tests.

**Gate:** Every installed A.E.S.I.R. model appears correctly in Msty's
selector and relevant model-information UI.

------------------------------------------------------------------------

# 10. Phase 5: Model Lifecycle Compatibility

Implement Msty-required behavior for:

-   `/api/pull`
-   `/api/create`
-   `/api/delete`
-   `/api/copy`

Potentially add other endpoints discovered by the Observatory.

## Pull

Bridge A.E.S.I.R.'s existing native/resumable model downloader into
Ollama-compatible progress events.

Requirements:

-   streamed progress
-   resumable transfer
-   digest validation
-   atomic publication
-   cancellation
-   insufficient-space failure
-   network failure recovery
-   duplicate download deduplication
-   aliases/tags

## Create/import

Translate Ollama Modelfile behavior into A.E.S.I.R. recipes where
supported.

Support progressively:

-   `FROM`
-   `PARAMETER`
-   `SYSTEM`
-   `TEMPLATE`
-   adapter directives when A.E.S.I.R. supports them
-   model metadata

Never silently pretend unsupported directives worked.

## Delete

-   catalog-safe
-   content-address-aware
-   reference-count/dedup safe
-   atomic
-   no deleting shared blobs still referenced by another model

## Copy

-   alias/catalog operation when possible
-   zero-copy blob reuse
-   atomic destination creation

**Gate:** Msty can manage A.E.S.I.R. models through its normal GUI
without requiring a terminal for routine operations.

------------------------------------------------------------------------

# 11. Phase 6: Model Parameter Fidelity

Msty exposes substantial local-model configuration. A.E.S.I.R. needs a
translation registry.

Cover observed values including:

-   `num_ctx`
-   `num_predict`
-   `temperature`
-   `top_k`
-   `top_p`
-   `min_p`
-   `seed`
-   `repeat_penalty`
-   `repeat_last_n`
-   keep-alive
-   GPU selection
-   GPU layers where semantically meaningful
-   model-specific options
-   skip-streaming behavior
-   model instructions
-   templates
-   stop sequences

Classify each option:

-   **native exact**
-   **translated**
-   **accepted no-op only if Ollama itself effectively treats it that
    way**
-   **unsupported with explicit error**

Do not lie about hardware controls. For example, if A.E.S.I.R. uses a
different native GPU architecture, translate intent rather than
mimicking Ollama implementation details blindly.

**Gate:** Msty's model configuration UI produces the expected A.E.S.I.R.
behavior.

------------------------------------------------------------------------

# 12. Phase 7: Context, Templates, and Conversation Semantics

Msty depends heavily on conversation framing.

Implement robust support for:

-   system prompts
-   user/assistant history
-   continuation from assistant messages
-   edited messages
-   regeneration
-   sticky prompts
-   global prompts
-   model instructions
-   model templates
-   stop sequences
-   context limits
-   context truncation policy where expected
-   context shield behavior as observed at the Msty boundary

Add model-family chat-template registry:

``` text
Llama
Qwen
Gemma
Mistral
Phi
DeepSeek
...
```

GGUF metadata should drive template selection wherever reliable.

**Gate:** Long Msty conversations remain coherent across edits,
regeneration, continuation, model switching, and system-prompt changes.

------------------------------------------------------------------------

# 13. Phase 8: Embeddings, the Knowledge Stack Blocker

**Priority: P0/P1**

Msty Knowledge Stacks use embedding models. This is mandatory for total
replacement.

Implement Ollama-compatible embedding endpoint behavior observed from
the installed Msty/Ollama version.

A.E.S.I.R. embedding runtime requirements:

-   embedding-model architecture profiles
-   batched input
-   deterministic vectors
-   correct dimensionality
-   pooling strategy
-   normalization where model requires it
-   tokenizer fidelity
-   context limits
-   multiple strings/request if protocol expects it
-   GPU execution
-   CPU path later where useful
-   model-purpose metadata

Initial target models should include at least one strong modern small
local embedding model that runs comfortably on the 4070.

Tests:

-   exact vector dimensionality
-   deterministic repeatability
-   cosine-similarity sanity set
-   long input
-   Unicode
-   batch
-   empty/invalid input
-   Knowledge Stack indexing
-   Knowledge Stack retrieval
-   re-index
-   switching embedding models

**Gate:** Create a Knowledge Stack from scratch in Msty using only
A.E.S.I.R. local models, index documents, retrieve relevant chunks, and
answer with citations/context normally.

------------------------------------------------------------------------

# 14. Phase 9: Knowledge Stack End-to-End Certification

Test the full chain:

``` text
Document
  ↓
Msty parser/chunker
  ↓
A.E.S.I.R. embedding model
  ↓
Msty vector/index layer
  ↓
query embedding through A.E.S.I.R.
  ↓
retrieved chunks
  ↓
A.E.S.I.R. chat model
  ↓
answer
```

Exercise:

-   TXT
-   Markdown
-   PDF
-   DOCX
-   JSON
-   large documents
-   many documents
-   source filenames
-   rebuild/re-index
-   different similarity thresholds
-   different chunk counts
-   local reranking paths if they touch Ollama
-   multiple selected Knowledge Stacks

Measure:

-   indexing speed
-   embedding throughput
-   retrieval latency
-   VRAM behavior
-   model swapping cost
-   simultaneous embedding/chat residency feasibility

**Stretch target:** Keep a small embedding model resident alongside the
main chat model when VRAM permits.

------------------------------------------------------------------------

# 15. Phase 10: Model Residency and `/api/ps`

Build A.E.S.I.R.'s model lifecycle manager.

Capabilities:

-   enumerate loaded models
-   unload model
-   keep-alive timer
-   memory-pressure eviction
-   max-loaded-model policy
-   LRU or smarter policy
-   explicit pinning
-   chat ↔ embedding model switching
-   simultaneous residency when memory permits
-   deterministic cleanup
-   crash-safe catalog state

Use A.E.S.I.R.'s hardware-aware memory planner rather than copying
Ollama's scheduler blindly.

**Better-than-Ollama opportunity:** A.E.S.I.R. can eventually choose
residency based on actual model topology, KV requirements, available
VRAM, expected workload, and heterogeneous compute.

------------------------------------------------------------------------

# 16. Phase 11: Parallel Chat and Concurrency

Msty exposes parallel-chat/service settings.

Move beyond the current one-request-at-a-time service.

Stages:

1.  concurrent network connections
2.  bounded request queue
3.  cancellation of queued requests
4.  fair scheduling
5.  multiple loaded models
6.  concurrent embedding requests
7.  continuous/dynamic batching where beneficial
8.  paged KV integration
9.  shared-prefix opportunities
10. workload-aware scheduling

Do not introduce concurrency into GPU state until ownership and
isolation are proven.

**Gate:** Msty split chats can operate concurrently without corrupting
state or starving one another.

------------------------------------------------------------------------

# 17. Phase 12: Tool / Function Calling

Capture exactly how Msty represents tools for Ollama-backed models.

Implement:

-   tool definitions
-   tool-call generation
-   structured arguments
-   assistant tool-call messages
-   tool result messages
-   multi-turn tool loops
-   streaming tool-call deltas if required
-   malformed tool-call handling
-   model capability advertisement

The inference engine may need:

-   grammar/JSON constraints
-   family-specific tool templates
-   reliable structured-output support

**Gate:** An Msty local model using A.E.S.I.R. can invoke supported
tools through the same UI/workflow as Ollama.

------------------------------------------------------------------------

# 18. Phase 13: Vision and Multimodal

This is both protocol work and substantial inference-engine work.

Compatibility layer:

-   Ollama image fields/messages
-   base64/image transport
-   size limits
-   validation
-   Msty attachment behavior

Runtime:

-   multimodal GGUF/model loading
-   vision encoder
-   projector
-   image preprocessing
-   multimodal token injection
-   family-specific templates
-   GPU kernels
-   memory planning

Candidate families should be chosen based on modern usefulness and
implementation tractability rather than historical Msty defaults.

**Gate:** Paste/drop an image into Msty and receive a valid answer from
an A.E.S.I.R.-hosted vision model.

------------------------------------------------------------------------

# 19. Phase 14: Service Configuration Compatibility

Msty can pass Ollama service configuration/environment settings.

Build a compatibility registry for the settings Msty actually sends.

Examples to investigate:

-   parallel request count
-   max loaded models
-   keep alive
-   model path
-   allowed origins
-   GPU visibility
-   host/port
-   queue limits
-   flash-attention-like intent
-   KV-cache configuration

Separate:

``` text
Ollama setting
   ↓
compatibility translator
   ↓
A.E.S.I.R. semantic intent
   ↓
native scheduler/runtime setting
```

Do not expose implementation fiction merely to copy Ollama names.

------------------------------------------------------------------------

# 20. Phase 15: Windows Integration Strategy

First certification can use WSL2, but Msty is running on Windows.

## Stage A: WSL2 backend

Target:

``` text
Msty.exe
   ↓ localhost:11434
WSL2 A.E.S.I.R.
   ↓
CUDA
   ↓
RTX 4070
```

Verify Windows↔WSL localhost forwarding reliably.

Handle:

-   startup
-   shutdown
-   sleep/resume
-   Windows reboot
-   WSL restart
-   port conflicts
-   firewall
-   stale processes

## Stage B: A.E.S.I.R. launcher

Provide a Windows-side launcher/service helper that:

-   starts WSL2 A.E.S.I.R.
-   waits for readiness
-   exposes diagnostics
-   stops cleanly
-   detects port conflicts
-   reports GPU/runtime state

## Stage C: Native Windows

Only pursue if justified by the broader A.E.S.I.R. roadmap. Do not
derail the Mojo/runtime roadmap solely to eliminate WSL2 if the
integration is already transparent.

------------------------------------------------------------------------

# 21. Phase 16: Drop-In `msty-local` Experiment

Msty's documented Local AI engine is a bundled Ollama executable renamed
`msty-local.exe`.

Long-term, investigate two deployment modes.

### Mode A: External endpoint

Safest first target.

Msty connects to A.E.S.I.R. through its Ollama/Msty Remote
configuration.

### Mode B: True executable substitution

Explore whether an A.E.S.I.R. Windows launcher/shim can satisfy the
executable lifecycle Msty expects from `msty-local.exe`.

Observe:

-   command-line arguments
-   environment variables
-   working directory
-   model path variables
-   process signals
-   update/version probes
-   startup readiness
-   stdout/stderr expectations

Do not ship this until Msty's launcher contract is black-box tested.

**Ultimate UX goal:** the user selects A.E.S.I.R. and Msty simply works.

------------------------------------------------------------------------

# 22. Phase 17: Hugging Face and GGUF Import

Msty supports downloading/importing GGUFs.

Map its workflows onto A.E.S.I.R.'s store.

Requirements:

-   local GGUF import
-   link vs copy semantics if needed
-   SHA-256 identity
-   metadata inspection
-   architecture detection
-   tokenizer detection
-   quantization detection
-   context detection
-   template selection
-   model alias/tag creation
-   progress reporting
-   failure rollback

A.E.S.I.R. should eventually provide **better admission diagnostics**
than Ollama:

> "This Qwen model requires X GiB for weights + Y GiB estimated KV at
> 32K context; your RTX 4070 has Z GiB currently usable. Recommended
> context: N."

That is a natural A.E.S.I.R. advantage.

------------------------------------------------------------------------

# 23. Phase 18: Error Compatibility

Good compatibility includes failure behavior.

Build fixtures for:

-   model not found
-   corrupt GGUF
-   unsupported architecture
-   unsupported quantization
-   insufficient RAM
-   insufficient VRAM
-   invalid context
-   malformed request
-   cancelled pull
-   disk full
-   network lost
-   GPU failure
-   context overflow
-   invalid tool call
-   invalid image
-   service unavailable
-   port occupied

Msty should display a useful error rather than hanging, crashing, or
receiving an alien response shape.

------------------------------------------------------------------------

# 24. Phase 19: Performance Parity

Once feature parity works, compare A.E.S.I.R. and Ollama on identical
models.

Measure:

-   cold startup
-   model load
-   prompt processing
-   tokens/sec
-   time-to-first-token
-   sustained decode
-   embedding throughput
-   VRAM
-   host RAM
-   model-switch latency
-   Knowledge Stack indexing
-   concurrency
-   power where measurable

Test on the same:

-   GGUF
-   quantization
-   context
-   prompt
-   sampling settings
-   hardware

Store machine-readable benchmark results.

Do not claim superiority from mismatched configurations.

------------------------------------------------------------------------

# 25. Phase 20: Better-than-Ollama A.E.S.I.R. Extensions

After compatibility is complete, add advantages without breaking the
Ollama façade.

Potential A.E.S.I.R.-specific features:

-   smarter VRAM admission
-   hardware-aware model recommendations
-   native model-family diagnostics
-   heterogeneous CPU/GPU/NPU scheduling
-   paged KV
-   prefix sharing
-   better multi-model residency
-   ultra-low-memory edge profiles
-   deterministic content-addressed model storage
-   model integrity verification
-   native resumable Hugging Face downloads
-   advanced telemetry kept entirely local
-   explainable scheduler decisions
-   automatic quantization/kernel selection
-   architecture-specific optimized kernels
-   ThunderKittens/HipKittens-inspired kernels where clean-room work
    proves useful
-   ZLUDA/AMD experimentation where appropriate

Expose these through optional A.E.S.I.R. APIs while keeping standard
Ollama behavior intact.

------------------------------------------------------------------------

# 26. Automated Certification Harness

Create:

``` text
scripts/msty_compat/
```

Components:

``` text
record_ollama.py
replay_fixture.py
compare_responses.py
stream_validator.py
model_lifecycle_test.py
embedding_test.py
knowledge_stack_probe.py
cancel_test.py
concurrency_test.py
windows_wsl_probe.ps1
generate_report.py
```

Where Python is used as a test driver, inference remains native
A.E.S.I.R.

Produce:

``` text
artifacts/msty-compat-report.json
artifacts/msty-compat-report.md
```

Each feature gets:

-   PASS
-   PARTIAL
-   FAIL
-   NOT APPLICABLE
-   NOT TESTED

No aspirational PASS states.

------------------------------------------------------------------------

# 27. Differential Testing Against Ollama

For captured requests:

``` text
fixture
 ├──→ Ollama
 │      ↓
 │   response A
 │
 └──→ A.E.S.I.R.
        ↓
     response B
```

Compare **structure and semantics**, not generated wording.

Validate:

-   status code
-   headers
-   schema
-   required fields
-   field types
-   stream framing
-   terminal event
-   error shape
-   lifecycle effects
-   model state

Generated text itself should only be compared where deterministic
settings and identical implementation make such comparison meaningful.

------------------------------------------------------------------------

# 28. Msty Release Drift Defense

Msty and Ollama evolve.

Add versioned compatibility profiles:

``` text
compat/
  ollama/
    protocol/
  msty/
    v1/
    current/
```

At every relevant Msty update:

1.  run Msty against real current Ollama
2.  record new traffic
3.  diff protocol corpus
4.  run A.E.S.I.R. suite
5.  classify new requirements
6.  implement only evidenced compatibility changes

This prevents A.E.S.I.R. from chasing undocumented guesses.

------------------------------------------------------------------------

# 29. Security Rules

Because this backend controls local models and user documents:

-   loopback by default
-   no unauthenticated remote exposure by accident
-   explicit opt-in LAN mode
-   bounded request/body sizes
-   safe GGUF path handling
-   no arbitrary file reads through API parameters
-   atomic model publication
-   digest verification
-   symlink defenses
-   bounded decompression/parsing
-   no secrets in logs
-   no prompt/document logging by default
-   cancellation-safe resource cleanup
-   fuzz JSON/HTTP compatibility boundary
-   fuzz GGUF metadata admission separately

Compatibility must never require weakening the native service's security
posture silently.

------------------------------------------------------------------------

# 30. Repository Layout

Recommended additions:

``` text
docs/
  msty/
    README.md
    BASELINE.md
    MSTY_COMPATIBILITY_MATRIX.md
    MSTY_CERTIFICATION.md
    MSTY_WINDOWS_WSL.md
    MSTY_KNOWLEDGE_STACK.md
    MSTY_MODEL_MANAGEMENT.md
    MSTY_TROUBLESHOOTING.md

src/
  compat/
    ollama/
      routes.mojo
      schemas.mojo
      streaming.mojo
      errors.mojo
      options.mojo
      lifecycle.mojo
      embeddings.mojo

tests/
  compatibility/
    ollama/
    msty/
      fixtures/

scripts/
  msty_compat/
```

Exact paths should follow the repository's existing architecture rather
than forcing this layout if current conventions differ.

------------------------------------------------------------------------

# 31. Priority Order

## P0: Make Msty pleasant for ordinary text use

1.  Observatory/protocol capture
2.  compatibility matrix
3.  NDJSON streaming
4.  `/api/ps`
5.  exact discovery/show schema
6.  cancellation
7.  conversation/template fidelity
8.  Msty text-chat certification

## P1: Make Knowledge Stacks fully local

9.  embeddings API
10. native embedding runtime
11. embedding model management
12. Knowledge Stack indexing
13. Knowledge Stack retrieval
14. simultaneous chat + embedding lifecycle

## P2: Make Msty manage A.E.S.I.R. completely

15. pull
16. create/import
17. delete
18. copy/tag
19. progress streaming
20. keep-alive
21. max-loaded-model behavior
22. service settings translation

## P3: Advanced Msty features

23. concurrency
24. tool calling
25. structured output
26. vision/multimodal
27. broader model-family coverage

## P4: Invisible replacement

28. Windows launcher
29. lifecycle integration
30. possible `msty-local` executable substitution
31. clean-machine certification

## P5: Surpass the reference backend

32. scheduler improvements
33. paged KV
34. prefix reuse
35. heterogeneous compute
36. smarter model admission
37. A.E.S.I.R.-specific optional enhancements

------------------------------------------------------------------------

# 32. Milestones

### M0 --- Observed

Every relevant Msty↔Ollama interaction has a sanitized fixture.

### M1 --- Chat Ready

Msty discovers A.E.S.I.R. models and performs streamed multi-turn text
chat.

### M2 --- Daily Driver

Stop, regenerate, continue, templates, model parameters, switching, and
lifecycle work reliably.

### M3 --- Knowledge Ready

Knowledge Stacks can be indexed and queried using A.E.S.I.R. embeddings
and chat.

### M4 --- GUI Managed

Models can be downloaded, imported, copied, configured, and removed from
Msty without terminal intervention.

### M5 --- Advanced Local AI

Concurrency and applicable tool/structured-output features work.

### M6 --- Multimodal

Msty vision workflows operate through A.E.S.I.R.

### M7 --- Drop-In Certified

A clean Windows + Msty installation passes the complete compatibility
suite with A.E.S.I.R. replacing Ollama.

### M8 --- Better Than Reference

On selected workloads, controlled benchmarks demonstrate specific
measurable advantages without sacrificing compatibility.

------------------------------------------------------------------------

# 33. Non-Goals

This side quest must **not**:

-   replace `BEST_IN_CLASS_GAMEPLAN.md`
-   halt broader A.E.S.I.R. architecture work
-   turn the core into an Msty-specific engine
-   copy Ollama source code into A.E.S.I.R.
-   fake unsupported capabilities
-   accept compatibility regressions as permanent shortcuts
-   require cloud services
-   require Docker
-   weaken local-first operation

Msty is the first flagship compatibility target, not the owner of
A.E.S.I.R.'s architecture.

------------------------------------------------------------------------

# 34. First Implementation Sprint

A practical first sprint should be narrowly focused.

## Slice MSTY-001 --- Observatory

-   establish real-Ollama baseline
-   record Msty startup
-   record model discovery
-   record `/api/chat`
-   record cancellation
-   record model show
-   record running-model queries
-   record Knowledge Stack embedding calls
-   produce first compatibility matrix

## Slice MSTY-002 --- Streaming

-   implement native NDJSON writer
-   connect token generation to writer
-   add final Ollama statistics event
-   cancellation/disconnect handling
-   Unicode boundary tests
-   differential tests
-   Msty live-chat test

## Slice MSTY-003 --- Discovery/Lifecycle Minimum

-   implement `/api/ps`
-   close schema gaps in tags/show/version
-   implement keep-alive semantics needed by Msty
-   verify model switching

## Slice MSTY-004 --- Embedding Vertical Slice

-   select one embedding architecture/model
-   native load
-   native inference
-   pooling/normalization
-   Ollama-compatible endpoint
-   deterministic tests
-   Msty Knowledge Stack indexing
-   query/retrieval test

At that point A.E.S.I.R. becomes genuinely useful inside Msty rather
than merely protocol-compatible in isolation.

------------------------------------------------------------------------

# 35. Development Doctrine for This Roadmap

For every slice:

1.  **Observe.**
2.  **Specify.**
3.  **Implement the smallest real vertical slice.**
4.  **Test against A.E.S.I.R. directly.**
5.  **Differential-test against Ollama.**
6.  **Test through Msty.**
7.  **Record evidence.**
8.  **Update the compatibility matrix.**
9.  **Only then mark the capability verified.**

The guiding rule is:

> **Application behavior is the proof.**

------------------------------------------------------------------------

# 36. Final Target Architecture

``` text
                         ┌──────────────────────────────┐
                         │            Msty              │
                         │                              │
                         │ Chat • Splits • Knowledge    │
                         │ Models • Vision • Tools      │
                         └──────────────┬───────────────┘
                                        │
                              Ollama-compatible API
                                        │
                         ┌──────────────▼───────────────┐
                         │ A.E.S.I.R. Compatibility     │
                         │ Gateway                      │
                         │                              │
                         │ schemas • NDJSON • errors    │
                         │ lifecycle • embeddings       │
                         │ tools • multimodal           │
                         └──────────────┬───────────────┘
                                        │
                         ┌──────────────▼───────────────┐
                         │ A.E.S.I.R. Runtime           │
                         │                              │
                         │ model profiles • tokenizer   │
                         │ scheduler • KV • sampler     │
                         │ memory planner • catalog     │
                         └──────────────┬───────────────┘
                                        │
                  ┌─────────────────────┼─────────────────────┐
                  │                     │                     │
               NVIDIA                 CPU               Future compute
                CUDA                  path              AMD/Intel/NPU
                  │                     │                     │
                  └─────────────────────┴─────────────────────┘
                                        │
                                  Local Models
```

------------------------------------------------------------------------

# 37. Victory Condition

The side quest is complete when a user can install Msty, point it at
A.E.S.I.R., and simply use Msty normally.

They should be able to download or import models, chat, stream
responses, switch models, build Knowledge Stacks, use local embeddings,
manage model lifecycle, use supported tools and multimodal models,
change model settings, stop generation, run parallel workflows, and
restart the machine without needing to understand the compatibility
layer.

At that point the relationship becomes:

``` text
Msty = user experience
A.E.S.I.R. = local AI engine
```

Ollama is no longer required.

And that is the real milestone: **A.E.S.I.R. stops being only an
inference-engine project and becomes a backend that an ordinary polished
AI application can actually live on.**
